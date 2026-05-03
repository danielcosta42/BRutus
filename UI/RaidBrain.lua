----------------------------------------------------------------------
-- BRutus Guild Manager - UI/RaidBrain
-- Floating Raid Leader HUD: boss stub, raid status, active alerts,
-- and next assignment actions from AssignmentService.
-- Toggle with /brutus brain or call BRutus.RaidBrain:Toggle().
----------------------------------------------------------------------
local RaidBrain = {}
BRutus.RaidBrain = RaidBrain

local UI = BRutus.UI
local C  = BRutus.Colors

-- Priority number → display color (matches AlertService internal values).
local ALERT_COLOR = {
    [1] = { r = C.red.r,    g = C.red.g,    b = C.red.b    }, -- HIGH
    [2] = { r = C.gold.r,   g = C.gold.g,   b = C.gold.b   }, -- MEDIUM
    [3] = { r = C.silver.r, g = C.silver.g, b = C.silver.b }, -- LOW
}

local _frame  = nil

----------------------------------------------------------------------
-- Internal: scan raid roster for dead/offline counts
----------------------------------------------------------------------
local function ScanRaidState()
    if not IsInRaid() then return 0, 0 end
    local dead, offline = 0, 0
    local total = GetNumGroupMembers()
    for i = 1, total do
        local name, _, _, _, _, _, _, online, isDead = GetRaidRosterInfo(i)
        if name then
            if not online then
                offline = offline + 1
            elseif isDead then
                dead = dead + 1
            end
        end
    end
    return dead, offline
end

----------------------------------------------------------------------
-- Internal: update the three alert text rows
----------------------------------------------------------------------
local function UpdateAlertRows(f, alerts)
    for i = 1, 3 do
        local row   = f.alertRows[i]
        local alert = alerts[i]
        if alert then
            row:SetText("- " .. alert.message)
            local col = ALERT_COLOR[alert.priority] or ALERT_COLOR[2]
            row:SetTextColor(col.r, col.g, col.b)
        else
            row:SetText("")
        end
    end
end

----------------------------------------------------------------------
-- Internal: update the three next-action text rows
----------------------------------------------------------------------
local function UpdateNextRows(f)
    local actions = {}
    if BRutus.AssignmentService then
        -- Stub encounter ID "default" until boss detection is available.
        actions = BRutus.AssignmentService:GetCurrentActions("default")
    end
    for i = 1, 3 do
        local row = f.nextRows[i]
        if actions[i] then
            row:SetText("- " .. actions[i])
            row:SetTextColor(C.white.r, C.white.g, C.white.b)
        elseif i == 1 then
            row:SetText("|cffAAAAAA(no assignments)|r")
        else
            row:SetText("")
        end
    end
end

----------------------------------------------------------------------
-- Internal: build the HUD frame (called once on first Show)
----------------------------------------------------------------------
local function BuildFrame()
    local f = CreateFrame("Frame", "BRutusRaidBrainFrame", UIParent, "BackdropTemplate")
    f:SetSize(280, 228)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(10)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, 0.95)
    f:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, C.border.a)

    ---- Header bar ----
    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT",  f, "TOPLEFT",  0,  0)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0,  0)
    header:SetHeight(22)
    header:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    header:SetBackdropColor(C.headerBg.r, C.headerBg.g, C.headerBg.b, 1.0)
    header:SetBackdropBorderColor(0, 0, 0, 0)

    local title = UI:CreateText(header, "RAID BRAIN", 11)
    title:SetPoint("CENTER", header, "CENTER", -8, 0)
    title:SetTextColor(C.gold.r, C.gold.g, C.gold.b)

    local closeBtn = UI:CreateCloseButton(header)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function() RaidBrain:Hide() end)

    ---- Accent line ----
    local accentLine = UI:CreateAccentLine(f)
    accentLine:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -22)
    accentLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -22)

    ---- Boss row ----
    local bossLabel = UI:CreateText(f, "Boss:", 10)
    bossLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -30)
    bossLabel:SetTextColor(C.silver.r, C.silver.g, C.silver.b)

    f.bossText = UI:CreateText(f, "Unknown", 10)
    f.bossText:SetPoint("LEFT", bossLabel, "RIGHT", 4, 0)
    f.bossText:SetTextColor(C.gold.r, C.gold.g, C.gold.b)

    ---- Separator ----
    local sep1 = UI:CreateSeparator(f)
    sep1:SetPoint("TOPLEFT",  f, "TOPLEFT",  4, -46)
    sep1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -46)

    ---- Raid state row ----
    local raidLabel = UI:CreateText(f, "Raid:", 10)
    raidLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -54)
    raidLabel:SetTextColor(C.silver.r, C.silver.g, C.silver.b)

    f.deadText = UI:CreateText(f, "Dead: 0", 10)
    f.deadText:SetPoint("LEFT", raidLabel, "RIGHT", 6, 0)

    f.offlineText = UI:CreateText(f, "Offline: 0", 10)
    f.offlineText:SetPoint("LEFT", f.deadText, "RIGHT", 10, 0)
    f.offlineText:SetTextColor(C.offline.r, C.offline.g, C.offline.b)

    ---- Separator ----
    local sep2 = UI:CreateSeparator(f)
    sep2:SetPoint("TOPLEFT",  f, "TOPLEFT",  4, -68)
    sep2:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -68)

    ---- Alerts section ----
    local alertsHeader = UI:CreateText(f, "Alerts:", 10)
    alertsHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -76)
    alertsHeader:SetTextColor(C.gold.r, C.gold.g, C.gold.b)

    f.alertRows = {}
    for i = 1, 3 do
        local row = UI:CreateText(f, "", 9)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -76 - (i * 14))
        row:SetWidth(252)
        row:SetJustifyH("LEFT")
        f.alertRows[i] = row
    end

    ---- Separator ----
    local sep3 = UI:CreateSeparator(f)
    sep3:SetPoint("TOPLEFT",  f, "TOPLEFT",  4, -124)
    sep3:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -124)

    ---- Next actions section ----
    local nextHeader = UI:CreateText(f, "Next:", 10)
    nextHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -132)
    nextHeader:SetTextColor(C.gold.r, C.gold.g, C.gold.b)

    f.nextRows = {}
    for i = 1, 3 do
        local row = UI:CreateText(f, "", 9)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -132 - (i * 14))
        row:SetWidth(252)
        row:SetJustifyH("LEFT")
        f.nextRows[i] = row
    end

    return f
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------

-- Rebuild all visible data from current service state.
function RaidBrain:Refresh()
    if not _frame or not _frame:IsShown() then return end

    local dead, offline = ScanRaidState()

    _frame.deadText:SetText("Dead: " .. dead)
    if dead > 0 then
        _frame.deadText:SetTextColor(C.red.r, C.red.g, C.red.b)
    else
        _frame.deadText:SetTextColor(C.green.r, C.green.g, C.green.b)
    end

    _frame.offlineText:SetText("Offline: " .. offline)

    local alerts = {}
    if BRutus.AlertService then
        alerts = BRutus.AlertService:GetActiveAlerts()
    end
    UpdateAlertRows(_frame, alerts)

    UpdateNextRows(_frame)
end

-- External update hook — called by services when data changes.
-- data may contain { alerts } for a partial update, or be nil for full refresh.
function RaidBrain:Update(data)
    if not _frame or not _frame:IsShown() then return end
    if data and data.alerts then
        UpdateAlertRows(_frame, data.alerts)
    else
        self:Refresh()
    end
end

-- Show the HUD. Lazily creates the frame on first call.
function RaidBrain:Show()
    if not _frame then
        _frame = BuildFrame()

        -- Subscribe to alert changes for instant alert row updates.
        if BRutus.Events then
            BRutus.Events:On("ALERT_UPDATED", "RaidBrain", function(data)
                if _frame and _frame:IsShown() then
                    UpdateAlertRows(_frame, data.alerts or {})
                end
            end)
        end

        -- Slow ticker to update raid state (dead/offline) while visible.
        BRutus.Compat.NewTicker(5, function()
            if _frame and _frame:IsShown() then
                BRutus.RaidBrain:Refresh()
            end
        end)
    end

    _frame:Show()
    self:Refresh()
end

-- Hide the HUD.
function RaidBrain:Hide()
    if _frame then
        _frame:Hide()
    end
end

-- Toggle the HUD on/off.
function RaidBrain:Toggle()
    if _frame and _frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- Returns true if the HUD frame is currently visible.
function RaidBrain:IsHUDShown()
    return _frame ~= nil and _frame:IsShown()
end
