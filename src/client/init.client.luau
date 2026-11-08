--!strict
-- Client boot (spec 9.2): require every module in Controllers, call Init() on all of them, then Start() on all.
-- Init sets up state and must not depend on other controllers having started; Start may use any controller.
-- Server Authority turns on streaming and deferred signals, so everything is fetched with WaitForChild.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript) :: any
local Types = require(Shared:WaitForChild("Types") :: ModuleScript)

-- Walk speed is applied in the shared simulation, on the same step as the server (Shared/WalkSpeedSync, spec 9.1).
require(Shared:WaitForChild("WalkSpeedSync") :: ModuleScript).Start()

-- Boot order: the controllers table in spec 9.2. Modules not listed here still load, after these, alphabetically.
local ORDER = {
	"InputController",
	"LineRenderer",
	"CritterFx",
	"PenRenderer",
	"HudController",
	"UpgradesUI",
	"IndexUI",
	"PenUI",
	"StoreUI",
	"OddsUI",
	"DailyUI",
	"RebirthUI",
	"ToastController",
	"TutorialController",
	"EventUI",
	"SoundController",
	"ZoneController",
}

local TAG = "[Client]"
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

local controllers: { { Name: string, Module: Types.Lifecycle } } = {}
for _, moduleScript in orderedModules(script:WaitForChild("Controllers")) do
	local module = require(moduleScript) :: any
	assert(
		type(module) == "table" and type(module.Init) == "function" and type(module.Start) == "function",
		`{TAG} {moduleScript.Name} must return a table with Init and Start functions`
	)
	table.insert(controllers, { Name = moduleScript.Name, Module = module })
end

for _, controller in controllers do
	if logBoot then
		print(`{TAG} Init {controller.Name}`)
	end
	controller.Module.Init()
end

for _, controller in controllers do
	if logBoot then
		print(`{TAG} Start {controller.Name}`)
	end
	controller.Module.Start()
end

print(`{TAG} Booted {#controllers} controllers in {string.format("%.1f", (os.clock() - bootStarted) * 1000)} ms`)
