----------------------------------------------------------------------
-- BRutus Guild Manager - Data Collector
-- Collects gear, professions, and stats from the local player
-- and stores data received from other guild members
----------------------------------------------------------------------
local DataCollector = {}
BRutus.DataCollector = DataCollector

function DataCollector:Initialize()
    -- Register inventory change events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    frame:RegisterEvent("SKILL_LINES_CHANGED")
    frame:RegisterEvent("CHAT_MSG_SKILL")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            C_Timer.After(0.5, function() DataCollector:CollectMyData() end)
        elseif event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" then
            C_Timer.After(1, function() DataCollector:CollectProfessions() end)
        end
    end)
end

----------------------------------------------------------------------
-- Collect all local player data
----------------------------------------------------------------------
function DataCollector:CollectMyData()
    local name = UnitName("player")
    local realm = GetRealmName()
    local key = BRutus:GetPlayerKey(name, realm)

    local _, class = UnitClass("player")
    local level = UnitLevel("player")
    local race = UnitRace("player") or ""

    local data = BRutus.db.members[key] or {}
    data.name = name
    data.realm = realm
    data.class = class
    data.level = level
    data.race = race
    data.lastUpdate = time()

    -- Collect gear
    data.gear = self:CollectGear()
    data.avgIlvl = self:CalculateAvgIlvl(data.gear)

    -- Collect professions
    data.professions = self:CollectProfessions()

    -- Collect basic stats
    data.stats = self:CollectStats()

    BRutus.db.members[key] = data
    BRutus.db.myData = data

    return data
end

----------------------------------------------------------------------
-- Collect equipped gear
----------------------------------------------------------------------
function DataCollector:CollectGear()
    local gear = {}

    for _, slotInfo in ipairs(BRutus.SlotIDs) do
        local slotId = slotInfo.id
        local itemLink = GetInventoryItemLink("player", slotId)
        local itemTexture = GetInventoryItemTexture("player", slotId)

        if itemLink then
            local itemName, _, itemQuality, itemLevel, _, _, _, _, _, itemIcon = GetItemInfo(itemLink)
            local itemId = tonumber(itemLink:match("item:(%d+)"))

            gear[slotId] = {
                link = itemLink,
                id = itemId,
                name = itemName or "",
                quality = itemQuality or 0,
                ilvl = itemLevel or 0,
                icon = itemTexture or itemIcon or "",
            }
        else
            gear[slotId] = nil
        end
    end

    return gear
end

----------------------------------------------------------------------
-- Calculate average item level
----------------------------------------------------------------------
function DataCollector:CalculateAvgIlvl(gear)
    if not gear then return 0 end

    local total = 0
    local count = 0

    for _, slotInfo in ipairs(BRutus.SlotIDs) do
        local item = gear[slotInfo.id]
        if item and item.ilvl and item.ilvl > 0 then
            total = total + item.ilvl
            count = count + 1
        end
    end

    if count == 0 then return 0 end
    return math.floor(total / count + 0.5)
end

----------------------------------------------------------------------
-- Collect professions
----------------------------------------------------------------------
function DataCollector:CollectProfessions()
    local profs = {}

    -- Get primary professions
    local numSkills = GetNumSkillLines()

    for i = 1, numSkills do
        local skillName, isHeader_, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(i)

        -- Check if it's a profession
        if not isHeader_ and self:IsProfession(skillName) then
            table.insert(profs, {
                name = skillName,
                rank = skillRank,
                maxRank = skillMaxRank,
                isPrimary = self:IsPrimaryProfession(skillName),
            })
        end
    end

    return profs
end

----------------------------------------------------------------------
-- Profession helpers
----------------------------------------------------------------------
local PRIMARY_PROFESSIONS = {
    ["Alchemy"] = true, ["Blacksmithing"] = true, ["Enchanting"] = true,
    ["Engineering"] = true, ["Herbalism"] = true, ["Jewelcrafting"] = true,
    ["Leatherworking"] = true, ["Mining"] = true, ["Skinning"] = true,
    ["Tailoring"] = true,
}

local SECONDARY_PROFESSIONS = {
    ["Cooking"] = true, ["First Aid"] = true, ["Fishing"] = true,
}

function DataCollector:IsProfession(name)
    return PRIMARY_PROFESSIONS[name] or SECONDARY_PROFESSIONS[name] or false
end

function DataCollector:IsPrimaryProfession(name)
    return PRIMARY_PROFESSIONS[name] or false
end

----------------------------------------------------------------------
-- Collect basic stats
----------------------------------------------------------------------
function DataCollector:CollectStats()
    local stats = {}
    stats.health = UnitHealthMax("player")
    stats.mana = UnitPowerMax("player", 0) -- Mana

    -- Base stats
    stats.strength  = UnitStat("player", 1) or 0
    stats.agility   = UnitStat("player", 2) or 0
    stats.stamina   = UnitStat("player", 3) or 0
    stats.intellect = UnitStat("player", 4) or 0
    stats.spirit    = UnitStat("player", 5) or 0

    return stats
end

----------------------------------------------------------------------
-- Store data received from another player
----------------------------------------------------------------------
function DataCollector:StoreReceivedData(playerKey, data)
    if not data or type(data) ~= "table" then return end
    if not data.name or not data.class then return end

    -- Merge with existing data
    local existing = BRutus.db.members[playerKey] or {}
    for k, v in pairs(data) do
        existing[k] = v
    end
    existing.lastSync = time()

    BRutus.db.members[playerKey] = existing

    -- Refresh UI if open
    if BRutus.RosterFrame and BRutus.RosterFrame:IsShown() then
        BRutus.RosterFrame:RefreshRoster()
    end
end

----------------------------------------------------------------------
-- Get serializable data for broadcasting
----------------------------------------------------------------------
function DataCollector:GetBroadcastData()
    local myData = BRutus.db.myData
    if not myData then
        myData = self:CollectMyData()
    end

    -- Create a clean copy without item links (too long for comms)
    local clean = {
        name = myData.name,
        realm = myData.realm,
        class = myData.class,
        level = myData.level,
        race = myData.race,
        avgIlvl = myData.avgIlvl,
        lastUpdate = myData.lastUpdate,
        professions = myData.professions,
        stats = myData.stats,
    }

    -- Serialize gear with just essential info
    if myData.gear then
        clean.gear = {}
        for slotId, item in pairs(myData.gear) do
            clean.gear[slotId] = {
                id = item.id,
                name = item.name,
                quality = item.quality,
                ilvl = item.ilvl,
                icon = item.icon,
            }
        end
    end

    -- Include attunements
    if myData.attunements then
        clean.attunements = myData.attunements
    end

    return clean
end
