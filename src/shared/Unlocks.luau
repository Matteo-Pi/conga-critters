--!strict
-- Unlocks: which biomes a player may enter and throw in (spec 3.1, 4.6; economy.md 4.2). Pure: callers pass LP and
-- any debug unlocks, so the server (ThrowService, gate access) and clients (lock effects) share one rule.
-- A biome is unlocked when LP reaches its GateLP, or when a debug command unlocked it this session.

local Config = require(script.Parent.Config)

local Unlocks = {}

export type DebugSet = { [string]: true }

function Unlocks.IsBiomeUnlocked(lp: number, debugUnlocked: DebugSet?, biomeId: string): boolean
	local biome = Config.Biomes.ById[biomeId]
	if not biome then
		return false
	end
	if debugUnlocked and debugUnlocked[biomeId] then
		return true
	end
	return lp >= biome.GateLP
end

-- The highest tier among unlocked fixed-tier biomes (economy.md 4.2): the biome cap and tier-matched biomes use it.
function Unlocks.TopTier(lp: number, debugUnlocked: DebugSet?): number
	local top = 0
	for _, biome in Config.Biomes.List do
		if not biome.TierMatched and biome.Tier and Unlocks.IsBiomeUnlocked(lp, debugUnlocked, biome.Id) then
			top = math.max(top, biome.Tier)
		end
	end
	return top
end

return Unlocks
