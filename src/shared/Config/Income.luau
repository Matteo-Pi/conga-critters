--!strict
-- Pen income and coin boosts (economy.md 5.6, 4.3, 4.5).
-- pen income per second = PenRate × coinBoost × sum of value(c) over critters in pen slots
-- coinBoost = (2x Coins) × (VIP) × (1 + min(FriendBoostMax, FriendBoostPerFriend × friends))
--           × rebirth bonus (Config/Rebirth) × Index bonus (Config/Index) × event coin multiplier

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Income: Types.IncomeConfig = {
	PenRate = 0.0006,
	TwoXCoinsMultiplier = 2,
	VIPMultiplier = 1.1,
	FriendBoostPerFriend = 0.1, -- coins only, not LP
	FriendBoostMax = 0.3,
}

return deepFreeze(Income)
