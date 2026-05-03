----------------------------------------------------------------------
-- BRutus Guild Manager - Services/AlertService
-- Central alert queue: priority ordering, deduplication, TTL expiry.
-- Max MAX_ALERTS active at once; HIGH bumps LOW when full.
----------------------------------------------------------------------
local AlertService = {}
BRutus.AlertService = AlertService

-- Numeric priorities — lower number = higher urgency.
local PRIORITY_HIGH   = 1
local PRIORITY_MEDIUM = 2
local PRIORITY_LOW    = 3

local PRIORITY_MAP = {
    HIGH   = PRIORITY_HIGH,
    MEDIUM = PRIORITY_MEDIUM,
    LOW    = PRIORITY_LOW,
}

local MAX_ALERTS  = 3
local DEFAULT_TTL = 30   -- seconds before an alert expires

local _alerts = {}
local _nextId  = 1

----------------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------------

local function expireAlerts()
    local now = GetTime()
    local i   = 1
    while i <= #_alerts do
        if now - _alerts[i].timestamp >= _alerts[i].ttl then
            table.remove(_alerts, i)
        else
            i = i + 1
        end
    end
end

local function isDuplicate(msg)
    for _, a in ipairs(_alerts) do
        if a.message == msg then return true end
    end
    return false
end

-- Sort in-place: HIGH first, then newest-first within same priority.
local function sortAlerts()
    table.sort(_alerts, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.timestamp > b.timestamp
    end)
end

local function emitUpdate()
    if BRutus.Events then
        BRutus.Events:Emit("ALERT_UPDATED", { alerts = AlertService:GetActiveAlerts() })
    end
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

-- Push an alert onto the queue.
-- alert = { message, priority ("HIGH"|"MEDIUM"|"LOW"), source, ttl }
-- Returns true if the alert was added, false if rejected (duplicate or
-- lower/equal priority than all active alerts when queue is full).
function AlertService:Push(alert)
    if not alert or not alert.message or alert.message == "" then return false end

    local numPriority = PRIORITY_MAP[alert.priority] or PRIORITY_MEDIUM

    expireAlerts()

    if isDuplicate(alert.message) then return false end

    local entry = {
        id        = _nextId,
        message   = alert.message,
        priority  = numPriority,
        timestamp = GetTime(),
        ttl       = alert.ttl or DEFAULT_TTL,
        source    = alert.source or "system",
    }
    _nextId = _nextId + 1

    if #_alerts >= MAX_ALERTS then
        sortAlerts()
        local worst = _alerts[#_alerts]
        if entry.priority >= worst.priority then
            -- New alert is not more urgent than the worst active — skip.
            return false
        end
        table.remove(_alerts, #_alerts)
    end

    tinsert(_alerts, entry)
    sortAlerts()
    emitUpdate()
    return true
end

-- Return the current active (non-expired) alerts, up to MAX_ALERTS.
function AlertService:GetActiveAlerts()
    expireAlerts()
    local result = {}
    for i = 1, math.min(#_alerts, MAX_ALERTS) do
        result[i] = _alerts[i]
    end
    return result
end

-- Remove expired alerts and notify listeners.
function AlertService:ClearExpired()
    expireAlerts()
    emitUpdate()
end

-- Remove all alerts immediately.
function AlertService:Clear()
    wipe(_alerts)
    emitUpdate()
end

-- Convenience helpers for common priority levels.
function AlertService:PushHigh(msg, source, ttl)
    return self:Push({ message = msg, priority = "HIGH",   source = source, ttl = ttl })
end

function AlertService:PushMedium(msg, source, ttl)
    return self:Push({ message = msg, priority = "MEDIUM", source = source, ttl = ttl })
end

function AlertService:PushLow(msg, source, ttl)
    return self:Push({ message = msg, priority = "LOW",    source = source, ttl = ttl })
end
