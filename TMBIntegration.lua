----------------------------------------------------------------------
-- BRutus Guild Manager - That's My BiS Integration
-- Imports and displays TMB wishlist, prio, and loot data
----------------------------------------------------------------------
local TMB = {}
BRutus.TMB = TMB

-- Type colors
TMB.TypeColors = {
    prio     = { r = 1.0, g = 0.5, b = 0.0 },  -- orange
    wishlist = { r = 0.3, g = 0.7, b = 1.0 },  -- blue
    received = { r = 0.3, g = 1.0, b = 0.3 },  -- green
}

function TMB:Initialize()
    if not BRutus.db.tmb then
        BRutus.db.tmb = {
            data = {},         -- [lowerName] = { wishlists = {}, prios = {}, received = {} }
            itemNotes = {},    -- [itemId] = { note, prioNote, tierLabel }
            lastImport = 0,
            importedBy = "",
        }
    end
    self:RebuildItemIndex()
    self:HookTooltips()
end

----------------------------------------------------------------------
-- CSV Parsing
----------------------------------------------------------------------
local function ParseCSVLine(line)
    local fields = {}
    local pos = 1
    local len = #line

    while pos <= len do
        if line:sub(pos, pos) == '"' then
            -- Quoted field
            local startPos = pos + 1
            local value = ""
            pos = startPos
            while pos <= len do
                if line:sub(pos, pos) == '"' then
                    if pos + 1 <= len and line:sub(pos + 1, pos + 1) == '"' then
                        value = value .. line:sub(startPos, pos)
                        pos = pos + 2
                        startPos = pos
                    else
                        value = value .. line:sub(startPos, pos - 1)
                        pos = pos + 1
                        break
                    end
                else
                    pos = pos + 1
                end
            end
            -- Skip comma
            if pos <= len and line:sub(pos, pos) == "," then
                pos = pos + 1
            end
            table.insert(fields, value)
        else
            -- Unquoted field
            local nextComma = line:find(",", pos, true)
            if nextComma then
                table.insert(fields, line:sub(pos, nextComma - 1))
                pos = nextComma + 1
            else
                table.insert(fields, line:sub(pos))
                pos = len + 1
            end
        end
    end

    return fields
end

----------------------------------------------------------------------
-- Import TMB CSV data
----------------------------------------------------------------------
function TMB:ImportCSV(csvText)
    if not csvText or csvText == "" then
        return false, "No data to import."
    end

    local lines = {}
    for line in csvText:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    if #lines < 2 then
        return false, "CSV must have a header and at least one data row."
    end

    -- Verify header and build column map
    local header = ParseCSVLine(lines[1])
    if not header[1] or strlower(strtrim(header[1])) ~= "type" then
        return false, "Invalid TMB export format. Expected 'type' as first column."
    end

    -- Map column names to indices dynamically
    local colMap = {}
    for idx, colName in ipairs(header) do
        colMap[strlower(strtrim(colName))] = idx
    end

    -- Required columns
    local cType           = colMap["type"]
    local cCharName       = colMap["character_name"]
    local cCharClass      = colMap["character_class"]
    local cCharIsAlt      = colMap["character_is_alt"]
    local cCharNote       = colMap["character_note"]
    local cSortOrder      = colMap["sort_order"]
    local cItemId         = colMap["item_id"]
    local cIsOffspec      = colMap["is_offspec"]
    local cReceivedAt     = colMap["received_at"]
    local cItemPrioNote   = colMap["item_prio_note"]
    local cItemTierLabel  = colMap["item_tier_label"]

    if not cType or not cCharName or not cItemId then
        return false, "CSV missing required columns: type, character_name, item_id."
    end

    -- Parse data
    local characters = {}  -- [lowerName] = { wishlists, prios, received }
    local itemNotes = {}
    local rowCount = 0

    for i = 2, #lines do
        local fields = ParseCSVLine(lines[i])
        if #fields >= cItemId then
            local rowType = strlower(strtrim(fields[cType] or ""))
            local charName = strtrim(fields[cCharName] or "")
            local itemId = tonumber(strtrim(fields[cItemId] or ""))
            local sortOrder = cSortOrder and tonumber(strtrim(fields[cSortOrder] or "")) or 999
            local isOffspec = (cIsOffspec and strtrim(fields[cIsOffspec] or "") == "1") or false
            local receivedAt = cReceivedAt and strtrim(fields[cReceivedAt] or "") or ""
            local prioNote = cItemPrioNote and strtrim(fields[cItemPrioNote] or "") or ""
            local tierLabel = cItemTierLabel and strtrim(fields[cItemTierLabel] or "") or ""

            if rowType == "item_note" then
                -- Item-level notes (no character)
                if itemId then
                    itemNotes[itemId] = {
                        prioNote = prioNote,
                        tierLabel = tierLabel,
                    }
                end
            elseif itemId and charName ~= "" then
                local key = strlower(charName)
                if not characters[key] then
                    characters[key] = {
                        name = charName,
                        class = cCharClass and strtrim(fields[cCharClass] or "") or "",
                        isAlt = (cCharIsAlt and strtrim(fields[cCharIsAlt] or "") == "1") or false,
                        note = cCharNote and strtrim(fields[cCharNote] or "") or "",
                        wishlists = {},
                        prios = {},
                        received = {},
                    }
                end

                local entry = {
                    itemId = itemId,
                    order = sortOrder,
                    isOffspec = isOffspec,
                    prioNote = prioNote,
                    tierLabel = tierLabel,
                }

                if rowType == "prio" then
                    table.insert(characters[key].prios, entry)
                elseif rowType == "wishlist" then
                    table.insert(characters[key].wishlists, entry)
                elseif rowType == "received" then
                    entry.receivedAt = receivedAt
                    table.insert(characters[key].received, entry)
                end

                rowCount = rowCount + 1
            end
        end
    end

    -- Sort by order
    for _, charData in pairs(characters) do
        table.sort(charData.prios, function(a, b) return a.order < b.order end)
        table.sort(charData.wishlists, function(a, b) return a.order < b.order end)
    end

    -- Store
    BRutus.db.tmb.data = characters
    BRutus.db.tmb.itemNotes = itemNotes
    BRutus.db.tmb.lastImport = time()
    BRutus.db.tmb.importedBy = UnitName("player")

    -- Build reverse item index
    self:RebuildItemIndex()

    -- Broadcast to guild
    self:BroadcastTMBData()

    local charCount = 0
    for _ in pairs(characters) do charCount = charCount + 1 end

    return true, string.format("Imported %d entries for %d characters.", rowCount, charCount)
end

----------------------------------------------------------------------
-- Get TMB data for a character (by display name)
----------------------------------------------------------------------
function TMB:GetCharacterData(name)
    if not BRutus.db.tmb or not BRutus.db.tmb.data then return nil end
    local key = strlower(name)
    return BRutus.db.tmb.data[key]
end

----------------------------------------------------------------------
-- Get item note
----------------------------------------------------------------------
function TMB:GetItemNote(itemId)
    if not BRutus.db.tmb or not BRutus.db.tmb.itemNotes then return nil end
    return BRutus.db.tmb.itemNotes[itemId]
end

----------------------------------------------------------------------
-- Get a summary string for a character (for roster display)
----------------------------------------------------------------------
function TMB:GetCharacterSummary(name)
    local data = self:GetCharacterData(name)
    if not data then return nil end

    local parts = {}
    if #data.prios > 0 then
        table.insert(parts, "|cffFF8000" .. #data.prios .. " prio|r")
    end
    if #data.wishlists > 0 then
        table.insert(parts, "|cff4CB5FF" .. #data.wishlists .. " wish|r")
    end
    if #data.received > 0 then
        table.insert(parts, "|cff4CFF4C" .. #data.received .. " recv|r")
    end

    if #parts == 0 then return nil end
    return table.concat(parts, " ")
end

----------------------------------------------------------------------
-- Resolve item name from cache or GetItemInfo
----------------------------------------------------------------------
function TMB:GetItemName(itemId)
    local name = GetItemInfo(itemId)
    return name or ("Item #" .. itemId)
end

function TMB:GetItemQuality(itemId)
    local _, _, quality = GetItemInfo(itemId)
    return quality or 1
end

----------------------------------------------------------------------
-- Broadcast TMB data to guild via CommSystem
----------------------------------------------------------------------
function TMB:BroadcastTMBData()
    if not BRutus.CommSystem then return end
    if not BRutus.db.tmb or not BRutus.db.tmb.data then return end

    local payload = {
        data = BRutus.db.tmb.data,
        itemNotes = BRutus.db.tmb.itemNotes,
        lastImport = BRutus.db.tmb.lastImport,
        importedBy = BRutus.db.tmb.importedBy,
    }

    local LibSerialize = LibStub("LibSerialize")
    local serialized = LibSerialize:Serialize(payload)
    BRutus.CommSystem:SendMessage("TM", serialized)
end

----------------------------------------------------------------------
-- Handle incoming TMB data from guild
----------------------------------------------------------------------
function TMB:HandleTMBData(data)
    local LibSerialize = LibStub("LibSerialize")
    local ok, payload = LibSerialize:Deserialize(data)
    if not ok or type(payload) ~= "table" then return end

    -- Only accept if newer than what we have
    local incomingTime = payload.lastImport or 0
    local ourTime = BRutus.db.tmb and BRutus.db.tmb.lastImport or 0

    if incomingTime > ourTime then
        BRutus.db.tmb.data = payload.data or {}
        BRutus.db.tmb.itemNotes = payload.itemNotes or {}
        BRutus.db.tmb.lastImport = payload.lastImport
        BRutus.db.tmb.importedBy = payload.importedBy or ""
        TMB:RebuildItemIndex()
        BRutus:Print("TMB data synced from " .. (payload.importedBy or "guild") .. ".")
    end
end

----------------------------------------------------------------------
-- Reverse index: itemId -> list of { name, class, type, order, isOffspec }
----------------------------------------------------------------------
function TMB:RebuildItemIndex()
    local index = {}
    local tmb = BRutus.db.tmb
    if not tmb or not tmb.data then
        self.itemIndex = index
        return
    end

    for _, charData in pairs(tmb.data) do
        local cc = charData.class or ""
        local name = charData.name or ""

        for _, item in ipairs(charData.prios) do
            if not index[item.itemId] then index[item.itemId] = {} end
            table.insert(index[item.itemId], {
                name = name, class = cc, type = "prio",
                order = item.order, isOffspec = item.isOffspec,
            })
        end
        for _, item in ipairs(charData.wishlists) do
            if not index[item.itemId] then index[item.itemId] = {} end
            table.insert(index[item.itemId], {
                name = name, class = cc, type = "wishlist",
                order = item.order, isOffspec = item.isOffspec,
            })
        end
        for _, item in ipairs(charData.received) do
            if not index[item.itemId] then index[item.itemId] = {} end
            table.insert(index[item.itemId], {
                name = name, class = cc, type = "received",
                order = item.order, receivedAt = item.receivedAt,
            })
        end
    end

    -- Sort each item's entries: prio first, then wishlist, then received; within same type by order
    local typePriority = { prio = 1, wishlist = 2, received = 3 }
    for _, entries in pairs(index) do
        table.sort(entries, function(a, b)
            local pa = typePriority[a.type] or 9
            local pb = typePriority[b.type] or 9
            if pa ~= pb then return pa < pb end
            return (a.order or 999) < (b.order or 999)
        end)
    end

    self.itemIndex = index
end

----------------------------------------------------------------------
-- Get who wants/has a specific item
----------------------------------------------------------------------
function TMB:GetItemInterest(itemId)
    if not self.itemIndex then return nil end
    return self.itemIndex[itemId]
end

----------------------------------------------------------------------
-- Record a loot award as "received" in local TMB data
----------------------------------------------------------------------
function TMB:RecordReceived(charName, itemId, itemLink)
    if not BRutus.db.tmb or not BRutus.db.tmb.data then return end
    local key = strlower(charName)

    if not BRutus.db.tmb.data[key] then
        BRutus.db.tmb.data[key] = {
            name = charName, class = "", isAlt = false, note = "",
            wishlists = {}, prios = {}, received = {},
        }
    end

    local charData = BRutus.db.tmb.data[key]
    if not charData.received then charData.received = {} end

    -- Avoid recording the same item twice in the same session
    for _, r in ipairs(charData.received) do
        if r.itemId == itemId and r.sessionAward then
            return  -- already recorded this session
        end
    end

    local receivedAt = date("%Y-%m-%d %H:%M:%S")
    table.insert(charData.received, {
        itemId     = itemId,
        itemLink   = itemLink or "",
        order      = 999,
        receivedAt = receivedAt,
        sessionAward = true,   -- flag: recorded by BRutus this session
    })

    -- Remove from prio/wishlist (item has been received)
    for _, list in ipairs({ charData.prios, charData.wishlists }) do
        for i = #list, 1, -1 do
            if list[i].itemId == itemId then
                table.remove(list, i)
            end
        end
    end

    self:RebuildItemIndex()
    BRutus:Print(format("|cff4CFF4C[TMB]|r Recorded %s → %s",
        itemLink or ("Item #" .. itemId), charName))
end

----------------------------------------------------------------------
-- Remove a received entry (undo)
----------------------------------------------------------------------
function TMB:RemoveReceived(charName, itemId)
    if not BRutus.db.tmb or not BRutus.db.tmb.data then return end
    local key = strlower(charName)
    local charData = BRutus.db.tmb.data[key]
    if not charData or not charData.received then return end

    for i = #charData.received, 1, -1 do
        if charData.received[i].itemId == itemId then
            table.remove(charData.received, i)
            break
        end
    end
    self:RebuildItemIndex()
end

----------------------------------------------------------------------
-- Export received loot as TMB-compatible CSV for import
-- Format matches the TMB export CSV so it can be re-imported
----------------------------------------------------------------------
function TMB:ExportReceivedCSV()
    local tmb = BRutus.db.tmb
    if not tmb or not tmb.data then
        return nil, "No TMB data imported."
    end

    local lines = {}
    table.insert(lines, "type,character_name,character_class,item_id,sort_order,is_offspec,received_at")

    local entries = {}
    for _, charData in pairs(tmb.data) do
        if charData.received then
            for _, r in ipairs(charData.received) do
                if r.sessionAward then   -- only export items recorded by BRutus
                    table.insert(entries, {
                        name      = charData.name or "",
                        class     = charData.class or "",
                        itemId    = r.itemId,
                        order     = r.order or 999,
                        isOffspec = r.isOffspec and "1" or "0",
                        receivedAt = r.receivedAt or "",
                    })
                end
            end
        end
    end

    if #entries == 0 then
        return nil, "No loot recorded this session. Award items first."
    end

    table.sort(entries, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.itemId < b.itemId
    end)

    for _, e in ipairs(entries) do
        table.insert(lines, format('received,"%s","%s",%d,%d,%s,"%s"',
            e.name, e.class, e.itemId, e.order, e.isOffspec, e.receivedAt))
    end

    return table.concat(lines, "\n"), nil
end

----------------------------------------------------------------------
-- Hook GameTooltip to show TMB reservations
----------------------------------------------------------------------
function TMB:HookTooltips()
    local function OnTooltipSetItem(tooltip)
        if not BRutus.db.tmb or not self.itemIndex then return end

        local _, link = tooltip:GetItem()
        if not link then return end

        local itemId = tonumber(link:match("item:(%d+)"))
        if not itemId then return end

        local entries = self.itemIndex[itemId]
        if not entries or #entries == 0 then return end

        -- Group entries by type
        local prios, wishlists, received = {}, {}, {}
        for _, e in ipairs(entries) do
            if e.type == "prio" then table.insert(prios, e)
            elseif e.type == "wishlist" then table.insert(wishlists, e)
            else table.insert(received, e) end
        end

        if #prios > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("Na prio de:", self.TypeColors.prio.r, self.TypeColors.prio.g, self.TypeColors.prio.b)
            for _, e in ipairs(prios) do
                local cc = BRutus.ClassColors[e.class:upper()] or BRutus.Colors.white
                local label = "#" .. e.order .. (e.isOffspec and " (OS)" or "")
                tooltip:AddDoubleLine("  " .. e.name, label, cc.r, cc.g, cc.b, 0.7, 0.7, 0.7)
            end
        end

        if #wishlists > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("Na wishlist de:", self.TypeColors.wishlist.r, self.TypeColors.wishlist.g, self.TypeColors.wishlist.b)
            for _, e in ipairs(wishlists) do
                local cc = BRutus.ClassColors[e.class:upper()] or BRutus.Colors.white
                local label = "#" .. e.order .. (e.isOffspec and " (OS)" or "")
                tooltip:AddDoubleLine("  " .. e.name, label, cc.r, cc.g, cc.b, 0.7, 0.7, 0.7)
            end
        end

        if #received > 0 then
            tooltip:AddLine(" ")
            tooltip:AddLine("Recebido por:", self.TypeColors.received.r, self.TypeColors.received.g, self.TypeColors.received.b)
            for _, e in ipairs(received) do
                local cc = BRutus.ClassColors[e.class:upper()] or BRutus.Colors.white
                local label = e.receivedAt or ""
                tooltip:AddDoubleLine("  " .. e.name, label, cc.r, cc.g, cc.b, 0.5, 0.5, 0.5)
            end
        end

        tooltip:Show()
    end

    GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)

    -- Also hook ItemRefTooltip (shift-click links in chat)
    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end

    -- Also hook ShoppingTooltip (comparison tooltips)
    if ShoppingTooltip1 then
        ShoppingTooltip1:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end
    if ShoppingTooltip2 then
        ShoppingTooltip2:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end
end
