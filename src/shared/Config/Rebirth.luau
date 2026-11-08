--!strict
-- Rebirth (economy.md 5.7, 4.7; spec 4.7).
-- need(k) = Needs[k] for k ≤ #Needs; after that the previous need × LPGrowth (LP) and × CoinGrowth (coins).
-- Each rebirth adds CoinBonus and LPBonus (additive) and cuts the throw cooldown by CooldownCut, down to
-- Throw.CooldownMin (economy.md 4.6). Rebirth adds no line capacity (since 2026-11-08).

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Rebirth: Types.RebirthConfig = {
	Needs = {
		{ LP = 750000, Coins = 12500000 },
		{ LP = 1700000, Coins = 140000000 },
		{ LP = 3700000, Coins = 480000000 },
		{ LP = 9500000, Coins = 1900000000 },
		{ LP = 23000000, Coins = 7700000000 },
	},
	LPGrowth = 2.5,
	CoinGrowth = 4,
	CoinBonus = 0.15,
	LPBonus = 0.15,
	CooldownCut = 0.05, -- seconds off the throw cooldown per rebirth
	RequiredBiome = "peaks", -- also needs an empty line
}

return deepFreeze(Rebirth)
