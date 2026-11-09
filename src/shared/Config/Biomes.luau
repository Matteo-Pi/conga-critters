--!strict
-- Biomes and depth bands (economy.md 5.3). Tier 4 and event biomes are added here as data when they ship.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local list: { Types.BiomeDef } = {
	{
		Id = "meadow",
		Name = "Sunny Meadow",
		Tier = 1,
		TierMatched = false,
		GateLP = 0,
		CoinMultiplier = 1,
		LPMultiplier = 1,
	},
	{
		Id = "jungle",
		Name = "Jungle",
		Tier = 2,
		TierMatched = false,
		GateLP = 1000,
		CoinMultiplier = 10,
		LPMultiplier = 5,
	},
	{
		Id = "peaks",
		Name = "Snowy Peaks",
		Tier = 3,
		TierMatched = false,
		GateLP = 50000,
		CoinMultiplier = 100,
		LPMultiplier = 25,
	},
}

local byId: { [string]: Types.BiomeDef } = {}
for _, biome in list do
	byId[biome.Id] = biome
end

local Biomes: Types.BiomesConfig = {
	List = list,
	ById = byId,
	-- Thirds of each biome by depth past its gate. Luck Mid 1.5, Far 2.25 since economy.md v0.6 (11.11): with lines
	-- capped at 100 the deep bands need this much to pay best (pillar 2).
	DepthBands = {
		{ Id = "Near", From = 0, To = 130, Luck = 1 },
		{ Id = "Mid", From = 130, To = 270, Luck = 1.5 },
		{ Id = "Far", From = 270, To = 400, Luck = 2.25 },
	},
}

return deepFreeze(Biomes)
