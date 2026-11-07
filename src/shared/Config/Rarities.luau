--!strict
-- Rarities (economy.md 5.1, 4.1). Ordered by rank; the roll treats rank 1 as each table's lowest only for
-- the Normal table (Golden Bait's lowest is Rare).

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local list: { Types.RarityDef } = {
	{ Id = "Common", Rank = 1, Weight = 70, Value = 5, LP = 1, Color = Color3.fromRGB(255, 255, 255) },
	{ Id = "Uncommon", Rank = 2, Weight = 22, Value = 15, LP = 2, Color = Color3.fromRGB(85, 200, 85) },
	{
		Id = "Rare",
		Rank = 3,
		Weight = 6,
		GoldenBaitWeight = 70,
		Value = 50,
		LP = 4,
		Color = Color3.fromRGB(60, 140, 255),
	},
	{
		Id = "Epic",
		Rank = 4,
		Weight = 1.6,
		GoldenBaitWeight = 22,
		Value = 200,
		LP = 8,
		Color = Color3.fromRGB(165, 80, 230),
	},
	{
		Id = "Legendary",
		Rank = 5,
		Weight = 0.35,
		GoldenBaitWeight = 7,
		Value = 1000,
		LP = 16,
		Color = Color3.fromRGB(255, 190, 40),
	},
	{
		Id = "Mythic",
		Rank = 6,
		Weight = 0.05,
		GoldenBaitWeight = 1,
		Value = 10000,
		LP = 32,
		Color = Color3.fromRGB(255, 100, 190),
	},
}

local byId: { [string]: Types.RarityDef } = {}
for _, rarity in list do
	byId[rarity.Id] = rarity
end

local Rarities: Types.RaritiesConfig = {
	List = list,
	ById = byId,
	LuckCap = 10,
}

return deepFreeze(Rarities)
