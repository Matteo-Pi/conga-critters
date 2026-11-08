--!strict
-- Debug switches and commands (spec 9.10). Debug commands work in Studio and, in live servers, for the UserIds in
-- Config/Admin's whitelist. They arrive by chat (`/debug <command> …`, a server TextChatCommand) or, in Studio only,
-- through a BindableFunction that MCP's execute_luau can invoke on the Server datamodel (spec 16).

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Debug: Types.DebugConfig = {
	LogBoot = true, -- print each service's and controller's Init and Start
	ChatCommand = "/debug", -- TextChatCommand.PrimaryAlias
	ChatCommandShort = "/d", -- TextChatCommand.SecondaryAlias
	StudioBridgeName = "DebugBridge", -- BindableFunction under ServerScriptService, Studio only
	RollMaxSamples = 1000000, -- `roll … <n>` refuses more than this
}

return deepFreeze(Debug)
