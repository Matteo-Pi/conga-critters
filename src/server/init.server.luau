--!strict
-- Server boot (spec 9.2): require every module in Services, call Init() on all of them, then Start() on all.
-- Init sets up state and must not depend on other services having started; Start may use any service.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Types = require(Shared:WaitForChild("Types") :: ModuleScript)

-- Config validator (spec 9.10): stops the start in Studio, warns in live servers.
require(script:WaitForChild("ConfigValidator") :: ModuleScript).Run()

-- Camera limits (Config/Camera). Set before any player joins; Player copies these from StarterPlayer on join.
StarterPlayer.CameraMaxZoomDistance = Config.Camera.CameraMaxZoomDistance

-- Characters don't collide with each other (spec 16). Before any player joins, so no character spawns without it.
require(script:WaitForChild("CharacterCollision") :: ModuleScript).Start()

-- Walk speed is applied in the shared simulation, never written by the server directly (Shared/WalkSpeedSync,
-- spec 9.1). A new character starts at the base speed, which an empty line walks at.
StarterPlayer.CharacterWalkSpeed = Config.Line.BaseWalkSpeed
require(Shared:WaitForChild("WalkSpeedSync") :: ModuleScript).Start()

-- Boot order: the services table in spec 9.2. Modules not listed here still load, after these, alphabetically.
local ORDER = {
	"DataService",
	"PlayerStateService",
	"MapService",
	"ThrowService",
	"LineService",
	"CutService",
	"DeliveryService",
	"PenService",
	"IncomeService",
	"UpgradeService",
	"IndexService",
	"DailyService",
	"ShieldService",
	"MonetisationService",
	"EventService",
	"AdminService",
	"AntiCheatService",
	"TelemetryService",
	"RebirthService",
	"FriendsService",
}

local TAG = "[Server]"
local logBoot: boolean = Config.Debug.LogBoot

local function orderedModules(folder: Instance): { ModuleScript }
	local byName: { [string]: ModuleScript } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			byName[child.Name] = child
		end
	end

	local ordered: { ModuleScript } = {}
	for _, name in ORDER do
		local module = byName[name]
		if module then
			table.insert(ordered, module)
			byName[name] = nil
		else
			warn(`{TAG} {name} is in the boot order but has no module`)
		end
	end

	local extras: { string } = {}
	for name in byName do
		table.insert(extras, name)
	end
	table.sort(extras)
	for _, name in extras do
		warn(`{TAG} {name} is not in the boot order; loading it last`)
		table.insert(ordered, byName[name])
	end
	return ordered
end

local bootStarted = os.clock()

local services: { { Name: string, Module: Types.Lifecycle } } = {}
for _, moduleScript in orderedModules(script:WaitForChild("Services")) do
	local module = require(moduleScript) :: any
	assert(
		type(module) == "table" and type(module.Init) == "function" and type(module.Start) == "function",
		`{TAG} {moduleScript.Name} must return a table with Init and Start functions`
	)
	table.insert(services, { Name = moduleScript.Name, Module = module })
end

for _, service in services do
	if logBoot then
		print(`{TAG} Init {service.Name}`)
	end
	service.Module.Init()
end

for _, service in services do
	if logBoot then
		print(`{TAG} Start {service.Name}`)
	end
	service.Module.Start()
end

print(`{TAG} Booted {#services} services in {string.format("%.1f", (os.clock() - bootStarted) * 1000)} ms`)
