--!strict
-- Who may use debug tools (spec 9.10): everyone in Studio, and in live servers only the UserIds in Config.Admin's
-- whitelist. The server checks it on every debug command (AdminService); the client checks it before showing
-- client-only debug views such as `/debug perf` (PerfOverlay), which only ever show the player's own machine.

local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("Config") :: ModuleScript)

local DebugAccess = {}

function DebugAccess.Allowed(userId: number?): boolean
	if RunService:IsStudio() then
		return true
	end
	if not userId then
		return false
	end
	return table.find(Config.Admin.Whitelist, userId) ~= nil
end

return DebugAccess
