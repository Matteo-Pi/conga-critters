--!strict
-- Rebirth (economy.md 5.7, 4.7; spec 4.7).
-- need(k) = Needs[k] for k ≤ #Needs; after that the previous need × LPGrowth (LP) and × CoinGrowth (coins).
-- Each rebirth adds CoinBonus and LPBonus (additive) and Line.RebirthLeashBonus capacity.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Rebirth: Types.RebirthConfig = {
	Needs = {
		{ LP = 1000000, Coins = 20000000 },
		{ LP = 2500000, Coins = 200000000 },
		{ LP = 5000000, Coins = 800000000 },
		{ LP = 12500000, Coins = 3000000000 },
		{ LP = 30000000, Coins = 12000000000 },
	},
	LPGrowth = 2.5,
	CoinGrowth = 4,
	CoinBonus = 0.15,
	LPBonus = 0.15,
	RequiredBiome = "peaks", -- also needs an empty line
}

return deepFreeze(Rebirth)
