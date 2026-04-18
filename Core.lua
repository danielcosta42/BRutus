----------------------------------------------------------------------
-- BRutus Guild Manager - Core
-- Premium Guild Roster & Member Inspector for TBC Anniversary
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- Global addon table
BRutus = {}
BRutus.ns = ns

-- Version
BRutus.VERSION = "1.0.0"
BRutus.COMM_VERSION = 1
BRutus.PREFIX = "BRutus"

-- Color constants
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

----------------------------------------------------------------------
-- Database defaults
----------------------------------------------------------------------
local DB_DEFAULTS = {
    version = 1,
    members = {},    -- [name-realm] = { gear, professions, attunements, ... }
    settings = {
        sortBy = "level",
        sortAsc = false,
        showOffline = true,
        minimap = { hide = false },
    },
    myData = {},
    lastSync = 0,
}

----------------------------------------------------------------------
-- Event frame
----------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == ADDON_NAME then
            BRutus:Initialize()
        end
    elseif event == "PLAYER_LOGIN" then
        BRutus:OnLogin()
    elseif event == "PLAYER_ENTERING_WORLD" then
        BRutus:OnEnterWorld()
    elseif event == "GUILD_ROSTER_UPDATE" then
        BRutus:OnGuildRosterUpdate()
    elseif event == "PLAYER_GUILD_UPDATE" then
        BRutus:OnGuildRosterUpdate()
    end
end)

----------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------
function BRutus:Initialize()
    -- Initialize saved variables
    if not BRutusDB then
        BRutusDB = {}
    end
    for k, v in pairs(DB_DEFAULTS) do
        if BRutusDB[k] == nil then
            if type(v) == "table" then
                BRutusDB[k] = self:DeepCopy(v)
            else
                BRutusDB[k] = v
            end
        end
    end
    self.db = BRutusDB

    -- Register addon prefix for communication
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
    end

    self:Print("v" .. self.VERSION .. " loaded. Type |cffFFD700/brutus|r to open.")
end

function BRutus:OnLogin()
    -- Initialize subsystems
    if BRutus.DataCollector then
        BRutus.DataCollector:Initialize()
    end
    if BRutus.AttunementTracker then
        BRutus.AttunementTracker:Initialize()
    end
    if BRutus.CommSystem then
        BRutus.CommSystem:Initialize()
    end
    if BRutus.Recruitment then
        BRutus.Recruitment:Initialize()
    end

    -- Request guild roster
    if IsInGuild() then
        C_GuildInfo.GuildRoster()
    end

    -- Hook into default guild frame so BRutus opens instead
    BRutus:HookGuildFrame()
end

function BRutus:OnEnterWorld()
    -- Collect own data after a short delay
    C_Timer.After(3, function()
        if BRutus.DataCollector then
            BRutus.DataCollector:CollectMyData()
        end
        if BRutus.AttunementTracker then
            BRutus.AttunementTracker:ScanAttunements()
        end
        -- Broadcast our data to guildies
        C_Timer.After(2, function()
            if BRutus.CommSystem then
                BRutus.CommSystem:BroadcastMyData()
            end
        end)
    end)
end

function BRutus:OnGuildRosterUpdate()
    if BRutus.RosterFrame and BRutus.RosterFrame:IsShown() then
        BRutus.RosterFrame:RefreshRoster()
    end
end

----------------------------------------------------------------------
-- Slash Commands
----------------------------------------------------------------------
SLASH_BRUTUS1 = "/brutus"
SLASH_BRUTUS2 = "/br"
SlashCmdList["BRUTUS"] = function(msg)
    msg = strtrim(msg or "")
    if msg == "scan" then
        if BRutus.DataCollector then
            BRutus.DataCollector:CollectMyData()
            BRutus:Print("Data collected.")
        end
    elseif msg == "sync" then
        if BRutus.CommSystem then
            BRutus.CommSystem:BroadcastMyData()
            BRutus:Print("Broadcasting data to guild...")
        end
    elseif msg == "reset" then
        BRutusDB = nil
        ReloadUI()
    elseif msg:match("^recruit") then
        local rest = msg:gsub("^recruit%s*", "")
        local args = {}
        for word in rest:gmatch("%S+") do
            table.insert(args, word)
        end
        if BRutus.Recruitment then
            BRutus.Recruitment:HandleCommand(args)
        end
    else
        BRutus:ToggleRoster()
    end
end

----------------------------------------------------------------------
-- Hook into the default Blizzard guild frame
----------------------------------------------------------------------
function BRutus:HookGuildFrame()
    -- Replace ToggleGuildFrame (called by J keybind and guild micro button)
    if ToggleGuildFrame then
        local originalToggleGuildFrame = ToggleGuildFrame
        ToggleGuildFrame = function()
            if IsInGuild() then
                BRutus:ToggleRoster()
            else
                originalToggleGuildFrame()
            end
        end
    end

    -- Also hook ToggleFriendsFrame for guild tab (tab 3)
    if ToggleFriendsFrame then
        local originalToggleFriendsFrame = ToggleFriendsFrame
        ToggleFriendsFrame = function(tabNumber, ...)
            if tabNumber == 3 and IsInGuild() then
                BRutus:ToggleRoster()
                return
            end
            return originalToggleFriendsFrame(tabNumber, ...)
        end
    end
end

----------------------------------------------------------------------
-- Toggle main roster window
----------------------------------------------------------------------
function BRutus:ToggleRoster()
    if not self.RosterFrame then
        self.RosterFrame = BRutus.CreateRosterFrame()
    end
    if self.RosterFrame:IsShown() then
        self.RosterFrame:Hide()
    else
        if IsInGuild() then
            C_GuildInfo.GuildRoster()
        end
        self.RosterFrame:UpdateTabVisibility()
        self.RosterFrame:SetActiveTab(self.RosterFrame.activeTab or "roster")
        self.RosterFrame:Show()
        self.RosterFrame:RefreshRoster()
    end
end

----------------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------------
function BRutus:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD700[BRutus]|r " .. tostring(msg))
end

function BRutus:IsOfficer()
    if not IsInGuild() then return false end
    local _, _, rankIndex = GetGuildInfo("player")
    if not rankIndex then return false end
    -- Check by rank index OR by CanGuildInvite permission
    return rankIndex <= 2 or CanGuildInvite()
end

function BRutus:DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == "table" then
            copy[k] = self:DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function BRutus:GetClassColor(class)
    local c = self.ClassColors[class]
    if c then
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end

function BRutus:GetClassColorHex(class)
    local r, g, b = self:GetClassColor(class)
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end

function BRutus:ColorText(text, r, g, b)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

function BRutus:FormatItemLevel(ilvl)
    if not ilvl or ilvl == 0 then return "|cff888888--|r" end
    local color
    if ilvl >= 141 then      -- T6+
        color = self.QualityColors[5]
    elseif ilvl >= 128 then   -- T5
        color = self.QualityColors[4]
    elseif ilvl >= 110 then   -- T4/Heroic
        color = self.QualityColors[3]
    elseif ilvl >= 85 then    -- Normal dungeons
        color = self.QualityColors[2]
    else
        color = self.QualityColors[1]
    end
    return self:ColorText(tostring(ilvl), color.r, color.g, color.b)
end

function BRutus:GetPlayerKey(name, realm)
    realm = realm or GetRealmName()
    return name .. "-" .. realm
end

function BRutus:TimeAgo(timestamp)
    if not timestamp or timestamp == 0 then return "Never" end
    local diff = time() - timestamp
    if diff < 60 then return "Just now"
    elseif diff < 3600 then return math.floor(diff / 60) .. "m ago"
    elseif diff < 86400 then return math.floor(diff / 3600) .. "h ago"
    else return math.floor(diff / 86400) .. "d ago"
    end
end
