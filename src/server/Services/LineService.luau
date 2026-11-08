--!strict
-- LineService: line state, capacity, walk speed, server paths, LineSync (spec 9.2).
-- C01-M2: just enough line for throwing: length, critters on their way and capacity (spec 4.3). Following, walk
-- speed, server paths and LineSync arrive in C01-M3. The line itself lives in the PlayerStateService session.
--
--   capacity = min(MaxCapacity, floor((leash capacity + RebirthLeashBonus × rebirths) × (Longer Leash ? ×1.5 : 1)))
--   room     = capacity − length − critters on their way
--
-- Display copies on the Player (spec 9.4): `LineLen` and `LineCap`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)

local PlayerStateService = require(script.Parent:WaitForChild("PlayerStateService") :: ModuleScript)

type LineEntry = PlayerStateService.LineEntry

local LineService = {}

-- Pure capacity rule, so checks can test it without a player.
function LineService.CapacityFor(leashLevel: number, rebirths: number, longerLeash: boolean): number
	local levels = Config.Upgrades.Tracks.Leash.Levels
	local leash = levels[math.clamp(math.floor(leashLevel), 1, #levels)].Value
	local base = leash + Config.Line.RebirthLeashBonus * rebirths
	local multiplier = if longerLeash then Config.Line.LongerLeashMultiplier else 1
	return math.min(Config.Line.MaxCapacity, math.floor(base * multiplier))
end

function LineService.Capacity(player: Player): number
	local session = PlayerStateService.Get(player)
	if not session then
		return 0
	end
	return LineService.CapacityFor(session.Upgrades.Leash, session.Rebirths, session.LongerLeash)
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

local function publish(player: Player)
	local session = PlayerStateService.Get(player)
	if not session then
		return
	end
	player:SetAttribute("LineLen", #session.Line.Entries)
	player:SetAttribute("LineCap", LineService.Capacity(player))
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
	if not session then
		return false
	end
	session.Line.Incoming = math.max(0, session.Line.Incoming - 1)
	if #session.Line.Entries >= LineService.Capacity(player) then
		return false
	end
	table.insert(session.Line.Entries, entry)
	publish(player)
	return true
end

-- Debug (spec 9.10): fill the line to `count` entries made by `make`, capped at capacity. Returns the new length.
function LineService.Fill(player: Player, count: number, make: () -> LineEntry): number
	local session = PlayerStateService.Get(player)
	if not session then
		return 0
	end
	local target = math.clamp(math.floor(count), 0, LineService.Capacity(player))
	local entries = session.Line.Entries
	while #entries > target do
		table.remove(entries)
	end
	while #entries < target do
		table.insert(entries, make())
	end
	publish(player)
	return #entries
end

-- Debug: set the Leash level (upgrades arrive in C01-M4).
function LineService.SetLeashLevel(player: Player, level: number): ()
	local session = PlayerStateService.Get(player)
	if not session then
		return
	end
	local levels = Config.Upgrades.Tracks.Leash.Levels
	session.Upgrades.Leash = math.clamp(math.floor(level), 1, #levels)
	publish(player)
end

function LineService.Init(): () end

function LineService.Start(): ()
	Players.PlayerAdded:Connect(publish)
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

export type LineService = typeof(LineService)

return LineService
