----------------------------------------------------------------------
-- BRutus Guild Manager - Services/AssignmentService
-- Manages per-encounter role and action assignments for the Raid Leader.
-- Data is local-only for now; prepared for future Sync integration.
----------------------------------------------------------------------
local AssignmentService = {}
BRutus.AssignmentService = AssignmentService

-- _assignments[encounterId] = {
--   roles   = { tank_main = "PlayerA", healer_group1 = { "B", "C" }, ... },
--   actions = { phase1 = { "Action text", ... }, phase2 = { ... }, ... }
-- }
local _assignments = {}

-- Store or replace the full assignment record for an encounter.
-- Emits ASSIGNMENT_UPDATED via EventBus.
function AssignmentService:SetAssignment(encounterId, data)
    if not encounterId or not data then return end
    _assignments[encounterId] = data
    if BRutus.Events then
        BRutus.Events:Emit("ASSIGNMENT_UPDATED", { encounterId = encounterId })
    end
end

-- Return the assignment record for an encounter, or nil if none set.
function AssignmentService:GetAssignment(encounterId)
    return _assignments[encounterId]
end

-- Return the action list for a given phase of an encounter.
-- If phase is nil, returns the first phase found.
-- Returns an empty table if no actions are available.
function AssignmentService:GetCurrentActions(encounterId, phase)
    local rec = _assignments[encounterId]
    if not rec or not rec.actions then return {} end
    if phase then
        return rec.actions[phase] or {}
    end
    -- Default: return the first phase defined.
    local _, firstPhase = next(rec.actions)
    return firstPhase or {}
end

-- Return the role map for an encounter, or {} if none set.
function AssignmentService:GetRoles(encounterId)
    local rec = _assignments[encounterId]
    if not rec then return {} end
    return rec.roles or {}
end
