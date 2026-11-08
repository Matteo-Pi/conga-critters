--!strict
-- ZoneController: zone-aware buttons (spec 9.2). Polls which zone the local character is in, ZonePollHz times a
-- second, using the same Zones.luau maths as the server. Map.Zones is Persistent, so every client always has it
-- (spec 3.2). Display only: the server makes its own zone decisions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Zones = require(Shared:WaitForChild("Zones") :: ModuleScript)

local ZoneController = {}

local zonesRoot: Instance? = nil
local current: Zones.ZoneInfo = { Safe = false }
local currentKey = Zones.Describe(current)
local listeners: { (Zones.ZoneInfo) -> () } = {}

-- The zone the local character was last seen in ({ Safe = false } with no character).
function ZoneController.Current(): Zones.ZoneInfo
	return current
end

-- Every zone a world point is in; nil until Map.Zones has arrived.
function ZoneController.Classify(point: Vector3): Zones.ZoneInfo?
	return if zonesRoot then Zones.Classify(zonesRoot, point) else nil
end

-- Called with the new zone whenever it changes.
function ZoneController.OnChanged(listener: (Zones.ZoneInfo) -> ()): ()
	table.insert(listeners, listener)
end

local function poll()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local info: Zones.ZoneInfo = { Safe = false }
	if zonesRoot and root and root:IsA("BasePart") then
		info = Zones.Classify(zonesRoot, root.Position)
	end
	local key = Zones.Describe(info)
	current = info
	if key ~= currentKey then
		currentKey = key
		for _, listener in listeners do
			task.spawn(listener, info)
		end
	end
end

function ZoneController.Init(): () end

function ZoneController.Start(): ()
	task.spawn(function()
		zonesRoot = workspace:WaitForChild("Map"):WaitForChild("Zones")
	end)
	local interval = 1 / Config.Throw.ZonePollHz
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= interval then
			elapsed = 0
			poll()
		end
	end)
end

export type ZoneController = typeof(ZoneController)

return ZoneController
