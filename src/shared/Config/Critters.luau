--!strict
-- Critter roster (spec 5.4). APPEND ONLY: a species' position in this list is its wire index (spec 9.4).
-- Never reorder or delete entries; set `Retired = true` instead. Saves store species by id.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local list: { Types.CritterDef } = {
	-- Sunny Meadow
	{ Id = "meadow_duckling", Name = "Duckling", Biome = "meadow", Rarity = "Common", Size = "S" },
	{ Id = "meadow_bunny", Name = "Bunny", Biome = "meadow", Rarity = "Common", Size = "S" },
	{ Id = "meadow_chick", Name = "Chick", Biome = "meadow", Rarity = "Common", Size = "S" },
	{ Id = "meadow_piglet", Name = "Piglet", Biome = "meadow", Rarity = "Uncommon", Size = "S" },
	{ Id = "meadow_lamb", Name = "Lamb", Biome = "meadow", Rarity = "Uncommon", Size = "M" },
	{ Id = "meadow_hedgehog", Name = "Hedgehog", Biome = "meadow", Rarity = "Rare", Size = "S" },
	{ Id = "meadow_fox", Name = "Fox", Biome = "meadow", Rarity = "Rare", Size = "M" },
	{ Id = "meadow_calf", Name = "Calf", Biome = "meadow", Rarity = "Epic", Size = "L" },
	{ Id = "meadow_alpaca", Name = "Alpaca", Biome = "meadow", Rarity = "Legendary", Size = "L" },
	{ Id = "meadow_starlight_stag", Name = "Starlight Stag", Biome = "meadow", Rarity = "Mythic", Size = "L" },

	-- Jungle
	{ Id = "jungle_tree_frog", Name = "Tree Frog", Biome = "jungle", Rarity = "Common", Size = "S" },
	{ Id = "jungle_parrot", Name = "Parrot", Biome = "jungle", Rarity = "Common", Size = "S" },
	{ Id = "jungle_gecko", Name = "Gecko", Biome = "jungle", Rarity = "Common", Size = "S" },
	{ Id = "jungle_toucan", Name = "Toucan", Biome = "jungle", Rarity = "Uncommon", Size = "S" },
	{ Id = "jungle_monkey", Name = "Monkey", Biome = "jungle", Rarity = "Uncommon", Size = "M" },
	{ Id = "jungle_capybara", Name = "Capybara", Biome = "jungle", Rarity = "Rare", Size = "M" },
	{ Id = "jungle_sloth", Name = "Sloth", Biome = "jungle", Rarity = "Rare", Size = "M" },
	{ Id = "jungle_tapir", Name = "Tapir", Biome = "jungle", Rarity = "Epic", Size = "L" },
	{ Id = "jungle_jaguar", Name = "Jaguar", Biome = "jungle", Rarity = "Legendary", Size = "L" },
	{ Id = "jungle_emperor_capybara", Name = "Emperor Capybara", Biome = "jungle", Rarity = "Mythic", Size = "M" },

	-- Snowy Peaks
	{ Id = "peaks_penguin_chick", Name = "Penguin Chick", Biome = "peaks", Rarity = "Common", Size = "S" },
	{ Id = "peaks_snow_hare", Name = "Snow Hare", Biome = "peaks", Rarity = "Common", Size = "S" },
	{ Id = "peaks_seal_pup", Name = "Seal Pup", Biome = "peaks", Rarity = "Common", Size = "S" },
	{ Id = "peaks_arctic_fox", Name = "Arctic Fox", Biome = "peaks", Rarity = "Uncommon", Size = "M" },
	{ Id = "peaks_puffin", Name = "Puffin", Biome = "peaks", Rarity = "Uncommon", Size = "S" },
	{ Id = "peaks_reindeer", Name = "Reindeer", Biome = "peaks", Rarity = "Rare", Size = "L" },
	{ Id = "peaks_snowy_owl", Name = "Snowy Owl", Biome = "peaks", Rarity = "Rare", Size = "S" },
	{ Id = "peaks_yak", Name = "Yak", Biome = "peaks", Rarity = "Epic", Size = "L" },
	{ Id = "peaks_snow_leopard", Name = "Snow Leopard", Biome = "peaks", Rarity = "Legendary", Size = "L" },
	{ Id = "peaks_aurora_bear", Name = "Aurora Bear", Biome = "peaks", Rarity = "Mythic", Size = "L" },
}

local byId: { [string]: Types.CritterDef } = {}
local indexById: { [string]: number } = {}
for index, critter in list do
	byId[critter.Id] = critter
	indexById[critter.Id] = index
end

local Critters: Types.CrittersConfig = {
	List = list,
	ById = byId,
	IndexById = indexById,
}

return deepFreeze(Critters)
