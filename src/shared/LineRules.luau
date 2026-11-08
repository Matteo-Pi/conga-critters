--!strict
-- LineRules: the conga line's pure rules (spec 4.3; economy.md 4.6), shared so the server, the HUD and the checks
-- all use the same maths. Every number comes from Config/Line and Config/Upgrades.
--
--   capacity  = min(MaxCapacity, floor(leash capacity × (Longer Leash ? ×1.5 : 1)))      rebirth adds none
--   walkSpeed = Speed track value × max(MinSpeedFactor, 1 − SlowPerCritter × length)
--   cooldown  = max(Throw.CooldownMin, Throw.Cooldown − Rebirth.CooldownCut × rebirths)  seconds between throws
--   conga     = the Multiplier of the last Conga step whose MinLength ≤ length (×1 below the first)

local Config = require(script.Parent.Config)

local LineRules = {}

local function level(levels: { any }, value: number): any
	return levels[math.clamp(math.floor(value), 1, #levels)]
end

function LineRules.Capacity(leashLevel: number, longerLeash: boolean): number
	local leash = level(Config.Upgrades.Tracks.Leash.Levels, leashLevel).Value
	local multiplier = if longerLeash then Config.Line.LongerLeashMultiplier else 1
	return math.min(Config.Line.MaxCapacity, math.floor(leash * multiplier))
end

-- Seconds between this player's throws: each rebirth cuts Rebirth.CooldownCut, down to Throw.CooldownMin.
function LineRules.ThrowCooldown(rebirths: number): number
	local cut = Config.Rebirth.CooldownCut * math.max(0, math.floor(rebirths))
	return math.max(Config.Throw.CooldownMin, Config.Throw.Cooldown - cut)
end

function LineRules.SpeedFactor(length: number): number
	return math.max(Config.Line.MinSpeedFactor, 1 - Config.Line.SlowPerCritter * length)
end

function LineRules.WalkSpeed(speedLevel: number, length: number): number
	local base = level(Config.Upgrades.Tracks.Speed.Levels, speedLevel).Value
	return base * LineRules.SpeedFactor(length)
end

function LineRules.Conga(length: number): number
	local multiplier = 1
	for _, step in Config.Line.Conga do
		if length >= step.MinLength then
			multiplier = step.Multiplier
		end
	end
	return multiplier
end

-- Studs between this follower and the one in front (or the leader).
function LineRules.Spacing(speciesId: string): number
	local def = Config.Critters.ById[speciesId]
	return if def then Config.Line.Spacing[def.Size] else Config.Line.Spacing.M
end

-- Studs of path to keep for a line of this capacity (spec 9.5).
function LineRules.PathKeep(capacity: number): number
	return capacity * Config.Line.Path.KeepPerCapacity + Config.Line.Path.KeepExtra
end

return LineRules
