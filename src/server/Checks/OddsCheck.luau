--!strict
-- C01-M1 check 1 (spec 10.2): over 100,000 rolls each, every rarity's and variant's share is within 4 standard
-- errors (√(p(1 − p)/n)) of its configured share, for Meadow at λ = 1, Golden Bait, Server Luck (λ = 2) and
-- Golden Hour. Also checks Odds.RarityChances against the worked table in economy.md 4.1 (spec 4.2).
-- Not loaded at boot; run with the `check odds` debug command.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Odds = require(Shared:WaitForChild("Odds") :: ModuleScript)
local Config = require(Shared:WaitForChild("Config") :: ModuleScript)

local OddsCheck = {}

local MAX_Z = 4
local YIELD_EVERY = 10000

-- economy.md 4.1: λ and the percentages shown, rounded to 3 significant figures there.
local WORKED: { { Lambda: number, Golden: boolean, Expected: { [string]: number } } } = {
	{
		Lambda = 1,
		Golden = false,
		Expected = { Common = 70, Uncommon = 22, Rare = 6, Epic = 1.6, Legendary = 0.35, Mythic = 0.05 },
	},
	{
		Lambda = 1.25,
		Golden = false,
		Expected = { Common = 65.1, Uncommon = 25.6, Rare = 6.98, Epic = 1.86, Legendary = 0.407, Mythic = 0.0581 },
	},
	{
		Lambda = 1.5,
		Golden = false,
		Expected = { Common = 60.9, Uncommon = 28.7, Rare = 7.83, Epic = 2.09, Legendary = 0.457, Mythic = 0.0652 },
	},
	{
		Lambda = 2,
		Golden = false,
		Expected = { Common = 53.8, Uncommon = 33.8, Rare = 9.23, Epic = 2.46, Legendary = 0.538, Mythic = 0.0769 },
	},
	{
		Lambda = 2.68,
		Golden = false,
		Expected = { Common = 46.5, Uncommon = 39.2, Rare = 10.7, Epic = 2.85, Legendary = 0.624, Mythic = 0.0891 },
	},
	{
		Lambda = 4.02,
		Golden = false,
		Expected = { Common = 36.7, Uncommon = 46.4, Rare = 12.7, Epic = 3.37, Legendary = 0.738, Mythic = 0.105 },
	},
	{
		Lambda = 10,
		Golden = false,
		Expected = { Common = 18.9, Uncommon = 59.5, Rare = 16.2, Epic = 4.32, Legendary = 0.946, Mythic = 0.135 },
	},
	{ Lambda = 1, Golden = true, Expected = { Rare = 70, Epic = 22, Legendary = 7, Mythic = 1 } },
	{ Lambda = 4.02, Golden = true, Expected = { Rare = 36.7, Epic = 46.4, Legendary = 14.8, Mythic = 2.11 } },
}

-- Half a unit in the third significant figure of `expected` (a percentage).
local function roundingTolerance(expected: number): number
	return 0.5 * 10 ^ (math.floor(math.log10(expected)) - 2)
end

local function fmtPct(x: number): string
	return string.format("%.4f%%", x * 100)
end

local function zLine(lines: { string }, label: string, id: string, k: number, n: number, p: number): boolean
	local observed = k / n
	local se = math.sqrt(p * (1 - p) / n)
	local z = if se > 0 then (observed - p) / se else (if observed == p then 0 else math.huge)
	local ok = math.abs(z) <= MAX_Z
	table.insert(
		lines,
		string.format(
			"%s %-28s %-10s expected %10s observed %10s (%6d/%d) z=%+.2f",
			if ok then "PASS" else "FAIL",
			label,
			id,
			fmtPct(p),
			fmtPct(observed),
			k,
			n,
			z
		)
	)
	return ok
end

local function sample(
	lines: { string },
	label: string,
	biomeId: string,
	ctx: Odds.Context,
	n: number,
	rng: Random,
	checkSpecies: boolean
): boolean
	local rarityCounts: { [string]: number } = {}
	local variantCounts: { [number]: number } = {}
	local speciesCounts: { [string]: number } = {}
	for i = 1, n do
		local result = Odds.Roll(biomeId, ctx, rng)
		assert(result, `Odds.Roll returned nil for {biomeId}`)
		rarityCounts[result.Rarity] = (rarityCounts[result.Rarity] or 0) + 1
		variantCounts[result.Variant] = (variantCounts[result.Variant] or 0) + 1
		speciesCounts[result.Species] = (speciesCounts[result.Species] or 0) + 1
		if i % YIELD_EVERY == 0 then
			task.wait()
		end
	end

	local allOk = true
	table.insert(lines, `-- {label}: {biomeId}, λ = {Odds.Luck(ctx)}, n = {n}`)
	local rarityChances = Odds.ForContext(ctx)
	for _, entry in rarityChances do
		allOk = zLine(lines, label .. " rarity", entry.Id, rarityCounts[entry.Id] or 0, n, entry.Chance) and allOk
	end
	for id, count in rarityCounts do
		local inTable = false
		for _, entry in rarityChances do
			inTable = inTable or entry.Id == id
		end
		if not inTable then
			table.insert(lines, `FAIL {label}: rolled {count} {id}, which is not in the table`)
			allOk = false
		end
	end
	for _, entry in Odds.VariantChances(ctx.GoldenBait, ctx.GoldenHour) do
		local wire = Config.Variants.ById[entry.Id].Wire
		allOk = zLine(lines, label .. " variant", entry.Id, variantCounts[wire] or 0, n, entry.Chance) and allOk
	end
	if checkSpecies then
		-- Within a rarity every species has an equal chance: share = P(rarity) / #pool.
		for _, entry in rarityChances do
			local pool = Odds.Pool(biomeId, entry.Id)
			for _, species in pool do
				allOk = zLine(lines, label .. " species", species, speciesCounts[species] or 0, n, entry.Chance / #pool)
					and allOk
			end
		end
	end
	return allOk
end

function OddsCheck.Run(n: number?, seed: number?): (boolean, string)
	local count = n or 100000
	local rng = Random.new(seed or 20261110)
	local lines: { string } = {}
	local allOk = true

	-- Worked table (economy.md 4.1 = spec 4.2)
	table.insert(lines, "-- RarityChances vs economy.md 4.1 worked table (3 significant figures)")
	for _, row in WORKED do
		local chances = Odds.RarityChances(row.Lambda, row.Golden)
		local rowOk = true
		local shown: { string } = {}
		for _, entry in chances do
			local expected = row.Expected[entry.Id]
			local pct = entry.Chance * 100
			if expected == nil or math.abs(pct - expected) > roundingTolerance(expected) + 1e-9 then
				rowOk = false
			end
			table.insert(shown, string.format("%s %.4g%%", entry.Id, pct))
		end
		local countExpected = 0
		for _ in row.Expected do
			countExpected += 1
		end
		rowOk = rowOk and countExpected == #chances
		allOk = allOk and rowOk
		table.insert(
			lines,
			string.format(
				"%s λ=%-5s %-7s %s",
				if rowOk then "PASS" else "FAIL",
				tostring(row.Lambda),
				if row.Golden then "golden" else "normal",
				table.concat(shown, ", ")
			)
		)
	end

	-- Luck for the contexts below
	local base = Odds.DefaultContext()
	local serverLuck = Odds.DefaultContext()
	serverLuck.ServerLuck = true
	local golden = Odds.DefaultContext()
	golden.GoldenBait = true
	local goldenHour = Odds.DefaultContext()
	goldenHour.GoldenHour = true

	local luckOk = Odds.Luck(base) == 1 and Odds.Luck(serverLuck) == 2 and Odds.Luck(golden) == 1
	local capped = Odds.DefaultContext()
	capped.BaitLevel = 15
	capped.Band = 3
	capped.ServerLuck = true
	capped.EventLuck = 99 -- capped to EventLuckCap (3), then λ capped to LuckCap (10)
	luckOk = luckOk and Odds.Luck(capped) == Config.Rarities.LuckCap
	allOk = allOk and luckOk
	table.insert(
		lines,
		string.format(
			"%s Luck: base %g, Server Luck %g, Golden Bait %g, bait 15 + Far + Server Luck + event 99 -> %g (cap %g)",
			if luckOk then "PASS" else "FAIL",
			Odds.Luck(base),
			Odds.Luck(serverLuck),
			Odds.Luck(golden),
			Odds.Luck(capped),
			Config.Rarities.LuckCap
		)
	)

	-- Sampled rolls
	allOk = sample(lines, "Meadow λ=1", "meadow", base, count, rng, true) and allOk
	allOk = sample(lines, "Golden Bait", "meadow", golden, count, rng, false) and allOk
	allOk = sample(lines, "Server Luck", "meadow", serverLuck, count, rng, false) and allOk
	allOk = sample(lines, "Golden Hour", "meadow", goldenHour, count, rng, false) and allOk

	table.insert(lines, if allOk then "OddsCheck: ALL PASS" else "OddsCheck: FAILURES ABOVE")
	return allOk, table.concat(lines, "\n")
end

return OddsCheck
