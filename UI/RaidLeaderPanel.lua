----------------------------------------------------------------------
-- BRutus Guild Manager - UI/RaidLeaderPanel
-- Officer-only Raid Leader configuration panel.
-- Sections: HUD controls, pre-pull check, active alerts, assignments.
----------------------------------------------------------------------
local UI = BRutus.UI
local C  = BRutus.Colors

-- Pre-built alert row references populated once in CreateRaidLeaderPanel.
local _alertRows = {}

-- Priority index → short colored tag for display.
local ALERT_TAG = {
    [1] = "|cffFF4444HIGH|r",
    [2] = "|cffFFD700MED|r",
    [3] = "|cffAAAAAA LOW|r",
}

----------------------------------------------------------------------
-- Internal: refresh only the 3 alert rows (safe to call frequently)
----------------------------------------------------------------------
local function RefreshAlertRows()
    if #_alertRows == 0 then return end
    local alerts = {}
    if BRutus.AlertService then
        alerts = BRutus.AlertService:GetActiveAlerts()
    end
    for i = 1, 3 do
        local row = _alertRows[i]
        local alert = alerts[i]
        if alert then
            local remaining = math.max(0, math.floor(alert.ttl - (GetTime() - alert.timestamp)))
            local tag = ALERT_TAG[alert.priority] or ALERT_TAG[2]
            row:SetText(format("[%s] %s  |cffAAAAAA(%ds)|r", tag, alert.message, remaining))
            row:Show()
        else
            if i == 1 then
                row:SetText("|cffAAAAAA(no active alerts)|r")
                row:Show()
            else
                row:SetText("")
                row:Hide()
            end
        end
    end
end

----------------------------------------------------------------------
-- Public: lightweight refresh — only updates dynamic parts.
-- Called from OnShow and from actions (Clear, Run Check, Save).
----------------------------------------------------------------------
function BRutus:RefreshRaidLeaderPanel()
    RefreshAlertRows()
end

----------------------------------------------------------------------
-- Create the Raid Leader panel (called once by RosterFrame).
-- parent is the tab content frame, already positioned.
-- All content goes into a scroll child so it never overflows.
----------------------------------------------------------------------
function BRutus:CreateRaidLeaderPanel(parent, _mainFrame)

    -- Reset row cache in case this is called more than once (safety guard).
    wipe(_alertRows)

    -- Scroll frame fills the entire parent tab area.
    local scrollFrame, p = UI:CreateScrollFrame(parent, "BRutusRaidLeaderScroll")
    scrollFrame:SetAllPoints(parent)
    -- Explicit content width: frame is 1080px, scrollbar ~20px, margins ~20px each.
    local CONTENT_W = 1020
    p:SetWidth(CONTENT_W)

    local LEFT = 16
    local W    = CONTENT_W - LEFT - 16   -- usable widget width

    -- Running vertical offset (negative = downward from TOPLEFT anchor).
    local yOff = -15

    ------------------------------------------------------------------
    -- Layout helpers (closures that update yOff)
    ------------------------------------------------------------------

    local function SectionHeader(text)
        local t = UI:CreateTitle(p, text, 13)
        t:SetPoint("TOPLEFT", LEFT, yOff)
        yOff = yOff - 22
        local sep = UI:CreateSeparator(p)
        sep:SetPoint("TOPLEFT",  LEFT, yOff)
        sep:SetPoint("TOPRIGHT", -LEFT, yOff)
        yOff = yOff - 12
    end

    local function BodyText(text, r, g, b)
        local t = UI:CreateText(p, text, 10, r or C.silver.r, g or C.silver.g, b or C.silver.b)
        t:SetPoint("TOPLEFT", LEFT, yOff)
        t:SetWidth(W)
        yOff = yOff - 16
        return t
    end

    local function RowLabel(text, xIndent)
        local t = UI:CreateText(p, text, 10, C.silver.r, C.silver.g, C.silver.b)
        t:SetPoint("TOPLEFT", LEFT + (xIndent or 0), yOff)
        return t
    end

    local function MakeEditBox(w, h)
        local eb = CreateFrame("EditBox", nil, p, "BackdropTemplate")
        eb:SetSize(w or 400, h or 22)
        eb:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        eb:SetBackdropColor(0.05, 0.05, 0.08, 1.0)
        eb:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.4)
        eb:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        eb:SetTextColor(C.white.r, C.white.g, C.white.b)
        eb:SetTextInsets(6, 6, 0, 0)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(120)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEnterPressed",  function(self) self:ClearFocus() end)
        return eb
    end

    local function Spacer(h)
        yOff = yOff - (h or 8)
    end

    ------------------------------------------------------------------
    -- SECTION 1: Raid Brain HUD
    ------------------------------------------------------------------
    SectionHeader("Raid Brain HUD")
    BodyText("Floating overlay showing raid state, active alerts and next assignment actions.")

    local hudStatusLabel = RowLabel("HUD status: ")
    local hudStatusText  = UI:CreateText(p, "Hidden", 10, C.offline.r, C.offline.g, C.offline.b)
    hudStatusText:SetPoint("LEFT", hudStatusLabel, "RIGHT", 4, 0)

    local hudToggleBtn = UI:CreateButton(p, "Toggle HUD", 110, 22)
    hudToggleBtn:SetPoint("LEFT", hudStatusText, "RIGHT", 20, 0)

    local function UpdateHUDStatus()
        if BRutus.RaidBrain and BRutus.RaidBrain:IsHUDShown() then
            hudStatusText:SetText("Visible")
            hudStatusText:SetTextColor(C.online.r, C.online.g, C.online.b)
        else
            hudStatusText:SetText("Hidden")
            hudStatusText:SetTextColor(C.offline.r, C.offline.g, C.offline.b)
        end
    end

    hudToggleBtn:SetScript("OnClick", function()
        if BRutus.RaidBrain then
            BRutus.RaidBrain:Toggle()
            UpdateHUDStatus()
        end
    end)

    yOff = yOff - 28
    Spacer(6)

    ------------------------------------------------------------------
    -- SECTION 2: Pre-Pull Validation
    ------------------------------------------------------------------
    SectionHeader("Pre-Pull Validation")
    BodyText("Checks raid for dead players, offline players and missing consumables.")

    local prePullText = UI:CreateText(p, "|cffAAAAAA(not yet run)|r", 10, 1, 1, 1)
    prePullText:SetPoint("TOPLEFT", LEFT, yOff)
    prePullText:SetWidth(W - 130)

    local runCheckBtn = UI:CreateButton(p, "Run Check", 110, 22)
    runCheckBtn:SetPoint("TOPLEFT", LEFT + W - 110, yOff - 2)
    runCheckBtn:SetScript("OnClick", function()
        if not BRutus.PrePullService then return end
        local result = BRutus.PrePullService:RunCheck()
        if result then
            local s = result.summary
            if s.totalIssues == 0 then
                prePullText:SetText("|cff00FF00Raid ready — no issues found.|r")
            else
                prePullText:SetText(format(
                    "|cffFF4444%d dead|r   |cffFF8800%d offline|r   |cffFFAA00%d no consumes|r   |cffAAAAAA(%d total)|r",
                    s.deadCount, s.offlineCount, s.noConsumes, s.totalIssues
                ))
            end
        else
            prePullText:SetText("|cffAAAAAA(not in raid)|r")
        end
        RefreshAlertRows()
    end)

    yOff = yOff - 28
    Spacer(6)

    ------------------------------------------------------------------
    -- SECTION 3: Active Alerts
    ------------------------------------------------------------------
    SectionHeader("Active Alerts")

    -- Action buttons on the same line
    local clearAlertsBtn = UI:CreateButton(p, "Clear All", 90, 22)
    clearAlertsBtn:SetPoint("TOPLEFT", LEFT, yOff - 2)
    clearAlertsBtn:SetScript("OnClick", function()
        if BRutus.AlertService then
            BRutus.AlertService:Clear()
        end
        -- RefreshAlertRows called via ALERT_UPDATED event (no need to call again)
    end)

    local testAlertBtn = UI:CreateButton(p, "Test Alert", 90, 22)
    testAlertBtn:SetPoint("LEFT", clearAlertsBtn, "RIGHT", 6, 0)
    testAlertBtn:SetScript("OnClick", function()
        if BRutus.AlertService then
            BRutus.AlertService:PushHigh("Test HIGH alert", "panel", 30)
        end
    end)

    yOff = yOff - 30

    -- 3 pre-built alert rows
    for i = 1, 3 do
        local row = UI:CreateText(p, "", 10, 1, 1, 1)
        row:SetPoint("TOPLEFT", LEFT + 8, yOff)
        row:SetWidth(W - 8)
        _alertRows[i] = row
        yOff = yOff - 16
    end

    Spacer(6)

    ------------------------------------------------------------------
    -- SECTION 4: Default Assignment Editor
    ------------------------------------------------------------------
    SectionHeader("Assignments (Default Encounter)")
    BodyText("Define up to 3 actions per phase for the 'default' encounter stub used by the HUD.",
        0.5, 0.5, 0.6)

    -- Load current assignments for pre-population
    local curActions1 = {}
    local curActions2 = {}
    if BRutus.AssignmentService then
        local rec = BRutus.AssignmentService:GetAssignment("default")
        if rec and rec.actions then
            curActions1 = rec.actions.phase1 or {}
            curActions2 = rec.actions.phase2 or {}
        end
    end

    -- Phase 1
    BodyText("Phase 1 — up to 3 actions:", C.gold.r, C.gold.g, C.gold.b)

    local phase1Inputs = {}
    for i = 1, 3 do
        RowLabel("Action " .. i .. ":", 8)
        local eb = MakeEditBox(W - 90, 22)
        eb:SetPoint("TOPLEFT", LEFT + 88, yOff)
        eb:SetText(curActions1[i] or "")
        phase1Inputs[i] = eb
        yOff = yOff - 28
    end

    Spacer(6)

    -- Phase 2
    BodyText("Phase 2 — up to 3 actions:", C.gold.r, C.gold.g, C.gold.b)

    local phase2Inputs = {}
    for i = 1, 3 do
        RowLabel("Action " .. i .. ":", 8)
        local eb = MakeEditBox(W - 90, 22)
        eb:SetPoint("TOPLEFT", LEFT + 88, yOff)
        eb:SetText(curActions2[i] or "")
        phase2Inputs[i] = eb
        yOff = yOff - 28
    end

    Spacer(4)

    local saveBtn = UI:CreateButton(p, "Save Assignments", 150, 24)
    saveBtn:SetPoint("TOPLEFT", LEFT, yOff - 2)
    saveBtn:SetScript("OnClick", function()
        if not BRutus.AssignmentService then return end

        local function collectInputs(inputs)
            local result = {}
            for _, eb in ipairs(inputs) do
                local v = strtrim(eb:GetText() or "")
                if v ~= "" then
                    tinsert(result, v)
                end
            end
            return result
        end

        local actions1 = collectInputs(phase1Inputs)
        local actions2 = collectInputs(phase2Inputs)

        BRutus.AssignmentService:SetAssignment("default", {
            actions = {
                phase1 = actions1,
                phase2 = actions2,
            }
        })

        BRutus:Print("[Raid Leader] Assignments saved.")

        -- Refresh HUD next-actions if visible
        if BRutus.RaidBrain then
            BRutus.RaidBrain:Refresh()
        end
    end)

    yOff = yOff - 34
    Spacer(8)

    ------------------------------------------------------------------
    -- SECTION 5: Slash Command Reference
    ------------------------------------------------------------------
    SectionHeader("Commands")
    BodyText("/brutus brain                  — toggle Raid Brain HUD")
    BodyText("/brutus ready                  — run pre-pull validation check")
    BodyText("/brutus cons                   — run consumable check on raid")
    BodyText("/brutus assign ssc [boss]      — generate SSC assignments")
    BodyText("/brutus assign tk  [boss]      — generate TK assignments")
    BodyText("/brutus assign preview         — re-open last preview")

    Spacer(8)

    ------------------------------------------------------------------
    -- SECTION 6: Assignment Templates
    ------------------------------------------------------------------
    SectionHeader("Assignment Templates")
    BodyText("Auto-fill assignments from SSC/TK templates using the current roster (or db members if not in raid).")

    -- Quick generate: full raid
    BodyText("Full Raid:", C.gold.r, C.gold.g, C.gold.b)

    local genSSCBtn = UI:CreateButton(p, "Generate SSC", 130, 22)
    genSSCBtn:SetPoint("TOPLEFT", LEFT, yOff - 2)
    genSSCBtn:SetScript("OnClick", function()
        if not BRutus.AssignmentAutoFillService then return end
        local results = BRutus.AssignmentAutoFillService:GenerateForRaid("SSC")
        if results[1] then BRutus:ShowAssignmentPreview(results[1]) end
        BRutus:Print(format("[Assign] SSC: %d bosses generated.", #results))
    end)

    local genTKBtn = UI:CreateButton(p, "Generate TK", 130, 22)
    genTKBtn:SetPoint("LEFT", genSSCBtn, "RIGHT", 6, 0)
    genTKBtn:SetScript("OnClick", function()
        if not BRutus.AssignmentAutoFillService then return end
        local results = BRutus.AssignmentAutoFillService:GenerateForRaid("TK")
        if results[1] then BRutus:ShowAssignmentPreview(results[1]) end
        BRutus:Print(format("[Assign] TK: %d bosses generated.", #results))
    end)

    yOff = yOff - 30
    Spacer(6)

    -- Per-boss buttons helper
    local BTN_W   = 108
    local BTN_GAP = 4
    local BTN_PER = 4  -- buttons per row

    local function BossBtnRow(raidId, bossKey, bossLabel, col, rowOffset)
        local btn = UI:CreateButton(p, bossLabel, BTN_W, 22)
        btn:SetPoint("TOPLEFT", LEFT + col * (BTN_W + BTN_GAP), yOff - rowOffset * 28 - 2)
        btn:SetScript("OnClick", function()
            if not BRutus.AssignmentAutoFillService then return end
            local res, err = BRutus.AssignmentAutoFillService:GenerateForBoss(raidId, bossKey)
            if res then
                BRutus:ShowAssignmentPreview(res)
                BRutus:Print(format("[Assign] %s/%s — Conf: %s  Missing: %d",
                    raidId, res.bossName, res.confidence, #res.missing))
            else
                BRutus:Print("|cffFF4444[Assign] " .. (err or "?") .. "|r")
            end
        end)
    end

    -- SSC per-boss buttons
    BodyText("SSC Bosses:", C.gold.r, C.gold.g, C.gold.b)

    local sscBosses = {
        { id = "hydross",    label = "Hydross"    },
        { id = "lurker",     label = "Lurker"     },
        { id = "leotheras",  label = "Leotheras"  },
        { id = "karathress", label = "Karathress" },
        { id = "morogrim",   label = "Morogrim"   },
        { id = "vashj",      label = "Lady Vashj" },
    }
    for i, boss in ipairs(sscBosses) do
        local col    = (i - 1) % BTN_PER
        local rowOff = math.floor((i - 1) / BTN_PER)
        BossBtnRow("SSC", boss.id, boss.label, col, rowOff)
    end
    yOff = yOff - math.ceil(#sscBosses / BTN_PER) * 28 - 2

    Spacer(6)

    -- TK per-boss buttons
    BodyText("TK Bosses:", C.gold.r, C.gold.g, C.gold.b)

    local tkBosses = {
        { id = "alar",       label = "Al'ar"      },
        { id = "voidreaver", label = "Void Reaver" },
        { id = "solarian",   label = "Solarian"   },
        { id = "kael",       label = "Kael'thas"  },
    }
    for i, boss in ipairs(tkBosses) do
        local col    = (i - 1) % BTN_PER
        local rowOff = math.floor((i - 1) / BTN_PER)
        BossBtnRow("TK", boss.id, boss.label, col, rowOff)
    end
    yOff = yOff - math.ceil(#tkBosses / BTN_PER) * 28 - 2

    Spacer(8)

    -- Finalize scroll child height so the scroll range is correct.
    p:SetHeight(math.abs(yOff) + 30)

    ------------------------------------------------------------------
    -- OnShow / OnHide: subscribe to events while panel is active
    ------------------------------------------------------------------
    parent:SetScript("OnShow", function()
        UpdateHUDStatus()
        RefreshAlertRows()
        if BRutus.Events then
            BRutus.Events:On("ALERT_UPDATED", "RaidLeaderPanel", function()
                RefreshAlertRows()
            end)
        end
    end)

    parent:SetScript("OnHide", function()
        if BRutus.Events then
            BRutus.Events:Off("ALERT_UPDATED", "RaidLeaderPanel")
        end
    end)
end
