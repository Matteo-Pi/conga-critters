--!strict
-- The conga line (economy.md 5.4, 4.6; spec 4.3).
-- capacity  = min(MaxCapacity, floor(leash capacity × (LongerLeashMultiplier if owned)))
--             100 free (the Leash track tops out there), 150 with Longer Leash; rebirth adds none (since 2026-11-08)
-- walkSpeed = (Speed track value) × max(MinSpeedFactor, 1 − SlowPerCritter × line length)
--             applied ahead of time in the shared simulation (Shared/WalkSpeedSync), SpeedLeadSeconds after a change
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
		{ MinLength = 75, Multiplier = 2.5 },
		{ MinLength = 100, Multiplier = 3 },
		{ MinLength = 150, Multiplier = 3.5 },
	},
	MaxCapacity = 150, -- the longest line (Leash 100 × Longer Leash 1.5); also the performance cap
	LongerLeashMultiplier = 1.5,
	BaseWalkSpeed = 20,
	SlowPerCritter = 0.003, -- ×0.70 at 100, ×0.60 (the floor) at 134 or more
	MinSpeedFactor = 0.6,
	-- Walk-speed changes are announced this long before they apply, so the client's predicted simulation applies them
	-- on the same step as the server's and nothing is corrected (spec 9.1; Server Authority docs: "light a fuse").
	SpeedLeadSeconds = 0.3,
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
		-- Ground height only (4.3): the leader is airborne when its feet are more than AirborneGap studs above the
		-- floor below (steps and slopes stay under it); the floor is looked for up to FloorProbe studs below the feet.
		AirborneGap = 1.5,
		FloorProbe = 60,
		HopMinGap = 1.0, -- a take-off within this many studs of the last hop marker adds none
		-- Path length added by height (a fence jumped over, a step) is caught up at LagCatchUp studs a second instead of
		-- all at once, up to LagMax studs (any more is caught up at once).
		LagCatchUp = 10,
		LagMax = 20,
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
		-- Phone cap lifted for the real-phone performance test (developer, 2026-11-08): 4,000 is more than 13 lines at
		-- the cap (12 debug leaders and the player's own), so only HideDistancePhone and FarUpdateEvery limit phones.
		-- Set a real cap from the phone numbers before launch (spec 16).
		MaxDrawnPhone = 4000,
		ClaimSeconds = 1.0,
		JoinHopHeight = 2.5,
		-- Every jump (walking or standing) sends a hop wave down the line, front to back, JumpWaveDelay seconds per
		-- follower: the developer's call on 2026-11-08 (it engages players). Each wave hop lasts JumpHopSeconds.
		JumpWave = true,
		JumpWaveHeight = 4.0,
		JumpWaveDelay = 0.03,
		-- Off since 2026-11-08 (the developer's call): followers also hop where the leader took off, as they pass that
		-- spot (spec 4.3 as first written), JumpHopHeight high.
		JumpHopAtSpot = false,
		JumpHopHeight = 3.5,
		JumpHopSeconds = 0.5,
		JumpWaveMax = 16, -- waves running down one line at once (a 150-line wave lasts about 4.5 s; jumps are ~1 s apart)
	},
	-- Own-line lengths that fire a banner with confetti (spec 4.3, 7.4), plus "FULL LINE!" when a line of at least
	-- FullLineBannerMin reaches its own capacity (100 free, 150 with Longer Leash), so free and pass lines get the same.
	Banners = { 50, 100 },
	FullLineBannerMin = 100,
}

return deepFreeze(Line)
