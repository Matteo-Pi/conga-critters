--!strict
-- MapService: zones, pen assignment, gate and pen access (spec 3, 9.2).
-- The map lives in the place file (Workspace.Map); zone parts are tagged under Workspace.Map.Zones (spec 3.2).
--
-- C01-M1: zone queries and pen assignment. Each player gets the lowest free pen plot when they join and frees it
-- when they leave; a rejoining player gets whichever pen is free then. The pen number is also a `PenIndex`
-- attribute on the Player so clients can find their own pen.
-- New players spawn at FirstSpawn (the only SpawnLocation). Spawning returning players at their pen needs saved
-- data and arrives with DataService in C01-M4, as do the gate and pen access checks (spec 16).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Zones") :: ModuleScript)

local TAG = "[MapService]"

local MapService = {}

-- Pen allocator: pure, so the checks can drive it with fake players.
export type PenAllocator = {
	Assign: (self: PenAllocator, key: any) -> number?,
	Release: (self: PenAllocator, key: any) -> (),
	PenOf: (self: PenAllocator, key: any) -> number?,
	OwnerOf: (self: PenAllocator, index: number) -> any,
	Count: number,
}

function MapService.NewPenAllocator(count: number): PenAllocator
	local owners: { [number]: any } = {}
	local pens: { [any]: number } = {}
	local allocator = {} :: PenAllocator
	allocator.Count = count

	function allocator.Assign(_self: PenAllocator, key: any): number?
		if pens[key] then
			return pens[key]
		end
		for index = 1, count do
			if owners[index] == nil then
				owners[index] = key
				pens[key] = index
				return index
			end
		end
		return nil
	end

	function allocator.Release(_self: PenAllocator, key: any): ()
		local index = pens[key]
		if index then
			owners[index] = nil
			pens[key] = nil
		end
	end

	function allocator.PenOf(_self: PenAllocator, key: any): number?
		return pens[key]
	end

	function allocator.OwnerOf(_self: PenAllocator, index: number): any
		return owners[index]
	end

	return allocator
end

local zonesRoot: Instance? = nil
local penParts: { [number]: BasePart } = {}
local allocator: PenAllocator? = nil

function MapService.ZonesRoot(): Instance
	assert(zonesRoot, `{TAG} not initialised`)
	return zonesRoot
end

-- Every zone a world point is in.
function MapService.ZoneAt(point: Vector3): Zones.ZoneInfo
	return Zones.Classify(MapService.ZonesRoot(), point)
end

function MapService.PenCount(): number
	return if allocator then allocator.Count else 0
end

function MapService.GetPen(player: Player): number?
	return if allocator then allocator:PenOf(player) else nil
end

function MapService.PenOwner(index: number): Player?
	local owner = if allocator then allocator:OwnerOf(index) else nil
	return if typeof(owner) == "Instance" and owner:IsA("Player") then owner else nil
end

function MapService.PenPart(index: number): BasePart?
	return penParts[index]
end

-- Where a returning player spawns: the pen's `Spawn` attachment (spec 3.2 note in 16), else the pen centre.
function MapService.PenSpawnCFrame(index: number): CFrame?
	local part = penParts[index]
	if not part then
		return nil
	end
	local spawn = part:FindFirstChild("Spawn")
	if spawn and spawn:IsA("Attachment") then
		return spawn.WorldCFrame
	end
	return part.CFrame
end

local function onPlayerAdded(player: Player)
	assert(allocator, `{TAG} not initialised`)
	if allocator:PenOf(player) or player.Parent ~= Players then
		return -- already assigned (Start's sweep and a queued PlayerAdded), or already gone
	end
	local index = allocator:Assign(player)
	if index then
		player:SetAttribute("PenIndex", index)
		print(`{TAG} {player.Name} ({player.UserId}) -> pen {index}`)
	else
		warn(`{TAG} no free pen for {player.Name}: all {allocator.Count} are taken`)
	end
end

local function onPlayerRemoving(player: Player)
	if not allocator then
		return
	end
	local index = allocator:PenOf(player)
	allocator:Release(player)
	if index then
		print(`{TAG} {player.Name} left; pen {index} is free`)
	end
end

function MapService.Init(): ()
	local map = workspace:WaitForChild("Map")
	local root = map:WaitForChild("Zones")
	zonesRoot = root

	for _, part in Zones.Tagged(root, "Pen") do
		local index = part:GetAttribute("PenIndex")
		if type(index) == "number" then
			if penParts[index] then
				warn(`{TAG} two pens have PenIndex {index}`)
			end
			penParts[index] = part
		else
			warn(`{TAG} {part:GetFullName()} has no PenIndex`)
		end
	end

	local count = 0
	while penParts[count + 1] do
		count += 1
	end
	if count == 0 then
		warn(`{TAG} no Pen zones found under {root:GetFullName()}`)
	end
	allocator = MapService.NewPenAllocator(count)
end

function MapService.Start(): ()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

export type MapService = typeof(MapService)

return MapService
