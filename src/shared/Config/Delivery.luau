--!strict
-- Delivery (economy.md 5.4, 4.4; spec 4.5.2, 4.5.5).
-- Critters leave the front at max(MinRate, L₀ ÷ RateDivisor) per second, L₀ = length when delivery starts.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local Delivery: Types.DeliveryConfig = {
	MinRate = 8,
	RateDivisor = 4,
	-- Leaving mid-run banks the line at base value: coin boosts apply, but no Conga multiplier and no LP.
	BankOnLeave = {
		UseConga = false,
		GiveLP = false,
	},
}

return deepFreeze(Delivery)
