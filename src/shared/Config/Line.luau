--!strict
-- The conga line (economy.md 5.4, 4.6; spec 4.3).
-- capacity  = min(MaxCapacity, floor((leash capacity + RebirthLeashBonus × rebirths) × (LongerLeashMultiplier if owned)))
-- walkSpeed = (Speed track value) × max(MinSpeedFactor, 1 − SlowPerCritter × line length)
-- Leash capacity and walk speed per level live in Config/Upgrades; Speed level 1 must equal BaseWalkSpeed.

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
	-- Breadcrumb paths (spec 9.5). Server and clients use the same numbers.
	Path = {
		MinStep = 0.4,
		KeepPerCapacity = 4, -- the largest spacing, so a full line of L critters still fits
		KeepExtra = 30,
		ResetJump = 25,
		ServerSampleHz = 15,
	},
	-- Client drawing (spec 9.5). Hand-tuned in C01-M3.
	Render = {
		HopHeight = 0.6,
		HopSpeed = 11,
		HopPhase = 0.7,
		IdleHop = 0.25,
		WaddleDegrees = 7,
		Smoothing = 8,
		SnapDistance = 60,
		FullDetailDistance = 80,
		FarUpdateEvery = 2, -- beyond FullDetailDistance, move a follower every this many frames
		HideDistance = 200,
		HideDistancePhone = 150,
		MaxDrawn = 900,
		MaxDrawnPhone = 350,
		ClaimSeconds = 1.0,
		JoinHopHeight = 2.5,
	},
	Banners = { 100, 200, 300 },
}

return deepFreeze(Line)
