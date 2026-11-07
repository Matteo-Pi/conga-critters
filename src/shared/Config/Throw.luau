--!strict
-- Throwing bait and critter arrival (spec 4.1, 4.2, 9.4). Not in spec 9.2's Config list; added on build day 1
-- because those numbers had no other home (logged in spec 16).

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Throw: Types.ThrowConfig = {
	Range = 45, -- studs
	Cooldown = 0.8, -- seconds
	CrittersPerThrow = 1, -- events (Critter Rush) can raise this
	RateLimitSlack = 0.1, -- ThrowBait allows 1 per (Cooldown − RateLimitSlack) s
	TargetRangeSlack = 6, -- target may be up to Range + this from the server-side position

	JoinDelay = 1.8, -- server adds the critter to the line this long after the bait lands
	RunInSeconds = 1.2, -- client animation
	EatSeconds = 0.6, -- client animation

	BurrowSearchRadius = 30, -- critter starts at the nearest Burrow within this of the bait
	FallbackSpawnMin = 14, -- else this far away, in a random direction
	FallbackSpawnMax = 20,
}

return deepFreeze(Throw)
