----------------------------------------------------------------------
-- BRutus Guild Manager - Member Detail Panel
-- Shows full gear inspection, professions, and attunement details
----------------------------------------------------------------------
local UI = BRutus.UI
local C = BRutus.Colors

local DETAIL_WIDTH = 420
local DETAIL_HEIGHT = 620

----------------------------------------------------------------------
-- Create an invisible tooltip hover zone over a region
-- anchor: FontString or Frame to overlay
-- link: itemLink string OR itemId number
-- w, h: optional size override (defaults to anchor size)
----------------------------------------------------------------------
local function CreateItemTooltipZone(parent, anchor, link, w, h)
    if not link then return end
    local zone = CreateFrame("Frame", nil, parent)
    zone:SetAllPoints(anchor)
    if w and h then
        zone:SetSize(w, h)
    end
    zone:EnableMouse(true)
    zone:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if type(link) == "number" then
            GameTooltip:SetHyperlink("item:" .. link)
        else
            GameTooltip:SetHyperlink(link)
        end
        GameTooltip:Show()
    end)
    zone:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    zone:Show()
    return zone
end

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
    content:SetPoint("BOTTOMRIGHT", -10, 5)
    UI:SkinScrollBar(content, "BRutusDetailScroll")

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
    -- Section: Spec
    ----------------------------------------------------------------
    local playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
    local specLabel = BRutus.SpecChecker and BRutus.SpecChecker:GetSpecLabel(playerKey)

    yOff = CreateSectionHeader(child, "TALENT SPEC", yOff, contentWidth)
    yOff = yOff - 5

    if specLabel then
        local spec = BRutus.db.members and BRutus.db.members[playerKey] and BRutus.db.members[playerKey].spec
        local cr, cg, cb = BRutus:GetClassColor(data.class)

        -- Talent distribution bar (one segment per tree; clickable to view tree)
        if spec and spec.points and spec.names then
            local barFrame = CreateFrame("Button", nil, child)
            barFrame:SetPoint("TOPLEFT", 10, yOff)
            barFrame:SetSize(contentWidth - 20, 20)
            barFrame:RegisterForClicks("LeftButtonUp")
            if spec.talents then
                barFrame:SetScript("OnClick", function()
                    local freshSpec = BRutus.db.members[playerKey]
                        and BRutus.db.members[playerKey].spec
                    BRutus:ShowTalentViewer(freshSpec or spec, data.name, data.class)
                end)
                barFrame:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText("Click to view talent tree", 1, 1, 0.6)
                    GameTooltip:Show()
                end)
                barFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            barFrame:Show()

            local total = 0
            for _, pts in ipairs(spec.points) do total = total + pts end
            if total == 0 then total = 1 end

            -- Three colour shades for the three trees
            local treeColors = {
                { r = cr,      g = cg,      b = cb      },
                { r = cr*0.65, g = cg*0.65, b = cb*0.65 },
                { r = cr*0.40, g = cg*0.40, b = cb*0.40 },
            }

            local xPos = 0
            for i, pts in ipairs(spec.points) do
                if pts > 0 then
                    local segW = math.floor(((pts / total) * (contentWidth - 20)) + 0.5)
                    local seg = barFrame:CreateTexture(nil, "OVERLAY")
                    seg:SetTexture("Interface\\Buttons\\WHITE8x8")
                    seg:SetPoint("TOPLEFT", xPos, 0)
                    seg:SetSize(segW, 18)
                    local tc = treeColors[i] or treeColors[1]
                    seg:SetVertexColor(tc.r, tc.g, tc.b, 0.85)
                    seg:Show()

                    local segLabel = barFrame:CreateFontString(nil, "OVERLAY")
                    segLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
                    segLabel:SetPoint("CENTER", seg, "CENTER", 0, 0)
                    segLabel:SetText(pts .. "  " .. (spec.names[i] or ""))
                    segLabel:SetTextColor(1, 1, 1)
                    segLabel:Show()

                    xPos = xPos + segW
                end
            end
            yOff = yOff - 24
        end

        -- Text label: e.g.  "41 / 5 / 15  (Protection)"
        local specText = child:CreateFontString(nil, "OVERLAY")
        specText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        specText:SetPoint("TOPLEFT", 10, yOff)
        specText:SetTextColor(cr, cg, cb)
        specText:SetText(specLabel)
        specText:Show()
        yOff = yOff - 22

        if spec and spec.scannedAt and spec.scannedAt > 0 then
            local age = GetServerTime() - spec.scannedAt
            local ageStr
            if age < 3600 then
                ageStr = math.floor(age / 60) .. "m ago"
            elseif age < 86400 then
                ageStr = math.floor(age / 3600) .. "h ago"
            else
                ageStr = math.floor(age / 86400) .. "d ago"
            end
            local scanText = child:CreateFontString(nil, "OVERLAY")
            scanText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            scanText:SetPoint("TOPLEFT", 10, yOff)
            scanText:SetTextColor(C.silver.r, C.silver.g, C.silver.b, 0.6)
            scanText:SetText("Last scanned: " .. ageStr)
            scanText:Show()
            yOff = yOff - 18
        end
    else
        local noSpec = child:CreateFontString(nil, "OVERLAY")
        noSpec:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
        noSpec:SetPoint("TOPLEFT", 15, yOff)
        noSpec:SetTextColor(C.silver.r, C.silver.g, C.silver.b, 0.5)
        noSpec:SetText("No spec data. Use /brutus specs to scan the group.")
        noSpec:Show()
        yOff = yOff - 25
    end

    yOff = yOff - 8

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
    -- Section: Attunements (account-wide propagation from linked chars)
    ----------------------------------------------------------------
    yOff = yOff - 10
    local playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
    yOff = CreateSectionHeader(child, "RAID ATTUNEMENTS", yOff, contentWidth)
    yOff = yOff - 5

    local attsToShow
    if BRutus.AttunementTracker then
        attsToShow = BRutus.AttunementTracker:GetEffectiveAttunements(playerKey)
    else
        attsToShow = data.attunements
    end

    if attsToShow and #attsToShow > 0 then
        for _, att in ipairs(attsToShow) do
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
                CreateItemTooltipZone(child, itemStr, item.itemId)
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
                CreateItemTooltipZone(child, itemStr, item.itemId)
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
                CreateItemTooltipZone(child, itemStr, item.itemId)
                yOff = yOff - 15
            end
        end
    end

    ----------------------------------------------------------------
    -- Section: Raid Attendance
    ----------------------------------------------------------------
    if BRutus.RaidTracker then
        yOff = yOff - 10
        playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
        local att          = BRutus.RaidTracker:GetAttendance(playerKey)
        local pct          = BRutus.RaidTracker:GetAttendance25ManPercent(playerKey)
        local total25      = BRutus.RaidTracker:GetTotal25ManSessions()
        local raids25      = att.raids25 or 0
        local attStr = string.format("RAID ATTENDANCE  --  %d%%  (%d/%d raids, 25-man)", pct, raids25, total25)
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
        playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
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
            -- Resolve item name locally from itemLink
            local displayName = entry.itemName or "?"
            if entry.itemLink then
                local localName = entry.itemLink:match("%[(.-)%]")
                if localName and localName ~= "" then
                    displayName = localName
                end
            end
            local dateStr = entry.timestamp and (" |cffAAAAAA" .. date("%m/%d", entry.timestamp) .. "|r") or ""
            local raidStr = entry.raid and entry.raid ~= "" and (" |cff888888(" .. entry.raid .. ")|r") or ""
            itemStr:SetText(string.format("|cff%02x%02x%02x%s|r%s%s",
                qColor.r * 255, qColor.g * 255, qColor.b * 255,
                displayName, raidStr, dateStr))
            itemStr:Show()
            if entry.itemLink then
                CreateItemTooltipZone(child, itemStr, entry.itemLink)
            end
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
        playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
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

            -- Progress tracking
            local progress = BRutus.TrialTracker:GetProgress(playerKey)
            if progress then
                -- iLvl progress
                local ilvlColor = progress.ilvlDelta > 0 and C.green or (progress.ilvlDelta < 0 and C.red or C.silver)
                local ilvlSign = progress.ilvlDelta > 0 and "+" or ""
                local ilvlStr = format("iLvl: %d >> %d  (%s%d)", progress.startIlvl, progress.currentIlvl, ilvlSign, progress.ilvlDelta)
                local ilvlText = child:CreateFontString(nil, "OVERLAY")
                ilvlText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
                ilvlText:SetPoint("TOPLEFT", 15, yOff - 3)
                ilvlText:SetTextColor(ilvlColor.r, ilvlColor.g, ilvlColor.b)
                ilvlText:SetText(ilvlStr)
                ilvlText:Show()

                -- Attunement progress
                local attColor = progress.attDelta > 0 and C.green or C.silver
                local attStr = format("Attunements: %d/%d >> %d/%d  (+%d)", progress.startAttDone, progress.attTotal, progress.currentAttDone, progress.attTotal, progress.attDelta)
                local attText = child:CreateFontString(nil, "OVERLAY")
                attText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
                attText:SetPoint("TOPLEFT", contentWidth / 2, yOff - 3)
                attText:SetTextColor(attColor.r, attColor.g, attColor.b)
                attText:SetText(attStr)
                attText:Show()
                yOff = yOff - 16
            end

            -- Trial notes (all of them, not just 3)
            if trial.notes and #trial.notes > 0 then
                local notesLabel = child:CreateFontString(nil, "OVERLAY")
                notesLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
                notesLabel:SetPoint("TOPLEFT", 15, yOff - 6)
                notesLabel:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
                notesLabel:SetText("Officer Comments (" .. #trial.notes .. ")")
                notesLabel:Show()
                yOff = yOff - 18

                for _, note in ipairs(trial.notes) do
                    local noteFS = child:CreateFontString(nil, "OVERLAY")
                    noteFS:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
                    noteFS:SetPoint("TOPLEFT", 20, yOff - 2)
                    noteFS:SetWidth(contentWidth - 40)
                    noteFS:SetJustifyH("LEFT")
                    noteFS:SetWordWrap(true)
                    local dateStr = note.timestamp and date("%m/%d %H:%M", note.timestamp) or ""
                    noteFS:SetText(format("|cffAAAAAA[%s %s]|r %s", note.author or "?", dateStr, note.text or ""))
                    noteFS:Show()
                    yOff = yOff - (noteFS:GetStringHeight() + 4)
                end
            end

            -- Add note input
            local addNoteBox = CreateFrame("EditBox", nil, child, "BackdropTemplate")
            addNoteBox:SetSize(contentWidth - 100, 22)
            addNoteBox:SetPoint("TOPLEFT", 15, yOff - 8)
            addNoteBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            addNoteBox:SetBackdropColor(0.05, 0.05, 0.08, 1)
            addNoteBox:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.4)
            addNoteBox:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            addNoteBox:SetTextColor(C.white.r, C.white.g, C.white.b)
            addNoteBox:SetTextInsets(6, 6, 2, 2)
            addNoteBox:SetAutoFocus(false)
            addNoteBox:SetMaxLetters(200)
            addNoteBox:Show()

            local placeholder = addNoteBox:CreateFontString(nil, "OVERLAY")
            placeholder:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            placeholder:SetPoint("LEFT", 6, 0)
            placeholder:SetTextColor(0.35, 0.35, 0.35)
            placeholder:SetText("Add officer comment...")
            addNoteBox:SetScript("OnTextChanged", function(self)
                if self:GetText() ~= "" then placeholder:Hide() else placeholder:Show() end
            end)
            addNoteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

            local addBtn = UI:CreateButton(child, "Add", 60, 22)
            addBtn:SetPoint("LEFT", addNoteBox, "RIGHT", 6, 0)
            addBtn:SetScript("OnClick", function()
                local text = addNoteBox:GetText()
                if text and strtrim(text) ~= "" then
                    BRutus.TrialTracker:AddTrialNote(playerKey, strtrim(text))
                    addNoteBox:SetText("")
                    addNoteBox:ClearFocus()
                    PopulateDetail(frame, data)
                end
            end)
            addNoteBox:SetScript("OnEnterPressed", function(self)
                local text = self:GetText()
                if text and strtrim(text) ~= "" then
                    BRutus.TrialTracker:AddTrialNote(playerKey, strtrim(text))
                    self:SetText("")
                    self:ClearFocus()
                    PopulateDetail(frame, data)
                end
            end)

            yOff = yOff - 36
        end
    end

    ----------------------------------------------------------------
    -- Section: Officer Notes (officer only)
    ----------------------------------------------------------------
    if BRutus.OfficerNotes and BRutus:IsOfficer() then
        yOff = yOff - 10
        playerKey = BRutus:GetPlayerKey(data.name, data.realm or GetRealmName())
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

    ----------------------------------------------------------------
    -- Section: Linked Characters (officer only — alt/main management)
    ----------------------------------------------------------------
    if BRutus:IsOfficer() then
        yOff = yOff - 10
        local linkedKeys = BRutus:GetLinkedChars(playerKey)
        local altLinks = (BRutus.db and BRutus.db.altLinks) or {}

        -- Header shows how many chars are linked
        local linkCount = #linkedKeys - 1  -- exclude self
        local hdrSuffix = linkCount > 0 and ("  --  " .. linkCount .. " vinculado(s)") or "  --  nenhum"
        yOff = CreateSectionHeader(child, "PERSONAGENS VINCULADOS" .. hdrSuffix, yOff, contentWidth)
        yOff = yOff - 5

        local noteLabel = child:CreateFontString(nil, "OVERLAY")
        noteLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
        noteLabel:SetPoint("TOPLEFT", 12, yOff)
        noteLabel:SetWidth(contentWidth - 20)
        noteLabel:SetTextColor(C.silver.r, C.silver.g, C.silver.b, 0.7)
        noteLabel:SetText("Chars vinculados compartilham attunements account-wide.")
        noteLabel:Show()
        yOff = yOff - 16

        -- List currently linked chars (excluding self)
        for _, lk in ipairs(linkedKeys) do
            if lk ~= playerKey then
                local lkName = lk:match("^([^-]+)") or lk
                local lkIsMain = (altLinks[lk] == nil)
                local lkLabel = child:CreateFontString(nil, "OVERLAY")
                lkLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
                lkLabel:SetPoint("TOPLEFT", 12, yOff)
                lkLabel:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
                lkLabel:SetText((lkIsMain and "[main] " or "[alt]  ") .. lkName)
                lkLabel:Show()

                -- Unlink button
                local unlinkBtn = UI:CreateButton(child, "Desvincular", 80, 18)
                unlinkBtn:SetPoint("LEFT", lkLabel, "RIGHT", 10, 0)
                local capturedKey = lk
                unlinkBtn:SetScript("OnClick", function()
                    -- If lk is the main, unlink playerKey from it; else unlink lk
                    if lkIsMain then
                        BRutus:UnlinkAlt(playerKey)
                    else
                        BRutus:UnlinkAlt(capturedKey)
                    end
                    PopulateDetail(frame, data)
                end)
                yOff = yOff - 22
            end
        end

        -- Input to add a new link
        local addLinkBox = CreateFrame("EditBox", nil, child, "BackdropTemplate")
        addLinkBox:SetSize(contentWidth - 110, 22)
        addLinkBox:SetPoint("TOPLEFT", 12, yOff - 6)
        addLinkBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        addLinkBox:SetBackdropColor(0.05, 0.05, 0.08, 1)
        addLinkBox:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.4)
        addLinkBox:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        addLinkBox:SetTextColor(C.white.r, C.white.g, C.white.b)
        addLinkBox:SetTextInsets(6, 6, 2, 2)
        addLinkBox:SetAutoFocus(false)
        addLinkBox:SetMaxLetters(60)
        addLinkBox:Show()

        local addLinkPlaceholder = addLinkBox:CreateFontString(nil, "OVERLAY")
        addLinkPlaceholder:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        addLinkPlaceholder:SetPoint("LEFT", 6, 0)
        addLinkPlaceholder:SetTextColor(0.35, 0.35, 0.35)
        addLinkPlaceholder:SetText("NomeDoAlt (este é o main)")
        addLinkBox:SetScript("OnTextChanged", function(self)
            if self:GetText() ~= "" then addLinkPlaceholder:Hide() else addLinkPlaceholder:Show() end
        end)
        addLinkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        local addLinkBtn = UI:CreateButton(child, "Vincular alt", 90, 22)
        addLinkBtn:SetPoint("LEFT", addLinkBox, "RIGHT", 6, 0)

        local doLink = function()
            local altName = strtrim(addLinkBox:GetText())
            if altName == "" then return end
            local realm = data.realm or GetRealmName()
            local altKey = BRutus:GetPlayerKey(altName, realm)
            -- playerKey is treated as the main; altKey as the alt
            if BRutus:LinkAlt(altKey, playerKey) then
                addLinkBox:SetText("")
                addLinkBox:ClearFocus()
                PopulateDetail(frame, data)
            end
        end
        addLinkBtn:SetScript("OnClick", doLink)
        addLinkBox:SetScript("OnEnterPressed", doLink)

        yOff = yOff - 34
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
-- Create a gear slot row (with enchant & gem display)
----------------------------------------------------------------------

-- Slots where missing enchant is a serious issue
local ENCHANT_WARNING_SLOTS = {
    [1] = true, [3] = true, [5] = true, [7] = true, [8] = true,
    [9] = true, [10] = true, [15] = true, [16] = true,
}

function CreateGearRow(parent, slotId, item, yOff, width)
    local ROW_H = 26
    local subRowH = 14
    local slotName = BRutus.SlotNames[slotId] or "Slot " .. slotId
    local hasExtra = false

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
        -- Resolve localized item name from ID when available
        local displayName = item.name
        if item.id then
            local localName = GetItemInfo(item.id)
            if localName and localName ~= "" then
                displayName = localName
            end
        end

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
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        nameText:SetTextColor(qColor.r, qColor.g, qColor.b)
        nameText:SetText(displayName)
        nameText:Show()

        -- Tooltip hover zone over gear row
        CreateItemTooltipZone(parent, nameText, item.link or item.id)

        -- Gem icons — inline after item name on the same row
        local gemAnchor = nameText
        if item.gems and #item.gems > 0 then
            for _, gem in ipairs(item.gems) do
                if gem.icon and gem.icon ~= "" then
                    local gemFrame = UI:CreateIcon(parent, 12, gem.icon)
                    gemFrame:SetPoint("LEFT", gemAnchor, "RIGHT", 4, 0)
                    gemFrame:Show()
                    gemAnchor = gemFrame

                    -- Gem tooltip on hover
                    if gem.id then
                        gemFrame:EnableMouse(true)
                        gemFrame:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetHyperlink("item:" .. gem.id)
                            GameTooltip:Show()
                        end)
                        gemFrame:SetScript("OnLeave", function()
                            GameTooltip:Hide()
                        end)
                    end
                end
            end
        end

        -- Item level
        local ilvlText = parent:CreateFontString(nil, "OVERLAY")
        ilvlText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        ilvlText:SetPoint("TOPRIGHT", -10, yOff - 5)
        ilvlText:SetText(BRutus:FormatItemLevel(item.ilvl))
        ilvlText:Show()

        -- Enchant line — sub-row below item name
        local enchantY = yOff - ROW_H
        if item.enchantName then
            local enchText = parent:CreateFontString(nil, "OVERLAY")
            enchText:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            enchText:SetPoint("TOPLEFT", 106, enchantY)
            enchText:SetTextColor(0.0, 0.8, 0.0)
            enchText:SetText(item.enchantName)
            enchText:Show()
            hasExtra = true
        elseif item.enchantId and item.enchantId > 0 then
            local enchText = parent:CreateFontString(nil, "OVERLAY")
            enchText:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            enchText:SetPoint("TOPLEFT", 106, enchantY)
            enchText:SetTextColor(0.0, 0.8, 0.0)
            enchText:SetText("Enchanted")
            enchText:Show()
            hasExtra = true
        elseif ENCHANT_WARNING_SLOTS[slotId] then
            local warnText = parent:CreateFontString(nil, "OVERLAY")
            warnText:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            warnText:SetPoint("TOPLEFT", 106, enchantY)
            warnText:SetTextColor(C.red.r, C.red.g, C.red.b, 0.7)
            warnText:SetText("Not enchanted")
            warnText:Show()
            hasExtra = true
        end
    else
        -- Empty slot
        local emptyText = parent:CreateFontString(nil, "OVERLAY")
        emptyText:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
        emptyText:SetPoint("TOPLEFT", 82, yOff - 5)
        emptyText:SetTextColor(0.3, 0.3, 0.3)
        emptyText:SetText("- Empty -")
        emptyText:Show()
    end

    local totalH = ROW_H + (hasExtra and subRowH or 0)

    -- Separator
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\Buttons\\WHITE8x8")
    sep:SetPoint("TOPLEFT", 10, yOff - totalH)
    sep:SetSize(width - 20, 1)
    sep:SetVertexColor(C.separator.r, C.separator.g, C.separator.b, 0.2)
    sep:Show()

    return yOff - totalH
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
        if att.accountWide and att.sourceChar then
            local srcName = att.sourceChar:match("^([^-]+)") or att.sourceChar
            statusText:SetText("ATTUNED |cff888888(conta: " .. srcName .. ")|r")
        else
            statusText:SetText("ATTUNED")
        end
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

----------------------------------------------------------------------
-- Talent Tree Viewer
-- A compact floating panel showing a member's talents tab by tab.
----------------------------------------------------------------------
local TV_SLOT_SIZE = 38   -- icon cell size (includes border/gap)
local TV_ICON_SIZE = 34   -- inner texture size
local TV_COLS      = 4
local TV_ROWS      = 9    -- max tier rows in TBC talent trees
local TV_W         = TV_COLS * TV_SLOT_SIZE + 22          -- 174
local TV_H         = 36 + 26 + 4 + TV_ROWS * TV_SLOT_SIZE + 10  -- 418

local function CreateTalentViewerFrame()
    local f = UI:CreatePanel(UIParent, "BRutusTalentViewer")
    f:SetSize(TV_W, TV_H)
    f:SetPoint("CENTER", 350, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(30)
    f:Hide()

    ----------------------------------------------------------------
    -- Title bar (draggable)
    ----------------------------------------------------------------
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT")
    titleBar:SetPoint("TOPRIGHT")
    titleBar:SetHeight(36)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

    local titleBg = titleBar:CreateTexture(nil, "ARTWORK")
    titleBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    titleBg:SetAllPoints()
    titleBg:SetVertexColor(C.headerBg.r, C.headerBg.g, C.headerBg.b, C.headerBg.a)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    titleText:SetPoint("LEFT", 8, 0)
    titleText:SetPoint("RIGHT", -26, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    titleText:SetWordWrap(false)
    f.titleText = titleText

    local closeBtn = UI:CreateCloseButton(titleBar)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local titleLine = f:CreateTexture(nil, "OVERLAY")
    titleLine:SetTexture("Interface\\Buttons\\WHITE8x8")
    titleLine:SetPoint("TOPLEFT",  0, -36)
    titleLine:SetPoint("TOPRIGHT", 0, -36)
    titleLine:SetHeight(1)
    titleLine:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.8)

    ----------------------------------------------------------------
    -- Tree tab buttons (3 trees per class)
    ----------------------------------------------------------------
    local tabW = math.floor((TV_W - 8) / 3)
    local tabs = {}
    for i = 1, 3 do
        local tab = CreateFrame("Button", nil, f, "BackdropTemplate")
        tab:SetSize(tabW - 2, 24)
        tab:SetPoint("TOPLEFT", 4 + (i - 1) * tabW, -38)
        tab:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        tab:SetBackdropColor(C.row2.r, C.row2.g, C.row2.b, 1)
        tab:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.5)

        local lbl = tab:CreateFontString(nil, "OVERLAY")
        lbl:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
        lbl:SetAllPoints()
        lbl:SetJustifyH("CENTER")
        lbl:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
        tab.label = lbl

        local capturedI = i
        tab:SetScript("OnClick", function()
            f.currentTab = capturedI
            f:RefreshGrid()
        end)
        tabs[i] = tab
    end
    f.tabs = tabs

    ----------------------------------------------------------------
    -- Icon slots — pre-created grid; repositioned on refresh
    ----------------------------------------------------------------
    local gridX = 11
    local gridY = -66  -- below title bar + tabs + gap
    local slots = {}
    for row = 1, TV_ROWS do
        slots[row] = {}
        for col = 1, TV_COLS do
            local slot = CreateFrame("Button", nil, f, "BackdropTemplate")
            slot:SetSize(TV_ICON_SIZE, TV_ICON_SIZE)
            slot:SetPoint(
                "TOPLEFT",
                gridX + (col - 1) * TV_SLOT_SIZE,
                gridY - (row - 1) * TV_SLOT_SIZE)
            slot:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            slot:SetBackdropColor(0, 0, 0, 0.7)
            slot:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.4)

            local icon = slot:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("TOPLEFT",     2, -2)
            icon:SetPoint("BOTTOMRIGHT", -2, 2)
            slot.icon = icon

            local rankText = slot:CreateFontString(nil, "OVERLAY")
            rankText:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
            rankText:SetPoint("BOTTOMRIGHT", -1, 2)
            slot.rankText = rankText

            local dimOverlay = slot:CreateTexture(nil, "OVERLAY")
            dimOverlay:SetTexture("Interface\\Buttons\\WHITE8x8")
            dimOverlay:SetAllPoints()
            dimOverlay:SetVertexColor(0, 0, 0, 0.55)
            slot.dimOverlay = dimOverlay

            slot:SetScript("OnEnter", function(self)
                if not self.talentData then return end
                local td = self.talentData
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(td.name, 1, 1, 1)
                if td.currentRank > 0 then
                    GameTooltip:AddLine(
                        format("Rank %d / %d", td.currentRank, td.maxRank),
                        0.9, 0.8, 0.1)
                else
                    GameTooltip:AddLine(
                        format("Not learned  (0/%d)", td.maxRank),
                        0.5, 0.5, 0.5)
                end
                GameTooltip:Show()
            end)
            slot:SetScript("OnLeave", function() GameTooltip:Hide() end)

            slot:Hide()
            slots[row][col] = slot
        end
    end
    f.slots = slots

    ----------------------------------------------------------------
    -- RefreshGrid: fill the grid from the current tab's talent data
    ----------------------------------------------------------------
    function f:RefreshGrid()
        local tab  = self.currentTab or 1
        local spec = self.spec
        if not spec then return end

        -- Tab button styles
        local cr, cg, cb = BRutus:GetClassColor(self.classToken)
        for i, tabBtn in ipairs(self.tabs) do
            local pts  = (spec.points and spec.points[i]) or 0
            local name = (spec.names  and spec.names[i])  or ("Tree " .. i)
            if #name > 8 then name = name:sub(1, 8) end
            tabBtn.label:SetText(name .. "\n" .. pts)
            if i == tab then
                tabBtn:SetBackdropColor(cr * 0.35, cg * 0.35, cb * 0.35, 1)
                tabBtn.label:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
            else
                tabBtn:SetBackdropColor(C.row2.r, C.row2.g, C.row2.b, 1)
                tabBtn.label:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
            end
        end

        -- Clear all slots
        for row = 1, TV_ROWS do
            for col = 1, TV_COLS do
                local slot = self.slots[row][col]
                slot.talentData = nil
                slot.icon:SetTexture("")
                slot.rankText:SetText("")
                slot.dimOverlay:Show()
                slot:Hide()
            end
        end

        -- Populate talents for the active tab
        local tabTalents = spec.talents and spec.talents[tab]
        if not tabTalents then return end

        for _, td in ipairs(tabTalents) do
            local row = tonumber(td.tier)   or 0
            local col = tonumber(td.column) or 0
            if row >= 1 and row <= TV_ROWS and col >= 1 and col <= TV_COLS then
                local slot = self.slots[row][col]
                slot.talentData = td
                slot.icon:SetTexture(
                    (td.icon and td.icon ~= "") and td.icon
                    or "Interface\\Icons\\INV_Misc_QuestionMark")
                if td.currentRank > 0 then
                    slot.icon:SetDesaturated(false)
                    slot.icon:SetAlpha(1.0)
                    slot.dimOverlay:Hide()
                    slot:SetBackdropBorderColor(cr * 0.8, cg * 0.8, cb * 0.8, 0.9)
                    if td.currentRank >= td.maxRank then
                        slot.rankText:SetTextColor(0.2, 1.0, 0.2)
                    else
                        slot.rankText:SetTextColor(1.0, 0.85, 0.0)
                    end
                    slot.rankText:SetText(td.currentRank .. "/" .. td.maxRank)
                else
                    slot.icon:SetDesaturated(true)
                    slot.icon:SetAlpha(0.4)
                    slot.dimOverlay:Show()
                    slot:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.3)
                    slot.rankText:SetTextColor(0.35, 0.35, 0.35)
                    slot.rankText:SetText("0/" .. td.maxRank)
                end
                slot:Show()
            end
        end
    end

    table.insert(UISpecialFrames, "BRutusTalentViewer")
    return f
end

----------------------------------------------------------------------
-- BRutus:ShowTalentViewer(spec, playerName, classToken)
-- Opens the talent tree viewer for the given spec record.
----------------------------------------------------------------------
function BRutus:ShowTalentViewer(spec, playerName, classToken)
    if not spec or not spec.talents then
        BRutus:Print("|cffFF4444No talent data available for this player.|r")
        return
    end

    if not self.TalentViewerFrame then
        self.TalentViewerFrame = CreateTalentViewerFrame()
    end
    local f = self.TalentViewerFrame
    f.spec       = spec
    f.classToken = classToken

    local shortName = (playerName or "?"):match("^([^-]+)") or playerName
    local specName  = spec.tree or "Unknown"
    f.titleText:SetText(shortName .. "  —  " .. specName)

    f.currentTab = spec.treeIndex or 1
    f:RefreshGrid()
    f:Show()
    f:Raise()
end
