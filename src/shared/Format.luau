--!strict
-- Number formatting for display (economy.md 8.3). Display only: affordability is always decided on exact numbers.
--
--   Format.Balance(n)    coins/LP held: rounds DOWN, so a balance never looks bigger than it is
--   Format.Price(n)      costs: rounds UP, so a price never looks smaller than it is
--   Format.PerMinute(s)  a per-second rate shown per minute (rounded down), e.g. pen income
--   Format.Odds(p)       a chance from 0 to 1 as a percentage with up to three significant figures
--
-- Below 1,000: the whole number. From 1,000: three significant figures, trailing zeros dropped, plus a suffix
-- (K, M, B, T, Qa, Qi, Sx, Sp, Oc, No, Dc). From 10^36 (past Dc): scientific notation, e.g. "1.2e36".
-- Never uses string.format("%d"), which errors on numbers with a fraction (economy.md 8.2).

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local SCIENTIFIC_EXPONENT = (#SUFFIXES + 1) * 3 -- 36
-- Absorbs float error such as 1229.9999999 or 500.0000000001 before flooring or ceiling. The values rounded are
-- at most 1,000, where a double's spacing is about 1e-13, so this never changes a genuinely different number.
local EPSILON = 1e-9

type Direction = "down" | "up"

local function round(x: number, direction: Direction): number
	local r = if direction == "down" then math.floor(x + EPSILON) else math.ceil(x - EPSILON)
	if r == 0 then
		return 0 -- ceil of a tiny positive number minus EPSILON is -0, which tostring shows as "-0"
	end
	return r
end

-- "123" with 2 integer digits -> "12.3"; trailing zeros and a bare point are dropped.
local function placePoint(digits: string, integerDigits: number): string
	local whole = string.sub(digits, 1, integerDigits)
	local fraction = string.gsub(string.sub(digits, integerDigits + 1), "0+$", "")
	if fraction == "" then
		return whole
	end
	return whole .. "." .. fraction
end

-- Largest e with 10^e <= n. math.log10 can be off by one near powers of ten, so correct it.
local function exponentOf(n: number): number
	local e = math.floor(math.log10(n))
	while 10 ^ (e + 1) <= n do
		e += 1
	end
	while 10 ^ e > n do
		e -= 1
	end
	return e
end

local function formatAmount(n: number, direction: Direction): string
	if n ~= n then
		return "?" -- NaN: a bug upstream; show something harmless
	end
	if n < 0 then
		return "-" .. formatAmount(-n, direction)
	end
	if n == math.huge then
		return "∞"
	end

	if n < 1000 then
		local whole = round(n, direction)
		if whole < 1000 then
			return tostring(whole)
		end
		n = whole -- 999.2 rounded up is 1,000: format it as "1K"
	end

	-- Three significant figures as an integer from 100 to 999, scaled by 10^(e − 2).
	local e = exponentOf(n)
	local mantissa = round(n / 10 ^ (e - 2), direction)
	if mantissa >= 1000 then -- rounding up carried into the next power of ten (999,500 -> 1,000K -> 1M)
		mantissa = 100
		e += 1
	elseif mantissa < 100 then -- float error pushed it just below (cannot happen after exponentOf, but be safe)
		mantissa = 100
	end
	local digits = tostring(mantissa)

	if e >= SCIENTIFIC_EXPONENT then
		return placePoint(digits, 1) .. "e" .. tostring(e)
	end

	local group = e // 3 -- 1 = K, 2 = M, …
	return placePoint(digits, e - group * 3 + 1) .. SUFFIXES[group]
end

function Format.Balance(n: number): string
	return formatAmount(n, "down")
end

function Format.Price(n: number): string
	return formatAmount(n, "up")
end

function Format.PerMinute(perSecond: number): string
	return formatAmount(perSecond * 60, "down")
end

local ODDS_FLOOR = 0.001 -- percent

function Format.Odds(chance: number): string
	if chance ~= chance or chance <= 0 then
		return "0%"
	end
	local percent = chance * 100
	if percent >= 100 then
		return "100%"
	end
	if percent < ODDS_FLOOR then
		return "less than 0.001%" -- never show a real chance as 0%
	end
	-- %g gives three significant figures and drops trailing zeros; values here stay in fixed notation.
	return string.format("%.3g", percent) .. "%"
end

export type Format = typeof(Format)

return table.freeze(Format)
