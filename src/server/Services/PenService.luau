--!strict
-- PenService: pen and storage contents, placement rules, pins, favourites, releases, PenSync and PenDisplay (spec 9.2).
-- TODO(C01-M4): protection check = Config.Pen.ProtectedMinRank / ProtectedVariants, OR the critter is bound.
-- Bound critters are always protected (never auto-released, may overflow storage): a hard rule from spec 0.3
-- rule 6 and spec 4.5.6, so it lives in code here, not in Config.

local PenService = {}

function PenService.Init(): () end

function PenService.Start(): () end

export type PenService = typeof(PenService)

return PenService
