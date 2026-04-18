----------------------------------------------------------------------
-- BRutus Guild Manager - Member Detail Panel
-- Shows full gear inspection, professions, and attunement details
----------------------------------------------------------------------
local UI = BRutus.UI
local C = BRutus.Colors

local DETAIL_WIDTH = 420
local DETAIL_HEIGHT = 620

----------------------------------------------------------------------
-- Show member detail panel
----------------------------------------------------------------------
function BRutus:ShowMemberDetail(memberData)
    if not memberData then return end

    local frame = self.DetailFrame
    if not frame then
        frame = CreateDetailFrame()
        self.DetailFrame = frame
    end

    PopulateDetail(frame, memberData)
    frame:Show()
end

----------------------------------------------------------------------
-- Create the detail frame
----------------------------------------------------------------------
function CreateDetailFrame()
    local frame = UI:CreatePanel(UIParent, "BRutusDetailFrame")
    frame:SetSize(DETAIL_WIDTH, DETAIL_HEIGHT)
    frame:SetPoint("CENTER", 250, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(20)
    frame:Hide()

    -- Outer glow border
    local outerBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    outerBorder:SetPoint("TOPLEFT", -2, 2)
    outerBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    outerBorder:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    outerBorder:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.3)
    outerBorder:SetFrameLevel(19)

    -- Top glow
    local topGlow = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    topGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    topGlow:SetPoint("TOPLEFT", 1, -1)
    topGlow:SetPoint("TOPRIGHT", -1, -1)
    topGlow:SetHeight(80)
    topGlow:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(C.accent.r, C.accent.g, C.accent.b, 0.06))

    ----------------------------------------------------------------
    -- Title Bar
    ----------------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(50)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local titleBg = titleBar:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    titleBg:SetAllPoints()
    titleBg:SetVertexColor(C.headerBg.r, C.headerBg.g, C.headerBg.b, C.headerBg.a)

    -- Class icon (big)
    local classIconFrame = CreateFrame("Frame", nil, titleBar, "BackdropTemplate")
    classIconFrame:SetSize(38, 38)
    classIconFrame:SetPoint("LEFT", 10, 0)
    classIconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    classIconFrame:SetBackdropColor(0, 0, 0, 0.8)
    classIconFrame:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.8)

    local classIcon = classIconFrame:CreateTexture(nil, "ARTWORK")
    classIcon:SetPoint("TOPLEFT", 2, -2)
    classIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.classIcon = classIcon
    frame.classIconFrame = classIconFrame

    -- Name
    local nameText = UI:CreateTitle(titleBar, "", 18)
    nameText:SetPoint("LEFT", classIconFrame, "RIGHT", 10, 6)
    frame.nameText = nameText

    -- Subtitle (level, race, class)
    local infoText = UI:CreateText(titleBar, "", 11, C.silver.r, C.silver.g, C.silver.b)
    infoText:SetPoint("LEFT", classIconFrame, "RIGHT", 10, -10)
    frame.infoText = infoText

    -- Close button
    local closeBtn = UI:CreateCloseButton(titleBar)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -12)
    closeBtn:SetFrameLevel(titleBar:GetFrameLevel() + 5)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Title line
    local titleLine = UI:CreateAccentLine(frame, 2)
    titleLine:SetPoint("TOPLEFT", 0, -50)
    titleLine:SetPoint("TOPRIGHT", 0, -50)

    ----------------------------------------------------------------
    -- Content scroll
    ----------------------------------------------------------------
    local content = CreateFrame("ScrollFrame", "BRutusDetailScroll", frame, "UIPanelScrollFrameTemplate")
    content:SetPoint("TOPLEFT", 5, -55)
    content:SetPoint("BOTTOMRIGHT", -25, 5)

    local child = CreateFrame("Frame", "BRutusDetailScrollChild", content)
    child:SetWidth(DETAIL_WIDTH - 35)
    child:SetHeight(1) -- will grow
    content:SetScrollChild(child)
    frame.content = child

    table.insert(UISpecialFrames, "BRutusDetailFrame")

    return frame
end

----------------------------------------------------------------------
-- Populate detail with member data
----------------------------------------------------------------------
function PopulateDetail(frame, data)
    -- Clear previous content
    local child = frame.content
    local children = { child:GetChildren() }
    for _, c in ipairs(children) do c:Hide() end
    local regions = { child:GetRegions() }
    for _, r in ipairs(regions) do r:Hide() end

    -- Class icon
    local classCoords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[data.class]
    if classCoords then
        frame.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CharacterCreate-Classes")
        frame.classIcon:SetTexCoord(unpack(classCoords))
    end

    -- Class color for border
    local cr, cg, cb = BRutus:GetClassColor(data.class)
    frame.classIconFrame:SetBackdropBorderColor(cr, cg, cb, 0.9)

    -- Name
    frame.nameText:SetText(data.name)
    frame.nameText:SetTextColor(cr, cg, cb)

    -- Info line
    local raceStr = data.race ~= "" and data.race or "Unknown"
    frame.infoText:SetText(string.format("Level %d %s %s  |  %s", data.level, raceStr, data.classDisplay, data.rank))

    local yOff = -5
    local contentWidth = DETAIL_WIDTH - 35

    ----------------------------------------------------------------
    -- Section: Stats
    ----------------------------------------------------------------
    if data.stats then
        yOff = CreateSectionHeader(child, "CHARACTER STATS", yOff, contentWidth)
        yOff = yOff - 5

        local statsGrid = CreateFrame("Frame", nil, child)
        statsGrid:SetPoint("TOPLEFT", 10, yOff)
        statsGrid:SetSize(contentWidth - 20, 40)
        statsGrid:Show()

        local statsList = {
            { label = "HP",  value = data.stats.health or 0, color = C.green },
            { label = "MP",  value = data.stats.mana or 0,   color = C.blue },
            { label = "STR", value = data.stats.strength or 0 },
            { label = "AGI", value = data.stats.agility or 0 },
            { label = "STA", value = data.stats.stamina or 0 },
            { label = "INT", value = data.stats.intellect or 0 },
            { label = "SPI", value = data.stats.spirit or 0 },
        }

        local colWidth = (contentWidth - 20) / 4
        for i, stat in ipairs(statsList) do
            local col = ((i - 1) % 4)
            local row = math.floor((i - 1) / 4)

            local label = child:CreateFontString(nil, "OVERLAY")
            label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            label:SetPoint("TOPLEFT", statsGrid, "TOPLEFT", col * colWidth, -(row * 20))
            label:SetTextColor(C.silver.r, C.silver.g, C.silver.b, 0.7)
            label:SetText(stat.label)
            label:Show()

            local value = child:CreateFontString(nil, "OVERLAY")
            value:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            value:SetPoint("LEFT", label, "RIGHT", 4, 0)
            local sc = stat.color or C.white
            value:SetTextColor(sc.r, sc.g, sc.b)
            value:SetText(tostring(stat.value))
            value:Show()
        end

        yOff = yOff - 50
    end

    ----------------------------------------------------------------
    -- Section: Equipment
    ----------------------------------------------------------------
     yOff = CreateSectionHeader(child, "EQUIPMENT" .. (data.avgIlvl and data.avgIlvl > 0 and ("  -  Avg iLvl: " .. data.avgIlvl) or ""), yOff, contentWidth)
    yOff = yOff - 5

    if data.gear then
        for _, slotInfo in ipairs(BRutus.SlotIDs) do
            local item = data.gear[slotInfo.id]
            yOff = CreateGearRow(child, slotInfo.id, item, yOff, contentWidth)
        end
    else
        local noData = child:CreateFontString(nil, "OVERLAY")
        noData:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        noData:SetPoint("TOPLEFT", 15, yOff)
        noData:SetTextColor(C.silver.r, C.silver.g, C.silver.b, 0.5)
        noData:SetText("No gear data available. Player needs BRutus addon.")
        noData:Show()
        yOff = yOff - 25
    end

    ----------------------------------------------------------------
    -- Section: Professions
    ----------------------------------------------------------------
    yOff = yOff - 10
    yOff = CreateSectionHeader(child, "PROFESSIONS", yOff, contentWidth)
    yOff = yOff - 5

    if data.professions and #data.professions > 0 then
        for _, prof in ipairs(data.professions) do
            yOff = CreateProfessionRow(child, prof, yOff, contentWidth)
        end
    else
        local noData = child:CreateFontString(nil, "OVERLAY")
        noData:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        noData:SetPoint("TOPLEFT", 15, yOff)
        noData:SetTextColor(C.silver.r, C.silver.g, C.silver.b, 0.5)
        noData:SetText("No profession data available.")
        noData:Show()
        yOff = yOff - 25
    end

    ----------------------------------------------------------------
    -- Section: Attunements
    ----------------------------------------------------------------
    yOff = yOff - 10
    yOff = CreateSectionHeader(child, "RAID ATTUNEMENTS", yOff, contentWidth)
    yOff = yOff - 5

    if data.attunements and #data.attunements > 0 then
        for _, att in ipairs(data.attunements) do
            yOff = CreateAttunementRow(child, att, yOff, contentWidth)
        end
    else
        local noData = child:CreateFontString(nil, "OVERLAY")
        noData:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        noData:SetPoint("TOPLEFT", 15, yOff)
        noData:SetTextColor(C.silver.r, C.silver.g, C.silver.b, 0.5)
        noData:SetText("No attunement data available.")
        noData:Show()
        yOff = yOff - 25
    end

    ----------------------------------------------------------------
    -- Section: TMB Loot (That's My BiS)
    ----------------------------------------------------------------
    local tmbData = BRutus.TMB and BRutus.TMB:GetCharacterData(data.name)
    if tmbData then
        yOff = yOff - 10
        local tmbParts = {}
        if #tmbData.prios > 0 then table.insert(tmbParts, #tmbData.prios .. " prio") end
        if #tmbData.wishlists > 0 then table.insert(tmbParts, #tmbData.wishlists .. " wish") end
        if #tmbData.received > 0 then table.insert(tmbParts, #tmbData.received .. " recv") end
        local tmbHeader = "THAT'S MY BIS" .. (#tmbParts > 0 and ("  --  " .. table.concat(tmbParts, " / ")) or "")
        yOff = CreateSectionHeader(child, tmbHeader, yOff, contentWidth)
        yOff = yOff - 5

        local TMBColors = BRutus.TMB.TypeColors

        -- Prios
        if #tmbData.prios > 0 then
            local prioLabel = child:CreateFontString(nil, "OVERLAY")
            prioLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            prioLabel:SetPoint("TOPLEFT", 10, yOff)
            prioLabel:SetTextColor(TMBColors.prio.r, TMBColors.prio.g, TMBColors.prio.b)
            prioLabel:SetText("PRIO:")
            prioLabel:Show()
            yOff = yOff - 14

            for _, item in ipairs(tmbData.prios) do
                local qColor = BRutus.QualityColors[BRutus.TMB:GetItemQuality(item.itemId)] or BRutus.QualityColors[1]
                local itemStr = child:CreateFontString(nil, "OVERLAY")
                itemStr:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
                itemStr:SetPoint("TOPLEFT", 20, yOff)
                itemStr:SetWidth(contentWidth - 30)
                itemStr:SetJustifyH("LEFT")
                itemStr:SetWordWrap(false)
                local osStr = item.isOffspec and " |cffAAAAAA(OS)|r" or ""
                itemStr:SetText(string.format("|cff%02x%02x%02x#%d %s|r%s",
                    qColor.r * 255, qColor.g * 255, qColor.b * 255,
                    item.order, BRutus.TMB:GetItemName(item.itemId), osStr))
                itemStr:Show()
                yOff = yOff - 15
            end
            yOff = yOff - 4
        end

        -- Wishlists
        if #tmbData.wishlists > 0 then
            local wishLabel = child:CreateFontString(nil, "OVERLAY")
            wishLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            wishLabel:SetPoint("TOPLEFT", 10, yOff)
            wishLabel:SetTextColor(TMBColors.wishlist.r, TMBColors.wishlist.g, TMBColors.wishlist.b)
            wishLabel:SetText("WISHLIST:")
            wishLabel:Show()
            yOff = yOff - 14

            for _, item in ipairs(tmbData.wishlists) do
                local qColor = BRutus.QualityColors[BRutus.TMB:GetItemQuality(item.itemId)] or BRutus.QualityColors[1]
                local itemStr = child:CreateFontString(nil, "OVERLAY")
                itemStr:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
                itemStr:SetPoint("TOPLEFT", 20, yOff)
                itemStr:SetWidth(contentWidth - 30)
                itemStr:SetJustifyH("LEFT")
                itemStr:SetWordWrap(false)
                local osStr = item.isOffspec and " |cffAAAAAA(OS)|r" or ""
                itemStr:SetText(string.format("|cff%02x%02x%02x#%d %s|r%s",
                    qColor.r * 255, qColor.g * 255, qColor.b * 255,
                    item.order, BRutus.TMB:GetItemName(item.itemId), osStr))
                itemStr:Show()
                yOff = yOff - 15
            end
            yOff = yOff - 4
        end

        -- Received
        if #tmbData.received > 0 then
            local recvLabel = child:CreateFontString(nil, "OVERLAY")
            recvLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            recvLabel:SetPoint("TOPLEFT", 10, yOff)
            recvLabel:SetTextColor(TMBColors.received.r, TMBColors.received.g, TMBColors.received.b)
            recvLabel:SetText("RECEIVED:")
            recvLabel:Show()
            yOff = yOff - 14

            for _, item in ipairs(tmbData.received) do
                local qColor = BRutus.QualityColors[BRutus.TMB:GetItemQuality(item.itemId)] or BRutus.QualityColors[1]
                local itemStr = child:CreateFontString(nil, "OVERLAY")
                itemStr:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
                itemStr:SetPoint("TOPLEFT", 20, yOff)
                itemStr:SetWidth(contentWidth - 30)
                itemStr:SetJustifyH("LEFT")
                itemStr:SetWordWrap(false)
                local dateStr = item.receivedAt and item.receivedAt ~= "" and (" |cffAAAAAA" .. item.receivedAt .. "|r") or ""
                itemStr:SetText(string.format("|cff%02x%02x%02x%s|r%s",
                    qColor.r * 255, qColor.g * 255, qColor.b * 255,
                    BRutus.TMB:GetItemName(item.itemId), dateStr))
                itemStr:Show()
                yOff = yOff - 15
            end
        end
    end

    ----------------------------------------------------------------
    -- Section: Raid Attendance
    ----------------------------------------------------------------
    if BRutus.RaidTracker then
        yOff = yOff - 10
        local playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
        local att = BRutus.RaidTracker:GetAttendance(playerKey)
        local pct = BRutus.RaidTracker:GetAttendancePercent(playerKey)
        local totalSessions = BRutus.RaidTracker:GetTotalSessions()
        local attStr = string.format("RAID ATTENDANCE  --  %d%%  (%d/%d raids)", pct, att.raids, totalSessions)
        yOff = CreateSectionHeader(child, attStr, yOff, contentWidth)

        if att.lastRaid > 0 then
            local lastStr = child:CreateFontString(nil, "OVERLAY")
            lastStr:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            lastStr:SetPoint("TOPLEFT", 15, yOff - 5)
            lastStr:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
            lastStr:SetText("Last raid: " .. date("%m/%d/%Y", att.lastRaid))
            lastStr:Show()
            yOff = yOff - 20
        end
    end

    ----------------------------------------------------------------
    -- Section: Loot History
    ----------------------------------------------------------------
    if BRutus.LootTracker then
        yOff = yOff - 10
        local playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
        local lootCount = BRutus.LootTracker:GetLootCount(playerKey)
        local lootHeader = "LOOT HISTORY  --  " .. lootCount .. " items"
        yOff = CreateSectionHeader(child, lootHeader, yOff, contentWidth)

        local recentLoot = BRutus.LootTracker:GetPlayerLoot(playerKey, 5)
        for _, entry in ipairs(recentLoot) do
            local qColor = BRutus.QualityColors[entry.quality] or BRutus.QualityColors[1]
            local itemStr = child:CreateFontString(nil, "OVERLAY")
            itemStr:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            itemStr:SetPoint("TOPLEFT", 15, yOff - 5)
            itemStr:SetWidth(contentWidth - 30)
            itemStr:SetJustifyH("LEFT")
            itemStr:SetWordWrap(false)
            local dateStr = entry.timestamp and (" |cffAAAAAA" .. date("%m/%d", entry.timestamp) .. "|r") or ""
            local raidStr = entry.raid and entry.raid ~= "" and (" |cff888888(" .. entry.raid .. ")|r") or ""
            itemStr:SetText(string.format("|cff%02x%02x%02x%s|r%s%s",
                qColor.r * 255, qColor.g * 255, qColor.b * 255,
                entry.itemName or "?", raidStr, dateStr))
            itemStr:Show()
            yOff = yOff - 15
        end
        if lootCount == 0 then
            yOff = yOff - 5
        end
    end

    ----------------------------------------------------------------
    -- Section: Trial Status (officer only)
    ----------------------------------------------------------------
    if BRutus.TrialTracker and BRutus:IsOfficer() then
        local playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
        local trial = BRutus.TrialTracker:GetTrial(playerKey)
        if trial then
            yOff = yOff - 10
            local daysRem = BRutus.TrialTracker:GetDaysRemaining(playerKey)
            local daysSince = BRutus.TrialTracker:GetDaysSinceStart(playerKey)
            local trialStr = "TRIAL STATUS  --  " .. (trial.status or "?"):upper()
            if daysRem then trialStr = trialStr .. "  (" .. daysRem .. " days left)" end
            yOff = CreateSectionHeader(child, trialStr, yOff, contentWidth)

            local infoStr = child:CreateFontString(nil, "OVERLAY")
            infoStr:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            infoStr:SetPoint("TOPLEFT", 15, yOff - 5)
            infoStr:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
            infoStr:SetText("Sponsor: " .. (trial.sponsor or "?") .. "  |  Day " .. (daysSince or 0))
            infoStr:Show()
            yOff = yOff - 20
        end
    end

    ----------------------------------------------------------------
    -- Section: Officer Notes (officer only)
    ----------------------------------------------------------------
    if BRutus.OfficerNotes and BRutus:IsOfficer() then
        yOff = yOff - 10
        local playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
        local notes = BRutus.OfficerNotes:GetNotes(playerKey)
        local notesHeader = "OFFICER NOTES  --  " .. #notes .. " notes"
        yOff = CreateSectionHeader(child, notesHeader, yOff, contentWidth)

        -- Show tags
        local tags = BRutus.OfficerNotes:GetAllTags(playerKey)
        if next(tags) then
            local tagParts = {}
            for k, v in pairs(tags) do
                table.insert(tagParts, k .. ": " .. tostring(v))
            end
            local tagStr = child:CreateFontString(nil, "OVERLAY")
            tagStr:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            tagStr:SetPoint("TOPLEFT", 15, yOff - 5)
            tagStr:SetTextColor(C.accent.r, C.accent.g, C.accent.b)
            tagStr:SetText(table.concat(tagParts, "  |  "))
            tagStr:Show()
            yOff = yOff - 16
        end

        -- Show last 3 notes
        for i = 1, math.min(3, #notes) do
            local note = notes[i]
            local noteStr = child:CreateFontString(nil, "OVERLAY")
            noteStr:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            noteStr:SetPoint("TOPLEFT", 15, yOff - 3)
            noteStr:SetWidth(contentWidth - 30)
            noteStr:SetJustifyH("LEFT")
            noteStr:SetWordWrap(true)
            local dateStr = note.timestamp and date("%m/%d", note.timestamp) or ""
            noteStr:SetText("|cffAAAAAA[" .. (note.author or "?") .. " " .. dateStr .. "]|r " .. (note.text or ""))
            noteStr:Show()
            yOff = yOff - (noteStr:GetStringHeight() + 4)
        end
    end

    -- Update scroll child height
    child:SetHeight(math.abs(yOff) + 20)
end

----------------------------------------------------------------------
-- Create a section header
----------------------------------------------------------------------
function CreateSectionHeader(parent, text, yOff, width)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetPoint("TOPLEFT", 0, yOff)
    bg:SetSize(width, 22)
    bg:SetVertexColor(C.headerBg.r, C.headerBg.g, C.headerBg.b, 0.6)
    bg:Show()

    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    label:SetPoint("LEFT", bg, "LEFT", 10, 0)
    label:SetTextColor(C.gold.r, C.gold.g, C.gold.b, 0.9)
    label:SetText(text)
    label:Show()

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetPoint("TOPLEFT", 0, yOff - 22)
    line:SetSize(width, 1)
    line:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.4)
    line:Show()

    return yOff - 26
end

----------------------------------------------------------------------
-- Create a gear slot row
----------------------------------------------------------------------
function CreateGearRow(parent, slotId, item, yOff, width)
    local ROW_H = 26
    local slotName = BRutus.SlotNames[slotId] or "Slot " .. slotId

    -- Slot label
    local slotLabel = parent:CreateFontString(nil, "OVERLAY")
    slotLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    slotLabel:SetPoint("TOPLEFT", 10, yOff - 4)
    slotLabel:SetWidth(65)
    slotLabel:SetJustifyH("RIGHT")
    slotLabel:SetTextColor(C.silver.r, C.silver.g, C.silver.b, 0.6)
    slotLabel:SetText(slotName)
    slotLabel:Show()

    if item and item.name and item.name ~= "" then
        -- Item icon
        if item.icon and item.icon ~= "" then
            local iconFrame = UI:CreateIcon(parent, 18, item.icon)
            iconFrame:SetPoint("TOPLEFT", 80, yOff - 1)
            iconFrame:Show()
            UI:SetIconQuality(iconFrame, item.quality)
        end

        -- Item name (colored by quality)
        local qColor = BRutus.QualityColors[item.quality] or BRutus.QualityColors[1]
        local nameText = parent:CreateFontString(nil, "OVERLAY")
        nameText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        nameText:SetPoint("TOPLEFT", 106, yOff - 5)
        nameText:SetWidth(width - 170)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        nameText:SetTextColor(qColor.r, qColor.g, qColor.b)
        nameText:SetText(item.name)
        nameText:Show()

        -- Item level
        local ilvlText = parent:CreateFontString(nil, "OVERLAY")
        ilvlText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        ilvlText:SetPoint("TOPRIGHT", -10, yOff - 5)
        ilvlText:SetText(BRutus:FormatItemLevel(item.ilvl))
        ilvlText:Show()
    else
        -- Empty slot
        local emptyText = parent:CreateFontString(nil, "OVERLAY")
        emptyText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        emptyText:SetPoint("TOPLEFT", 82, yOff - 5)
        emptyText:SetTextColor(0.3, 0.3, 0.3)
         emptyText:SetText("- Empty -")
        emptyText:Show()
    end

    -- Separator
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\Buttons\\WHITE8x8")
    sep:SetPoint("TOPLEFT", 10, yOff - ROW_H)
    sep:SetSize(width - 20, 1)
    sep:SetVertexColor(C.separator.r, C.separator.g, C.separator.b, 0.2)
    sep:Show()

    return yOff - ROW_H
end

----------------------------------------------------------------------
-- Create a profession row
----------------------------------------------------------------------
function CreateProfessionRow(parent, prof, yOff, width)
    local ROW_H = 30

    -- Profession name
    local nameColor = prof.isPrimary and C.gold or C.silver
    local nameText = parent:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    nameText:SetPoint("TOPLEFT", 15, yOff - 3)
    nameText:SetTextColor(nameColor.r, nameColor.g, nameColor.b)
    nameText:SetText(prof.name)
    nameText:Show()

    -- Skill level text
    local skillText = parent:CreateFontString(nil, "OVERLAY")
    skillText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    skillText:SetPoint("TOPRIGHT", -10, yOff - 4)
    skillText:SetTextColor(C.white.r, C.white.g, C.white.b)
    skillText:SetText(string.format("%d / %d", prof.rank, prof.maxRank))
    skillText:Show()

    -- Progress bar
    local progressBar = UI:CreateProgressBar(parent, width - 30, 6)
    progressBar:SetPoint("TOPLEFT", 15, yOff - 18)
    progressBar:SetProgress(prof.maxRank > 0 and (prof.rank / prof.maxRank) or 0)
    progressBar:Show()

    return yOff - ROW_H
end

----------------------------------------------------------------------
-- Create an attunement row
----------------------------------------------------------------------
function CreateAttunementRow(parent, att, yOff, width)
    local ROW_H = 34

    -- Background with subtle color coding
    local rowBg = parent:CreateTexture(nil, "BACKGROUND")
    rowBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    rowBg:SetPoint("TOPLEFT", 5, yOff)
    rowBg:SetSize(width - 10, ROW_H - 2)
    if att.complete then
        rowBg:SetVertexColor(C.green.r * 0.1, C.green.g * 0.1, C.green.b * 0.1, 0.3)
    else
        rowBg:SetVertexColor(0.05, 0.05, 0.08, 0.3)
    end
    rowBg:Show()

    -- Tier badge
    local tierBadge = parent:CreateFontString(nil, "OVERLAY")
    tierBadge:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    tierBadge:SetPoint("TOPLEFT", 10, yOff - 4)
    tierBadge:SetTextColor(C.accentDim.r, C.accentDim.g, C.accentDim.b)
    tierBadge:SetText("[" .. att.tier .. "]")
    tierBadge:Show()

    -- Raid name
    local nameText = parent:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    nameText:SetPoint("LEFT", tierBadge, "RIGHT", 5, 0)
    nameText:Show()

    -- Status
    local statusText = parent:CreateFontString(nil, "OVERLAY")
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    statusText:SetPoint("TOPRIGHT", -10, yOff - 4)
    statusText:Show()

    if att.complete then
        nameText:SetTextColor(C.green.r, C.green.g, C.green.b)
        nameText:SetText(att.name)
        statusText:SetTextColor(C.green.r, C.green.g, C.green.b)
        statusText:SetText("ATTUNED")
    elseif att.progress and att.progress > 0 then
        nameText:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
        nameText:SetText(att.name)
        statusText:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
        statusText:SetText(string.format("%d/%d", att.questsDone or 0, att.questsTotal or 0))
    else
        nameText:SetTextColor(C.red.r, C.red.g, C.red.b, 0.7)
        nameText:SetText(att.name)
        statusText:SetTextColor(C.red.r, C.red.g, C.red.b, 0.7)
        statusText:SetText("NOT STARTED")
    end

    -- Progress bar (only for in-progress attunements, not completed ones)
    if not att.complete and att.questsTotal and att.questsTotal > 0 then
        local progressBar = UI:CreateProgressBar(parent, width - 30, 5)
        progressBar:SetPoint("TOPLEFT", 10, yOff - 20)
        progressBar:SetProgress(att.progress or 0)
        progressBar:Show()
    end

    return yOff - ROW_H
end
