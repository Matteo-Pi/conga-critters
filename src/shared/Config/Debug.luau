--!strict
-- Debug switches and commands (spec 9.10). Debug commands work in Studio and, in live servers, for the UserIds in
-- Config/Admin's whitelist. They arrive by chat (`/debug <command> …`, a server TextChatCommand) or, in Studio only,
-- through a BindableFunction that MCP's execute_luau can invoke on the Server datamodel (spec 16).

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Debug: Types.DebugConfig = {
	LogBoot = true, -- print each service's and controller's Init and Start
	LogThrows = true, -- print every accepted and rejected throw (server) and each critter's arrival timings (client)
	ChatCommand = "/debug", -- TextChatCommand.PrimaryAlias
	ChatCommandShort = "/d", -- TextChatCommand.SecondaryAlias
	ChatCommandName = "DebugCommand", -- the TextChatCommand's Name under TextChatService (the client finds it by name)
	PerfCommand = "perf", -- `/debug perf [on|off]`: client-only box with FPS, LineRenderer ms and followers drawn
	PerfWindowSeconds = 5, -- the box's average and worst LineRenderer ms cover this many seconds
	PerfRefreshSeconds = 0.5, -- how often the box's text updates
	StudioBridgeName = "DebugBridge", -- BindableFunction under ServerScriptService, Studio only
	RollMaxSamples = 1000000, -- `roll … <n>` refuses more than this
	MaxLeaders = 12, -- `leaders <k>` spawns at most this many debug leaders
	LeadersFolderName = "DebugLeaders", -- Workspace folder holding debug leader models
	LeaderNamePrefix = "DebugLeader_", -- leader -n is the model named prefix .. n
	LeaderIdBase = -1000, -- leader k owns id LeaderIdBase − k; Studio test players use −1, −2, …
	RendererBridgeName = "LineRendererDebug", -- client BindableFunction under PlayerScripts, Studio only
}

return deepFreeze(Debug)
