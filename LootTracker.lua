----------------------------------------------------------------------
-- BRutus Guild Manager - Loot Tracker
-- Hooks loot distribution events, logs item/recipient/date
----------------------------------------------------------------------
local LootTracker = {}
BRutus.LootTracker = LootTracker

function LootTracker:Initialize()
    if not BRutus.db.lootHistory then
        BRutus.db.lootHistory = {}
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_LOOT")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_LOOT" then
            LootTracker:OnLootMessage(...)
        end
    end)
end

-- Parse loot messages
-- Format: "PlayerName receives loot: [Item Link]xCount."
-- Format: "You receive loot: [Item Link]."
function LootTracker:OnLootMessage(msg)
    if not msg then return end

    -- Only track while in a raid/dungeon
    local _, instanceType = GetInstanceInfo()
    if instanceType ~= "raid" and instanceType ~= "party" then return end

    local player, itemLink, count

    -- "PlayerName receives loot: [Item Link]xCount."
    player, itemLink, count = msg:match("(.+) receives loot: (|.+|r)x?(%d*)")
    if not player then
        -- "You receive loot: [Item Link]."
        itemLink, count = msg:match("You receive loot: (|.+|r)x?(%d*)")
        if itemLink then
            player = UnitName("player")
        end
    end

    if not itemLink then return end
    count = tonumber(count) or 1

    -- Extract item info
    local itemName, _, itemQuality = GetItemInfo(itemLink)
    if not itemName then return end

    -- Only track Rare (3) and above
    if itemQuality < 3 then return end

    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    local raidName = ""
    if BRutus.RaidTracker and BRutus.RaidTracker.RAID_INSTANCES then
        raidName = BRutus.RaidTracker.RAID_INSTANCES[instanceID] or "Unknown"
    end

    local realm = GetRealmName()
    local playerKey = player .. "-" .. realm

    local entry = {
        itemLink = itemLink,
        itemName = itemName,
        quality = itemQuality,
        player = player,
        playerKey = playerKey,
        count = count,
        timestamp = GetServerTime(),
        raid = raidName,
        instanceID = instanceID,
    }

    table.insert(BRutus.db.lootHistory, 1, entry)

    -- Cap history at 500 entries
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
