--!strict
-- EventService: clock events, MemoryStore, MessagingService (spec 9.2).

local EventService = {}

function EventService.Init(): () end

function EventService.Start(): () end

export type EventService = typeof(EventService)

return EventService
