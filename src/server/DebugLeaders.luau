--!strict
-- DebugLeaders: dummy characters that walk random paths with full lines, owned by negative ids (spec 9.10), for
-- performance tests (C01-M3 check 4). Not a service: AdminService's `leaders <k>` command drives it.
--
-- Each leader is a default R15 model named `DebugLeader_<n>` in `Workspace.DebugLeaders` (names from Config.Debug;
-- attribute `LeaderId` = −n). Clients find a leader's model by that name. It walks to random points inside one biome with server-side
-- Humanoid:MoveTo (biomes are convex, so straight walks stay inside) at the walk speed LineService sets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Odds = require(Shared:WaitForChild("Odds") :: ModuleScript)
local Zones = require(Shared:WaitForChild("Zones") :: ModuleScript)

local Services = script.Parent:WaitForChild("Services")
local LineService = require(Services:WaitForChild("LineService") :: ModuleScript)
local MapService = require(Services:WaitForChild("MapService") :: ModuleScript)

local DebugLeaders = {}

export type Leader = {
	Id: number, -- Config.Debug.LeaderIdBase − k (Studio test players already use −1, −2, …)
	Model: Model,
	Alive: boolean,
}

local FOLDER_NAME = Config.Debug.LeadersFolderName
local leaders: { Leader } = {}
local rng = Random.new()

local function folder(): Folder
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = workspace
	return created
end

function DebugLeaders.ModelName(id: number): string
	return `{Config.Debug.LeaderNamePrefix}{-id}`
end

local function floorAt(point: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { MapService.ZonesRoot(), folder() }
	local hit = workspace:Raycast(point + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else nil
end

-- A random floor point inside the biome, or nil after a few misses.
function DebugLeaders.RandomPoint(biomeId: string): Vector3?
	for _, part in Zones.Tagged(MapService.ZonesRoot(), "Biome") do
		if part:GetAttribute("BiomeId") ~= biomeId then
			continue
		end
		for _ = 1, 30 do
			local half = part.Size / 2
			local local_ = Vector3.new(rng:NextNumber(-half.X, half.X), 0, rng:NextNumber(-half.Z, half.Z))
			local point = part.CFrame:PointToWorldSpace(local_)
			if MapService.ZoneAt(point).BiomeId == biomeId then
				local floor = floorAt(point)
				if floor and MapService.ZoneAt(floor + Vector3.new(0, 1, 0)).BiomeId == biomeId then
					return floor
				end
			end
		end
	end
	return nil
end

local function makeEntries(biomeId: string, count: number): { any }
	local entries = {}
	for _ = 1, count do
		local result = Odds.Roll(biomeId, Odds.DefaultContext(), rng)
		if result then
			table.insert(entries, { Species = result.Species, Variant = result.Variant, Bound = false, Paid = false })
		end
	end
	return entries
end

local function wander(leader: Leader, biomeId: string)
	local humanoid = leader.Model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	while leader.Alive and leader.Model.Parent do
		local target = DebugLeaders.RandomPoint(biomeId)
		if target then
			humanoid:MoveTo(target)
			local done = false
			local connection = humanoid.MoveToFinished:Connect(function()
				done = true
			end)
			local started = os.clock()
			while not done and leader.Alive and os.clock() - started < 30 do
				task.wait(0.25)
			end
			connection:Disconnect()
		else
			task.wait(1)
		end
	end
end

local function spawnLeader(id: number, biomeId: string): Leader?
	local start = DebugLeaders.RandomPoint(biomeId)
	if not start then
		return nil
	end
	local description = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = DebugLeaders.ModelName(id)
	model:SetAttribute("LeaderId", id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	model:PivotTo(CFrame.new(start + Vector3.new(0, 3, 0)))
	model.Parent = folder()
	local leader: Leader = { Id = id, Model = model, Alive = true }
	LineService.AddLeader(id, model, makeEntries(biomeId, Config.Line.MaxCapacity))
	task.spawn(wander, leader, biomeId)
	return leader
end

local function removeLeader(leader: Leader)
	leader.Alive = false
	LineService.RemoveLeader(leader.Id)
	leader.Model:Destroy()
end

function DebugLeaders.Count(): number
	return #leaders
end

-- Spawn or remove leaders until there are `k`, in `biomeId` (the Meadow by default). Returns how many there are.
function DebugLeaders.Set(k: number, biomeId: string?): number
	local biome = biomeId or Config.Biomes.List[1].Id
	local target = math.clamp(math.floor(k), 0, Config.Debug.MaxLeaders)
	while #leaders > target do
		removeLeader(table.remove(leaders) :: Leader)
	end
	while #leaders < target do
		local leader = spawnLeader(Config.Debug.LeaderIdBase - (#leaders + 1), biome)
		if not leader then
			break
		end
		table.insert(leaders, leader)
	end
	return #leaders
end

-- Figure-of-eight walk (C01-M3 check 1): MCP's character_navigation desyncs under Server Authority, so the server
-- walks the character with Humanoid:MoveTo along a lemniscate x = A sin t, z = A sin t cos t in the biome's own
-- frame (x across the biome), centred `depth` studs in from its entrance, waypoint to waypoint.
export type Walk =
	{ Running: boolean, Lap: number, Laps: number, Distance: number, StartedAt: number, EndedAt: number? }

local currentWalk: Walk? = nil

function DebugLeaders.WalkStatus(): Walk?
	return currentWalk
end

function DebugLeaders.StopWalk(): ()
	if currentWalk then
		currentWalk.Running = false
	end
end

-- A biome's entrance (the end of its Biome zone nearer the hub at the origin), the direction into it and the
-- direction across it. Nil if the biome has no Biome zone.
function DebugLeaders.BiomeFrame(biomeId: string): (Vector3?, Vector3, Vector3)
	for _, part in Zones.Tagged(MapService.ZonesRoot(), "Biome") do
		if part:GetAttribute("BiomeId") == biomeId then
			local frame = part.CFrame
			local half = part.Size.Z / 2
			local front = frame:PointToWorldSpace(Vector3.new(0, 0, -half)) -- along LookVector
			local back = frame:PointToWorldSpace(Vector3.new(0, 0, half))
			if front.Magnitude < back.Magnitude then
				return front, -frame.LookVector, frame.RightVector
			end
			return back, frame.LookVector, frame.RightVector
		end
	end
	return nil, Vector3.zAxis, Vector3.xAxis
end

-- A floor point `depth` studs into the biome along its axis.
function DebugLeaders.PointInBiome(biomeId: string, depth: number): Vector3?
	local entrance, inward = DebugLeaders.BiomeFrame(biomeId)
	if not entrance then
		return nil
	end
	return floorAt(entrance + inward * depth)
end

function DebugLeaders.WalkFigureEight(
	humanoid: Humanoid,
	biomeId: string,
	size: number,
	laps: number,
	depth: number
): string
	local entrance, inward, across = DebugLeaders.BiomeFrame(biomeId)
	if not entrance then
		return `no Biome zone for {biomeId}`
	end
	local root = humanoid.RootPart
	if not root then
		return "no root part"
	end
	local centre = entrance + inward * depth

	local waypoints: { Vector3 } = {}
	local steps = 64
	for i = 0, steps - 1 do
		local t = i / steps * 2 * math.pi
		local p = centre + across * (size * math.sin(t)) + inward * (size * math.sin(t) * math.cos(t))
		local floor = floorAt(p)
		if not floor then
			return string.format("no floor at (%.0f, %.0f)", p.X, p.Z)
		end
		table.insert(waypoints, floor)
	end

	DebugLeaders.StopWalk()
	local walk: Walk = { Running = true, Lap = 0, Laps = laps, Distance = 0, StartedAt = os.clock(), EndedAt = nil }
	currentWalk = walk
	task.spawn(function()
		local last = root.Position
		-- Walk to the start point first (not counted as a lap).
		local function goTo(point: Vector3): boolean
			humanoid:MoveTo(point)
			local started = os.clock()
			while walk.Running do
				local here = root.Position
				walk.Distance += (Vector3.new(here.X, 0, here.Z) - Vector3.new(last.X, 0, last.Z)).Magnitude
				last = here
				if (Vector3.new(here.X - point.X, 0, here.Z - point.Z)).Magnitude < 2.5 then
					return true
				end
				if os.clock() - started > 20 then
					return false
				end
				humanoid:MoveTo(point) -- MoveTo times out after 8 s on its own
				task.wait(0.05)
			end
			return false
		end
		goTo(waypoints[1])
		walk.Distance = 0
		walk.StartedAt = os.clock()
		while walk.Running and walk.Lap < walk.Laps do
			for i = 2, #waypoints + 1 do
				if not walk.Running or not goTo(waypoints[(i - 1) % #waypoints + 1]) then
					walk.Running = false
					break
				end
			end
			if walk.Running then
				walk.Lap += 1
			end
		end
		humanoid:MoveTo(root.Position)
		walk.Running = false
		walk.EndedAt = os.clock()
	end)
	return string.format(
		"figure-of-eight: %d waypoints, half-width %d studs, centre (%.0f, %.0f), %d laps",
		#waypoints,
		size,
		centre.X,
		centre.Z,
		laps
	)
end

return DebugLeaders
