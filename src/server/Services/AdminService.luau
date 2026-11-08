--!strict
-- AdminService: admin and debug commands (spec 4.10, 9.10).
--
-- C01-M1: the debug command dispatcher. Access: Studio, or a UserId in Config.Admin.Whitelist; anything else is
-- ignored and logged. Two ways in, one dispatcher (`AdminService.Run`):
--   * chat: `/debug <command> …` (alias `/d`), a TextChatCommand created by the server;
--   * Studio only: `ServerScriptService.DebugBridge:Invoke(text, userId?)`, for MCP's execute_luau on the Server
--     datamodel (requiring this module from there would give a separate copy without the live state).
-- Spec 4.10 names an `AdminCommand` remote for admin commands; the two routes are to be brought together in C01-M8
-- (spec 16). Replies go to the server console and are returned to the bridge caller.
-- C01-M3: `fill` now draws followers (LineSync); new `speed`, `longleash`, `leaders`, `walk8` and `linepos`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)
local Odds = require(Shared:WaitForChild("Odds") :: ModuleScript)
local Zones = require(Shared:WaitForChild("Zones") :: ModuleScript)

local Services = script.Parent
local LineService = require(Services:WaitForChild("LineService") :: ModuleScript)
local MapService = require(Services:WaitForChild("MapService") :: ModuleScript)
local PlayerStateService = require(Services:WaitForChild("PlayerStateService") :: ModuleScript)
local ThrowService = require(Services:WaitForChild("ThrowService") :: ModuleScript)

local Checks = script.Parent.Parent:WaitForChild("Checks")
local DebugLeaders = require(script.Parent.Parent:WaitForChild("DebugLeaders") :: ModuleScript)

local TAG = "[Debug]"

local AdminService = {}

type Handler = (caller: Player?, args: { string }) -> string
type Command = {
	Usage: string,
	Help: string,
	Run: Handler,
}

local commands: { [string]: Command } = {}
local order: { string } = {}

local function register(name: string, usage: string, help: string, run: Handler)
	commands[name] = { Usage = usage, Help = help, Run = run }
	table.insert(order, name)
end

-- Commands from spec 9.10 whose systems don't exist yet: they reply with the milestone that brings them.
local function later(name: string, usage: string, help: string, milestone: string)
	register(name, usage, help, function()
		return `{name}: arrives in {milestone}`
	end)
end

function AdminService.CanDebug(userId: number?): boolean
	if RunService:IsStudio() then
		return true
	end
	if not userId then
		return false
	end
	return table.find(Config.Admin.Whitelist, userId) ~= nil
end

-- "me" (the caller, or the only/first player when there is no caller), a name prefix, or a UserId.
local function findPlayer(caller: Player?, token: string?): (Player?, string?)
	if token == nil or token == "" or string.lower(token) == "me" then
		local player = caller or Players:GetPlayers()[1]
		if player then
			return player, nil
		end
		return nil, "no players in the server"
	end
	local lower = string.lower(token)
	local userId = tonumber(token)
	local matches: { Player } = {}
	for _, player in Players:GetPlayers() do
		if userId and player.UserId == userId then
			return player, nil
		end
		if string.sub(string.lower(player.Name), 1, #lower) == lower then
			table.insert(matches, player)
		end
	end
	if #matches == 1 then
		return matches[1], nil
	end
	return nil, if #matches == 0 then `no player matches "{token}"` else `"{token}" matches {#matches} players`
end

local function biomeList(): string
	local ids: { string } = {}
	for _, biome in Config.Biomes.List do
		table.insert(ids, biome.Id)
	end
	return table.concat(ids, ", ")
end

local function unlockedReport(player: Player): string
	local session = PlayerStateService.Get(player)
	local lines =
		{ `{player.Name}: LP {PlayerStateService.GetLP(player)}, top tier {PlayerStateService.TopTier(player)}` }
	for _, biome in Config.Biomes.List do
		local open = PlayerStateService.IsBiomeUnlocked(player, biome.Id)
		local viaDebug = session and session.DebugUnlocked[biome.Id] == true
		table.insert(
			lines,
			string.format(
				"  %-8s %-8s GateLP %d%s",
				biome.Id,
				if open then "unlocked" else "locked",
				biome.GateLP,
				if viaDebug then " (debug unlock)" else ""
			)
		)
	end
	return table.concat(lines, "\n")
end

local function runCheck(name: string): string
	local module = Checks:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		return `check: no module {name}`
	end
	local check = require(module) :: any
	local ok, report = check.Run()
	return report .. (if ok then "" else "\n(FAILED)")
end

register("help", "help", "list commands", function()
	local lines = { `Debug commands ({Config.Debug.ChatCommand} <command> …):` }
	for _, name in order do
		table.insert(lines, string.format("  %-44s %s", commands[name].Usage, commands[name].Help))
	end
	return table.concat(lines, "\n")
end)

register("pens", "pens", "who owns each pen plot", function()
	local lines = { `Pens ({MapService.PenCount()} plots):` }
	for index = 1, MapService.PenCount() do
		local owner = MapService.PenOwner(index)
		table.insert(lines, `  pen {index}: {if owner then `{owner.Name} ({owner.UserId})` else "free"}`)
	end
	return table.concat(lines, "\n")
end)

register("zone", "zone [player]", "zones at the player's position", function(caller, args)
	local player, err = findPlayer(caller, args[1])
	if not player then
		return `zone: {err}`
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return `zone: {player.Name} has no character`
	end
	local p = root.Position
	return string.format(
		"%s at (%.1f, %.1f, %.1f): %s",
		player.Name,
		p.X,
		p.Y,
		p.Z,
		Zones.Describe(MapService.ZoneAt(p))
	)
end)

register(
	"roll",
	"roll <biome> [band] [n] [golden] [serverluck] [goldenhour]",
	"sample rolls and summarise them",
	function(_caller, args)
		local biomeId = args[1]
		if not biomeId or not Config.Biomes.ById[biomeId] then
			return `roll: biome must be one of {biomeList()}`
		end
		local ctx = Odds.DefaultContext()
		ctx.Band = tonumber(args[2]) or 1
		local n = math.clamp(math.floor(tonumber(args[3]) or 1), 1, Config.Debug.RollMaxSamples)
		for i = 4, #args do
			local flag = string.lower(args[i])
			if flag == "golden" then
				ctx.GoldenBait = true
			elseif flag == "serverluck" then
				ctx.ServerLuck = true
			elseif flag == "goldenhour" then
				ctx.GoldenHour = true
			end
		end
		local rng = Random.new()
		if n == 1 then
			local result = Odds.Roll(biomeId, ctx, rng)
			if not result then
				return "roll: nothing to roll"
			end
			return `roll: {result.Species} ({result.Rarity}, variant {result.Variant}), λ = {Odds.Luck(ctx)}`
		end
		local byRarity: { [string]: number } = {}
		local byVariant: { [number]: number } = {}
		for i = 1, n do
			local result = Odds.Roll(biomeId, ctx, rng)
			if result then
				byRarity[result.Rarity] = (byRarity[result.Rarity] or 0) + 1
				byVariant[result.Variant] = (byVariant[result.Variant] or 0) + 1
			end
			if i % 10000 == 0 then
				task.wait()
			end
		end
		local lines = { `roll: {n} × {biomeId} band {ctx.Band}, λ = {Odds.Luck(ctx)}` }
		for _, entry in Odds.ForContext(ctx) do
			local k = byRarity[entry.Id] or 0
			table.insert(
				lines,
				string.format("  %-10s %7d  %8.4f%%  (odds %8.4f%%)", entry.Id, k, k / n * 100, entry.Chance * 100)
			)
		end
		for _, entry in Odds.VariantChances(ctx.GoldenBait, ctx.GoldenHour) do
			local k = byVariant[Config.Variants.ById[entry.Id].Wire] or 0
			table.insert(
				lines,
				string.format("  %-10s %7d  %8.4f%%  (odds %8.4f%%)", entry.Id, k, k / n * 100, entry.Chance * 100)
			)
		end
		return table.concat(lines, "\n")
	end
)

register("check", "check <odds|zones|pens|all>", "run the C01-M1 acceptance checks", function(_caller, args)
	local which = string.lower(args[1] or "all")
	local map = { odds = "OddsCheck", zones = "ZonesCheck", pens = "PensCheck" }
	if which == "all" then
		return table.concat({ runCheck("ZonesCheck"), runCheck("PensCheck"), runCheck("OddsCheck") }, "\n")
	end
	local name = map[which]
	if not name then
		return "check: odds, zones, pens or all"
	end
	return runCheck(name)
end)

register("lp", "lp <player|me> <amount>", "set session Lead Power", function(caller, args)
	local player, err = findPlayer(caller, args[1])
	if not player then
		return `lp: {err}`
	end
	local amount = tonumber(args[2])
	if not amount or amount ~= amount or amount < 0 or amount == math.huge then
		return "lp: amount must be a number of 0 or more"
	end
	PlayerStateService.SetLP(player, amount)
	return unlockedReport(player)
end)

register("unlock", "unlock <player|me> <biomeId|all>", "unlock biomes for this session", function(caller, args)
	local player, err = findPlayer(caller, args[1])
	if not player then
		return `unlock: {err}`
	end
	local target = args[2]
	if target == "all" then
		for _, biome in Config.Biomes.List do
			PlayerStateService.AddDebugUnlock(player, biome.Id)
		end
	elseif target and Config.Biomes.ById[target] then
		PlayerStateService.AddDebugUnlock(player, target)
	else
		return `unlock: biome must be all or one of {biomeList()}`
	end
	return unlockedReport(player)
end)

register("relock", "relock <player|me>", "clear this session's debug unlocks", function(caller, args)
	local player, err = findPlayer(caller, args[1])
	if not player then
		return `relock: {err}`
	end
	PlayerStateService.ClearDebugUnlocks(player)
	return unlockedReport(player)
end)

register("unlocked", "unlocked [player]", "each biome's lock state, LP and GateLP", function(caller, args)
	local player, err = findPlayer(caller, args[1])
	if not player then
		return `unlocked: {err}`
	end
	return unlockedReport(player)
end)

local function lineReport(player: Player): string
	local session = PlayerStateService.Get(player)
	local tutorial = if session
		then `tutorial {if session.Tutorial.Done then "done" else "running"}, free throws {session.Tutorial.FreeThrows}`
		else "no session"
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return string.format(
		"%s: line %d/%d, %d on the way, room %d; Leash %d, Speed %d, Longer Leash %s; walk speed %.3f (Humanoid %s); Golden Bait %d; %s",
		player.Name,
		LineService.Length(player),
		LineService.Capacity(player),
		LineService.Incoming(player),
		LineService.Room(player),
		if session then session.Upgrades.Leash else 0,
		if session then session.Upgrades.Speed else 0,
		if session and session.LongerLeash then "on" else "off",
		LineService.WalkSpeedOf(player.UserId),
		if humanoid then string.format("%.3f", humanoid.WalkSpeed) else "none",
		if session then session.GoldenBait else 0,
		tutorial
	)
end

register("throws", "throws [reset]", "accepted and rejected throws, by reason", function(_caller, args)
	local report = ThrowService.Report()
	if args[1] and string.lower(args[1]) == "reset" then
		ThrowService.ResetStats()
		return report .. "\n(counters reset)"
	end
	return report
end)

register("line", "line [player]", "line length, critters on the way, capacity", function(caller, args)
	local player, err = findPlayer(caller, args[1])
	if not player then
		return `line: {err}`
	end
	return lineReport(player)
end)

-- Debug: raise the Leash level, then the Longer Leash pass, to the lowest setting whose capacity holds n (never
-- lowers anything). Returns what changed, or "" when the line already holds n. Capped at MaxCapacity.
local function raiseCapacity(player: Player, n: number): string
	local session = PlayerStateService.Get(player)
	if not session or LineService.Capacity(player) >= n then
		return ""
	end
	local want = math.min(n, Config.Line.MaxCapacity)
	local levels = #Config.Upgrades.Tracks.Leash.Levels
	local function lowestLevel(longer: boolean): number?
		for level = session.Upgrades.Leash, levels do
			if LineService.CapacityFor(level, session.Rebirths, longer) >= want then
				return level
			end
		end
		return nil
	end
	local level = lowestLevel(session.LongerLeash)
	local pass = false
	if not level and not session.LongerLeash then
		level = lowestLevel(true)
		pass = true
	end
	local target = level or levels
	if pass then
		LineService.SetLongerLeash(player, true)
	end
	LineService.SetLeashLevel(player, target)
	return `fill: raised Leash to level {target}{if pass then " and turned Longer Leash on" else ""}; capacity {LineService.Capacity(player)}`
end

register(
	"fill",
	"fill <player|me> <n> [biome]",
	"fill a line to n critters; raises Leash (then Longer Leash) to the lowest setting that holds n",
	function(caller, args)
		local player, err = findPlayer(caller, args[1])
		if not player then
			return `fill: {err}`
		end
		local n = tonumber(args[2])
		if not n or n ~= n or n < 0 then
			return "fill: n must be a number of 0 or more"
		end
		local biomeId = args[3] or Config.Biomes.List[1].Id
		if not Config.Biomes.ById[biomeId] then
			return `fill: biome must be one of {biomeList()}`
		end
		local raised = raiseCapacity(player, math.floor(n))
		local rng = Random.new()
		LineService.Fill(player, n, function()
			local result = Odds.Roll(biomeId, Odds.DefaultContext(), rng)
			assert(result, `{biomeId} has no critters`)
			return { Species = result.Species, Variant = result.Variant, Bound = false, Paid = false }
		end)
		return if raised ~= "" then `{raised}\n{lineReport(player)}` else lineReport(player)
	end
)

register("leash", "leash <player|me> <level>", "set the Leash level (upgrades arrive in C01-M4)", function(caller, args)
	local player, err = findPlayer(caller, args[1])
	if not player then
		return `leash: {err}`
	end
	local level = tonumber(args[2])
	if not level or level ~= level then
		return `leash: level must be 1 to {#Config.Upgrades.Tracks.Leash.Levels}`
	end
	LineService.SetLeashLevel(player, level)
	return lineReport(player)
end)

register("speed", "speed <player|me> <level>", "set the Speed level (upgrades arrive in C01-M4)", function(caller, args)
	local player, err = findPlayer(caller, args[1])
	if not player then
		return `speed: {err}`
	end
	local level = tonumber(args[2])
	if not level or level ~= level then
		return `speed: level must be 1 to {#Config.Upgrades.Tracks.Speed.Levels}`
	end
	LineService.SetSpeedLevel(player, level)
	return lineReport(player)
end)

register(
	"longleash",
	"longleash <player|me> <on|off>",
	"own the Longer Leash pass this session (passes arrive in C01-M6)",
	function(caller, args)
		local player, err = findPlayer(caller, args[1])
		if not player then
			return `longleash: {err}`
		end
		local what = string.lower(args[2] or "")
		if what ~= "on" and what ~= "off" then
			return "longleash: on or off"
		end
		LineService.SetLongerLeash(player, what == "on")
		return lineReport(player)
	end
)

register(
	"leaders",
	"leaders <k> [length] [biome]",
	"spawn or remove debug leaders until there are k, each with a line of length (default: the last used, at first the max)",
	function(_caller, args)
		local k = tonumber(args[1])
		if not k or k ~= k or k < 0 then
			return `leaders: k must be 0 to {Config.Debug.MaxLeaders}`
		end
		local length: number? = nil
		local biomeArg = 2
		if args[2] and tonumber(args[2]) then
			length = tonumber(args[2])
			biomeArg = 3
			if length ~= length or (length :: number) < 0 then
				return `leaders: length must be 0 to {Config.Line.MaxCapacity}`
			end
		end
		local biomeId = args[biomeArg]
		if biomeId and not Config.Biomes.ById[biomeId] then
			return `leaders: biome must be one of {biomeList()}`
		end
		local count = DebugLeaders.Set(k, biomeId, length)
		local lengths: { string } = {}
		for ownerId, length in LineService.Lines() do
			table.insert(lengths, `{ownerId}: {length}`)
		end
		table.sort(lengths)
		return `leaders: {count} debug leaders; lines {table.concat(lengths, ", ")}`
	end
)

register(
	"goto",
	"goto <player|me> <biome> [depth]",
	"move the player (on the server) depth studs into a biome, facing in",
	function(caller, args)
		local player, err = findPlayer(caller, args[1])
		if not player then
			return `goto: {err}`
		end
		local biomeId = args[2]
		if not biomeId or not Config.Biomes.ById[biomeId] then
			return `goto: biome must be one of {biomeList()}`
		end
		local character = player.Character
		if not character then
			return `goto: {player.Name} has no character`
		end
		local depth = tonumber(args[3]) or 200
		local point = DebugLeaders.PointInBiome(biomeId, depth)
		local _, inward = DebugLeaders.BiomeFrame(biomeId)
		if not point then
			return `goto: no floor {depth} studs into {biomeId}`
		end
		local lifted = point + Vector3.new(0, 4, 0)
		character:PivotTo(CFrame.lookAt(lifted, lifted + inward))
		return string.format("goto: %s to (%.0f, %.0f, %.0f) in %s", player.Name, point.X, point.Y, point.Z, biomeId)
	end
)

register(
	"walk8",
	"walk8 <player|me> [halfWidth] [laps] [depth] | stop | status",
	"walk a figure of eight in the player's biome (server MoveTo)",
	function(caller, args)
		local first = string.lower(args[1] or "")
		if first == "stop" then
			DebugLeaders.StopWalk()
			return "walk8: stopped"
		end
		if first == "status" then
			local walk = DebugLeaders.WalkStatus()
			if not walk then
				return "walk8: no walk yet"
			end
			return string.format(
				"walk8: %s, lap %d/%d, %.0f studs in %.1f s",
				if walk.Running then "running" else "finished",
				walk.Lap,
				walk.Laps,
				walk.Distance,
				(walk.EndedAt or os.clock()) - walk.StartedAt
			)
		end
		local player, err = findPlayer(caller, args[1])
		if not player then
			return `walk8: {err}`
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or not humanoid.RootPart then
			return `walk8: {player.Name} has no character`
		end
		local biomeId = MapService.ZoneAt(humanoid.RootPart.Position).BiomeId or Config.Biomes.List[1].Id
		local size = tonumber(args[2]) or 60
		local laps = tonumber(args[3]) or 2
		local depth = tonumber(args[4]) or 200
		return "walk8: " .. DebugLeaders.WalkFigureEight(humanoid, biomeId, size, laps, depth)
	end
)

register(
	"linepos",
	"linepos <player|me|leaderId> [every]",
	"server-side follower positions (every n-th)",
	function(caller, args)
		local ownerId = tonumber(args[1])
		if not ownerId or ownerId > Config.Debug.LeaderIdBase then
			local player, err = findPlayer(caller, args[1])
			if not player then
				return `linepos: {err}`
			end
			ownerId = player.UserId
		end
		local id = ownerId :: number
		local every = math.max(1, math.floor(tonumber(args[2]) or 50))
		local positions, count = LineService.FollowerPositions(id)
		local out = {
			`linepos {id}: {count} followers, walk speed {string.format("%.3f", LineService.WalkSpeedOf(id))}`,
		}
		local points, studs, newest, hops = LineService.PathInfo(id, 8)
		local hopList = {}
		for _, d in hops do
			table.insert(hopList, string.format("%.1f", d))
		end
		table.insert(
			out,
			string.format(
				"  server path: %d points, %.2f studs; %d hop markers%s",
				points,
				studs,
				#hops,
				if #hops > 0 then " at " .. table.concat(hopList, ", ") else ""
			)
		)
		for k, p in newest do
			table.insert(out, string.format("  point %d: (%.2f, %.2f, %.2f)", k - 1, p.X, p.Y, p.Z))
		end
		for i = every, count, every do
			local p = positions[i]
			table.insert(out, string.format("  %d: %.2f, %.2f, %.2f", i, p.X, p.Y, p.Z))
		end
		if count > 0 and count % every ~= 0 then
			local p = positions[count]
			table.insert(out, string.format("  %d: %.2f, %.2f, %.2f", count, p.X, p.Y, p.Z))
		end
		return table.concat(out, "\n")
	end
)

register("golden", "golden <player|me> <n>", "set the Golden Bait count", function(caller, args)
	local player, err = findPlayer(caller, args[1])
	if not player then
		return `golden: {err}`
	end
	local n = tonumber(args[2])
	if not n or n ~= n or n < 0 or n == math.huge then
		return "golden: n must be a number of 0 or more"
	end
	PlayerStateService.SetGoldenBait(player, n)
	return lineReport(player)
end)

register(
	"tutorial",
	"tutorial <player|me> <reset|done>",
	"restart or end the tutorial's fixed rolls",
	function(caller, args)
		local player, err = findPlayer(caller, args[1])
		if not player then
			return `tutorial: {err}`
		end
		local session = PlayerStateService.Get(player)
		if not session then
			return "tutorial: no session"
		end
		local what = string.lower(args[2] or "")
		if what == "reset" then
			session.Tutorial.Done = false
			session.Tutorial.FreeThrows = 0
		elseif what == "done" then
			session.Tutorial.Done = true
		else
			return "tutorial: reset or done"
		end
		return lineReport(player)
	end
)

later("coins", "coins <player|me> <amount>", "give coins", "C01-M4")
later("storage", "storage <player|me> [n|full]", "fill storage", "C01-M4")
later("reset", "reset <player|me>", "reset a profile (Studio only)", "C01-M4")
later("policy", "policy <player|me> <restricted|normal>", "force PolicyService result", "C01-M6")
later("serverluck", "serverluck [minutes]", "start Server Luck", "C01-M6")
later("playtime", "playtime <player|me> <minutes>", "set minutes of playtime", "C01-M7")
later("clock", "clock <+hours|reset>", "shift the clock", "C01-M7")
later("friends", "friends <player|me> <n>", "set Friend Boost's friend count", "C01-M9")

local function split(text: string): { string }
	local tokens: { string } = {}
	for token in string.gmatch(text, "%S+") do
		table.insert(tokens, token)
	end
	return tokens
end

-- Run one command line (without the chat alias). `caller` is nil for the Studio bridge.
function AdminService.Run(caller: Player?, text: string): string
	local userId = if caller then caller.UserId else nil
	if caller and not AdminService.CanDebug(userId) then
		warn(`{TAG} ignored a debug command from {caller.Name} ({caller.UserId}): not whitelisted`)
		return "not allowed"
	end
	local tokens = split(text)
	local name = string.lower(table.remove(tokens, 1) or "help")
	local command = commands[name]
	local reply: string
	if not command then
		reply = `unknown command "{name}"; try help`
	else
		local ok, result = pcall(command.Run, caller, tokens)
		reply = if ok then result else `{name} failed: {result}`
	end
	print(`{TAG} {if caller then caller.Name else "bridge"}> {text}\n{reply}`)
	return reply
end

local function stripAlias(text: string): string
	local _, finish = string.find(text, "^%s*/%S+%s*")
	return if finish then string.sub(text, finish + 1) else text
end

function AdminService.Init(): () end

function AdminService.Start(): ()
	local command = Instance.new("TextChatCommand")
	command.Name = "DebugCommand"
	command.PrimaryAlias = Config.Debug.ChatCommand
	command.SecondaryAlias = Config.Debug.ChatCommandShort
	command.AutocompleteVisible = false
	command.Triggered:Connect(function(source: TextSource, unfilteredText: string)
		local player = Players:GetPlayerByUserId(source.UserId)
		if not player then
			return
		end
		AdminService.Run(player, stripAlias(unfilteredText))
	end)
	command.Parent = TextChatService

	if RunService:IsStudio() then
		local bridge = Instance.new("BindableFunction")
		bridge.Name = Config.Debug.StudioBridgeName
		bridge.OnInvoke = function(text: any, userId: any): string
			if type(text) ~= "string" then
				return "DebugBridge: pass the command text"
			end
			local caller = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
			return AdminService.Run(caller, text)
		end
		bridge.Parent = ServerScriptService
	end
end

export type AdminService = typeof(AdminService)

return AdminService
