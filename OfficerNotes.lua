----------------------------------------------------------------------
-- BRutus Guild Manager - Officer Notes
-- Private notes per member, synced between officers via comm system
----------------------------------------------------------------------
local OfficerNotes = {}
BRutus.OfficerNotes = OfficerNotes

local LibSerialize = LibStub("LibSerialize")

function OfficerNotes:Initialize()
    if not BRutus.db.officerNotes then
        BRutus.db.officerNotes = {}  -- [playerKey] = { notes = { {text, author, timestamp} }, tags = {} }
    end
end

function OfficerNotes:AddNote(playerKey, text)
    if not BRutus:IsOfficer() then return false end
    if not text or text == "" then return false end

    if not BRutus.db.officerNotes[playerKey] then
        BRutus.db.officerNotes[playerKey] = { notes = {}, tags = {} }
    end

    local entry = {
        text = text,
        author = UnitName("player"),
        timestamp = GetServerTime(),
    }
    table.insert(BRutus.db.officerNotes[playerKey].notes, 1, entry)

    -- Cap at 50 notes per player
    while #BRutus.db.officerNotes[playerKey].notes > 50 do
        table.remove(BRutus.db.officerNotes[playerKey].notes)
    end

    -- Broadcast to other officers
    self:BroadcastNote(playerKey, entry)
    return true
end

function OfficerNotes:DeleteNote(playerKey, index)
    if not BRutus:IsOfficer() then return end
    local data = BRutus.db.officerNotes[playerKey]
    if data and data.notes[index] then
        table.remove(data.notes, index)
    end
end

function OfficerNotes:GetNotes(playerKey)
    local data = BRutus.db.officerNotes[playerKey]
    if data then
        return data.notes or {}
    end
    return {}
end

function OfficerNotes:SetTag(playerKey, tag, value)
    if not BRutus:IsOfficer() then return end
    if not BRutus.db.officerNotes[playerKey] then
        BRutus.db.officerNotes[playerKey] = { notes = {}, tags = {} }
    end
    BRutus.db.officerNotes[playerKey].tags[tag] = value
end

function OfficerNotes:GetTag(playerKey, tag)
    local data = BRutus.db.officerNotes[playerKey]
    if data and data.tags then
        return data.tags[tag]
    end
    return nil
end

function OfficerNotes:GetAllTags(playerKey)
    local data = BRutus.db.officerNotes[playerKey]
    if data and data.tags then
        return data.tags
    end
    return {}
end

-- Predefined tags for quick marking
OfficerNotes.QUICK_TAGS = {
    { key = "role",     label = "Role",       options = { "Tank", "Healer", "DPS", "Flex" } },
    { key = "priority", label = "Prioridade", options = { "Alta", "Media", "Baixa" } },
    { key = "status",   label = "Status",     options = { "Core", "Reserva", "Trial", "Social" } },
}

----------------------------------------------------------------------
-- Comm sync (officer-only broadcast)
----------------------------------------------------------------------
function OfficerNotes:BroadcastNote(playerKey, noteEntry)
    if not BRutus.CommSystem then return end
    local data = {
        target = playerKey,
        note = noteEntry,
    }
    local serialized = LibSerialize:Serialize(data)
    BRutus.CommSystem:SendMessage("ON", serialized)
end

function OfficerNotes:HandleIncoming(data)
    if not BRutus:IsOfficer() then return end

    local ok, payload = LibSerialize:Deserialize(data)
    if not ok or type(payload) ~= "table" then return end

    local playerKey = payload.target
    local note = payload.note
    if not playerKey or not note then return end

    if not BRutus.db.officerNotes[playerKey] then
        BRutus.db.officerNotes[playerKey] = { notes = {}, tags = {} }
    end

    -- Avoid duplicates (same author + timestamp)
    for _, existing in ipairs(BRutus.db.officerNotes[playerKey].notes) do
        if existing.author == note.author and existing.timestamp == note.timestamp then
            return
        end
    end

    table.insert(BRutus.db.officerNotes[playerKey].notes, 1, note)
end
