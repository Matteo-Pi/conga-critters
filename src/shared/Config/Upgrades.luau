--!strict
-- Upgrade tracks (economy.md 5.5). Every level's effect (`Value`) and cost; level 1 is free.
-- Leash: capacity. Bait: luck multiplier. Pen: slots. Speed: walk speed. Storage: storage limit.
-- Costs are per level, not a formula, because income jumps ×10 at each biome. Rebirth resets every track.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local function track(id: string, levels: { { number } }): Types.UpgradeTrack
	local out: { Types.UpgradeLevel } = {}
	for _, row in levels do
		table.insert(out, { Value = row[1], Cost = row[2] })
	end
	return { Id = id, Levels = out }
end

local Upgrades: Types.UpgradesConfig = {
	Order = { "Leash", "Bait", "Pen", "Speed", "Storage" },
	Tracks = {
		Leash = track("Leash", {
			{ 10, 0 },
			{ 15, 30 },
			{ 20, 80 },
			{ 30, 200 },
			{ 40, 500 },
			{ 50, 2000 },
			{ 65, 6000 },
			{ 80, 15000 },
			{ 100, 40000 },
			{ 125, 250000 },
			{ 150, 700000 },
			{ 175, 2000000 },
			{ 200, 5000000 },
		}),
		Bait = track("Bait", {
			{ 1.00, 0 },
			{ 1.12, 50 },
			{ 1.24, 150 },
			{ 1.36, 400 },
			{ 1.48, 1000 },
			{ 1.60, 3000 },
			{ 1.72, 10000 },
			{ 1.84, 30000 },
			{ 1.96, 80000 },
			{ 2.08, 250000 },
			{ 2.20, 700000 },
			{ 2.32, 2000000 },
			{ 2.44, 5000000 },
			{ 2.56, 12000000 },
			{ 2.68, 30000000 },
		}),
		Pen = track("Pen", {
			{ 6, 0 },
			{ 8, 100 },
			{ 10, 300 },
			{ 12, 800 },
			{ 14, 2500 },
			{ 16, 8000 },
			{ 18, 25000 },
			{ 20, 70000 },
			{ 22, 200000 },
			{ 24, 600000 },
			{ 26, 1500000 },
			{ 28, 4000000 },
			{ 30, 10000000 },
		}),
		Speed = track("Speed", {
			{ 20, 0 },
			{ 21, 75 },
			{ 22, 250 },
			{ 23, 800 },
			{ 24, 3000 },
			{ 25, 10000 },
			{ 26, 40000 },
			{ 27, 150000 },
			{ 28, 500000 },
		}),
		Storage = track("Storage", {
			{ 50, 0 },
			{ 75, 2000 },
			{ 100, 20000 },
			{ 125, 200000 },
			{ 150, 1000000 },
			{ 175, 3000000 },
			{ 200, 8000000 },
		}),
	},
}

return deepFreeze(Upgrades)
