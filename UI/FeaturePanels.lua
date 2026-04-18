----------------------------------------------------------------------
-- BRutus Guild Manager - Feature Panels UI
-- UI panels for: Raids, Loot, Trials
----------------------------------------------------------------------
local UI = BRutus.UI
local C = BRutus.Colors

----------------------------------------------------------------------
-- RAID ATTENDANCE PANEL
----------------------------------------------------------------------
function BRutus:CreateRaidsPanel(parent, _mainFrame)
    local scrollParent = CreateFrame("Frame", nil, parent)
    scrollParent:SetPoint("TOPLEFT", 10, -10)
    scrollParent:SetPoint("BOTTOMRIGHT", -10, 10)

    -- Title
    local title = UI:CreateTitle(scrollParent, "Raid Attendance", 14)
    title:SetPoint("TOPLEFT", 0, 0)

    -- Status text
    local statusText = UI:CreateText(scrollParent, "", 10, C.silver.r, C.silver.g, C.silver.b)
    statusText:SetPoint("TOPRIGHT", 0, -2)

    -- Sessions list area
    local sessionsHeader = UI:CreateHeaderText(scrollParent, "Recent Sessions", 11)
    sessionsHeader:SetPoint("TOPLEFT", 0, -30)

    local sessionScroll = CreateFrame("ScrollFrame", "BRutusRaidSessionScroll", scrollParent, "UIPanelScrollFrameTemplate")
    sessionScroll:SetPoint("TOPLEFT", 0, -50)
    sessionScroll:SetPoint("BOTTOMRIGHT", -30, 140)

    local sessionContent = CreateFrame("Frame", nil, sessionScroll)
    sessionContent:SetSize(800, 1)
    sessionScroll:SetScrollChild(sessionContent)

    -- Attendance list area
    local attHeader = UI:CreateHeaderText(scrollParent, "Member Attendance", 11)
    attHeader:SetPoint("BOTTOMLEFT", 0, 120)

    local attScroll = CreateFrame("ScrollFrame", "BRutusAttendanceScroll", scrollParent, "UIPanelScrollFrameTemplate")
    attScroll:SetPoint("BOTTOMLEFT", 0, 10)
    attScroll:SetPoint("BOTTOMRIGHT", -30, 10)
    attScroll:SetHeight(105)

    local attContent = CreateFrame("Frame", nil, attScroll)
    attContent:SetSize(800, 1)
    attScroll:SetScrollChild(attContent)

    parent:SetScript("OnShow", function()
        BRutus:RefreshRaidsPanel(sessionContent, attContent, statusText)
    end)
end

function BRutus:RefreshRaidsPanel(sessionContent, attContent, statusText)
    if not BRutus.RaidTracker then return end

    -- Clear existing children
    for _, child in pairs({ sessionContent:GetChildren() }) do child:Hide() end
    for _, child in pairs({ attContent:GetChildren() }) do child:Hide() end

    local totalSessions = BRutus.RaidTracker:GetTotalSessions()
    local trackingStr = BRutus.RaidTracker.trackingActive and "|cff00ff00Tracking Active|r" or "|cff888888Idle|r"
    statusText:SetText("Sessions: " .. totalSessions .. "  |  " .. trackingStr)

    -- Sessions list
    local sessions = BRutus.RaidTracker:GetRecentSessions(20)
    local yOff = 0
    for _, s in ipairs(sessions) do
        local row = CreateFrame("Frame", nil, sessionContent, "BackdropTemplate")
        row:SetSize(sessionContent:GetWidth() - 10, 22)
        row:SetPoint("TOPLEFT", 0, -yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(C.row1.r, C.row1.g, C.row1.b, C.row1.a)

        local raidName = UI:CreateText(row, s.data.name or "Unknown", 10, C.gold.r, C.gold.g, C.gold.b)
        raidName:SetPoint("LEFT", 6, 0)

        local dateStr = date("%m/%d %H:%M", s.data.startTime or 0)
        local dateText = UI:CreateText(row, dateStr, 10, C.silver.r, C.silver.g, C.silver.b)
        dateText:SetPoint("LEFT", 200, 0)

        local playerCount = BRutus.RaidTracker:CountTable(s.data.players or {})
        local countText = UI:CreateText(row, playerCount .. " players", 10, C.white.r, C.white.g, C.white.b)
        countText:SetPoint("LEFT", 320, 0)

        local encCount = s.data.encounters and #s.data.encounters or 0
        local encText = UI:CreateText(row, encCount .. " bosses", 10, C.accent.r, C.accent.g, C.accent.b)
        encText:SetPoint("LEFT", 420, 0)

        yOff = yOff + 24
    end
    sessionContent:SetHeight(math.max(1, yOff))

    -- Attendance list
    local attData = BRutus.db.raidTracker and BRutus.db.raidTracker.attendance or {}
    local attList = {}
    for key, att in pairs(attData) do
        table.insert(attList, { key = key, data = att })
    end
    table.sort(attList, function(a, b) return a.data.raids > b.data.raids end)

    yOff = 0
    for _, entry in ipairs(attList) do
        local row = CreateFrame("Frame", nil, attContent, "BackdropTemplate")
        row:SetSize(attContent:GetWidth() - 10, 20)
        row:SetPoint("TOPLEFT", 0, -yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(C.row2.r, C.row2.g, C.row2.b, C.row2.a)

        local nameText = UI:CreateText(row, entry.key:match("^([^-]+)") or entry.key, 10, C.white.r, C.white.g, C.white.b)
        nameText:SetPoint("LEFT", 6, 0)

        local pct = BRutus.RaidTracker:GetAttendancePercent(entry.key)
        local pctColor = pct >= 75 and C.green or (pct >= 50 and C.gold or C.red)
        local pctText = UI:CreateText(row, pct .. "%", 10, pctColor.r, pctColor.g, pctColor.b)
        pctText:SetPoint("LEFT", 200, 0)

        local raidsText = UI:CreateText(row, entry.data.raids .. "/" .. totalSessions, 10, C.silver.r, C.silver.g, C.silver.b)
        raidsText:SetPoint("LEFT", 280, 0)

        yOff = yOff + 22
    end
    attContent:SetHeight(math.max(1, yOff))
end

----------------------------------------------------------------------
-- LOOT HISTORY PANEL
----------------------------------------------------------------------
function BRutus:CreateLootPanel(parent, _mainFrame)
    local scrollParent = CreateFrame("Frame", nil, parent)
    scrollParent:SetPoint("TOPLEFT", 10, -10)
    scrollParent:SetPoint("BOTTOMRIGHT", -10, 10)

    local title = UI:CreateTitle(scrollParent, "Loot History", 14)
    title:SetPoint("TOPLEFT", 0, 0)

    local countText = UI:CreateText(scrollParent, "", 10, C.silver.r, C.silver.g, C.silver.b)
    countText:SetPoint("TOPRIGHT", 0, -2)

    -- Column headers
    local colHeader = CreateFrame("Frame", nil, scrollParent)
    colHeader:SetPoint("TOPLEFT", 0, -28)
    colHeader:SetPoint("TOPRIGHT", 0, -28)
    colHeader:SetHeight(20)

    local hItem = UI:CreateHeaderText(colHeader, "ITEM", 10)
    hItem:SetPoint("LEFT", 6, 0)
    local hPlayer = UI:CreateHeaderText(colHeader, "PLAYER", 10)
    hPlayer:SetPoint("LEFT", 300, 0)
    local hRaid = UI:CreateHeaderText(colHeader, "RAID", 10)
    hRaid:SetPoint("LEFT", 450, 0)
    local hDate = UI:CreateHeaderText(colHeader, "DATE", 10)
    hDate:SetPoint("LEFT", 600, 0)

    local sep = UI:CreateSeparator(scrollParent)
    sep:SetPoint("TOPLEFT", 0, -50)
    sep:SetPoint("TOPRIGHT", 0, -50)

    local lootScroll = CreateFrame("ScrollFrame", "BRutusLootScroll", scrollParent, "UIPanelScrollFrameTemplate")
    lootScroll:SetPoint("TOPLEFT", 0, -52)
    lootScroll:SetPoint("BOTTOMRIGHT", -30, 0)

    local lootContent = CreateFrame("Frame", nil, lootScroll)
    lootContent:SetSize(800, 1)
    lootScroll:SetScrollChild(lootContent)

    parent:SetScript("OnShow", function()
        BRutus:RefreshLootPanel(lootContent, countText)
    end)
end

function BRutus:RefreshLootPanel(content, countText)
    if not BRutus.LootTracker then return end

    for _, child in pairs({ content:GetChildren() }) do child:Hide() end

    local history = BRutus.LootTracker:GetHistory(100)
    countText:SetText(#BRutus.db.lootHistory .. " items tracked")

    local yOff = 0
    for _, entry in ipairs(history) do
        local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
        row:SetSize(content:GetWidth() - 10, 22)
        row:SetPoint("TOPLEFT", 0, -yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

        local altIdx = (math.floor(yOff / 22) % 2 == 0) and C.row1 or C.row2
        row:SetBackdropColor(altIdx.r, altIdx.g, altIdx.b, altIdx.a)

        -- Item name with quality color
        local qColor = BRutus.QualityColors[entry.quality] or BRutus.QualityColors[1]
        local itemText = UI:CreateText(row, entry.itemName or "?", 10, qColor.r, qColor.g, qColor.b)
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetWidth(280)

        -- Hover tooltip for item
        if entry.itemLink then
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(entry.itemLink)
                GameTooltip:Show()
                self:SetBackdropColor(C.rowHover.r, C.rowHover.g, C.rowHover.b, C.rowHover.a)
            end)
            row:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
                self:SetBackdropColor(altIdx.r, altIdx.g, altIdx.b, altIdx.a)
            end)
        end

        -- Player
        local memberData = BRutus.db.members[entry.playerKey]
        local pClass = memberData and memberData.class
        local pr, pg, pb = 1, 1, 1
        if pClass then
            pr, pg, pb = BRutus:GetClassColor(pClass)
        end
        local playerText = UI:CreateText(row, entry.player or "?", 10, pr, pg, pb)
        playerText:SetPoint("LEFT", 300, 0)

        -- Raid
        local raidText = UI:CreateText(row, entry.raid or "", 10, C.silver.r, C.silver.g, C.silver.b)
        raidText:SetPoint("LEFT", 450, 0)

        -- Date
        local dateStr = date("%m/%d %H:%M", entry.timestamp or 0)
        local dateText = UI:CreateText(row, dateStr, 10, C.silver.r, C.silver.g, C.silver.b)
        dateText:SetPoint("LEFT", 600, 0)

        yOff = yOff + 22
    end
    content:SetHeight(math.max(1, yOff))
end

----------------------------------------------------------------------
-- TRIAL TRACKER PANEL
----------------------------------------------------------------------
function BRutus:CreateTrialsPanel(parent, _mainFrame)
    local scrollParent = CreateFrame("Frame", nil, parent)
    scrollParent:SetPoint("TOPLEFT", 10, -10)
    scrollParent:SetPoint("BOTTOMRIGHT", -10, 10)

    local title = UI:CreateTitle(scrollParent, "Trial Members", 14)
    title:SetPoint("TOPLEFT", 0, 0)

    local statusText = UI:CreateText(scrollParent, "", 10, C.silver.r, C.silver.g, C.silver.b)
    statusText:SetPoint("TOPRIGHT", 0, -2)

    -- Column headers
    local colHeader = CreateFrame("Frame", nil, scrollParent)
    colHeader:SetPoint("TOPLEFT", 0, -28)
    colHeader:SetPoint("TOPRIGHT", 0, -28)
    colHeader:SetHeight(20)

    local hName = UI:CreateHeaderText(colHeader, "MEMBER", 10)
    hName:SetPoint("LEFT", 6, 0)
    local hSponsor = UI:CreateHeaderText(colHeader, "SPONSOR", 10)
    hSponsor:SetPoint("LEFT", 180, 0)
    local hStart = UI:CreateHeaderText(colHeader, "START", 10)
    hStart:SetPoint("LEFT", 300, 0)
    local hDays = UI:CreateHeaderText(colHeader, "REMAINING", 10)
    hDays:SetPoint("LEFT", 420, 0)
    local hStatus = UI:CreateHeaderText(colHeader, "STATUS", 10)
    hStatus:SetPoint("LEFT", 530, 0)

    local sep = UI:CreateSeparator(scrollParent)
    sep:SetPoint("TOPLEFT", 0, -50)
    sep:SetPoint("TOPRIGHT", 0, -50)

    local trialScroll = CreateFrame("ScrollFrame", "BRutusTrialScroll", scrollParent, "UIPanelScrollFrameTemplate")
    trialScroll:SetPoint("TOPLEFT", 0, -52)
    trialScroll:SetPoint("BOTTOMRIGHT", -30, 0)

    local trialContent = CreateFrame("Frame", nil, trialScroll)
    trialContent:SetSize(800, 1)
    trialScroll:SetScrollChild(trialContent)

    parent.trialContent = trialContent
    parent.statusText = statusText

    parent:SetScript("OnShow", function()
        BRutus:RefreshTrialsPanel(parent)
    end)
end

function BRutus:RefreshTrialsPanel(parent)
    local content = parent.trialContent
    local statusText = parent.statusText
    if not content or not BRutus.TrialTracker then return end

    for _, child in pairs({ content:GetChildren() }) do child:Hide() end

    local trials = BRutus.TrialTracker:GetAllTrials()
    local activeCount = 0
    for _, t in ipairs(trials) do
        if t.data.status == BRutus.TrialTracker.STATUS.TRIAL then
            activeCount = activeCount + 1
        end
    end
    statusText:SetText(activeCount .. " active trials")

    local yOff = 0
    for _, trial in ipairs(trials) do
        local data = trial.data
        local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
        row:SetSize(content:GetWidth() - 10, 26)
        row:SetPoint("TOPLEFT", 0, -yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

        local altIdx = (math.floor(yOff / 26) % 2 == 0) and C.row1 or C.row2
        row:SetBackdropColor(altIdx.r, altIdx.g, altIdx.b, altIdx.a)

        -- Name with class color
        local shortName = trial.key:match("^([^-]+)") or trial.key
        local memberData = BRutus.db.members[trial.key]
        local pClass = memberData and memberData.class
        local pr, pg, pb = 1, 1, 1
        if pClass then pr, pg, pb = BRutus:GetClassColor(pClass) end

        local nameText = UI:CreateText(row, shortName, 10, pr, pg, pb)
        nameText:SetPoint("LEFT", 6, 0)

        local sponsorText = UI:CreateText(row, data.sponsor or "?", 10, C.silver.r, C.silver.g, C.silver.b)
        sponsorText:SetPoint("LEFT", 180, 0)

        local startStr = date("%m/%d/%y", data.startDate or 0)
        local startText = UI:CreateText(row, startStr, 10, C.silver.r, C.silver.g, C.silver.b)
        startText:SetPoint("LEFT", 300, 0)

        local daysRem = BRutus.TrialTracker:GetDaysRemaining(trial.key)
        local daysStr = daysRem and (daysRem .. " days") or "-"
        local daysColor = C.white
        if daysRem then
            daysColor = daysRem > 14 and C.green or (daysRem > 7 and C.gold or C.red)
        end
        local daysText = UI:CreateText(row, daysStr, 10, daysColor.r, daysColor.g, daysColor.b)
        daysText:SetPoint("LEFT", 420, 0)

        -- Status badge
        local statusColor = C.silver
        local statusStr = data.status or "?"
        if data.status == "trial" then
            statusColor = C.gold
            statusStr = "TRIAL"
        elseif data.status == "approved" then
            statusColor = C.green
            statusStr = "APPROVED"
        elseif data.status == "denied" then
            statusColor = C.red
            statusStr = "DENIED"
        elseif data.status == "expired" then
            statusColor = C.red
            statusStr = "EXPIRED"
        end
        local sText = UI:CreateText(row, statusStr, 10, statusColor.r, statusColor.g, statusColor.b)
        sText:SetPoint("LEFT", 530, 0)

        -- Action buttons for active trials
        if data.status == "trial" then
            local approveBtn = UI:CreateButton(row, "OK", 30, 18)
            approveBtn:SetPoint("LEFT", 620, 0)
            approveBtn:SetScript("OnClick", function()
                BRutus.TrialTracker:UpdateStatus(trial.key, BRutus.TrialTracker.STATUS.APPROVED)
                BRutus:RefreshTrialsPanel(parent)
            end)

            local denyBtn = UI:CreateButton(row, "X", 24, 18)
            denyBtn:SetPoint("LEFT", approveBtn, "RIGHT", 4, 0)
            denyBtn:SetScript("OnClick", function()
                BRutus.TrialTracker:UpdateStatus(trial.key, BRutus.TrialTracker.STATUS.DENIED)
                BRutus:RefreshTrialsPanel(parent)
            end)
        end

        yOff = yOff + 28
    end

    if #trials == 0 then
        local emptyText = UI:CreateText(content, "No trial members tracked.", 11, C.silver.r, C.silver.g, C.silver.b)
        emptyText:SetPoint("TOPLEFT", 0, 0)
        yOff = 30
    end

    content:SetHeight(math.max(1, yOff))
end
