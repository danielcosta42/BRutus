----------------------------------------------------------------------
-- BRutus Guild Manager - Static Game Data
-- Color palettes, class colors, item quality colors, gear slot tables.
-- Loaded immediately after Core.lua so all modules can reference these.
----------------------------------------------------------------------

-- UI color constants
BRutus.Colors = {
    gold      = { r = 1.0, g = 0.84, b = 0.0 },
    darkGold  = { r = 0.8, g = 0.67, b = 0.0 },
    silver    = { r = 0.75, g = 0.75, b = 0.75 },
    panel     = { r = 0.08, g = 0.08, b = 0.12, a = 1.0 },
    panelDark = { r = 0.05, g = 0.05, b = 0.08, a = 1.0 },
    row1      = { r = 0.14, g = 0.14, b = 0.20, a = 1.0 },
    row2      = { r = 0.10, g = 0.10, b = 0.16, a = 1.0 },
    rowHover  = { r = 0.22, g = 0.20, b = 0.32, a = 1.0 },
    accent    = { r = 0.50, g = 0.35, b = 1.0 },
    accentDim = { r = 0.35, g = 0.25, b = 0.70 },
    online    = { r = 0.30, g = 1.0,  b = 0.30 },
    offline   = { r = 0.50, g = 0.50, b = 0.50 },
    white     = { r = 1.0, g = 1.0, b = 1.0 },
    red       = { r = 1.0, g = 0.3, b = 0.3 },
    green     = { r = 0.3, g = 1.0, b = 0.3 },
    blue      = { r = 0.3, g = 0.5, b = 1.0 },
    headerBg  = { r = 0.14, g = 0.12, b = 0.22, a = 1.0 },
    border    = { r = 0.40, g = 0.30, b = 0.70, a = 0.6 },
    separator = { r = 0.30, g = 0.25, b = 0.50, a = 0.4 },
}

-- Class colors (TBC)
BRutus.ClassColors = {
    ["WARRIOR"]     = { r = 0.78, g = 0.61, b = 0.43 },
    ["PALADIN"]     = { r = 0.96, g = 0.55, b = 0.73 },
    ["HUNTER"]      = { r = 0.67, g = 0.83, b = 0.45 },
    ["ROGUE"]       = { r = 1.00, g = 0.96, b = 0.41 },
    ["PRIEST"]      = { r = 1.00, g = 1.00, b = 1.00 },
    ["SHAMAN"]      = { r = 0.00, g = 0.44, b = 0.87 },
    ["MAGE"]        = { r = 0.25, g = 0.78, b = 0.92 },
    ["WARLOCK"]     = { r = 0.53, g = 0.53, b = 0.93 },
    ["DRUID"]       = { r = 1.00, g = 0.49, b = 0.04 },
}

-- Item quality colors
BRutus.QualityColors = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor
    [1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common
    [2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon
    [3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare
    [4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic
    [5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary
}

-- Inventory slot IDs for TBC
BRutus.SlotIDs = {
    { id = 1,  name = "HeadSlot" },
    { id = 2,  name = "NeckSlot" },
    { id = 3,  name = "ShoulderSlot" },
    { id = 15, name = "BackSlot" },
    { id = 5,  name = "ChestSlot" },
    { id = 9,  name = "WristSlot" },
    { id = 10, name = "HandsSlot" },
    { id = 6,  name = "WaistSlot" },
    { id = 7,  name = "LegsSlot" },
    { id = 8,  name = "FeetSlot" },
    { id = 11, name = "Finger0Slot" },
    { id = 12, name = "Finger1Slot" },
    { id = 13, name = "Trinket0Slot" },
    { id = 14, name = "Trinket1Slot" },
    { id = 16, name = "MainHandSlot" },
    { id = 17, name = "SecondaryHandSlot" },
    { id = 18, name = "RangedSlot" },
}

-- Slot display names
BRutus.SlotNames = {
    [1]  = "Head",
    [2]  = "Neck",
    [3]  = "Shoulder",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [11] = "Ring 1",
    [12] = "Ring 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [18] = "Ranged",
}
