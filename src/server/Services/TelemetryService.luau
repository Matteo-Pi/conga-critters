--!strict
-- TelemetryService: wraps AnalyticsService; never lets an analytics error break gameplay (spec 9.2).

local TelemetryService = {}

function TelemetryService.Init(): () end

function TelemetryService.Start(): () end

export type TelemetryService = typeof(TelemetryService)

return TelemetryService
