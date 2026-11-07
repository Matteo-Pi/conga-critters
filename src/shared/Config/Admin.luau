--!strict
-- Admin and live-server debug access (spec 4.10, 9.10). STUB: commands arrive in C01-M8.
-- The server checks this whitelist on every AdminCommand.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Admin: Types.AdminConfig = {
	Whitelist = {}, -- UserIds
}

return deepFreeze(Admin)
