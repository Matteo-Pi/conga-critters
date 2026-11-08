--!strict
-- LineService: line state, capacity, walk speed, server paths, LineSync (spec 4.3, 9.4, 9.5).
--
-- One line per owner id: a player's UserId, or a negative id for a debug leader (spec 9.10). A player's entries are
-- the session's own table (PlayerStateService), so the line ends with the session. Rules (shared LineRules):
--   capacity  = min(MaxCapacity, floor((leash capacity + RebirthLeashBonus × rebirths) × (Longer Leash ? ×1.5 : 1)))
--   room      = capacity − length − critters on their way
--   walkSpeed = Speed track value × max(0.6, 1 − 0.0015 × length), set on the Humanoid by the server
--
-- Server paths (9.5): each leader's ground position is recorded ServerSampleHz times a second into a shared Path;
-- `FollowerPositions` places the followers from it (for cuts, C01-M5). Clients keep their own paths for drawing.
--
-- LineSync (9.4): every change goes to all clients with the line's next sequence number: `append` for arrivals,
-- `removeFront` for deliveries, `snapshot` for anything else (debug fill, cuts), `clear` when the line ends. A
-- client asks with RequestLineSync (1 per 2 s) on joining and after a gap, and gets a snapshot of every line.
--
-- Display copies on the Player (9.4): `LineLen` and `LineCap`.
-- If the character dies (4.3), the line is kept for now: banking arrives with C01-M4 and loose critters with C01-M5.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local LineRules = require(Shared:WaitForChild("LineRules") :: ModuleScript)
local Net = require(Shared:WaitForChild("Net") :: ModuleScript)
local Path = require(Shared:WaitForChild("Path") :: ModuleScript)

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService") :: ModuleScript)

type LineEntry = PlayerStateService.LineEntry

local LineService = {}

type Line = {
	OwnerId: number,
	Player: Player?, -- nil for debug leaders
	Model: Model?, -- debug leaders only
	Entries: { LineEntry },
	Seq: number,
	Offsets: { number }, -- cumulative spacing behind the leader
	Path: Path.Path?, -- nil until the leader has a character
}

local lines: { [number]: Line } = {}
local lineSync: RemoteEvent? = nil

-- Scratch arrays for FollowerPositions.
local scratchPos: { Vector3 } = {}
local scratchDir: { Vector3 } = {}

local function sync(): RemoteEvent
	return assert(lineSync, "LineService not initialised")
end

local function packEntry(entry: LineEntry): number
	return Net.PackCritter(Config.Critters.IndexById[entry.Species] or 0, entry.Variant, entry.Bound)
end

local function packAll(entries: { LineEntry }, from: number?): { number }
	local packed = table.create(#entries)
	for i = from or 1, #entries do
		table.insert(packed, packEntry(entries[i]))
	end
	return packed
end

local function rebuildOffsets(line: Line)
	local entries = line.Entries
	Path.Offsets(#entries, function(i)
		return LineRules.Spacing(entries[i].Species)
	end, line.Offsets)
end

-- Pure capacity rule, so checks can test it without a player.
function LineService.CapacityFor(leashLevel: number, rebirths: number, longerLeash: boolean): number
	return LineRules.Capacity(leashLevel, rebirths, longerLeash)
end

function LineService.Capacity(player: Player): number
	local session = PlayerStateService.Get(player)
	if not session then
		return 0
	end
	return LineRules.Capacity(session.Upgrades.Leash, session.Rebirths, session.LongerLeash)
end

local function capacityOf(line: Line): number
	if line.Player then
		return LineService.Capacity(line.Player)
	end
	return Config.Line.MaxCapacity
end

-- The player's line, created on first use. Nil for a player who has left.
local function lineFor(player: Player): Line?
	local session = PlayerStateService.Get(player)
	if not session then
		return nil
	end
	local line = lines[player.UserId]
	if line and line.Player == player then
		line.Entries = session.Line.Entries
		return line
	end
	local created: Line = {
		OwnerId = player.UserId,
		Player = player,
		Model = nil,
		Entries = session.Line.Entries,
		Seq = 0,
		Offsets = {},
		Path = nil,
	}
	rebuildOffsets(created)
	lines[player.UserId] = created
	return created
end

local function character(line: Line): (BasePart?, Humanoid?)
	local model: Model? = if line.Player then line.Player.Character else line.Model
	if not model then
		return nil, nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") then
		return nil, humanoid
	end
	return root, humanoid
end

function LineService.WalkSpeedOf(ownerId: number): number
	local line = lines[ownerId]
	if not line then
		return 0
	end
	local speedLevel = 1
	if line.Player then
		local session = PlayerStateService.Get(line.Player)
		speedLevel = if session then session.Upgrades.Speed else 1
	end
	return LineRules.WalkSpeed(speedLevel, #line.Entries)
end

local function applyWalkSpeed(line: Line)
	local _, humanoid = character(line)
	if humanoid then
		local speed = LineService.WalkSpeedOf(line.OwnerId)
		if math.abs(humanoid.WalkSpeed - speed) > 1e-3 then
			humanoid.WalkSpeed = speed
		end
	end
end

local function publish(line: Line)
	local player = line.Player
	if player then
		player:SetAttribute("LineLen", #line.Entries)
		player:SetAttribute("LineCap", LineService.Capacity(player))
	end
	if line.Path then
		Path.SetKeep(line.Path, LineRules.PathKeep(capacityOf(line)))
	end
	applyWalkSpeed(line)
end

local function changed(line: Line, op: Net.LineSyncOp, entries: { number }?, count: number?)
	rebuildOffsets(line)
	line.Seq += 1
	local payload: Net.LineSyncPayload =
		{ userId = line.OwnerId, seq = line.Seq, op = op, entries = entries, count = count }
	sync():FireAllClients(payload)
	publish(line)
end

local function snapshotPayload(line: Line): Net.LineSyncPayload
	return { userId = line.OwnerId, seq = line.Seq, op = "snapshot", entries = packAll(line.Entries) }
end

function LineService.Length(player: Player): number
	local session = PlayerStateService.Get(player)
	return if session then #session.Line.Entries else 0
end

function LineService.Incoming(player: Player): number
	local session = PlayerStateService.Get(player)
	return if session then session.Line.Incoming else 0
end

-- Free places: capacity minus the line and the critters on their way.
function LineService.Room(player: Player): number
	local session = PlayerStateService.Get(player)
	if not session then
		return 0
	end
	return math.max(0, LineService.Capacity(player) - #session.Line.Entries - session.Line.Incoming)
end

-- The line's entries (read-only by convention).
function LineService.Entries(player: Player): { LineEntry }
	local session = PlayerStateService.Get(player)
	return if session then session.Line.Entries else {}
end

-- A critter is on its way (a throw was accepted).
function LineService.Reserve(player: Player, count: number): ()
	local session = PlayerStateService.Get(player)
	if session then
		session.Line.Incoming += count
	end
end

-- Critters on their way that will never arrive.
function LineService.Cancel(player: Player, count: number): ()
	local session = PlayerStateService.Get(player)
	if session then
		session.Line.Incoming = math.max(0, session.Line.Incoming - count)
	end
end

-- A critter on its way arrives. Returns false, and drops it, if the owner left or the line is full by now.
function LineService.Arrive(player: Player, entry: LineEntry): boolean
	local session = PlayerStateService.Get(player)
	local line = lineFor(player)
	if not session or not line then
		return false
	end
	session.Line.Incoming = math.max(0, session.Line.Incoming - 1)
	if #line.Entries >= LineService.Capacity(player) then
		return false
	end
	table.insert(line.Entries, entry)
	changed(line, "append", { packEntry(entry) })
	return true
end

-- The front `count` critters leave (delivery, C01-M4). Returns them, front first.
function LineService.RemoveFront(player: Player, count: number): { LineEntry }
	local line = lineFor(player)
	if not line then
		return {}
	end
	local n = math.clamp(math.floor(count), 0, #line.Entries)
	if n == 0 then
		return {}
	end
	local removed = table.move(line.Entries, 1, n, 1, {})
	table.move(line.Entries, n + 1, #line.Entries + n, 1)
	changed(line, "removeFront", nil, n)
	return removed
end

-- Replace the whole line (cuts, C01-M5). Entries beyond capacity are dropped.
function LineService.SetEntries(player: Player, entries: { LineEntry }): ()
	local line = lineFor(player)
	if not line then
		return
	end
	table.clear(line.Entries)
	for i = 1, math.min(#entries, LineService.Capacity(player)) do
		table.insert(line.Entries, entries[i])
	end
	changed(line, "snapshot", packAll(line.Entries))
end

function LineService.Clear(player: Player): ()
	local line = lineFor(player)
	if not line then
		return
	end
	table.clear(line.Entries)
	changed(line, "clear")
end

-- Debug (spec 9.10): fill the line to `count` entries made by `make`, capped at capacity. Returns the new length.
function LineService.Fill(player: Player, count: number, make: () -> LineEntry): number
	local line = lineFor(player)
	if not line then
		return 0
	end
	local target = math.clamp(math.floor(count), 0, LineService.Capacity(player))
	local entries = line.Entries
	while #entries > target do
		table.remove(entries)
	end
	while #entries < target do
		table.insert(entries, make())
	end
	changed(line, "snapshot", packAll(entries))
	return #entries
end

-- Debug: set the Leash level (upgrades arrive in C01-M4).
function LineService.SetLeashLevel(player: Player, level: number): ()
	local session = PlayerStateService.Get(player)
	local line = lineFor(player)
	if not session or not line then
		return
	end
	local levels = Config.Upgrades.Tracks.Leash.Levels
	session.Upgrades.Leash = math.clamp(math.floor(level), 1, #levels)
	publish(line)
end

-- Debug: set the Speed level (upgrades arrive in C01-M4).
function LineService.SetSpeedLevel(player: Player, level: number): ()
	local session = PlayerStateService.Get(player)
	local line = lineFor(player)
	if not session or not line then
		return
	end
	local levels = Config.Upgrades.Tracks.Speed.Levels
	session.Upgrades.Speed = math.clamp(math.floor(level), 1, #levels)
	publish(line)
end

-- Debug: own or lose the Longer Leash pass for this session (MonetisationService arrives in C01-M6).
function LineService.SetLongerLeash(player: Player, owned: boolean): ()
	local session = PlayerStateService.Get(player)
	local line = lineFor(player)
	if not session or not line then
		return
	end
	session.LongerLeash = owned
	publish(line)
end

-- Debug leaders (spec 9.10): a line owned by a negative id, led by a dummy model.
function LineService.AddLeader(ownerId: number, model: Model, entries: { LineEntry }): ()
	assert(ownerId < 0, "debug leaders use negative ids")
	local existing = lines[ownerId]
	if existing then
		LineService.RemoveLeader(ownerId)
	end
	local line: Line = {
		OwnerId = ownerId,
		Player = nil,
		Model = model,
		Entries = entries,
		Seq = 0,
		Offsets = {},
		Path = nil,
	}
	lines[ownerId] = line
	changed(line, "snapshot", packAll(entries))
end

function LineService.RemoveLeader(ownerId: number): ()
	local line = lines[ownerId]
	if not line or line.Player then
		return
	end
	table.clear(line.Entries)
	changed(line, "clear")
	lines[ownerId] = nil
end

-- Server-side follower positions (ground level), front first, for cuts and checks. The arrays are reused by the
-- next call: copy anything you keep. Returns the positions and how many there are (0 without a path).
function LineService.FollowerPositions(ownerId: number): ({ Vector3 }, number)
	local line = lines[ownerId]
	if not line or not line.Path then
		return scratchPos, 0
	end
	local root, humanoid = character(line)
	if not root then
		return scratchPos, 0
	end
	local count = #line.Entries
	Path.Sample(line.Path, Path.LiveHead(line.Path, root, humanoid), line.Offsets, count, scratchPos, scratchDir)
	return scratchPos, count
end

-- Debug: the server path's point count, studs kept behind the leader, its newest `n` points, and its hop markers
-- (path distances).
function LineService.PathInfo(ownerId: number, n: number): (number, number, { Vector3 }, { number })
	local line = lines[ownerId]
	local path = line and line.Path
	if not line or not path then
		return 0, 0, {}, {}
	end
	local root, humanoid = character(line)
	local head = if root then Path.LiveHead(path, root, humanoid) else Vector3.zero
	return path.Count, Path.Length(path, head), Path.Newest(path, n), table.clone(path.HopDist)
end

-- Every line's owner id and length (debug and checks).
function LineService.Lines(): { [number]: number }
	local out: { [number]: number } = {}
	for ownerId, line in lines do
		out[ownerId] = #line.Entries
	end
	return out
end

local function sample()
	for _, line in lines do
		local root, humanoid = character(line)
		if not root or (humanoid and humanoid.Health <= 0) then
			line.Path = nil -- start again when the leader is back
			continue
		end
		local path = line.Path
		if not path then
			path = Path.new(LineRules.PathKeep(capacityOf(line)))
			line.Path = path
		end
		-- Ground height only, never in the air (4.3); a take-off leaves a hop marker.
		local ground, airborne = Path.Locate(path, root, humanoid)
		Path.Record(path, ground, airborne, -root.CFrame.LookVector)
		Path.DropPassed(path, Path.FollowDistance(path, ground) - (line.Offsets[#line.Entries] or 0))
		applyWalkSpeed(line)
	end
end

local function onRequestLineSync(player: Player)
	local session = PlayerStateService.Get(player)
	if not session or not session.SyncBucket:Take(os.clock()) then
		return
	end
	for _, line in lines do
		sync():FireClient(player, snapshotPayload(line))
	end
end

function LineService.Init(): ()
	lineSync = Net.Event(Net.Names.LineSync)
	Net.Event(Net.Names.RequestLineSync).OnServerEvent:Connect(onRequestLineSync)
end

function LineService.Start(): ()
	local function onPlayerAdded(player: Player)
		local line = lineFor(player)
		if line then
			publish(line)
		end
		player.CharacterAdded:Connect(function()
			local current = lineFor(player)
			if current then
				current.Path = nil
				applyWalkSpeed(current)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		local line = lines[player.UserId]
		if line and line.Player == player then
			lines[player.UserId] = nil
			line.Seq += 1
			sync():FireAllClients({ userId = player.UserId, seq = line.Seq, op = "clear" } :: Net.LineSyncPayload)
		end
	end)

	local interval = 1 / Config.Line.Path.ServerSampleHz
	local carry = 0
	RunService.Heartbeat:Connect(function(dt: number)
		carry += dt
		if carry < interval then
			return
		end
		carry = math.min(carry - interval, interval)
		sample()
	end)
end

export type LineService = typeof(LineService)

return LineService
