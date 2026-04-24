----------------------------------------------------------------------
-- BRutus Guild Manager - Feature Panels UI
-- UI panels for: Raids, Loot, Trials
----------------------------------------------------------------------
local UI = BRutus.UI
local C = BRutus.Colors

-- Session filter state: true = 25-man only, false = all raids
local _raidFilter25 = true

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
    statusText:SetPoint("TOPLEFT", 200, -4)

    -- Export to TMB button (25-man data)
    local exportBtn = UI:CreateButton(scrollParent, "Export for TMB", 140, 22)
    exportBtn:SetPoint("TOPRIGHT", 0, 0)
    exportBtn:SetScript("OnClick", function()
        if not BRutus.RaidTracker then return end
        local json, err = BRutus.RaidTracker:ExportForTMB()
        if not json then
            BRutus:Print("|cffFF4444Export failed:|r " .. (err or "unknown error"))
            return
        end
        BRutus:ShowExportPopup("TMB Attendance Export (25-man)", json)
    end)

    ----------------------------------------------------------------
    -- Sessions section (top ~40%)
    ----------------------------------------------------------------
    local sessionsLabel = UI:CreateHeaderText(scrollParent, "Sessions", 11)
    sessionsLabel:SetPoint("TOPLEFT", 0, -28)

    -- Filter toggle buttons
    local filterAllBtn  = UI:CreateButton(scrollParent, "Todas", 58, 18)
    local filter25Btn   = UI:CreateButton(scrollParent, "25-man", 62, 18)
    filterAllBtn:SetPoint("LEFT", sessionsLabel, "RIGHT", 10, 0)
    filter25Btn:SetPoint("LEFT", filterAllBtn,   "RIGHT",  4, 0)

    local sessionScroll = CreateFrame("ScrollFrame", "BRutusRaidSessionScroll", scrollParent, "UIPanelScrollFrameTemplate")
    sessionScroll:SetPoint("TOPLEFT",     0,   -50)
    sessionScroll:SetPoint("BOTTOMRIGHT", -10, 250)
    UI:SkinScrollBar(sessionScroll, "BRutusRaidSessionScroll")

    local sessionContent = CreateFrame("Frame", nil, sessionScroll)
    sessionContent:SetSize(800, 1)
    sessionScroll:SetScrollChild(sessionContent)

    ----------------------------------------------------------------
    -- Attendance section (bottom ~50%)
    ----------------------------------------------------------------
    local attLabel = UI:CreateHeaderText(scrollParent, "Member Attendance — 25-man only", 11)
    attLabel:SetPoint("BOTTOMLEFT", 0, 236)

    local attScroll = CreateFrame("ScrollFrame", "BRutusAttendanceScroll", scrollParent, "UIPanelScrollFrameTemplate")
    attScroll:SetPoint("BOTTOMLEFT",  0,   10)
    attScroll:SetPoint("BOTTOMRIGHT", -10, 10)
    attScroll:SetHeight(220)
    UI:SkinScrollBar(attScroll, "BRutusAttendanceScroll")

    local attContent = CreateFrame("Frame", nil, attScroll)
    attContent:SetSize(800, 1)
    attScroll:SetScrollChild(attContent)

    ----------------------------------------------------------------
    -- Filter button wiring
    ----------------------------------------------------------------
    local function SetFilterActive(only25)
        _raidFilter25 = only25
        if only25 then
            filter25Btn:LockHighlight()
            filterAllBtn:UnlockHighlight()
        else
            filterAllBtn:LockHighlight()
            filter25Btn:UnlockHighlight()
        end
        BRutus:RefreshRaidsPanel(sessionContent, attContent, statusText)
    end

    filterAllBtn:SetScript("OnClick", function() SetFilterActive(false) end)
    filter25Btn:SetScript("OnClick",  function() SetFilterActive(true)  end)

    parent:SetScript("OnShow", function()
        SetFilterActive(_raidFilter25)
    end)
end

-- Session expand state (persists while panel is shown)
local _sessionExpanded = {}

function BRutus:RefreshRaidsPanel(sessionContent, attContent, statusText)
    if not BRutus.RaidTracker then return end

    -- Clear existing children
    for _, child in pairs({ sessionContent:GetChildren() }) do child:Hide() end
    for _, child in pairs({ attContent:GetChildren()     }) do child:Hide() end

    local totalAll  = BRutus.RaidTracker:GetTotalSessions()
    local total25   = BRutus.RaidTracker:GetTotal25ManSessions()
    local trackStr  = BRutus.RaidTracker.trackingActive
                      and "|cff00ff00Tracking|r" or "|cff888888Idle|r"
    statusText:SetText(totalAll .. " sessions (" .. total25 .. " 25-man)  |  " .. trackStr)

    ----------------------------------------------------------------
    -- Sessions list (filtered, most recent 20)
    ----------------------------------------------------------------
    local sessions = BRutus.RaidTracker:GetRecentSessions(50, _raidFilter25)
    local yOff = 0

    for idx, s in ipairs(sessions) do
        local sd      = s.data
        local is25    = BRutus.RaidTracker:Is25Man(sd.instanceID)
        local isExp   = _sessionExpanded[s.id]
        local rowH    = 22

        -- Main session row
        local row = CreateFrame("Button", nil, sessionContent, "BackdropTemplate")
        row:SetSize(sessionContent:GetWidth() - 10, rowH)
        row:SetPoint("TOPLEFT", 0, -yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        local bg = (idx % 2 == 1) and C.row1 or C.row2
        row:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

        -- Expand arrow
        local arrow = UI:CreateText(row, isExp and "▼" or "▶", 9, C.accent.r, C.accent.g, C.accent.b)
        arrow:SetPoint("LEFT", 4, 0)

        -- Raid name
        local nameClr = is25 and C.gold or C.silver
        local nameText = UI:CreateText(row, sd.name or "Unknown", 10, nameClr.r, nameClr.g, nameClr.b)
        nameText:SetPoint("LEFT", 18, 0)

        -- 25-man badge
        if is25 then
            local badge = UI:CreateText(row, "[25]", 9, C.accent.r, C.accent.g, C.accent.b)
            badge:SetPoint("LEFT", 165, 0)
        end

        -- PUG badge
        if sd.isGuildRaid == false then
            local pugBadge = UI:CreateText(row, "[PUG]", 9, 0.6, 0.6, 0.6)
            pugBadge:SetPoint("LEFT", is25 and 195 or 165, 0)
        end

        -- Date
        local dateStr  = date("%m/%d %H:%M", sd.startTime or 0)
        local dateText = UI:CreateText(row, dateStr, 10, C.silver.r, C.silver.g, C.silver.b)
        dateText:SetPoint("LEFT", 210, 0)

        -- Duration
        local dur = sd.duration or (sd.endTime and sd.startTime and (sd.endTime - sd.startTime))
        if dur then
            local durStr = format("%dh%02dm", floor(dur/3600), floor((dur%3600)/60))
            local durText = UI:CreateText(row, durStr, 9, C.silver.r, C.silver.g, C.silver.b)
            durText:SetPoint("LEFT", 310, 0)
        end

        -- Player count
        local pCount    = BRutus.RaidTracker:CountTable(sd.players or {})
        local countText = UI:CreateText(row, pCount .. " players", 10, C.white.r, C.white.g, C.white.b)
        countText:SetPoint("LEFT", 370, 0)

        -- Boss count with kills/wipes breakdown
        local kills, wipes = 0, 0
        if sd.encounters then
            for _, enc in ipairs(sd.encounters) do
                if enc.success then kills = kills + 1
                else wipes = wipes + 1 end
            end
        end
        local encStr = kills .. " kills"
        if wipes > 0 then encStr = encStr .. " / " .. wipes .. " wipes" end
        local encClr = kills > 0 and C.green or C.silver
        local encText  = UI:CreateText(row, encStr, 10, encClr.r, encClr.g, encClr.b)
        encText:SetPoint("LEFT", 470, 0)

        -- Delete button (officer only)
        if BRutus:IsOfficer() then
            local delBtn = UI:CreateButton(row, "X", 20, 16)
            delBtn:SetPoint("RIGHT", -4, 0)
            delBtn:SetScript("OnClick", function()
                BRutus.RaidTracker:DeleteSession(s.id)
                _sessionExpanded[s.id] = nil
                BRutus:RefreshRaidsPanel(sessionContent, attContent, statusText)
            end)
        end

        -- Toggle expand on click
        local capturedID = s.id
        row:SetScript("OnClick", function()
            _sessionExpanded[capturedID] = not _sessionExpanded[capturedID]
            BRutus:RefreshRaidsPanel(sessionContent, attContent, statusText)
        end)
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C.rowHover.r, C.rowHover.g, C.rowHover.b, C.rowHover.a)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
        end)

        yOff = yOff + rowH + 2

        -- Expanded: per-player breakdown
        if isExp then
            local snapshots = sd.snapshots or {}
            local firstSnap = snapshots[1]
            local lastSnap  = snapshots[#snapshots]

            -- Build player list with penalty info
            local playerList = {}
            for key in pairs(sd.players or {}) do
                local shortName = key:match("^([^-]+)") or key
                local memberData = BRutus.db.members and BRutus.db.members[key]
                local class = memberData and memberData.class or nil

                local wasLate = firstSnap and firstSnap.members and not firstSnap.members[key]
                local leftEarly = lastSnap and lastSnap.members and not lastSnap.members[key]

                -- Consumable check across snapshots
                local consumeChecks, consumeHits = 0, 0
                for _, snap in ipairs(snapshots) do
                    if snap.members and snap.members[key] then
                        consumeChecks = consumeChecks + 1
                        if snap.members[key].hasConsumes then
                            consumeHits = consumeHits + 1
                        end
                    end
                end
                local noConsumes = consumeChecks > 0 and (consumeHits / consumeChecks) < 0.5

                -- Score
                local score = 100
                if wasLate    then score = score - (BRutus.RaidTracker.PENALTIES.LATE or 10) end
                if leftEarly  then score = score - (BRutus.RaidTracker.PENALTIES.LEFT_EARLY or 10) end
                if noConsumes then score = score - (BRutus.RaidTracker.PENALTIES.NO_CONSUMES or 10) end
                score = math.max(0, math.min(100, score))

                table.insert(playerList, {
                    key = key, name = shortName, class = class,
                    score = score, wasLate = wasLate, leftEarly = leftEarly,
                    noConsumes = noConsumes, consumeHits = consumeHits, consumeChecks = consumeChecks,
                })
            end

            table.sort(playerList, function(a, b)
                if a.score ~= b.score then return a.score > b.score end
                local ca = a.class or "ZZZZ"; local cb2 = b.class or "ZZZZ"
                if ca ~= cb2 then return ca < cb2 end
                return a.name < b.name
            end)

            -- Column headers for expanded section
            local hdrFrame = CreateFrame("Frame", nil, sessionContent, "BackdropTemplate")
            hdrFrame:SetSize(sessionContent:GetWidth() - 30, 16)
            hdrFrame:SetPoint("TOPLEFT", 20, -yOff)
            hdrFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            hdrFrame:SetBackdropColor(0.04, 0.04, 0.08, 1)

            local function Hdr(txt, x)
                local t = UI:CreateText(hdrFrame, txt, 8, C.accent.r, C.accent.g, C.accent.b)
                t:SetPoint("LEFT", x, 0)
            end
            Hdr("PLAYER", 6); Hdr("SCORE", 120); Hdr("LATE", 170); Hdr("LEFT EARLY", 210); Hdr("NO CONS", 290)
            yOff = yOff + 18

            for pIdx, p in ipairs(playerList) do
                local pRow = CreateFrame("Frame", nil, sessionContent, "BackdropTemplate")
                pRow:SetSize(sessionContent:GetWidth() - 30, 18)
                pRow:SetPoint("TOPLEFT", 20, -yOff)
                pRow:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                local pbg = (pIdx % 2 == 1) and { r=0.05, g=0.04, b=0.09 } or { r=0.07, g=0.06, b=0.12 }
                pRow:SetBackdropColor(pbg.r, pbg.g, pbg.b, 0.9)

                -- Class-colored name
                local cr, cg, cb = BRutus:GetClassColor(p.class)
                local nameT = UI:CreateText(pRow, p.name, 9, cr, cg, cb)
                nameT:SetPoint("LEFT", 6, 0)
                nameT:SetWidth(110)

                -- Score (colored)
                local sr, sg, sb = C.green.r, C.green.g, C.green.b
                if p.score < 75 then sr, sg, sb = C.gold.r, C.gold.g, C.gold.b end
                if p.score < 50 then sr, sg, sb = C.red.r,  C.red.g,  C.red.b  end
                local scoreT = UI:CreateText(pRow, p.score .. "%", 9, sr, sg, sb)
                scoreT:SetPoint("LEFT", 120, 0)

                -- Penalty flags
                local function Flag(x, val, redTxt, greenTxt)
                    local r2, g2, b2 = val and C.red.r or C.green.r, val and C.red.g or C.green.g, val and C.red.b or C.green.b
                    local t = UI:CreateText(pRow, val and redTxt or greenTxt, 8, r2, g2, b2)
                    t:SetPoint("LEFT", x, 0)
                end
                Flag(170, p.wasLate,    "LATE",    "OK")
                Flag(210, p.leftEarly,  "LEFT",    "OK")

                -- Consumables: show ratio
                local consStr = p.consumeChecks > 0
                    and format("%d/%d", p.consumeHits, p.consumeChecks)
                    or "-"
                local cr2, cg2, cb2 = (not p.noConsumes) and C.green.r or C.red.r,
                                       (not p.noConsumes) and C.green.g or C.red.g,
                                       (not p.noConsumes) and C.green.b or C.red.b
                local consT = UI:CreateText(pRow, consStr, 8, cr2, cg2, cb2)
                consT:SetPoint("LEFT", 290, 0)

                yOff = yOff + 20
            end
            yOff = yOff + 6
        end
    end
    sessionContent:SetHeight(math.max(1, yOff))

    ----------------------------------------------------------------
    -- Attendance list — always 25-man stats regardless of filter
    ----------------------------------------------------------------
    local attData = BRutus.db.raidTracker and BRutus.db.raidTracker.attendance or {}
    local attList = {}
    for key, att in pairs(attData) do
        if (att.raids25 or 0) > 0 then
            table.insert(attList, { key = key, data = att })
        end
    end
    table.sort(attList, function(a, b)
        local pa = BRutus.RaidTracker:GetAttendance25ManPercent(a.key)
        local pb = BRutus.RaidTracker:GetAttendance25ManPercent(b.key)
        if pa == pb then
            return (a.data.raids25 or 0) > (b.data.raids25 or 0)
        end
        return pa > pb
    end)

    -- Column headers
    local attHdr = CreateFrame("Frame", nil, attContent, "BackdropTemplate")
    attHdr:SetSize(attContent:GetWidth() - 10, 16)
    attHdr:SetPoint("TOPLEFT", 0, 0)
    attHdr:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    attHdr:SetBackdropColor(0.04, 0.04, 0.08, 1)
    local function AHdr(txt, x)
        local t = UI:CreateText(attHdr, txt, 8, C.accent.r, C.accent.g, C.accent.b)
        t:SetPoint("LEFT", x, 0)
    end
    AHdr("PLAYER", 6); AHdr("ATT%", 160); AHdr("RAIDS", 220); AHdr("AVG SCORE", 280); AHdr("LAST RAID", 380)

    yOff = 20
    for idx, entry in ipairs(attList) do
        local row = CreateFrame("Frame", nil, attContent, "BackdropTemplate")
        row:SetSize(attContent:GetWidth() - 10, 20)
        row:SetPoint("TOPLEFT", 0, -yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        local bg = (idx % 2 == 1) and C.row1 or C.row2
        row:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

        local shortName = entry.key:match("^([^-]+)") or entry.key
        local memberData = BRutus.db.members and BRutus.db.members[entry.key]
        local class = memberData and memberData.class
        local cr, cg, cb = BRutus:GetClassColor(class)
        local nameText = UI:CreateText(row, shortName, 10, cr, cg, cb)
        nameText:SetPoint("LEFT", 6, 0)

        local pct      = BRutus.RaidTracker:GetAttendance25ManPercent(entry.key)
        local pctClr   = pct >= 75 and C.green or (pct >= 50 and C.gold or C.red)
        local pctText  = UI:CreateText(row, pct .. "%", 10, pctClr.r, pctClr.g, pctClr.b)
        pctText:SetPoint("LEFT", 160, 0)

        local raids25  = entry.data.raids25 or 0
        local fracText = UI:CreateText(row, raids25 .. "/" .. total25, 10, C.silver.r, C.silver.g, C.silver.b)
        fracText:SetPoint("LEFT", 220, 0)

        -- Average score per attended raid
        local avgScore = 0
        if raids25 > 0 and entry.data.totalScore25 then
            avgScore = math.floor(entry.data.totalScore25 / raids25 + 0.5)
        end
        local asr, asg, asb = C.green.r, C.green.g, C.green.b
        if avgScore < 80 then asr, asg, asb = C.gold.r, C.gold.g, C.gold.b end
        if avgScore < 60 then asr, asg, asb = C.red.r,  C.red.g,  C.red.b  end
        local avgScoreText = UI:CreateText(row, avgScore .. " pts", 9, asr, asg, asb)
        avgScoreText:SetPoint("LEFT", 280, 0)

        -- Last raid date
        local lastStr = entry.data.lastRaid and entry.data.lastRaid > 0
            and date("%m/%d/%Y", entry.data.lastRaid) or "-"
        local lastText = UI:CreateText(row, lastStr, 9, C.silver.r, C.silver.g, C.silver.b)
        lastText:SetPoint("LEFT", 380, 0)

        -- Hover: tooltip with penalty breakdown
        local capturedEntry = entry
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C.rowHover.r, C.rowHover.g, C.rowHover.b, C.rowHover.a)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(shortName, cr, cg, cb)
            GameTooltip:AddLine("25-man Attendance", C.gold.r, C.gold.g, C.gold.b)
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Raids attended:", raids25 .. "/" .. total25, 1,1,1, C.silver.r,C.silver.g,C.silver.b)
            GameTooltip:AddDoubleLine("Attendance %:", pct .. "%", 1,1,1, pctClr.r,pctClr.g,pctClr.b)
            if avgScore > 0 then
                GameTooltip:AddDoubleLine("Avg score/raid:", avgScore .. " pts", 1,1,1, asr,asg,asb)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Score starts at 100 per raid.", 0.6,0.6,0.6)
            GameTooltip:AddLine("-" .. (BRutus.RaidTracker.PENALTIES.LATE or 10) .. " Late arrival", 0.7,0.5,0.5)
            GameTooltip:AddLine("-" .. (BRutus.RaidTracker.PENALTIES.LEFT_EARLY or 10) .. " Left early", 0.7,0.5,0.5)
            GameTooltip:AddLine("-" .. (BRutus.RaidTracker.PENALTIES.NO_CONSUMES or 10) .. " No consumables", 0.7,0.5,0.5)
            GameTooltip:AddLine("Absent sessions count as 0.", 0.6,0.6,0.6)
            GameTooltip:Show()
            local _ = capturedEntry
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
            GameTooltip:Hide()
        end)

        yOff = yOff + 22
    end

    if #attList == 0 then
        local emptyText = UI:CreateText(attContent, "No 25-man attendance data yet.", 10, C.silver.r, C.silver.g, C.silver.b)
        emptyText:SetPoint("TOPLEFT", 6, -yOff)
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
    lootScroll:SetPoint("BOTTOMRIGHT", -10, 0)
    UI:SkinScrollBar(lootScroll, "BRutusLootScroll")

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

        -- Item name with quality color (resolved from itemLink for locale)
        local qColor = BRutus.QualityColors[entry.quality] or BRutus.QualityColors[1]
        local displayName = entry.itemName or "?"
        if entry.itemLink then
            local localName = entry.itemLink:match("%[(.-)%]")
            if localName and localName ~= "" then
                displayName = localName
            end
        end
        local itemText = UI:CreateText(row, displayName, 10, qColor.r, qColor.g, qColor.b)
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
    local hIlvl = UI:CreateHeaderText(colHeader, "iLVL", 10)
    hIlvl:SetPoint("LEFT", 140, 0)
    local hAtt = UI:CreateHeaderText(colHeader, "ATTUNE", 10)
    hAtt:SetPoint("LEFT", 210, 0)
    local hSponsor = UI:CreateHeaderText(colHeader, "SPONSOR", 10)
    hSponsor:SetPoint("LEFT", 290, 0)
    local hDays = UI:CreateHeaderText(colHeader, "REMAINING", 10)
    hDays:SetPoint("LEFT", 400, 0)
    local hStatus = UI:CreateHeaderText(colHeader, "STATUS", 10)
    hStatus:SetPoint("LEFT", 500, 0)

    local sep = UI:CreateSeparator(scrollParent)
    sep:SetPoint("TOPLEFT", 0, -50)
    sep:SetPoint("TOPRIGHT", 0, -50)

    local trialScroll = CreateFrame("ScrollFrame", "BRutusTrialScroll", scrollParent, "UIPanelScrollFrameTemplate")
    trialScroll:SetPoint("TOPLEFT", 0, -52)
    trialScroll:SetPoint("BOTTOMRIGHT", -10, 0)
    UI:SkinScrollBar(trialScroll, "BRutusTrialScroll")

    local trialContent = CreateFrame("Frame", nil, trialScroll)
    trialContent:SetSize(800, 1)
    trialScroll:SetScrollChild(trialContent)

    parent.trialContent = trialContent
    parent.statusText = statusText
    parent.expandedTrials = {}

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

    local expanded = parent.expandedTrials or {}
    local yOff = 0

    for _, trial in ipairs(trials) do
        local data = trial.data
        local isExpanded = expanded[trial.key]
        local memberData = BRutus.db.members[trial.key]
        local progress = BRutus.TrialTracker:GetProgress(trial.key)

        -- Main row
        local row = CreateFrame("Button", nil, content, "BackdropTemplate")
        row:SetSize(content:GetWidth() - 10, 26)
        row:SetPoint("TOPLEFT", 0, -yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

        local rowIdx = math.floor(yOff / 26) % 2
        local altIdx = (rowIdx == 0) and C.row1 or C.row2
        row:SetBackdropColor(altIdx.r, altIdx.g, altIdx.b, altIdx.a)

        -- Expand arrow
        local arrow = UI:CreateText(row, isExpanded and "v" or ">", 10, C.accent.r, C.accent.g, C.accent.b)
        arrow:SetPoint("LEFT", 2, 0)

        -- Name with class color
        local shortName = trial.key:match("^([^-]+)") or trial.key
        local pClass = memberData and memberData.class
        local pr, pg, pb = 1, 1, 1
        if pClass then pr, pg, pb = BRutus:GetClassColor(pClass) end

        local nameText = UI:CreateText(row, shortName, 10, pr, pg, pb)
        nameText:SetPoint("LEFT", 14, 0)

        -- iLvl with delta
        if progress then
            local ilvlSign = progress.ilvlDelta > 0 and "+" or ""
            local ilvlColor = progress.ilvlDelta > 0 and C.green or (progress.ilvlDelta < 0 and C.red or C.silver)
            local ilvlStr = format("%d (%s%d)", progress.currentIlvl, ilvlSign, progress.ilvlDelta)
            local ilvlText = UI:CreateText(row, ilvlStr, 9, ilvlColor.r, ilvlColor.g, ilvlColor.b)
            ilvlText:SetPoint("LEFT", 140, 0)

            -- Attunement progress
            local attColor = progress.attDelta > 0 and C.green or C.silver
            local attStr = format("%d/%d (+%d)", progress.currentAttDone, progress.attTotal, progress.attDelta)
            local attText = UI:CreateText(row, attStr, 9, attColor.r, attColor.g, attColor.b)
            attText:SetPoint("LEFT", 210, 0)
        else
            local ilvlVal = memberData and memberData.avgIlvl or 0
            if ilvlVal > 0 then
                local ilvlText = UI:CreateText(row, tostring(ilvlVal), 9, C.silver.r, C.silver.g, C.silver.b)
                ilvlText:SetPoint("LEFT", 140, 0)
            end
            local noProgText = UI:CreateText(row, "-", 9, C.silver.r, C.silver.g, C.silver.b)
            noProgText:SetPoint("LEFT", 210, 0)
        end

        local sponsorText = UI:CreateText(row, data.sponsor or "?", 10, C.silver.r, C.silver.g, C.silver.b)
        sponsorText:SetPoint("LEFT", 290, 0)

        local daysRem = BRutus.TrialTracker:GetDaysRemaining(trial.key)
        local daysStr = daysRem and (daysRem .. "d") or "-"
        local daysColor = C.white
        if daysRem then
            daysColor = daysRem > 14 and C.green or (daysRem > 7 and C.gold or C.red)
        end
        local daysText = UI:CreateText(row, daysStr, 10, daysColor.r, daysColor.g, daysColor.b)
        daysText:SetPoint("LEFT", 400, 0)

        -- Status badge
        local statusColor = C.silver
        local statusStr = data.status or "?"
        if data.status == "trial" then
            statusColor = C.gold; statusStr = "TRIAL"
        elseif data.status == "approved" then
            statusColor = C.green; statusStr = "APPROVED"
        elseif data.status == "denied" then
            statusColor = C.red; statusStr = "DENIED"
        elseif data.status == "expired" then
            statusColor = C.red; statusStr = "EXPIRED"
        end
        local sText = UI:CreateText(row, statusStr, 10, statusColor.r, statusColor.g, statusColor.b)
        sText:SetPoint("LEFT", 500, 0)

        -- Action buttons for active trials
        if data.status == "trial" then
            local approveBtn = UI:CreateButton(row, "OK", 30, 18)
            approveBtn:SetPoint("LEFT", 580, 0)
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

        -- Click to expand/collapse
        row:SetScript("OnClick", function()
            expanded[trial.key] = not expanded[trial.key]
            parent.expandedTrials = expanded
            BRutus:RefreshTrialsPanel(parent)
        end)

        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C.rowHover.r, C.rowHover.g, C.rowHover.b, C.rowHover.a)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(altIdx.r, altIdx.g, altIdx.b, altIdx.a)
        end)

        yOff = yOff + 28

        -- Expanded detail section
        if isExpanded then
            local detailFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
            detailFrame:SetPoint("TOPLEFT", 10, -yOff)
            detailFrame:SetPoint("TOPRIGHT", -10, -yOff)
            detailFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            detailFrame:SetBackdropColor(0.06, 0.06, 0.10, 0.8)

            local dY = -6

            -- Start date
            local startStr = date("%m/%d/%y", data.startDate or 0)
            local daysSince = BRutus.TrialTracker:GetDaysSinceStart(trial.key)
            local infoFS = detailFrame:CreateFontString(nil, "OVERLAY")
            infoFS:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            infoFS:SetPoint("TOPLEFT", 10, dY)
            infoFS:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
            infoFS:SetText(format("Started: %s  |  Day %d  |  Sponsor: %s", startStr, daysSince or 0, data.sponsor or "?"))
            infoFS:Show()
            dY = dY - 16

            -- Officer comments
            if data.notes and #data.notes > 0 then
                local notesLabel = detailFrame:CreateFontString(nil, "OVERLAY")
                notesLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
                notesLabel:SetPoint("TOPLEFT", 10, dY)
                notesLabel:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
                notesLabel:SetText("Comments:")
                notesLabel:Show()
                dY = dY - 14

                for _, note in ipairs(data.notes) do
                    local noteFS = detailFrame:CreateFontString(nil, "OVERLAY")
                    noteFS:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
                    noteFS:SetPoint("TOPLEFT", 14, dY)
                    noteFS:SetWidth(content:GetWidth() - 60)
                    noteFS:SetJustifyH("LEFT")
                    noteFS:SetWordWrap(true)
                    local dateStr = note.timestamp and date("%m/%d %H:%M", note.timestamp) or ""
                    noteFS:SetText(format("|cffAAAAAA[%s %s]|r %s", note.author or "?", dateStr, note.text or ""))
                    noteFS:Show()
                    dY = dY - (noteFS:GetStringHeight() + 3)
                end
            end

            -- Inline add note
            local addBox = CreateFrame("EditBox", nil, detailFrame, "BackdropTemplate")
            addBox:SetSize(content:GetWidth() - 120, 20)
            addBox:SetPoint("TOPLEFT", 10, dY - 4)
            addBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            addBox:SetBackdropColor(0.04, 0.04, 0.07, 1)
            addBox:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.3)
            addBox:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            addBox:SetTextColor(C.white.r, C.white.g, C.white.b)
            addBox:SetTextInsets(4, 4, 2, 2)
            addBox:SetAutoFocus(false)
            addBox:SetMaxLetters(200)
            addBox:Show()

            local ph = addBox:CreateFontString(nil, "OVERLAY")
            ph:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
            ph:SetPoint("LEFT", 4, 0)
            ph:SetTextColor(0.3, 0.3, 0.3)
            ph:SetText("Add comment...")
            addBox:SetScript("OnTextChanged", function(self)
                if self:GetText() ~= "" then ph:Hide() else ph:Show() end
            end)
            addBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

            local addBtn = UI:CreateButton(detailFrame, "Add", 50, 20)
            addBtn:SetPoint("LEFT", addBox, "RIGHT", 4, 0)
            addBtn:SetScript("OnClick", function()
                local text = addBox:GetText()
                if text and strtrim(text) ~= "" then
                    BRutus.TrialTracker:AddTrialNote(trial.key, strtrim(text))
                    addBox:SetText("")
                    addBox:ClearFocus()
                    BRutus:RefreshTrialsPanel(parent)
                end
            end)
            addBox:SetScript("OnEnterPressed", function(self)
                local text = self:GetText()
                if text and strtrim(text) ~= "" then
                    BRutus.TrialTracker:AddTrialNote(trial.key, strtrim(text))
                    self:SetText("")
                    self:ClearFocus()
                    BRutus:RefreshTrialsPanel(parent)
                end
            end)

            dY = dY - 30
            detailFrame:SetHeight(math.abs(dY) + 6)
            yOff = yOff + math.abs(dY) + 8
        end
    end

    if #trials == 0 then
        local emptyText = UI:CreateText(content, "No trial members tracked.", 11, C.silver.r, C.silver.g, C.silver.b)
        emptyText:SetPoint("TOPLEFT", 0, 0)
        yOff = 30
    end

    content:SetHeight(math.max(1, yOff))
end

----------------------------------------------------------------------
-- EXPORT POPUP (copyable text box)
----------------------------------------------------------------------
function BRutus:ShowExportPopup(titleStr, text)
    if self.exportPopup then self.exportPopup:Hide() end

    local f = CreateFrame("Frame", "BRutusExportPopup", UIParent, "BackdropTemplate")
    f:SetSize(500, 350)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.06, 0.05, 0.10, 0.98)
    f:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.8)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local titleText = f:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    titleText:SetPoint("TOP", 0, -10)
    titleText:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    titleText:SetText(titleStr or "Export")

    local hint = f:CreateFontString(nil, "OVERLAY")
    hint:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    hint:SetPoint("TOP", 0, -28)
    hint:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    hint:SetText("Press Ctrl+A to select all, then Ctrl+C to copy")

    -- Scroll frame for the edit box
    local scrollFrame = CreateFrame("ScrollFrame", "BRutusExportScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -48)
    scrollFrame:SetPoint("BOTTOMRIGHT", -12, 40)
    UI:SkinScrollBar(scrollFrame, "BRutusExportScroll")

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    editBox:SetTextColor(C.white.r, C.white.g, C.white.b)
    editBox:SetWidth(scrollFrame:GetWidth() - 10)
    editBox:SetAutoFocus(true)
    editBox:SetText(text or "")
    editBox:HighlightText()
    editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    scrollFrame:SetScrollChild(editBox)

    local closeBtn = UI:CreateCloseButton(f)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local closeTextBtn = UI:CreateButton(f, "Close", 80, 24)
    closeTextBtn:SetPoint("BOTTOM", 0, 10)
    closeTextBtn:SetScript("OnClick", function() f:Hide() end)

    f:Show()
    self.exportPopup = f
end

----------------------------------------------------------------------
-- SETTINGS PANEL
----------------------------------------------------------------------
function BRutus:CreateSettingsPanel(parent, _mainFrame)
    local scrollFrame, content = UI:CreateScrollFrame(parent, "BRutusSettingsScroll")
    scrollFrame:SetPoint("TOPLEFT", 12, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -12, 10)
    content:SetWidth(scrollFrame:GetWidth() - 20)

    parent:SetScript("OnShow", function()
        BRutus:RefreshSettingsPanel(content)
    end)
end

function BRutus:RefreshSettingsPanel(content)
    -- Clear existing
    for _, child in pairs({ content:GetChildren() }) do child:Hide() end

    local yOff = 0

    -- Title
    local title = UI:CreateTitle(content, "Settings", 16)
    title:SetPoint("TOPLEFT", 0, -yOff)
    yOff = yOff + 28

    local subtitle = UI:CreateText(content, "Enable or disable modules and adjust settings. Changes take effect immediately.", 10, C.silver.r, C.silver.g, C.silver.b)
    subtitle:SetPoint("TOPLEFT", 0, -yOff)
    subtitle:SetWidth(content:GetWidth() - 20)
    yOff = yOff + 24

    -- Separator
    local sep1 = UI:CreateSeparator(content)
    sep1:SetPoint("TOPLEFT", 0, -yOff)
    sep1:SetPoint("TOPRIGHT", -10, -yOff)
    yOff = yOff + 12

    --------------------------------------------------------------------
    -- MODULE TOGGLES
    --------------------------------------------------------------------
    local sectionTitle = UI:CreateHeaderText(content, "MODULES", 12)
    sectionTitle:SetPoint("TOPLEFT", 0, -yOff)
    yOff = yOff + 22

    -- Ensure modules table exists
    if not BRutus.db.settings.modules then
        BRutus.db.settings.modules = {
            raidTracker = true, lootTracker = true, lootMaster = true,
            consumableChecker = true, recruitment = true, trialTracker = true,
            officerNotes = true, tmb = true, commSystem = true,
            raidHUD = true,
        }
    end
    local mods = BRutus.db.settings.modules
    local isOfficer = BRutus:IsOfficer()

    local modules = {
        { key = "raidTracker",       label = "Raid Tracker",         desc = "Track raid attendance, penalties, and sessions", officerOnly = true },
        { key = "lootTracker",       label = "Loot Tracker",         desc = "Record loot drops from boss kills" },
        { key = "lootMaster",        label = "Loot Master",          desc = "Master Loot with TMB auto-council" },
        { key = "consumableChecker", label = "Consumable Checker",   desc = "Scan raid for missing flasks/food/elixirs" },
        { key = "raidHUD",           label = "Raid CD Tracker",      desc = "Floating tracker for raid cooldowns and consumable check" },
        { key = "tmb",               label = "TMB Integration",      desc = "That's My BiS wishlist/prio import", officerOnly = true },
        { key = "trialTracker",      label = "Trial Tracker",        desc = "Track trial member progress (officer)", officerOnly = true },
        { key = "officerNotes",      label = "Officer Notes",        desc = "Private notes on guild members (officer)", officerOnly = true },
        { key = "recruitment",       label = "Recruitment",          desc = "Auto-post recruitment messages (officer)", officerOnly = true },
        { key = "commSystem",        label = "Comm System",          desc = "Sync member data between addon users" },
    }

    for _, mod in ipairs(modules) do
        if not mod.officerOnly or isOfficer then
        local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
        row:SetSize(content:GetWidth() - 10, 36)
        row:SetPoint("TOPLEFT", 0, -yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(0.08, 0.06, 0.14, 0.5)

        local cb = UI:CreateCheckbox(row, mod.label, 18)
        cb:SetPoint("LEFT", 8, 0)
        cb.checkbox:SetChecked(mods[mod.key] ~= false)
        cb.checkbox.onChanged = function(_, checked)
            mods[mod.key] = checked
            if checked then
                BRutus:Print(mod.label .. " |cff00ff00enabled|r. Reload UI to apply.")
            else
                BRutus:Print(mod.label .. " |cffFF4444disabled|r. Reload UI to apply.")
            end
        end

        local desc = UI:CreateText(row, mod.desc, 9, C.silver.r, C.silver.g, C.silver.b)
        desc:SetPoint("LEFT", 240, 0)
        desc:SetWidth(400)

        yOff = yOff + 38
        end
    end

    yOff = yOff + 8

    -- Separator
    local sep2 = UI:CreateSeparator(content)
    sep2:SetPoint("TOPLEFT", 0, -yOff)
    sep2:SetPoint("TOPRIGHT", -10, -yOff)
    yOff = yOff + 12

    if isOfficer then
    --------------------------------------------------------------------
    -- LOOT MASTER SETTINGS (officer only)
    --------------------------------------------------------------------
    local lmTitle = UI:CreateHeaderText(content, "LOOT MASTER", 12)
    lmTitle:SetPoint("TOPLEFT", 0, -yOff)
    yOff = yOff + 22

    -- Roll duration
    local durLabel = UI:CreateText(content, "Roll Duration (seconds):", 11, C.white.r, C.white.g, C.white.b)
    durLabel:SetPoint("TOPLEFT", 8, -yOff)

    local durBox = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    durBox:SetSize(60, 22)
    durBox:SetPoint("LEFT", durLabel, "RIGHT", 10, 0)
    durBox:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    durBox:SetBackdropColor(0.06, 0.05, 0.10, 0.9)
    durBox:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.5)
    durBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    durBox:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    durBox:SetNumeric(true)
    durBox:SetMaxLetters(3)
    durBox:SetAutoFocus(false)
    durBox:SetText(tostring(BRutus.db.lootMaster.rollDuration or 30))
    durBox:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val >= 5 and val <= 120 then
            BRutus.db.lootMaster.rollDuration = val
            if BRutus.LootMaster then BRutus.LootMaster.ROLL_DURATION = val end
            BRutus:Print("Roll duration set to " .. val .. "s")
        else
            BRutus:Print("Duration must be between 5 and 120 seconds.")
            self:SetText(tostring(BRutus.db.lootMaster.rollDuration or 30))
        end
        self:ClearFocus()
    end)
    durBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    yOff = yOff + 30

    -- Auto announce
    local autoAnn = UI:CreateCheckbox(content, "Auto-announce loot when ML opens loot window", 18)
    autoAnn:SetPoint("TOPLEFT", 8, -yOff)
    autoAnn.checkbox:SetChecked(BRutus.db.lootMaster.autoAnnounce ~= false)
    autoAnn.checkbox.onChanged = function(_, checked)
        BRutus.db.lootMaster.autoAnnounce = checked
        if BRutus.LootMaster then BRutus.LootMaster.AUTO_ANNOUNCE = checked end
    end
    yOff = yOff + 28

    -- TMB auto-council
    local tmbCouncil = UI:CreateCheckbox(content, "TMB Auto-Council (check TMB before rolling)", 18)
    tmbCouncil:SetPoint("TOPLEFT", 8, -yOff)
    tmbCouncil.checkbox:SetChecked(BRutus.db.lootMaster.tmbOnlyMode or false)
    tmbCouncil.checkbox.onChanged = function(_, checked)
        BRutus.db.lootMaster.tmbOnlyMode = checked
        if BRutus.LootMaster then BRutus.LootMaster.TMB_ONLY_MODE = checked end
    end
    yOff = yOff + 28

    yOff = yOff + 8
    local sep3 = UI:CreateSeparator(content)
    sep3:SetPoint("TOPLEFT", 0, -yOff)
    sep3:SetPoint("TOPRIGHT", -10, -yOff)
    yOff = yOff + 12

    end -- isOfficer (Loot Master settings)

    --------------------------------------------------------------------
    -- RAID TRACKER SETTINGS
    --------------------------------------------------------------------
    local rtTitle = UI:CreateHeaderText(content, "RAID TRACKER", 12)
    rtTitle:SetPoint("TOPLEFT", 0, -yOff)
    yOff = yOff + 22

    local penaltyInfo = UI:CreateText(content, "Penalties per session (base score = 100):", 11, C.white.r, C.white.g, C.white.b)
    penaltyInfo:SetPoint("TOPLEFT", 8, -yOff)
    yOff = yOff + 20

    local penalties = {
        { label = "Late (missed first snapshot)", val = BRutus.RaidTracker and BRutus.RaidTracker.PENALTIES.LATE or 10 },
        { label = "Left Early (missed last snapshot)", val = BRutus.RaidTracker and BRutus.RaidTracker.PENALTIES.LEFT_EARLY or 10 },
        { label = "No Consumables (<50% snapshots)", val = BRutus.RaidTracker and BRutus.RaidTracker.PENALTIES.NO_CONSUMES or 10 },
    }
    for _, p in ipairs(penalties) do
        local pt = UI:CreateText(content, "  -" .. p.val .. "  " .. p.label, 10, C.silver.r, C.silver.g, C.silver.b)
        pt:SetPoint("TOPLEFT", 16, -yOff)
        yOff = yOff + 16
    end

    yOff = yOff + 8
    local sep4 = UI:CreateSeparator(content)
    sep4:SetPoint("TOPLEFT", 0, -yOff)
    sep4:SetPoint("TOPRIGHT", -10, -yOff)
    yOff = yOff + 12

    if isOfficer then
    --------------------------------------------------------------------
    -- TEST FUNCTIONS (officer only)
    --------------------------------------------------------------------
    local testTitle = UI:CreateHeaderText(content, "TEST FUNCTIONS", 12)
    testTitle:SetPoint("TOPLEFT", 0, -yOff)
    yOff = yOff + 6

    local testNote = UI:CreateText(content, "Simulate features to preview how they work. No data is sent to raid or guild chat.", 10, C.silver.r, C.silver.g, C.silver.b)
    testNote:SetPoint("TOPLEFT", 0, -yOff)
    testNote:SetWidth(content:GetWidth() - 20)
    yOff = yOff + 22

    -- Test: Consumable Check
    local testCons = UI:CreateButton(content, "Test Consumable Check", 200, 26)
    testCons:SetPoint("TOPLEFT", 8, -yOff)
    testCons:SetScript("OnClick", function()
        if BRutus.ConsumableChecker then
            local results = BRutus.ConsumableChecker:CheckRaid()
            if results then
                local missing = BRutus.ConsumableChecker:GetMissingCount(results)
                BRutus:Print("Consumable Check Test: " .. missing .. " players missing buffs.")
                BRutus:Print("Use |cffFFD700/brutus consreport|r to see details in raid chat.")
            else
                BRutus:Print("Consumable check returned no results (not in a raid?).")
            end
        else
            BRutus:Print("|cffFF4444Consumable Checker module is disabled.|r")
        end
    end)
    local testConsDesc = UI:CreateText(content, "Scans your current raid for missing consumables", 9, C.silver.r, C.silver.g, C.silver.b)
    testConsDesc:SetPoint("LEFT", testCons, "RIGHT", 10, 0)
    yOff = yOff + 32

    -- Test: Loot Master Roll Popup
    local testLM = UI:CreateButton(content, "Test Roll Popup", 200, 26)
    testLM:SetPoint("TOPLEFT", 8, -yOff)
    testLM:SetScript("OnClick", function()
        if BRutus.LootMaster then
            BRutus.LootMaster.testMode = true
            -- Simulate a roll popup with a fake item
            BRutus.LootMaster:ShowRollPopup(
                "|cffff8000|Hitem:32837::::::::70:::::|h[Warglaive of Azzinoth]|h|r",
                15,
                32837
            )
            BRutus:Print("Test roll popup shown (15s timer). Try MS/OS/Pass buttons.")
        else
            BRutus:Print("|cffFF4444Loot Master module is disabled.|r")
        end
    end)
    local testLMDesc = UI:CreateText(content, "Shows the raider roll popup with a sample item", 9, C.silver.r, C.silver.g, C.silver.b)
    testLMDesc:SetPoint("LEFT", testLM, "RIGHT", 10, 0)
    yOff = yOff + 32

    -- Test: TMB Council Preview
    local testCouncil = UI:CreateButton(content, "Test TMB Council", 200, 26)
    testCouncil:SetPoint("TOPLEFT", 8, -yOff)
    testCouncil:SetScript("OnClick", function()
        if BRutus.LootMaster then
            BRutus.LootMaster.testMode = true
            -- Show council frame with fake data
            local fakeWinner = { name = UnitName("player"), class = select(2, UnitClass("player")), tmbType = "prio", order = 1 }
            local fakeCandidates = {
                fakeWinner,
                { name = "TestPlayer", class = "WARRIOR", tmbType = "prio", order = 2 },
                { name = "AnotherOne", class = "MAGE", tmbType = "wishlist", order = 1 },
            }
            BRutus.LootMaster.activeLoot = {
                link = "|cffff8000|Hitem:32837::::::::70:::::|h[Warglaive of Azzinoth]|h|r",
                slot = nil,
                itemId = 32837,
            }
            BRutus.LootMaster:ShowCouncilResultFrame(
                fakeWinner,
                "|cffff8000|Hitem:32837::::::::70:::::|h[Warglaive of Azzinoth]|h|r",
                nil,
                fakeCandidates
            )
            BRutus:Print("Test council frame shown. Award button won't work (no loot slot).")
        else
            BRutus:Print("|cffFF4444Loot Master module is disabled.|r")
        end
    end)
    local testCouncilDesc = UI:CreateText(content, "Shows the ML council result frame with sample data", 9, C.silver.r, C.silver.g, C.silver.b)
    testCouncilDesc:SetPoint("LEFT", testCouncil, "RIGHT", 10, 0)
    yOff = yOff + 32

    -- Test: ML Roll Tracker
    local testRollFrame = UI:CreateButton(content, "Test Roll Tracker", 200, 26)
    testRollFrame:SetPoint("TOPLEFT", 8, -yOff)
    testRollFrame:SetScript("OnClick", function()
        if BRutus.LootMaster then
            BRutus.LootMaster.testMode = true
            BRutus.LootMaster.activeLoot = {
                link = "|cffa335ee|Hitem:30110::::::::70:::::|h[Tsunami Talisman]|h|r",
                slot = nil,
                itemId = 30110,
                startTime = GetServerTime(),
                endTime = GetServerTime() + 30,
            }
            BRutus.LootMaster.rolls = {
                ["TestWarrior-Realm"] = { name = "TestWarrior", class = "WARRIOR", rollType = "MS", roll = 87, tmb = { type = "prio", order = 1 } },
                ["TestMage-Realm"] = { name = "TestMage", class = "MAGE", rollType = "MS", roll = 54, tmb = { type = "wishlist", order = 2 } },
                ["TestPriest-Realm"] = { name = "TestPriest", class = "PRIEST", rollType = "OS", roll = 92, tmb = nil },
                ["TestRogue-Realm"] = { name = "TestRogue", class = "ROGUE", rollType = "PASS", roll = 0, tmb = nil },
            }
            BRutus.LootMaster:ShowRollFrame()
            BRutus:Print("Test roll tracker shown with sample rolls.")
        else
            BRutus:Print("|cffFF4444Loot Master module is disabled.|r")
        end
    end)
    local testRFDesc = UI:CreateText(content, "Shows the ML roll tracker with sample roll data", 9, C.silver.r, C.silver.g, C.silver.b)
    testRFDesc:SetPoint("LEFT", testRollFrame, "RIGHT", 10, 0)
    yOff = yOff + 32

    -- Test: Raid Tracker Status
    local testRT = UI:CreateButton(content, "Test Raid Status", 200, 26)
    testRT:SetPoint("TOPLEFT", 8, -yOff)
    testRT:SetScript("OnClick", function()
        if BRutus.RaidTracker then
            local total = BRutus.RaidTracker:GetTotalSessions()
            local tracking = BRutus.RaidTracker.trackingActive
            BRutus:Print(string.format("Raid Tracker: %d sessions recorded. Currently %s.",
                total, tracking and "|cff00ff00tracking|r" or "|cffFF4444not tracking|r"))
            if BRutus.RaidTracker.currentRaid then
                BRutus:Print("Active raid: " .. (BRutus.RaidTracker.currentRaid.name or "Unknown"))
            end
        else
            BRutus:Print("|cffFF4444Raid Tracker module is disabled.|r")
        end
    end)
    local testRTDesc = UI:CreateText(content, "Shows current raid tracking status and session count", 9, C.silver.r, C.silver.g, C.silver.b)
    testRTDesc:SetPoint("LEFT", testRT, "RIGHT", 10, 0)
    yOff = yOff + 32

    -- Test: Export Attendance
    local testExport = UI:CreateButton(content, "Test TMB Export", 200, 26)
    testExport:SetPoint("TOPLEFT", 8, -yOff)
    testExport:SetScript("OnClick", function()
        if BRutus.RaidTracker then
            local json, err = BRutus.RaidTracker:ExportForTMB()
            if json then
                BRutus:ShowExportPopup("TMB Attendance Export", json)
            else
                BRutus:Print("|cffFF4444Export failed:|r " .. (err or "No attendance data"))
            end
        else
            BRutus:Print("|cffFF4444Raid Tracker module is disabled.|r")
        end
    end)
    local testExpDesc = UI:CreateText(content, "Opens the TMB attendance export window", 9, C.silver.r, C.silver.g, C.silver.b)
    testExpDesc:SetPoint("LEFT", testExport, "RIGHT", 10, 0)
    yOff = yOff + 32

    end -- isOfficer (Test Functions)

    yOff = yOff + 8
    local sep5 = UI:CreateSeparator(content)
    sep5:SetPoint("TOPLEFT", 0, -yOff)
    sep5:SetPoint("TOPRIGHT", -10, -yOff)
    yOff = yOff + 12

    if isOfficer then
    --------------------------------------------------------------------
    -- OFFICER RANK CONFIGURATION (officer only)
    --------------------------------------------------------------------
    local rankTitle = UI:CreateHeaderText(content, "OFFICER RANKS", 12)
    rankTitle:SetPoint("TOPLEFT", 0, -yOff)
    yOff = yOff + 22

    local rankDesc = UI:CreateText(content,
        "Ranks marcados terão acesso a funcionalidades de officer no BRutus.",
        10, C.silver.r, C.silver.g, C.silver.b)
    rankDesc:SetPoint("TOPLEFT", 8, -yOff)
    rankDesc:SetWidth(content:GetWidth() - 20)
    yOff = yOff + 18

    -- Read current max rank setting
    local currentMaxRank = BRutus.db.settings.officerMaxRank or 2

    -- Get rank names from the WoW guild control API (1-based, rank 1 = GM)
    local numRanks = 0
    if GuildControlGetNumRanks then
        numRanks = GuildControlGetNumRanks() or 0
    end

    if numRanks == 0 then
        local noRankText = UI:CreateText(content, "Guild rank info not available. Open the Guild panel first.", 10, C.silver.r, C.silver.g, C.silver.b)
        noRankText:SetPoint("TOPLEFT", 8, -yOff)
        yOff = yOff + 18
    else
        -- Checkboxes: one per rank (rank 0 = index 1 in GuildControl = GM, always checked)
        -- We store officerMaxRank as 0-based WoW rankIndex
        for i = 1, numRanks do
            local rankWoWIndex = i - 1  -- convert to 0-based WoW rankIndex
            local rankName = GuildControlGetRankName and GuildControlGetRankName(i) or ("Rank " .. rankWoWIndex)
            if not rankName or rankName == "" then rankName = "Rank " .. rankWoWIndex end

            local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
            row:SetSize(content:GetWidth() - 10, 26)
            row:SetPoint("TOPLEFT", 0, -yOff)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            row:SetBackdropColor(0.08, 0.06, 0.14, 0.5)

            local isGM = (rankWoWIndex == 0)
            local isChecked = (rankWoWIndex <= currentMaxRank)

            local cb = UI:CreateCheckbox(row, rankName, 18)
            cb:SetPoint("LEFT", 8, 0)
            cb.checkbox:SetChecked(isChecked)

            -- Rank label showing 0-based index
            local idxLabel = UI:CreateText(row, "(rank " .. rankWoWIndex .. ")", 9, C.silver.r, C.silver.g, C.silver.b)
            idxLabel:SetPoint("LEFT", 220, 0)

            if isGM then
                -- GM is always an officer, cannot be unchecked
                cb.checkbox:Disable()
                local lockNote = UI:CreateText(row, "|cff666666sempre officer|r", 9, 0.4, 0.4, 0.4)
                lockNote:SetPoint("LEFT", 280, 0)
            else
            local capturedRankIndex = rankWoWIndex
            cb.checkbox.onChanged = function(_, checked)
                -- officerMaxRank = highest rank that is checked.
                -- Checking a rank implicitly checks all ranks above it (lower index).
                -- Unchecking a rank implicitly unchecks all ranks below it (higher index).
                local newMax
                if checked then
                    -- Expand threshold to include this rank if it's higher
                    newMax = math.max(capturedRankIndex, BRutus.db.settings.officerMaxRank or 0)
                else
                    -- Shrink threshold to exclude this rank and all below it
                    newMax = capturedRankIndex - 1
                    if newMax < 0 then newMax = 0 end
                end
                BRutus.db.settings.officerMaxRank = newMax
                local newRankName = GuildControlGetRankName and GuildControlGetRankName(newMax + 1) or ("Rank " .. newMax)
                BRutus:Print("Officer threshold: ranks 0-" .. newMax .. " (" .. newRankName .. " e acima são officers).")
            end
            end

            yOff = yOff + 28
        end
    end

    yOff = yOff + 4
    local rankNote = UI:CreateText(content,
        "Alteração tem efeito imediato. Reload UI necessário para recarregar módulos de officer.",
        9, C.silver.r, C.silver.g, C.silver.b)
    rankNote:SetPoint("TOPLEFT", 8, -yOff)
    rankNote:SetWidth(content:GetWidth() - 20)
    yOff = yOff + 20

    end -- isOfficer (Rank config)

    yOff = yOff + 8
    local sep6 = UI:CreateSeparator(content)
    sep6:SetPoint("TOPLEFT", 0, -yOff)
    sep6:SetPoint("TOPRIGHT", -10, -yOff)
    yOff = yOff + 12

    -- Reload UI button
    local reloadBtn = UI:CreateButton(content, "Reload UI", 120, 28)
    reloadBtn:SetPoint("TOPLEFT", 8, -yOff)
    reloadBtn:SetBackdropColor(0.4, 0.15, 0.0, 0.6)
    reloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)
    reloadBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.6, 0.2, 0.0, 0.8)
        self:SetBackdropBorderColor(C.gold.r, C.gold.g, C.gold.b, 0.8)
    end)
    reloadBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.4, 0.15, 0.0, 0.6)
        self:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.5)
    end)
    local reloadNote = UI:CreateText(content, "Required after enabling/disabling modules", 9, C.silver.r, C.silver.g, C.silver.b)
    reloadNote:SetPoint("LEFT", reloadBtn, "RIGHT", 10, 0)
    yOff = yOff + 36

    content:SetHeight(math.max(1, yOff))
end
