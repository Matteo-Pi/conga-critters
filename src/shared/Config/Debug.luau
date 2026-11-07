--!strict
-- Debug switches (spec 9.10). STUB: debug commands arrive in C01-M1.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Debug: Types.DebugConfig = {
	LogBoot = true, -- print each service's and controller's Init and Start
}

return deepFreeze(Debug)
