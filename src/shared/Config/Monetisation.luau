--!strict
-- Passes and developer products (spec 6.1, 6.2; economy.md 5.11). STUB: every Id is 0 until the passes and
-- products exist on the Creator Hub (C01-M6). The config validator must reject zero ids in live servers.
-- Pass effects live with the systems they change: Income (2x Coins, VIP), Line (Longer Leash), Pen (Big Storage).

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Monetisation: Types.MonetisationConfig = {
	Passes = {
		TwoXCoins = { Key = "TwoXCoins", Name = "2x Coins", Id = 0, Price = 399, Priority = "P0" },
		LongerLeash = { Key = "LongerLeash", Name = "Longer Leash", Id = 0, Price = 299, Priority = "P0" },
		VIP = { Key = "VIP", Name = "VIP", Id = 0, Price = 249, Priority = "P1" },
		AutoBait = { Key = "AutoBait", Name = "Auto-Bait", Id = 0, Price = 499, Priority = "P2" },
		BigStorage = { Key = "BigStorage", Name = "Big Storage", Id = 0, Price = 149, Priority = "P1" },
		MoreFavoritesI = {
			Key = "MoreFavoritesI",
			Name = "More Favourites I",
			Id = 0,
			Price = 99,
			Priority = "P1",
			FavoriteSlots = 2,
		},
		MoreFavoritesII = {
			Key = "MoreFavoritesII",
			Name = "More Favourites II",
			Id = 0,
			Price = 199,
			Priority = "P1",
			FavoriteSlots = 3,
		},
	},
	Products = {
		GoldenBait3 = {
			Key = "GoldenBait3",
			Name = "Golden Bait ×3",
			Id = 0,
			Price = 49,
			Priority = "P0",
			PaidRandom = true, -- paid random item: odds panel + PolicyService gating (spec 6.4)
			GoldenBait = 3,
		},
		LineShield = {
			Key = "LineShield",
			Name = "Line Shield",
			Id = 0,
			Price = 29,
			Priority = "P0",
			PaidRandom = false,
			ShieldSeconds = 600,
		},
		ServerLuck = {
			Key = "ServerLuck",
			Name = "Server Luck",
			Id = 0,
			Price = 99,
			Priority = "P0",
			PaidRandom = true, -- paid odds booster (spec 6.4)
			LuckMultiplier = 2,
			LuckMinutes = 15,
		},
	},
	ServerLuck = {
		MaxQueueMinutes = 60, -- buying again adds time, never a bigger multiplier
		BuyableBelowMinutes = 45, -- the button is unavailable while more than this is queued
	},
}

return deepFreeze(Monetisation)
