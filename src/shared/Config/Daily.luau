--!strict
-- Daily ladder and Golden Bait Stand (economy.md 5.9; spec 4.9).
-- "Best pen income" is defined in economy.md 4.5; amounts are worked out when the player claims or buys.

local Types = require(script.Parent.Parent.Types)
local Shields = require(script.Parent.Shields)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Daily: Types.DailyConfig = {
	-- A missed day pauses the ladder; after day 7 it starts again at day 1.
	Ladder = {
		{ Kind = "Coins", Minutes = 10, Floor = 100 },
		{ Kind = "GoldenBait", Amount = 1 },
		{ Kind = "Shield", Seconds = Shields.DailySeconds },
		{ Kind = "Coins", Minutes = 20, Floor = 250 },
		{ Kind = "GoldenBait", Amount = 2 },
		{ Kind = "Coins", Minutes = 30, Floor = 500 },
		{ Kind = "GoldenBait", Amount = 3, FirstTimeBadgeId = 0 }, -- badge id 0 until created
	},
	Stand = {
		Stock = 3,
		FreeCount = 1,
		PriceMinutes = 15, -- minutes of best pen income per paid bait
		PriceFloor = 500,
		RestockHourUTC = 0,
	},
}

return deepFreeze(Daily)
