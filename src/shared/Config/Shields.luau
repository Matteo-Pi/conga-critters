--!strict
-- Shields (spec 4.11, 6.2). Shield time is stored; each tap starts or extends a shield from storage.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Shields: Types.ShieldsConfig = {
	BeginnerSeconds = 300, -- first 5 min of playtime…
	BeginnerEndsAtBiome = "jungle", -- …or until this biome unlocks, whichever is first
	DailySeconds = 300, -- daily ladder, day 3
	LineShieldSeconds = 600, -- Line Shield product
	DailyStoredMax = 3600, -- daily rewards stop adding once this much is stored; bought time always adds in full
	ActivateSeconds = 600, -- per tap
	MaxActiveSeconds = 1800,
}

return deepFreeze(Shields)
