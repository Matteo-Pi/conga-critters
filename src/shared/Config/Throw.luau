--!strict
-- Throwing bait and critter arrival (spec 4.1, 4.2, 9.4). Not in spec 9.2's Config list; added on build day 1
-- because those numbers had no other home (logged in spec 16).

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Throw: Types.ThrowConfig = {
	Range = 45, -- studs
	Cooldown = 0.8, -- seconds; the client waits this long between throws
	CrittersPerThrow = 1, -- events (Critter Rush) can raise this
	RateLimitSlack = 0.1, -- the server accepts a throw (Cooldown − RateLimitSlack) s after the last accepted one
	RateLimitBurst = 3, -- ThrowBait token bucket: refills 1 per (Cooldown − RateLimitSlack) s, holds this many
	TargetRangeSlack = 6, -- target may be up to Range + this from the server-side position

	JoinDelay = 1.8, -- server adds the critter to the line this long after the bait lands
	RunInSeconds = 1.2, -- client animation
	EatSeconds = 0.6, -- client animation
	HopSeconds = 0.4, -- client animation: the hop from the bait to the line, after JoinDelay

	BurrowSearchRadius = 30, -- critter starts at the nearest Burrow within this of the bait
	FallbackSpawnMin = 14, -- else this far away, in a random direction
	FallbackSpawnMax = 20,

	-- Hand-tuned feel (C01-M2).
	FlightSeconds = 0.45, -- bait arc from hand to landing; the server uses it to time the landing
	ArcHeight = 7, -- studs above the straight line at the arc's midpoint
	RejectGraceSeconds = 0.4, -- a bait no CritterSpawned matched this long after landing (plus ping) puffs away
	ZonePollHz = 10, -- the client checks which zone it is in this often (THROW hidden in the hub)
}

return deepFreeze(Throw)
