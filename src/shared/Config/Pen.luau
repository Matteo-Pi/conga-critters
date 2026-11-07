--!strict
-- Pen, storage and favourites (economy.md 5.6; spec 4.5.6–4.5.9).
-- Pen slots (6 → 30) and the storage limit (50 → 200) come from the Pen and Storage tracks in Config/Upgrades.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Pen: Types.PenConfig = {
	BigStorageBonus = 100, -- Big Storage pass

	-- Critters matching these overflow a full storage (up to OverflowLimit) and are never auto-released,
	-- whatever the filter (spec 4.5.6 steps 2 and 4): rarity rank at least ProtectedMinRank, or a listed variant.
	-- Bound critters ALWAYS count too, but that is a hard rule (spec 0.3 rule 6, spec 4.5.6), checked in
	-- PenService code, not a Config value.
	-- Not the same as the spec's "protected" (pinned or favourite), which stops every automatic move or release.
	ProtectedMinRank = 5, -- Legendary
	ProtectedVariants = { "Rainbow" },
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
