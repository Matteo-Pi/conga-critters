--!strict
-- Events and luck boosts (economy.md 5.10; spec 4.10). New events are data: add an entry to `list`.
-- Clock events start from UTC time; admin events go out through MessagingService and MemoryStore.

local Types = require(script.Parent.Parent.Types)
local deepFreeze = require(script.Parent.Parent.Util.DeepFreeze)

local list: { Types.EventDef } = {
	{
		Id = "golden_hour",
		Name = "Golden Hour",
		Schedule = { Kind = "Hourly", StartMinute = 0, DurationMinutes = 5 }, -- :00 to :05 UTC every hour
		Effects = { GoldenMultiplier = 5, RainbowMultiplier = 3 }, -- variant caps still apply
	},
	{
		Id = "critter_rush",
		Name = "Critter Rush",
		-- Admin-started (`/event start critter_rush [minutes]`); runs 30 minutes when no length is given (spec 16).
		Schedule = { Kind = "Admin", DurationMinutes = 30 },
		Effects = { CrittersPerThrow = 2 },
	},
}

local byId: { [string]: Types.EventDef } = {}
for _, event in list do
	byId[event.Id] = event
end

local Events: Types.EventsConfig = {
	List = list,
	ById = byId,
	EventLuckCap = 3, -- eventLuck in the roll (economy.md 4.1) is at most this
	AdminLuck = {
		MaxMultiplier = 3, -- `/luck <multiplier> <minutes>`
		MaxMinutes = 30,
	},
	Stampede = {
		MaxCount = 60, -- `/stampede <biome> [count]`
		MinRarity = "Rare",
	},
	WeeklyAdmin = {
		WeekdayUTC = 7, -- Saturday
		HourUTC = 20,
	},
}

return deepFreeze(Events)
