--!strict
-- Line cutting (economy.md 10, 9.2; spec 4.4.2, 4.4.4, 4.4.5).
-- Only the back half can be cut: positions ceil(L/2) + 1 to L.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Cutting: Types.CuttingConfig = {
	-- Tier rule: when set to N, nobody can cut in a biome more than N tiers below their own top tier.
	-- nil = off (launch setting). 0 = only their own top biome or event biomes.
	CutTierGap = nil,

	CheckHz = 10,
	MinVictimLength = 10,
	CapsuleRadius = 2.75, -- studs, around the cutter's movement since the last check
	MaxVerticalGap = 4, -- studs
	MinCutterSpeed = 6, -- horizontal studs/s
	MinFreeSlots = 1,
	CutterCooldown = 10, -- s since the cutter's last cut
	VictimCooldown = 15, -- s since the victim was last cut (the immunity bubble)
	PairCooldown = 60, -- s, same cutter and victim
	CleanSeconds = 10, -- cutter must have no anti-cheat flag in this window
	FriendCuts = true,

	LooseSeconds = 8, -- loose critters hop in place this long, then run off
	GrabRadius = 4, -- studs

	BigStealAt = 50, -- "BIG STEAL!" banner
	ServerToastAt = 100, -- server-wide toast naming only the cutter
}

return deepFreeze(Cutting)
