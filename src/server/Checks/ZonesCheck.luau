--!strict
-- C01-M1 check 2 (spec 10.2): zone tests return the right zone for sample points across the hub, every depth band,
-- every pen and every gate. The points come from the intended greybox layout (spec 3.1, 16; CHANGELOG build day
-- 2d), not from the zone parts, so a misplaced or mis-rotated part fails.
-- Not loaded at boot; run with the `check zones` debug command.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared:WaitForChild("Zones") :: ModuleScript)

local ZonesCheck = {}

-- Greybox layout: hub at the origin; gates on a 105-stud ring, 60° apart; each biome's near end 115 studs out,
-- 400 deep, 110 wide at the near end and 350 at the far end; bands 0–130, 130–270, 270–400.
local Y = 3
local GATE_RING = 105
local BIOME_START = 115
local BIOME_DEPTH = 400
local NEAR_WIDTH = 110
local FAR_WIDTH = 350

-- Gate slots: angle in degrees (from +X towards +Z) and what's behind them.
local GATES: { { Angle: number, Biome: string?, Slot: number } } = {
	{ Angle = 0, Biome = "meadow", Slot = 1 },
	{ Angle = 60, Biome = "jungle", Slot = 2 },
	{ Angle = 120, Biome = "peaks", Slot = 3 },
	{ Angle = 180, Biome = nil, Slot = 4 },
	{ Angle = 240, Biome = nil, Slot = 5 },
	{ Angle = 300, Biome = nil, Slot = 6 },
}

-- Pen plot centres (8 pens on a 62-stud ring, 22.5° either side of each hub corner).
local PENS: { Vector3 } = {
	Vector3.new(57, Y, 24),
	Vector3.new(24, Y, 57),
	Vector3.new(-24, Y, 57),
	Vector3.new(-57, Y, 24),
	Vector3.new(-57, Y, -24),
	Vector3.new(-24, Y, -57),
	Vector3.new(24, Y, -57),
	Vector3.new(57, Y, -24),
}

local function axis(angleDeg: number): (Vector3, Vector3)
	local a = math.rad(angleDeg)
	local forward = Vector3.new(math.cos(a), 0, math.sin(a))
	local side = Vector3.new(-math.sin(a), 0, math.cos(a))
	return forward, side
end

-- A point `depth` studs past a biome's near end and `lateral` studs off its axis.
local function biomePoint(angleDeg: number, depth: number, lateral: number): Vector3
	local forward, side = axis(angleDeg)
	return Vector3.new(0, Y, 0) + forward * (BIOME_START + depth) + side * lateral
end

local function halfWidthAt(depth: number): number
	return (NEAR_WIDTH + (FAR_WIDTH - NEAR_WIDTH) * depth / BIOME_DEPTH) / 2
end

function ZonesCheck.Cases(): { { Name: string, Point: Vector3, Expected: string } }
	local cases: { { Name: string, Point: Vector3, Expected: string } } = {}
	local function add(name: string, point: Vector3, expected: string)
		table.insert(cases, { Name = name, Point = point, Expected = expected })
	end

	add("hub centre", Vector3.new(0, Y, 0), "safe")
	add("FirstSpawn pad", Vector3.new(65, Y, 0), "safe")
	for index, point in PENS do
		add(`pen {index} centre`, point, `safe pen={index}`)
	end
	for _, gate in GATES do
		local forward = axis(gate.Angle)
		local point = Vector3.new(0, Y, 0) + forward * GATE_RING
		if gate.Biome then
			add(`gate {gate.Slot} ({gate.Biome})`, point, `safe gate={gate.Biome}`)
		else
			add(`gate {gate.Slot} (coming soon)`, point, `safe soon={gate.Slot}`)
		end
	end
	local bandMids = { 65, 200, 335 }
	for _, gate in GATES do
		local biome = gate.Biome
		if not biome then
			continue
		end
		for band, depth in bandMids do
			add(`{biome} band {band} on axis`, biomePoint(gate.Angle, depth, 0), `biome={biome} band={band}`)
		end
		-- Just inside and just outside an angled wall, at the middle of the Mid band.
		local edge = halfWidthAt(200)
		add(`{biome} mid, 5 inside the left edge`, biomePoint(gate.Angle, 200, edge - 5), `biome={biome} band=2`)
		add(`{biome} mid, 5 outside the right edge`, biomePoint(gate.Angle, 200, -(edge + 5)), "none")
		add(`{biome} near the near-band seam`, biomePoint(gate.Angle, 129, 0), `biome={biome} band=1`)
		add(`{biome} past the far seam`, biomePoint(gate.Angle, 271, 0), `biome={biome} band=3`)
	end
	add("past the Meadow's far end", biomePoint(0, BIOME_DEPTH + 10, 0), "none")
	add("between Meadow and Jungle", biomePoint(30, 200, 0), "none")
	return cases
end

function ZonesCheck.Run(): (boolean, string)
	local root = workspace:WaitForChild("Map"):WaitForChild("Zones")
	local lines: { string } = {}
	local allOk = true
	local cases = ZonesCheck.Cases()
	for _, case in cases do
		local actual = Zones.Describe(Zones.Classify(root, case.Point))
		local ok = actual == case.Expected
		allOk = allOk and ok
		table.insert(
			lines,
			string.format(
				"%s %-36s (%7.1f, %5.1f, %7.1f) expected %-26s got %s",
				if ok then "PASS" else "FAIL",
				case.Name,
				case.Point.X,
				case.Point.Y,
				case.Point.Z,
				case.Expected,
				actual
			)
		)
	end
	table.insert(lines, `ZonesCheck: {#cases} points, ` .. (if allOk then "ALL PASS" else "FAILURES ABOVE"))
	return allOk, table.concat(lines, "\n")
end

return ZonesCheck
