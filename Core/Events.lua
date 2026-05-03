----------------------------------------------------------------------
-- BRutus Guild Manager - Core/Events
-- Minimal in-process pub/sub EventBus.
-- Modules subscribe with On(), unsubscribe with Off(), fire with Emit().
----------------------------------------------------------------------
local Events = {}
BRutus.Events = Events

-- _listeners[eventName][listenerId] = callbackFn
local _listeners = {}

-- Subscribe to an event.
-- BRutus.Events:On("ALERT_UPDATED", "RaidBrain", function(data) ... end)
function Events:On(event, id, fn)
    if not _listeners[event] then
        _listeners[event] = {}
    end
    _listeners[event][id] = fn
end

-- Unsubscribe a specific listener from an event.
function Events:Off(event, id)
    if _listeners[event] then
        _listeners[event][id] = nil
    end
end

-- Emit an event, calling every registered subscriber with the data payload.
function Events:Emit(event, data)
    if not _listeners[event] then return end
    for _, fn in pairs(_listeners[event]) do
        fn(data)
    end
end

-- Remove all listeners for an event (use on module teardown).
function Events:Clear(event)
    _listeners[event] = nil
end
