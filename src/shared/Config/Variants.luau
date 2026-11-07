--!strict
-- Variants (economy.md 5.2, 4.1). Rolled after species: Rainbow if u < rainbow, Golden if u < rainbow + golden,
-- otherwise Normal. Golden Bait and Golden Hour multiply the base chance, then the cap applies.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local list: { Types.VariantDef } = {
	{
		Id = "Normal",
		Wire = 0,
		Chance = 0, -- takes the rest
		ValueMultiplier = 1,
		GoldenBaitMultiplier = 1,
		GoldenHourMultiplier = 1,
		Cap = 1,
	},
	{
		Id = "Golden",
		Wire = 1,
		Chance = 0.02,
		ValueMultiplier = 3,
		GoldenBaitMultiplier = 5,
		GoldenHourMultiplier = 5,
		Cap = 0.25,
	},
	{
		Id = "Rainbow",
		Wire = 2,
		Chance = 0.001,
		ValueMultiplier = 10,
		GoldenBaitMultiplier = 5,
		GoldenHourMultiplier = 3,
		Cap = 0.02,
	},
}

local byId: { [string]: Types.VariantDef } = {}
for _, variant in list do
	byId[variant.Id] = variant
end

local Variants: Types.VariantsConfig = {
	List = list,
	ById = byId,
}

return deepFreeze(Variants)
