--!strict
-- The conga line (economy.md 5.4, 4.6; spec 4.3).
-- capacity  = min(MaxCapacity, floor((leash capacity + RebirthLeashBonus × rebirths) × (LongerLeashMultiplier if owned)))
-- walkSpeed = (BaseWalkSpeed + speed level − 1) × max(MinSpeedFactor, 1 − SlowPerCritter × line length)
-- Leash capacity and walk speed per level live in Config/Upgrades.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Line: Types.LineConfig = {
	-- Conga multiplier, set by the line's length when delivery starts.
	Conga = {
		{ MinLength = 1, Multiplier = 1 },
		{ MinLength = 10, Multiplier = 1.25 },
		{ MinLength = 25, Multiplier = 1.5 },
		{ MinLength = 50, Multiplier = 2 },
		{ MinLength = 100, Multiplier = 3 },
		{ MinLength = 150, Multiplier = 3.5 },
		{ MinLength = 200, Multiplier = 4 },
		{ MinLength = 300, Multiplier = 5 },
	},
	MaxCapacity = 300, -- performance cap; passes and rebirths never exceed it
	RebirthLeashBonus = 10,
	LongerLeashMultiplier = 1.5,
	BaseWalkSpeed = 20,
	SlowPerCritter = 0.0015,
	MinSpeedFactor = 0.6,
	-- Follower spacing in studs, by size class.
	Spacing = {
		S = 2.2,
		M = 3.0,
		L = 4.0,
	},
}

return deepFreeze(Line)
