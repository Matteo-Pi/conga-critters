--!strict
-- Every Config module in one table: `local Config = require(Shared.Config)`, then `Config.Line.MaxCapacity`.
-- All content and numbers live here (CLAUDE.md); each module is deep-frozen.

return table.freeze({
	Rarities = require(script.Rarities),
	Variants = require(script.Variants),
	Critters = require(script.Critters),
	Biomes = require(script.Biomes),
	Upgrades = require(script.Upgrades),
	Line = require(script.Line),
	Throw = require(script.Throw),
	Cutting = require(script.Cutting),
	Delivery = require(script.Delivery),
	Pen = require(script.Pen),
	Income = require(script.Income),
	Rebirth = require(script.Rebirth),
	Index = require(script.Index),
	Events = require(script.Events),
	Daily = require(script.Daily),
	Shields = require(script.Shields),
	Monetisation = require(script.Monetisation),
	Tutorial = require(script.Tutorial),
	Admin = require(script.Admin),
	Debug = require(script.Debug),
})
