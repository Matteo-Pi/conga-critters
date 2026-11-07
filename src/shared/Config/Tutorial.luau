--!strict
-- Tutorial (spec 2.1, 2.2, 4.5.8). Fixed rolls happen only on free throws during the tutorial, never on
-- anything paid. The rest of the tutorial's data arrives with its milestone.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Tutorial: Types.TutorialConfig = {
	FixedRolls = {
		{ Throw = 3, Rarity = "Uncommon" },
		{ Throw = 6, Rarity = "Rare" },
	},
	-- The Manage Pen menu introduces itself only after this much playtime (and a delivery that stores a critter).
	ManagePenIntroMinPlaySeconds = 300,
}

return deepFreeze(Tutorial)
