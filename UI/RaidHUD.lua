----------------------------------------------------------------------
-- UI/RaidHUD.lua
-- Floating Raid CD Tracker + Consumable Check popup
-- Auto-shows when in raid as leader or assist
----------------------------------------------------------------------
local BRutus = BRutus
local UI     = BRutus.UI
local C      = BRutus.Colors

----------------------------------------------------------------------
-- TBC RAID CD DEFINITIONS
-- iconID   = spellID whose texture is used as the column icon
-- spellIDs = all spellIDs that count as this CD (all ranks)
-- cooldown = approx seconds (for timer display, not enforcement)
-- class    = UnitClassBase / GetRaidRosterInfo fileName
----------------------------------------------------------------------
local RAID_CDS = {
    {
        key      = "rebirth",
        label    = "Battle Rez",
        class    = "DRUID",
        iconID   = 20484,
        cooldown = 1800,
        spellIDs = { 20484, 20748, 20747, 20742, 20739, 20737 },
    },
    {
        key      = "bloodlust",
        label    = "Bloodlust/Hero",
        class    = "SHAMAN",
        iconID   = 2825,
        cooldown = 600,
        spellIDs = { 2825, 32182 },
    },
    {
        key      = "innervate",
        label    = "Innervate",
        class    = "DRUID",
        iconID   = 29166,
        cooldown = 360,
        spellIDs = { 29166 },
    },
    {
        key      = "pi",
        label    = "Power Infusion",
        class    = "PRIEST",
        iconID   = 10060,
        cooldown = 180,
        spellIDs = { 10060 },
    },
    {
        key      = "md",
        label    = "Misdirection",
        class    = "HUNTER",
        iconID   = 34477,
        cooldown = 30,
        spellIDs = { 34477 },
    },
    {
        key      = "loh",
        label    = "Lay on Hands",
        class    = "PALADIN",
        iconID   = 633,
        cooldown = 3600,
        spellIDs = { 633, 2800, 10310 },
    },
    {
        key      = "di",
        label    = "Div. Intervention",
        class    = "PALADIN",
        iconID   = 19752,
        cooldown = 3600,
        spellIDs = { 19752 },
    },
    {
        key      = "ps",
        label    = "Pain Suppression",
        class    = "PRIEST",
        iconID   = 33206,
        cooldown = 180,
        spellIDs = { 33206 },
    },
    {
        key      = "sf",
        label    = "Shadowfiend",
        class    = "PRIEST",
        iconID   = 34433,
        cooldown = 300,
        spellIDs = { 34433 },
    },
    {
        key      = "tranquility",
        label    = "Tranquility",
        class    = "DRUID",
        iconID   = 740,
        cooldown = 300,
        spellIDs = { 740, 8918, 9862, 9863 },
    },
    {
        key      = "shieldwall",
        label    = "Shield Wall",
        class    = "WARRIOR",
        iconID   = 871,
        cooldown = 1800,
        spellIDs = { 871 },
    },
    {
        key      = "laststand",
        label    = "Last Stand",
        class    = "WARRIOR",
        iconID   = 12975,
        cooldown = 480,
        spellIDs = { 12975 },
    },
}

-- Reverse lookup: spellID -> cd entry
local SPELL_TO_CD = {}
for _, cd in ipairs(RAID_CDS) do
    for _, sid in ipairs(cd.spellIDs) do
        SPELL_TO_CD[sid] = cd
    end
end

----------------------------------------------------------------------
-- MODULE STATE
----------------------------------------------------------------------
local _cdState     = {}   -- [playerName][cdKey] = { usedAt, duration }
local _raidMembers = {}   -- [name] = classFile  (e.g. "WARRIOR")
local _hudFrame    = nil
local _consPopup   = nil
local _collapsed   = false
local _lastTick    = 0

----------------------------------------------------------------------
-- LAYOUT CONSTANTS
----------------------------------------------------------------------
local HUD_W      = 420
local HEADER_H   = 22
local ROW_H      = 22
local ICON_W     = 18
local LABEL_W    = 90
local FOOT_H     = 36

local CP_W         = 520
local CP_H         = 460
local CONS_ROW_H   = 24
local CONS_NAME_W  = 140
local CONS_COL_W   = 44
local CONS_COL_PAD = 4

----------------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------------
local function FormatTime(s)
    s = floor(s)
    if s >= 60 then
        return format("%dm%ds", floor(s / 60), s % 60)
    end
    return format("%ds", s)
end

local function IsLeaderOrAssist()
    if not IsInRaid() then return false end
    local myName = UnitName("player")
    for i = 1, GetNumGroupMembers() do
        local rName, rank = GetRaidRosterInfo(i)
        if rName == myName then
            return rank >= 1
        end
    end
    return false
end

local function ScanRaidRoster()
    wipe(_raidMembers)
    for i = 1, GetNumGroupMembers() do
        local name, _, _, _, _, classFile = GetRaidRosterInfo(i)
        if name then
            _raidMembers[name] = classFile
        end
    end
end

----------------------------------------------------------------------
-- COMBAT LOG — detect CD usage for all raid members
----------------------------------------------------------------------
local _clFrame = CreateFrame("Frame")
_clFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
_clFrame:SetScript("OnEvent", function()
    local _, event, _, _, srcName, _, _, _, _, _, _, spellID =
        CombatLogGetCurrentEventInfo()
    if event ~= "SPELL_CAST_SUCCESS" or not srcName then return end
    local cd = SPELL_TO_CD[spellID]
    if not cd then return end
    if not _cdState[srcName] then _cdState[srcName] = {} end
    _cdState[srcName][cd.key] = { usedAt = GetTime(), duration = cd.cooldown }
end)

----------------------------------------------------------------------
-- HUD ROW UPDATE (called from ticker)
----------------------------------------------------------------------
local function UpdateRow(row)
    if not row or not row:IsShown() then return end
    local parts = {}
    local now = GetTime()
    for _, p in ipairs(row.players) do
        local st = _cdState[p.name] and _cdState[p.name][row.cdKey]
        local remaining = st and (st.duration - (now - st.usedAt)) or 0
        if remaining > 0 then
            parts[#parts + 1] = "|cff999999" .. p.shortName
                              .. " " .. FormatTime(remaining) .. "|r"
        else
            parts[#parts + 1] = "|cff" .. p.colorHex .. p.shortName .. "|r"
        end
    end
    row.playerText:SetText(table.concat(parts, "  "))
end

----------------------------------------------------------------------
-- BUILD / REBUILD HUD ROWS
----------------------------------------------------------------------
local function BuildHUDRows(f)
    for _, r in ipairs(f.rows or {}) do r:Hide() end
    f.rows = {}

    ScanRaidRoster()

    local yOff = 2
    for _, cd in ipairs(RAID_CDS) do
        local players = {}
        for name, classFile in pairs(_raidMembers) do
            if classFile == cd.class then
                local shortName = name:sub(1, 12)
                local hex = BRutus:GetClassColorHex(classFile)
                table.insert(players, { name = name, shortName = shortName, colorHex = hex })
            end
        end

        if #players > 0 then
            table.sort(players, function(a, b) return a.name < b.name end)

            local row = CreateFrame("Frame", nil, f.bodyFrame)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT",  4, -yOff)
            row:SetPoint("TOPRIGHT", -4, -yOff)
            row.cdKey   = cd.key
            row.players = players

            -- Alternating background
            local bgCol = (#f.rows % 2 == 0) and C.row1 or C.row2
            local bgTex = row:CreateTexture(nil, "BACKGROUND")
            bgTex:SetAllPoints()
            bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
            bgTex:SetVertexColor(bgCol.r, bgCol.g, bgCol.b, bgCol.a)

            -- Spell icon
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(ICON_W, ICON_W)
            icon:SetPoint("LEFT", 2, 0)
            local spellTex = GetSpellTexture(cd.iconID)
            icon:SetTexture(spellTex or "Interface\\Icons\\INV_Misc_QuestionMark")
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            -- CD label
            local lbl = row:CreateFontString(nil, "OVERLAY")
            lbl:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            lbl:SetPoint("LEFT", ICON_W + 4, 0)
            lbl:SetWidth(LABEL_W)
            lbl:SetJustifyH("LEFT")
            lbl:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
            lbl:SetText(cd.label)

            -- Player name list (colored, updated by ticker)
            local pText = row:CreateFontString(nil, "OVERLAY")
            pText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            pText:SetPoint("LEFT", ICON_W + LABEL_W + 6, 0)
            pText:SetPoint("RIGHT", -2, 0)
            pText:SetJustifyH("LEFT")
            row.playerText = pText

            -- Tooltip: show full names + CD status
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(cd.label, C.gold.r, C.gold.g, C.gold.b)
                local now2 = GetTime()
                for _, p in ipairs(self.players) do
                    local st = _cdState[p.name] and _cdState[p.name][self.cdKey]
                    local rem = st and (st.duration - (now2 - st.usedAt)) or 0
                    local status
                    if rem > 0 then
                        status = "|cffff5555" .. FormatTime(rem) .. "|r"
                    else
                        status = "|cff55ff55Ready|r"
                    end
                    GameTooltip:AddLine(p.name .. ": " .. status, 1, 1, 1, false)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)

            UpdateRow(row)
            row:Show()
            table.insert(f.rows, row)
            yOff = yOff + ROW_H
        end
    end

    -- Resize body + main frame
    f.bodyFrame:SetHeight(math.max(1, yOff + 2))
    local totalH = HEADER_H + yOff + 2 + FOOT_H
    f:SetHeight(totalH)
end

----------------------------------------------------------------------
-- CREATE RAID HUD
----------------------------------------------------------------------
function BRutus:CreateRaidHUD()
    if _hudFrame then return end

    local f = CreateFrame("Frame", "BRutusRaidHUD", UIParent, "BackdropTemplate")
    f:SetWidth(HUD_W)
    f:SetHeight(200)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, 0.92)
    f:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 1)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(50)
    f:SetClampedToScreen(true)

    -- Restore saved position
    local pos = BRutus.db.raidHUDPos
    if pos then
        f:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -250, -180)
    end

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        BRutus.db.raidHUDPos = {
            point = point, relPoint = relPoint,
            x = floor(x), y = floor(y),
        }
    end)

    ----------------------------------------------------------------
    -- Header bar (draggable)
    ----------------------------------------------------------------
    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    header:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    header:SetBackdropColor(C.headerBg.r, C.headerBg.g, C.headerBg.b, 1)

    local titleText = header:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    titleText:SetPoint("LEFT", 8, 0)
    titleText:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    titleText:SetText("BRutus — Raid CDs")

    ----------------------------------------------------------------
    -- Collapse button  (— / +)
    ----------------------------------------------------------------
    local colBtn = CreateFrame("Button", nil, header)
    colBtn:SetSize(18, 18)
    colBtn:SetPoint("RIGHT", -22, 0)

    local colBtnText = colBtn:CreateFontString(nil, "OVERLAY")
    colBtnText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    colBtnText:SetAllPoints()
    colBtnText:SetJustifyH("CENTER")
    colBtnText:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    colBtnText:SetText("—")

    colBtn:SetScript("OnClick", function()
        _collapsed = not _collapsed
        f.bodyFrame:SetShown(not _collapsed)
        f.consBtn:SetShown(not _collapsed)
        colBtnText:SetText(_collapsed and "+" or "—")
        if _collapsed then
            f:SetHeight(HEADER_H + 2)
        else
            BuildHUDRows(f)
        end
    end)

    ----------------------------------------------------------------
    -- Close button
    ----------------------------------------------------------------
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("RIGHT", -2, 0)

    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    closeTxt:SetAllPoints()
    closeTxt:SetJustifyH("CENTER")
    closeTxt:SetTextColor(0.85, 0.20, 0.20)
    closeTxt:SetText("×")

    closeBtn:SetScript("OnClick", function() f:Hide() end)

    ----------------------------------------------------------------
    -- Body frame (holds CD rows)
    ----------------------------------------------------------------
    f.bodyFrame = CreateFrame("Frame", nil, f)
    f.bodyFrame:SetPoint("TOPLEFT",  header, "BOTTOMLEFT",  0, 0)
    f.bodyFrame:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)

    ----------------------------------------------------------------
    -- Check Consumables button
    ----------------------------------------------------------------
    f.consBtn = UI:CreateButton(f, "Check Consumables", 200, 24)
    f.consBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
    f.consBtn:SetScript("OnClick", function()
        BRutus:ShowConsumablePopup()
    end)

    ----------------------------------------------------------------
    -- Per-0.5s ticker: update cooldown countdown text
    ----------------------------------------------------------------
    f.rows = {}
    f:SetScript("OnUpdate", function(self, elapsed)
        _lastTick = _lastTick + elapsed
        if _lastTick < 0.5 then return end
        _lastTick = 0
        for _, row in ipairs(self.rows) do
            UpdateRow(row)
        end
    end)

    _hudFrame = f
    f:Hide()

    BuildHUDRows(f)
end

----------------------------------------------------------------------
-- VISIBILITY: show when in raid as leader/assist, hide otherwise
----------------------------------------------------------------------
function BRutus:UpdateRaidHUDVisibility()
    if not _hudFrame then return end
    local moduleEnabled = not BRutus.db or not BRutus.db.settings
        or not BRutus.db.settings.modules
        or BRutus.db.settings.modules.raidHUD ~= false
    local shouldShow = moduleEnabled and IsInRaid() and IsLeaderOrAssist()
    if shouldShow then
        if not _hudFrame:IsShown() then
            _hudFrame:Show()
        end
        if not _collapsed then
            BuildHUDRows(_hudFrame)
        end
    else
        _hudFrame:Hide()
    end
end

----------------------------------------------------------------------
-- EVENT HANDLING — auto show/hide on roster changes
----------------------------------------------------------------------
local _evtFrame = CreateFrame("Frame")
_evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
_evtFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
_evtFrame:RegisterEvent("RAID_ROSTER_UPDATE")

_evtFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Wait for BRutus.db to be ready (set in ADDON_LOADED)
        C_Timer.After(2, function()
            if BRutus.db then
                BRutus:CreateRaidHUD()
                BRutus:UpdateRaidHUDVisibility()
            end
        end)
    else
        BRutus:UpdateRaidHUDVisibility()
    end
end)

----------------------------------------------------------------------
-- CONSUMABLE POPUP — full grid, standalone floating frame
----------------------------------------------------------------------
local function BuildConsPopup(f)
    local CC = BRutus.ConsumableChecker
    if not CC then return end

    -- Status text
    local results = CC:GetLastResults()
    if CC.lastCheck then
        local ago = floor(GetServerTime() - (CC.lastCheck.time or 0))
        f.statusText:SetText("Last scan: " .. ago .. "s ago")
    elseif results and next(results) then
        f.statusText:SetText("Data from previous session — rescan for fresh results")
    else
        f.statusText:SetText("Not in a raid — join a raid group to scan")
    end

    local cols    = CC.COLUMN_ORDER
    local content = f.content
    local rowPool = f.rowPool

    -- Hide pooled rows
    for _, row in ipairs(rowPool) do
        row:Hide()
        for _, region in ipairs({ row:GetRegions() }) do region:Hide() end
        for _, child  in ipairs({ row:GetChildren() }) do child:Hide()  end
    end

    -- Build column icon headers only once
    if not f.headersBuilt then
        f.headersBuilt = true
        for i, col in ipairs(cols) do
            local xOff = CONS_NAME_W + (i - 1) * (CONS_COL_W + CONS_COL_PAD)

            local ico = f.headerRow:CreateTexture(nil, "ARTWORK")
            ico:SetSize(CONS_COL_W - 4, CONS_COL_W - 4)
            ico:SetPoint("BOTTOMLEFT", xOff + 2, 2)
            local icoTex = GetSpellTexture(col.icon)
            ico:SetTexture(icoTex or "Interface\\Icons\\INV_Misc_QuestionMark")
            ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            local ha = CreateFrame("Frame", nil, f.headerRow)
            ha:SetSize(CONS_COL_W, CONS_ROW_H + 4)
            ha:SetPoint("BOTTOMLEFT", xOff, 0)
            ha:EnableMouse(true)
            local cat      = CC.CONSUMABLES[col.key]
            local catLabel = cat and cat.label or col.key
            ha:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(catLabel, C.gold.r, C.gold.g, C.gold.b)
                GameTooltip:Show()
            end)
            ha:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end

    if not results or not next(results) then
        content:SetHeight(40)
        return
    end

    -- Sort: by class then name
    local list = {}
    for _, p in pairs(results) do
        table.insert(list, p)
    end
    table.sort(list, function(a, b)
        local ca = a.class or "ZZZ"
        local cb = b.class or "ZZZ"
        return ca == cb and a.name < b.name or ca < cb
    end)

    local yOff = 0
    for idx, p in ipairs(list) do
        -- Reuse or create row frame
        local row = rowPool[idx]
        if not row then
            row = CreateFrame("Frame", nil, content, "BackdropTemplate")
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

            row._nameText = UI:CreateText(row, "", 10, 1, 1, 1)
            row._nameText:SetPoint("LEFT", 6, 0)
            row._nameText:SetWidth(CONS_NAME_W - 10)

            row._cells = {}
            for i2, _ in ipairs(cols) do
                local xOff2  = CONS_NAME_W + (i2 - 1) * (CONS_COL_W + CONS_COL_PAD)
                local cell   = {}
                local iconSz = CONS_ROW_H - 4
                local xPad   = floor((CONS_COL_W - iconSz) / 2)

                local cico = row:CreateTexture(nil, "ARTWORK")
                cico:SetSize(iconSz, iconSz)
                cico:SetPoint("LEFT", xOff2 + xPad, 0)
                cico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                cell.icon = cico

                local miss = row:CreateFontString(nil, "OVERLAY")
                miss:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
                miss:SetPoint("LEFT", xOff2 + floor(CONS_COL_W / 2) - 4, 0)
                miss:SetTextColor(0.85, 0.15, 0.15)
                miss:SetText("-")
                cell.missText = miss

                local ha2 = CreateFrame("Frame", nil, row)
                ha2:SetSize(CONS_COL_W, CONS_ROW_H)
                ha2:SetPoint("LEFT", xOff2, 0)
                ha2:EnableMouse(true)
                cell.hitArea = ha2

                row._cells[i2] = cell
            end
            rowPool[idx] = row
        end

        row:SetSize(content:GetWidth(), CONS_ROW_H)
        row:SetPoint("TOPLEFT", 0, -yOff)
        local bg = (idx % 2 == 1) and C.row1 or C.row2
        row:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
        row:Show()

        -- Name (class-colored)
        local cr, cg, cbv = BRutus:GetClassColor(p.class)
        row._nameText:SetTextColor(cr, cg, cbv)
        row._nameText:SetText(p.name or "?")
        row._nameText:Show()

        -- Per-category cells
        for i, col in ipairs(cols) do
            local cell    = row._cells[i]
            local hasBuff = p.buffs[col.key]

            -- Support both new format ({name, id}) and old format (plain string)
            local buffId   = type(hasBuff) == "table" and hasBuff.id   or nil
            local buffName = type(hasBuff) == "table" and hasBuff.name or hasBuff

            if hasBuff then
                -- Prefer actual buff icon; fall back to category representative icon
                local buffTex = (buffId and GetSpellTexture(buffId))
                             or GetSpellTexture(col.icon)
                             or "Interface\\Icons\\INV_Misc_QuestionMark"
                cell.icon:SetTexture(buffTex)
                cell.icon:Show()
                cell.missText:Hide()
                cell.hitArea:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:ClearLines()
                    GameTooltip:AddLine(p.name, cr, cg, cbv)
                    GameTooltip:AddLine(type(buffName) == "string" and buffName or "?", 1, 1, 1, true)
                    GameTooltip:Show()
                end)
                cell.hitArea:SetScript("OnLeave", function() GameTooltip:Hide() end)
            else
                cell.icon:Hide()
                cell.missText:Show()
                cell.hitArea:SetScript("OnEnter", nil)
                cell.hitArea:SetScript("OnLeave", nil)
            end
        end

        -- Hover highlight
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C.rowHover.r, C.rowHover.g, C.rowHover.b, C.rowHover.a)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
        end)

        yOff = yOff + CONS_ROW_H + 2
    end
    content:SetHeight(math.max(1, yOff))
end

function BRutus:ShowConsumablePopup()
    local CC = BRutus.ConsumableChecker
    if CC then CC:CheckRaid() end

    if _consPopup then
        _consPopup:Show()
        BuildConsPopup(_consPopup)
        return
    end

    local f = CreateFrame("Frame", "BRutusConsPopup", UIParent, "BackdropTemplate")
    f:SetSize(CP_W, CP_H)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, 0.96)
    f:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 1)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(60)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)

    -- Header
    local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
    hdr:SetHeight(HEADER_H)
    hdr:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, 0)
    hdr:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    hdr:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    hdr:SetBackdropColor(C.headerBg.r, C.headerBg.g, C.headerBg.b, 1)

    local hTitle = hdr:CreateFontString(nil, "OVERLAY")
    hTitle:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    hTitle:SetPoint("LEFT", 10, 0)
    hTitle:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    hTitle:SetText("Consumable Check")

    local hClose = CreateFrame("Button", nil, hdr)
    hClose:SetSize(18, 18)
    hClose:SetPoint("RIGHT", -2, 0)
    local hCloseTxt = hClose:CreateFontString(nil, "OVERLAY")
    hCloseTxt:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    hCloseTxt:SetAllPoints()
    hCloseTxt:SetJustifyH("CENTER")
    hCloseTxt:SetTextColor(0.85, 0.20, 0.20)
    hCloseTxt:SetText("×")
    hClose:SetScript("OnClick", function() f:Hide() end)

    -- Status text
    f.statusText = UI:CreateText(f, "No scan yet", 10, C.silver.r, C.silver.g, C.silver.b)
    f.statusText:SetPoint("TOPLEFT", 10, -(HEADER_H + 8))

    -- Report to Raid button
    local repBtn = UI:CreateButton(f, "Report to Raid", 120, 22)
    repBtn:SetPoint("TOPRIGHT", -10, -(HEADER_H + 4))
    repBtn:SetScript("OnClick", function()
        local CC = BRutus.ConsumableChecker
        if CC then CC:ReportToChat("RAID") end
    end)

    -- Column header row (icons per category)
    local headerRow = CreateFrame("Frame", nil, f)
    headerRow:SetPoint("TOPLEFT",  f, "TOPLEFT",  10, -(HEADER_H + 32))
    headerRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -(HEADER_H + 32))
    headerRow:SetHeight(CONS_ROW_H + 4)
    f.headerRow    = headerRow
    f.headersBuilt = false

    -- "Player" column header label
    local nameHdr = UI:CreateText(headerRow, "Player", 9, C.gold.r, C.gold.g, C.gold.b)
    nameHdr:SetPoint("BOTTOMLEFT", 6, 2)

    -- Scrollable player list
    local scroll = CreateFrame(
        "ScrollFrame", "BRutusConsPopupScroll", f, "UIPanelScrollFrameTemplate"
    )
    scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",     10, -(HEADER_H + 32 + CONS_ROW_H + 8))
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 10)
    UI:SkinScrollBar(scroll, "BRutusConsPopupScroll")

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CP_W - 46, 1)
    scroll:SetScrollChild(content)

    f.content = content
    f.rowPool  = {}

    _consPopup = f
    BuildConsPopup(f)
end
