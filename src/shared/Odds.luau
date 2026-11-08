--!strict
-- Odds: roll and display maths; the server rolls, clients display (spec 4.2; economy.md 4.1).
-- One module for both so the odds shown always equal the odds rolled, including every active boost (spec 6.4).
--
--   λ = min(LuckCap, baitLuck × bandLuck × serverLuck × eventLuck)
--   weight[r] = tableWeight[r] × λ for every rarity above the table's lowest; the lowest keeps its weight
--   golden  = min(cap, chance × goldenBait × goldenHour), the same for rainbow
--   u in [0, 1): Rainbow if u < rainbow; Golden if u < rainbow + golden; otherwise Normal
--
-- Every number comes from Config. Fixed tutorial rolls are not here: ThrowService applies them (spec 2.2).

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Odds = {}

export type Context = {
	BaitLevel: number, -- Bait upgrade level, 1 to the track's top level
	Band: number, -- depth band index into Config.Biomes.DepthBands (1 Near, 2 Mid, 3 Far)
	ServerLuck: boolean, -- Server Luck is running
	EventLuck: number, -- product of active event and /luck multipliers, 1 when none (capped here)
	GoldenBait: boolean, -- thrown with Golden Bait: Golden Bait table and variant multiplier
	GoldenHour: boolean, -- Golden Hour is running: its variant multipliers apply
}

export type Chance = {
	Id: string,
	Chance: number,
}

export type RollResult = {
	Species: string,
	Rarity: string,
	Variant: number, -- wire number: 0 Normal, 1 Golden, 2 Rainbow
}

-- Species pools: biome id -> rarity id -> species ids, non-retired only, in Config order.
local pools: { [string]: { [string]: { string } } } = {}
for _, critter: Types.CritterDef in Config.Critters.List do
	if not critter.Retired then
		local byRarity = pools[critter.Biome]
		if not byRarity then
			byRarity = {}
			pools[critter.Biome] = byRarity
		end
		local pool = byRarity[critter.Rarity]
		if not pool then
			pool = {}
			byRarity[critter.Rarity] = pool
		end
		table.insert(pool, critter.Id)
	end
end

local GOLDEN_HOUR: Types.EventDef? = Config.Events.ById["golden_hour"]

-- Default context: Normal bait level 1, Near band, no boosts.
function Odds.DefaultContext(): Context
	return {
		BaitLevel = 1,
		Band = 1,
		ServerLuck = false,
		EventLuck = 1,
		GoldenBait = false,
		GoldenHour = false,
	}
end

function Odds.BaitLuck(level: number): number
	local levels = Config.Upgrades.Tracks.Bait.Levels
	local clamped = math.clamp(math.floor(level), 1, #levels)
	return levels[clamped].Value
end

function Odds.BandLuck(band: number): number
	local bands = Config.Biomes.DepthBands
	local entry = bands[math.clamp(math.floor(band), 1, #bands)]
	return entry.Luck
end

function Odds.Luck(ctx: Context): number
	local serverLuck = if ctx.ServerLuck then Config.Monetisation.Products.ServerLuck.LuckMultiplier or 1 else 1
	local eventLuck = math.clamp(ctx.EventLuck, 1, Config.Events.EventLuckCap)
	local lambda = Odds.BaitLuck(ctx.BaitLevel) * Odds.BandLuck(ctx.Band) * serverLuck * eventLuck
	return math.min(Config.Rarities.LuckCap, lambda)
end

-- Rarity chances for a luck value, in rank order. Golden Bait uses its own table (rarities with GoldenBaitWeight).
function Odds.RarityChances(lambda: number, goldenBait: boolean): { Chance }
	local weights: { Chance } = {}
	for _, rarity in Config.Rarities.List do
		local weight = if goldenBait then rarity.GoldenBaitWeight else rarity.Weight
		if weight and weight > 0 then
			-- The table's lowest rarity (the first one present) keeps its weight; every rarity above it is × λ.
			table.insert(weights, { Id = rarity.Id, Chance = if #weights == 0 then weight else weight * lambda })
		end
	end
	local total = 0
	for _, entry in weights do
		total += entry.Chance
	end
	for _, entry in weights do
		entry.Chance /= total
	end
	return weights
end

-- Variant chances in wire order (Normal, Golden, Rainbow). Normal takes the rest.
function Odds.VariantChances(goldenBait: boolean, goldenHour: boolean): { Chance }
	local effects = if goldenHour and GOLDEN_HOUR then GOLDEN_HOUR.Effects else nil
	local out: { Chance } = {}
	local rest = 1
	local normalIndex: number? = nil
	for _, variant in Config.Variants.List do
		if variant.Chance <= 0 then
			table.insert(out, { Id = variant.Id, Chance = 0 })
			normalIndex = #out
		else
			local multiplier = if goldenBait then variant.GoldenBaitMultiplier else 1
			if effects then
				if variant.Id == "Golden" then
					multiplier *= effects.GoldenMultiplier or 1
				elseif variant.Id == "Rainbow" then
					multiplier *= effects.RainbowMultiplier or 1
				end
			end
			local chance = math.min(variant.Cap, variant.Chance * multiplier)
			table.insert(out, { Id = variant.Id, Chance = chance })
			rest -= chance
		end
	end
	if normalIndex then
		out[normalIndex].Chance = rest
	end
	return out
end

-- Every rarity's chance for a context, for odds panels.
function Odds.ForContext(ctx: Context): { Chance }
	return Odds.RarityChances(Odds.Luck(ctx), ctx.GoldenBait)
end

-- Species that can be rolled for a biome and rarity (non-retired). Empty table when none.
function Odds.Pool(biomeId: string, rarityId: string): { string }
	local byRarity = pools[biomeId]
	return (byRarity and byRarity[rarityId]) or {}
end

local function pick(chances: { Chance }, u: number): string
	local acc = 0
	for _, entry in chances do
		acc += entry.Chance
		if u < acc then
			return entry.Id
		end
	end
	return chances[#chances].Id -- float rounding: u just under 1
end

-- Variant from a uniform u in [0, 1): Rainbow if u < rainbow, Golden if u < rainbow + golden, else Normal.
function Odds.PickVariant(variantChances: { Chance }, u: number): number
	local byId: { [string]: number } = {}
	for _, entry in variantChances do
		byId[entry.Id] = entry.Chance
	end
	local rainbow = byId.Rainbow or 0
	local golden = byId.Golden or 0
	local id = if u < rainbow then "Rainbow" elseif u < rainbow + golden then "Golden" else "Normal"
	return Config.Variants.ById[id].Wire
end

-- One full roll: rarity, then species (equal chance among the biome's species of that rarity), then variant.
-- Returns nil if the biome has no species of the rolled rarity (the config validator prevents this).
function Odds.Roll(biomeId: string, ctx: Context, rng: Random): RollResult?
	local rarity = pick(Odds.ForContext(ctx), rng:NextNumber())
	local pool = Odds.Pool(biomeId, rarity)
	if #pool == 0 then
		return nil
	end
	local species = pool[rng:NextInteger(1, #pool)]
	local variant = Odds.PickVariant(Odds.VariantChances(ctx.GoldenBait, ctx.GoldenHour), rng:NextNumber())
	return { Species = species, Rarity = rarity, Variant = variant }
end

return Odds
