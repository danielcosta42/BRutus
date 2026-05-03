----------------------------------------------------------------------
-- BRutus Guild Manager - UI/AssignmentPreview
-- Floating preview window for auto-generated raid assignments.
-- Shows: boss name, confidence, all slots with assigned players,
-- phase groupings (Kael-style), missing slots and warnings.
----------------------------------------------------------------------
local UI = BRutus.UI
local C  = BRutus.Colors

-- Layout constants
local PREVIEW_W = 530
local PREVIEW_H = 480
local ROW_H     = 16
local MAX_ROWS  = 80

-- Priority display tags
local PRIO_TAG = {
    HIGH   = "|cffFF4444[H]|r ",
    MEDIUM = "|cffFFD700[M]|r ",
    LOW    = "|cffAAAAAA[L]|r ",
}

-- Confidence color strings
local CONF_COLOR = {
    HIGH   = "|cff00FF00HIGH|r",
    MEDIUM = "|cffFFD700MEDIUM|r",
    LOW    = "|cffFF4444LOW|r",
}

-- Singleton state
local _frame   = nil
local _rows    = {}
local _numRows = 0

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function ConfTag(c)
    return CONF_COLOR[c] or "|cffAAAAAA?|r"
end

local function WriteRow(text)
    _numRows = _numRows + 1
    if _numRows <= MAX_ROWS and _rows[_numRows] then
        _rows[_numRows]:SetText(text or "")
        _rows[_numRows]:Show()
    end
end

local function ClearRows()
    for i = 1, MAX_ROWS do
        if _rows[i] then
            _rows[i]:SetText("")
            _rows[i]:Hide()
        end
    end
    _numRows = 0
end

----------------------------------------------------------------------
-- Build the singleton frame (called once on first show)
----------------------------------------------------------------------
local function BuildFrame()
    local f = CreateFrame("Frame", "BRutusAssignmentPreview", UIParent, "BackdropTemplate")
    f:SetSize(PREVIEW_W, PREVIEW_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.05, 0.05, 0.10, 0.97)
    f:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.8)

    -- Title bar
    local title = UI:CreateHeaderText(f, "Assignment Preview", 12)
    title:SetPoint("TOPLEFT", 12, -10)

    -- Close button
    local closeBtn = UI:CreateCloseButton(f)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Top separator
    local sep1 = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sep1:SetHeight(1)
    sep1:SetPoint("TOPLEFT",  8, -28)
    sep1:SetPoint("TOPRIGHT", -8, -28)
    sep1:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    sep1:SetBackdropColor(C.border.r, C.border.g, C.border.b, 0.5)

    -- Summary line (raid, boss, confidence, generated-by)
    local summary = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    summary:SetPoint("TOPLEFT", 12, -36)
    summary:SetWidth(PREVIEW_W - 24)
    summary:SetJustifyH("LEFT")
    summary:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    f.summaryText = summary

    -- Second separator
    local sep2 = CreateFrame("Frame", nil, f, "BackdropTemplate")
    sep2:SetHeight(1)
    sep2:SetPoint("TOPLEFT",  8, -52)
    sep2:SetPoint("TOPRIGHT", -8, -52)
    sep2:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    sep2:SetBackdropColor(C.border.r, C.border.g, C.border.b, 0.4)

    -- Scroll frame for slot rows
    local scrollFrame, content = UI:CreateScrollFrame(f, "BRutusAssignPreviewScroll")
    scrollFrame:SetPoint("TOPLEFT",     8, -58)
    scrollFrame:SetPoint("BOTTOMRIGHT", -4,  8)
    -- SetWidth must be explicit: GetWidth() returns 0 before anchor layout resolves.
    content:SetWidth(PREVIEW_W - 28)
    f.content = content

    -- Pre-build text rows inside the content frame
    for i = 1, MAX_ROWS do
        local row = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row:SetWidth(PREVIEW_W - 44)
        row:SetJustifyH("LEFT")
        row:SetPoint("TOPLEFT", 4, -(i - 1) * ROW_H)
        row:SetText("")
        row:Hide()
        _rows[i] = row
    end

    f:Hide()
    tinsert(UISpecialFrames, "BRutusAssignmentPreview")
    return f
end

----------------------------------------------------------------------
-- Populate preview rows from a GenerateForBoss result table.
----------------------------------------------------------------------
local function PopulateResult(result)
    ClearRows()
    if not result then
        WriteRow("|cffFF4444No result to display.|r")
        return
    end

    local lastPhase = nil

    for _, slot in ipairs(result.slots or {}) do
        -- Phase section header (Kael-style bosses)
        if slot.phase and slot.phase ~= lastPhase then
            if lastPhase ~= nil then WriteRow("") end
            -- Look up display name from template phases list
            local phaseName = slot.phase
            if BRutus.AssignmentTemplateService then
                local boss = BRutus.AssignmentTemplateService:GetBoss(
                    result.raidId, result.bossId)
                if boss and boss.phases then
                    for _, ph in ipairs(boss.phases) do
                        if ph.id == slot.phase then
                            phaseName = ph.name
                            break
                        end
                    end
                end
            end
            WriteRow("|cffFFD700\226\128\148 " .. phaseName .. " \226\128\148|r")
            lastPhase = slot.phase
        end

        -- Build assigned-names string with MISSING highlighted
        local parts = {}
        local hasMissing = false
        for _, a in ipairs(slot.assigned or {}) do
            if a == "MISSING" then
                tinsert(parts, "|cffFF4444MISSING|r")
                hasMissing = true
            else
                tinsert(parts, a)
            end
        end
        local namesStr
        if hasMissing then
            namesStr = table.concat(parts, ", ")
        else
            namesStr = "|cff00FF00" .. table.concat(parts, ", ") .. "|r"
        end

        local prio = PRIO_TAG[slot.priority] or PRIO_TAG["MEDIUM"]
        WriteRow(prio .. "|cffFFFFFF" .. slot.label .. ":|r  " .. namesStr)

        -- Notes (dimmed)
        if slot.notes then
            WriteRow("   |cff666666" .. slot.notes .. "|r")
        end

        -- Slot-level warnings
        for _, w in ipairs(slot.warnings or {}) do
            WriteRow("   |cffFF8800! " .. w .. "|r")
        end
    end

    -- Global warnings
    if #(result.warnings or {}) > 0 then
        WriteRow("")
        WriteRow("|cffFF8800Warnings:|r")
        for _, w in ipairs(result.warnings) do
            WriteRow("  |cffFF8800! " .. w .. "|r")
        end
    end

    -- Missing critical slots summary
    if #(result.missing or {}) > 0 then
        WriteRow("")
        WriteRow("|cffFF4444Critical slots MISSING:|r")
        for _, m in ipairs(result.missing) do
            WriteRow("  |cffFF4444\226\128\162 " .. m.label .. "|r")
        end
    end

    -- Resize content frame to fit rows
    if _frame and _frame.content then
        _frame.content:SetHeight(math.max(1, _numRows * ROW_H + 8))
    end
end

----------------------------------------------------------------------
-- Public: display the preview window with a GenerateForBoss result.
----------------------------------------------------------------------
function BRutus:ShowAssignmentPreview(result)
    if not _frame then
        _frame = BuildFrame()
    end

    if result then
        local raidShort = result.raidId   or "?"
        local bossName  = result.bossName or result.bossId or "?"
        local confStr   = ConfTag(result.confidence)
        local byStr     = result.generatedBy or "Unknown"
        local modeStr   = (IsInRaid and IsInRaid())
            and ""
            or "  |cffFF8800[Pre-Raid]|r"

        _frame.summaryText:SetText(
            "|cffFFD700" .. raidShort .. "|r  \226\155\186  " ..
            bossName .. "   Confidence: " .. confStr ..
            "   |cffAAAAAAby " .. byStr .. "|r" .. modeStr
        )
        PopulateResult(result)
    end

    _frame:Show()
end

-- Public: hide the preview window.
function BRutus:HideAssignmentPreview()
    if _frame then _frame:Hide() end
end
