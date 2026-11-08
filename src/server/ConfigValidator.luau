--!strict
-- Config validator (spec 9.10), run at server start before any service loads. It collects every problem, then
-- stops the start in Studio (error) and warns in live servers.
--
-- Checks: unique ids; species point at real biomes and rarities; every biome has a non-retired species of every
-- rarity; every weight is positive; depth bands are contiguous; upgrade costs rise; every species has a model in
-- ReplicatedStorage.Assets.Critters; and, in live servers only, no P0 pass or product id is 0 (spec 16).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)

local TAG = "[ConfigValidator]"

local ConfigValidator = {}

local function checkUnique(problems: { string }, what: string, ids: { any })
	local seen: { [any]: boolean } = {}
	for _, id in ids do
		if seen[id] then
			table.insert(problems, `{what}: duplicate id {tostring(id)}`)
		end
		seen[id] = true
	end
end

local function positive(value: any): boolean
	return type(value) == "number" and value == value and value > 0 and value < math.huge
end

-- Returns the list of problems; `live` adds the live-server checks.
function ConfigValidator.Collect(live: boolean): { string }
	local problems: { string } = {}

	-- Rarities
	local rarityIds: { string } = {}
	local ranks: { number } = {}
	for _, rarity in Config.Rarities.List do
		table.insert(rarityIds, rarity.Id)
		table.insert(ranks, rarity.Rank)
		if not positive(rarity.Weight) then
			table.insert(problems, `Rarities: {rarity.Id} Weight must be positive`)
		end
		if rarity.GoldenBaitWeight ~= nil and not positive(rarity.GoldenBaitWeight) then
			table.insert(problems, `Rarities: {rarity.Id} GoldenBaitWeight must be positive or absent`)
		end
	end
	checkUnique(problems, "Rarities", rarityIds)
	checkUnique(problems, "Rarities (Rank)", ranks)
	if not positive(Config.Rarities.LuckCap) then
		table.insert(problems, "Rarities: LuckCap must be positive")
	end

	-- Variants
	local variantIds: { string } = {}
	local wires: { number } = {}
	local restTakers = 0
	for _, variant in Config.Variants.List do
		table.insert(variantIds, variant.Id)
		table.insert(wires, variant.Wire)
		if variant.Chance == 0 then
			restTakers += 1
		elseif not positive(variant.Chance) or not positive(variant.Cap) then
			table.insert(problems, `Variants: {variant.Id} Chance and Cap must be positive`)
		end
	end
	checkUnique(problems, "Variants", variantIds)
	checkUnique(problems, "Variants (Wire)", wires)
	if restTakers ~= 1 then
		table.insert(problems, `Variants: exactly one variant must have Chance 0 (takes the rest); found {restTakers}`)
	end

	-- Biomes and depth bands
	local biomeIds: { string } = {}
	for _, biome in Config.Biomes.List do
		table.insert(biomeIds, biome.Id)
		if not biome.TierMatched and type(biome.Tier) ~= "number" then
			table.insert(problems, `Biomes: {biome.Id} needs a Tier unless it is TierMatched`)
		end
		if not positive(biome.CoinMultiplier) or not positive(biome.LPMultiplier) then
			table.insert(problems, `Biomes: {biome.Id} multipliers must be positive`)
		end
	end
	checkUnique(problems, "Biomes", biomeIds)
	local expectedFrom = 0
	for i, band in Config.Biomes.DepthBands do
		if band.From ~= expectedFrom or band.To <= band.From then
			table.insert(problems, `Biomes: depth band {i} ({band.Id}) is not contiguous`)
		end
		if not positive(band.Luck) then
			table.insert(problems, `Biomes: depth band {band.Id} Luck must be positive`)
		end
		expectedFrom = band.To
	end

	-- Critters
	local critterIds: { string } = {}
	local covered: { [string]: { [string]: boolean } } = {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local critterAssets = assets and assets:FindFirstChild("Critters")
	if not critterAssets then
		table.insert(problems, "Assets: ReplicatedStorage.Assets.Critters is missing")
	end
	for _, critter in Config.Critters.List do
		table.insert(critterIds, critter.Id)
		if not Config.Biomes.ById[critter.Biome] then
			table.insert(problems, `Critters: {critter.Id} has unknown biome {critter.Biome}`)
		end
		if not Config.Rarities.ById[critter.Rarity] then
			table.insert(problems, `Critters: {critter.Id} has unknown rarity {critter.Rarity}`)
		end
		if not critter.Retired then
			covered[critter.Biome] = covered[critter.Biome] or {}
			covered[critter.Biome][critter.Rarity] = true
			if critterAssets and not critterAssets:FindFirstChild(critter.Id) then
				table.insert(problems, `Assets: no model for {critter.Id} in ReplicatedStorage.Assets.Critters`)
			end
		end
	end
	checkUnique(problems, "Critters", critterIds)
	for _, biome in Config.Biomes.List do
		for _, rarity in Config.Rarities.List do
			if not (covered[biome.Id] and covered[biome.Id][rarity.Id]) then
				table.insert(problems, `Critters: biome {biome.Id} has no {rarity.Id} species`)
			end
		end
	end

	-- Upgrades
	for _, trackId in Config.Upgrades.Order do
		local track = Config.Upgrades.Tracks[trackId]
		if not track then
			table.insert(problems, `Upgrades: track {trackId} is in Order but not in Tracks`)
			continue
		end
		local lastCost = -1
		for level, row in track.Levels do
			if level == 1 and row.Cost ~= 0 then
				table.insert(problems, `Upgrades: {trackId} level 1 must cost 0`)
			elseif level > 1 and row.Cost <= lastCost then
				table.insert(problems, `Upgrades: {trackId} level {level} cost must be above level {level - 1}`)
			end
			lastCost = row.Cost
		end
	end

	-- Events
	local eventIds: { string } = {}
	for _, event in Config.Events.List do
		table.insert(eventIds, event.Id)
	end
	checkUnique(problems, "Events", eventIds)

	-- Monetisation: keys match their table keys; live P0 ids aren't zero
	for key, pass in Config.Monetisation.Passes do
		if pass.Key ~= key then
			table.insert(problems, `Monetisation: pass {key} has Key {pass.Key}`)
		end
		if live and pass.Priority == "P0" and pass.Id == 0 then
			table.insert(problems, `Monetisation: P0 pass {key} has Id 0`)
		end
	end
	for key, product in Config.Monetisation.Products do
		if product.Key ~= key then
			table.insert(problems, `Monetisation: product {key} has Key {product.Key}`)
		end
		if live and product.Priority == "P0" and product.Id == 0 then
			table.insert(problems, `Monetisation: P0 product {key} has Id 0`)
		end
	end

	return problems
end

-- Run at boot: errors in Studio if anything is wrong, warns in live servers.
function ConfigValidator.Run(): ()
	local studio = RunService:IsStudio()
	local problems = ConfigValidator.Collect(not studio)
	if #problems == 0 then
		print(`{TAG} Config OK`)
		return
	end
	local message = `{TAG} {#problems} problem(s):\n  ` .. table.concat(problems, "\n  ")
	if studio then
		error(message, 0)
	else
		warn(message)
	end
end

return ConfigValidator
