----------------------------------------------------------------------
-- BRutus Guild Manager - Loot Tracker
-- Records items awarded by the Master Looter (officer-only).
-- History is populated exclusively via RecordMLAward;
-- generic CHAT_MSG_LOOT is NOT tracked.
----------------------------------------------------------------------
local LootTracker = {}
BRutus.LootTracker = LootTracker

function LootTracker:Initialize()
    if not BRutus.db.lootHistory then
        BRutus.db.lootHistory = {}
    end
end

-- Record a master-loot award to the persistent history.
-- Called by LootMaster:AwardLoot (locally) and by the AWARD
-- addon message handler (peers, officer-verified).
function LootTracker:RecordMLAward(entry)
    if not BRutus.db.lootHistory then
        BRutus.db.lootHistory = {}
    end
    table.insert(BRutus.db.lootHistory, 1, entry)
    while #BRutus.db.lootHistory > 500 do
        table.remove(BRutus.db.lootHistory)
    end
end

function LootTracker:GetHistory(limit)
    limit = limit or 50
    local result = {}
    for i = 1, math.min(limit, #BRutus.db.lootHistory) do
        result[i] = BRutus.db.lootHistory[i]
    end
    return result
end

function LootTracker:GetPlayerLoot(playerKey, limit)
    limit = limit or 20
    local result = {}
    for _, entry in ipairs(BRutus.db.lootHistory) do
        if entry.playerKey == playerKey then
            table.insert(result, entry)
            if #result >= limit then break end
        end
    end
    return result
end

function LootTracker:GetLootCount(playerKey)
    local count = 0
    for _, entry in ipairs(BRutus.db.lootHistory) do
        if entry.playerKey == playerKey then
            count = count + 1
        end
    end
    return count
end

function LootTracker:GetRaidLoot(raidName, limit)
    limit = limit or 50
    local result = {}
    for _, entry in ipairs(BRutus.db.lootHistory) do
        if entry.raid == raidName then
            table.insert(result, entry)
            if #result >= limit then break end
        end
    end
    return result
end

function LootTracker:DeleteEntry(index)
    if BRutus.db.lootHistory[index] then
        table.remove(BRutus.db.lootHistory, index)
    end
end

function LootTracker:ClearHistory()
    wipe(BRutus.db.lootHistory)
end
