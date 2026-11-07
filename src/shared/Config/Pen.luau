--!strict
-- Pen, storage and favourites (economy.md 5.6; spec 4.5.6–4.5.9).
-- Pen slots (6 → 30) and the storage limit (50 → 200) come from the Pen and Storage tracks in Config/Upgrades.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Pen: Types.PenConfig = {
	BigStorageBonus = 100, -- Big Storage pass

	-- Never-release critters: never auto-released, whatever the filter, and they overflow a full storage
	-- (up to OverflowLimit) instead of being released (spec 4.5.6 steps 2 and 4). A critter is never-release if
	-- its rarity rank is at least NeverReleaseMinRank or its variant is listed in NeverReleaseVariants.
	-- Bound critters are ALWAYS never-release too, but that is a hard rule (spec 0.3 rule 6, spec 4.5.6),
	-- checked in PenService code, not a Config value.
	NeverReleaseMinRank = 5, -- Legendary
	NeverReleaseVariants = { "Rainbow" },
	OverflowLimit = 50,

	-- Defaults for new players' settings (saved per player in Settings).
	AutoPlace = true,
	AutoRelease = {
		Enabled = true,
		UpTo = 3, -- rarity rank: Rare or lower
		IncludeGolden = false, -- Normal variant only, so Golden critters are kept
	},
	MaxReleaseUpTo = 4, -- the filter goes up to Epic at most

	WarningFraction = 0.9, -- Manage Pen warning dot when storage is at least this full

	FreeFavorites = 3,
	MaxFavorites = 8, -- free slots plus both More Favourites passes
}

return deepFreeze(Pen)
