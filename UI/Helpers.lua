----------------------------------------------------------------------
-- BRutus Guild Manager - UI Helpers
-- Reusable UI factory functions for the premium visual style
----------------------------------------------------------------------
local Helpers = {}
BRutus.UI = Helpers

local C = BRutus.Colors

----------------------------------------------------------------------
-- Create a premium background panel with gradient + border
----------------------------------------------------------------------
function Helpers:CreatePanel(parent, name, level)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    f:SetFrameLevel(level or 1)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(C.panel.r, C.panel.g, C.panel.b, C.panel.a)
    f:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, C.border.a)
    return f
end

----------------------------------------------------------------------
-- Create a dark sub-panel (for insets)
----------------------------------------------------------------------
function Helpers:CreateDarkPanel(parent, name, level)
    local f = self:CreatePanel(parent, name, level)
    f:SetBackdropColor(C.panelDark.r, C.panelDark.g, C.panelDark.b, C.panelDark.a)
    return f
end

----------------------------------------------------------------------
-- Create a glowing accent line (horizontal separator)
----------------------------------------------------------------------
function Helpers:CreateAccentLine(parent, thickness)
    thickness = thickness or 2
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetHeight(thickness)
    line:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.7)
    return line
end

----------------------------------------------------------------------
-- Create a separator line (dimmer)
----------------------------------------------------------------------
function Helpers:CreateSeparator(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetHeight(1)
    line:SetVertexColor(C.separator.r, C.separator.g, C.separator.b, C.separator.a)
    return line
end

----------------------------------------------------------------------
-- Create premium gold title text
----------------------------------------------------------------------
function Helpers:CreateTitle(parent, text, size)
    size = size or 18
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    fs:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    fs:SetText(text or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    return fs
end

----------------------------------------------------------------------
-- Create standard text
----------------------------------------------------------------------
function Helpers:CreateText(parent, text, size, r, g, b)
    size = size or 12
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    fs:SetTextColor(r or C.white.r, g or C.white.g, b or C.white.b)
    fs:SetText(text or "")
    return fs
end

----------------------------------------------------------------------
-- Create header text (for column headers)
----------------------------------------------------------------------
function Helpers:CreateHeaderText(parent, text, size)
    size = size or 11
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    fs:SetTextColor(C.gold.r, C.gold.g, C.gold.b, 0.9)
    fs:SetText(text or "")
    return fs
end

----------------------------------------------------------------------
-- Create a premium styled button
----------------------------------------------------------------------
function Helpers:CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 28)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(C.accentDim.r, C.accentDim.g, C.accentDim.b, 0.6)
    btn:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.5)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    label:SetText(text or "")
    btn.label = label

    -- Hover effects
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C.accent.r, C.accent.g, C.accent.b, 0.5)
        self:SetBackdropBorderColor(C.gold.r, C.gold.g, C.gold.b, 0.8)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C.accentDim.r, C.accentDim.g, C.accentDim.b, 0.6)
        self:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.5)
    end)

    return btn
end

----------------------------------------------------------------------
-- Create a styled checkbox with label
----------------------------------------------------------------------
function Helpers:CreateCheckbox(parent, labelText, size)
    size = size or 20
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(size + 200, size)

    local cb = CreateFrame("CheckButton", nil, frame)
    cb:SetSize(size, size)
    cb:SetPoint("LEFT", 0, 0)

    -- Custom box background
    local bg = cb:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetAllPoints()
    bg:SetVertexColor(0.08, 0.06, 0.14, 0.9)

    local border = cb:CreateTexture(nil, "BORDER")
    border:SetTexture("Interface\\Buttons\\WHITE8x8")
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", 1, -1)
    border:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.5)

    -- Checkmark text
    local check = cb:CreateFontString(nil, "OVERLAY")
    check:SetFont("Fonts\\FRIZQT__.TTF", size - 6, "OUTLINE")
    check:SetPoint("CENTER", 1, 0)
    check:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    check:SetText("")
    cb.checkMark = check

    cb:SetScript("OnClick", function(self)
        if self:GetChecked() then
            self.checkMark:SetText("X")
            border:SetVertexColor(C.gold.r, C.gold.g, C.gold.b, 0.8)
        else
            self.checkMark:SetText("")
            border:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.5)
        end
        if self.onChanged then self:onChanged(self:GetChecked()) end
    end)

    -- Update visual on SetChecked
    local origSetChecked = cb.SetChecked
    cb.SetChecked = function(self, val)
        origSetChecked(self, val)
        if val then
            self.checkMark:SetText("X")
            border:SetVertexColor(C.gold.r, C.gold.g, C.gold.b, 0.8)
        else
            self.checkMark:SetText("")
            border:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.5)
        end
    end

    cb:SetScript("OnEnter", function()
        bg:SetVertexColor(0.14, 0.10, 0.22, 0.9)
    end)
    cb:SetScript("OnLeave", function()
        bg:SetVertexColor(0.08, 0.06, 0.14, 0.9)
    end)

    -- Label
    local label = frame:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    label:SetTextColor(C.white.r, C.white.g, C.white.b)
    label:SetText(labelText or "")
    frame.label = label

    frame.checkbox = cb
    return frame
end

----------------------------------------------------------------------
-- Create close button (X)
----------------------------------------------------------------------
function Helpers:CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(18, 18)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
    })
    btn:SetBackdropColor(0.6, 0.2, 0.2, 0.4)

    local x = btn:CreateFontString(nil, "OVERLAY")
    x:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    x:SetPoint("CENTER", 0, 0)
    x:SetTextColor(0.8, 0.8, 0.8)
    x:SetText("X")
    btn.x = x

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.8, 0.2, 0.2, 0.7)
        self.x:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.6, 0.2, 0.2, 0.4)
        self.x:SetTextColor(0.8, 0.8, 0.8)
    end)

    return btn
end

----------------------------------------------------------------------
-- Skin a default WoW scrollbar into a thin, subtle track+thumb
-- Works with both UIPanelScrollFrameTemplate and FauxScrollFrameTemplate
----------------------------------------------------------------------
function Helpers:SkinScrollBar(scrollFrame, scrollName)
    local scrollBar = scrollFrame.ScrollBar
        or (scrollName and _G[scrollName .. "ScrollBar"])
        or nil
    if not scrollBar then return end

    -- Hide the default Blizzard up/down buttons and thumb texture
    local upBtn = scrollBar.ScrollUpButton
        or _G[scrollName and (scrollName .. "ScrollBarScrollUpButton")]
    local downBtn = scrollBar.ScrollDownButton
        or _G[scrollName and (scrollName .. "ScrollBarScrollDownButton")]
    local thumbTex = scrollBar.ThumbTexture
        or (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture())
        or _G[scrollName and (scrollName .. "ScrollBarThumbTexture")]

    if upBtn then upBtn:SetAlpha(0); upBtn:SetSize(1, 1); upBtn:EnableMouse(false) end
    if downBtn then downBtn:SetAlpha(0); downBtn:SetSize(1, 1); downBtn:EnableMouse(false) end
    if thumbTex then thumbTex:SetAlpha(0) end

    -- Make the scrollbar thin and positioned inside the frame
    scrollBar:SetWidth(6)
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -2)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -2, 2)

    -- Track background
    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetTexture("Interface\\Buttons\\WHITE8x8")
    track:SetVertexColor(0.08, 0.08, 0.12, 0.4)

    -- Custom thumb overlay
    local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
    thumb:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.5)
    thumb:SetSize(6, 40)
    scrollBar.customThumb = thumb

    -- Update thumb position on scroll
    local function UpdateThumb()
        local min, max = scrollBar:GetMinMaxValues()
        local val = scrollBar:GetValue()
        local trackHeight = scrollBar:GetHeight() or 100
        local thumbHeight = math.max(20, trackHeight * (trackHeight / (trackHeight + max - min + 1)))
        thumb:SetHeight(thumbHeight)

        if max <= min then
            thumb:Hide()
            return
        end
        thumb:Show()
        local ratio = (val - min) / (max - min)
        local travel = trackHeight - thumbHeight
        local yOff = -(ratio * travel)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", scrollBar, "TOPRIGHT", 0, yOff)
    end

    scrollBar:HookScript("OnValueChanged", function() UpdateThumb() end)
    scrollBar:HookScript("OnMinMaxChanged", function() UpdateThumb() end)
    -- Initial
    C_Timer.After(0.05, UpdateThumb)

    return scrollBar
end

----------------------------------------------------------------------
-- Create a scroll frame with custom scrollbar
----------------------------------------------------------------------
function Helpers:CreateScrollFrame(parent, name)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    local scrollChild = CreateFrame("Frame", name and (name .. "Child") or nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)

    -- Apply thin scrollbar skin
    self:SkinScrollBar(scrollFrame, name)

    return scrollFrame, scrollChild
end

----------------------------------------------------------------------
-- Create an icon frame with border
----------------------------------------------------------------------
function Helpers:CreateIcon(parent, size, iconPath)
    size = size or 32
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(size + 4, size + 4)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, C.border.a)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    if iconPath then
        icon:SetTexture(iconPath)
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Trim default icon borders
    frame.icon = icon

    return frame
end

----------------------------------------------------------------------
-- Create a quality-colored icon border
----------------------------------------------------------------------
function Helpers:SetIconQuality(iconFrame, quality)
    quality = quality or 1
    local color = BRutus.QualityColors[quality] or BRutus.QualityColors[1]
    iconFrame:SetBackdropBorderColor(color.r, color.g, color.b, 0.9)
end

----------------------------------------------------------------------
-- Create a progress bar
----------------------------------------------------------------------
function Helpers:CreateProgressBar(parent, width, height)
    width = width or 100
    height = height or 8

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.08, 0.8)
    frame:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.3)

    local bar = frame:CreateTexture(nil, "ARTWORK")
    bar:SetTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetHeight(height - 2)
    bar:SetWidth(1)
    bar:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.8)
    frame.bar = bar

    function frame:SetProgress(value)
        value = math.max(0, math.min(1, value or 0))
        local barWidth = math.max(1, (width - 2) * value)
        self.bar:SetWidth(barWidth)

        if value >= 1 then
            self.bar:SetVertexColor(C.green.r, C.green.g, C.green.b, 0.8)
        elseif value > 0 then
            self.bar:SetVertexColor(C.gold.r, C.gold.g, C.gold.b, 0.8)
        else
            self.bar:SetVertexColor(C.red.r, C.red.g, C.red.b, 0.5)
        end
    end

    return frame
end

----------------------------------------------------------------------
-- Create a tooltip-enhanced frame
----------------------------------------------------------------------
function Helpers:AddTooltip(frame, title, lines)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then
            GameTooltip:AddLine(title, C.gold.r, C.gold.g, C.gold.b)
        end
        if lines then
            for _, line in ipairs(lines) do
                if type(line) == "table" then
                    GameTooltip:AddLine(line.text, line.r or 1, line.g or 1, line.b or 1, line.wrap)
                else
                    GameTooltip:AddLine(line, 1, 1, 1, true)
                end
            end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

----------------------------------------------------------------------
-- Create a tab button
----------------------------------------------------------------------
function Helpers:CreateTab(parent, text, width)
    local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tab:SetSize(width or 100, 28)
    tab:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local label = tab:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(text or "")
    tab.label = label

    function tab:SetActive(active)
        if active then
            tab:SetBackdropColor(C.accent.r, C.accent.g, C.accent.b, 0.4)
            tab:SetBackdropBorderColor(C.gold.r, C.gold.g, C.gold.b, 0.8)
            tab.label:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
        else
            tab:SetBackdropColor(C.panelDark.r, C.panelDark.g, C.panelDark.b, 0.6)
            tab:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.3)
            tab.label:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
        end
    end

    tab:SetActive(false)

    tab:SetScript("OnEnter", function(self)
        if not self.isActive then
            self:SetBackdropColor(C.accent.r, C.accent.g, C.accent.b, 0.2)
        end
    end)
    tab:SetScript("OnLeave", function(self)
        if not self.isActive then
            self:SetBackdropColor(C.panelDark.r, C.panelDark.g, C.panelDark.b, 0.6)
        end
    end)

    return tab
end
