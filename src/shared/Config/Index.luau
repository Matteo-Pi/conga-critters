--!strict
-- Index rewards (economy.md 5.8; spec 4.8). Granted per biome; they survive rebirth.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Index: Types.IndexConfig = {
	NormalSetCoinBonus = 0.1, -- +10% coins per completed Normal set, added together, no cap
	NormalSetBadgeId = 0, -- 0 until the badge is created
	GoldenSetReward = "GoldenPenDecor",
	RainbowSetReward = "RainbowTrail",
	RainbowSetMaxRank = 3, -- the Rainbow set needs only Common, Uncommon and Rare species
}

return deepFreeze(Index)
