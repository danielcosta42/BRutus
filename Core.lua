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
        modules = {
            raidTracker = true,
            lootTracker = true,
            lootMaster = true,
            consumableChecker = true,
            recruitment = true,
            trialTracker = true,
            officerNotes = true,
            tmb = true,
            commSystem = true,
        },
    },
    myData = {},
    lastSync = 0,
    tmb = {
        data = {},
        itemNotes = {},
        lastImport = 0,
        importedBy = "",
    },
    raidTracker = {
        sessions = {},
        attendance = {},
    },
    lootHistory = {},
    lootMaster = {
        rollDuration = 30,
        autoAnnounce = true,
        tmbOnlyMode = false,
        awardHistory = {},
    },
    officerNotes = {},
    trials = {},
    consumableChecks = { lastResults = {} },

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
    -- Module enabled helper
    local function modEnabled(key)
        if not self.db.settings or not self.db.settings.modules then return true end
        return self.db.settings.modules[key] ~= false
    end

    -- Initialize subsystems (always-on)
    if BRutus.DataCollector then
        BRutus.DataCollector:Initialize()
    end
    if BRutus.AttunementTracker then
        BRutus.AttunementTracker:Initialize()
    end
    if BRutus.CommSystem and modEnabled("commSystem") then
        BRutus.CommSystem:Initialize()
    end
    if BRutus.TMB and modEnabled("tmb") then
        BRutus.TMB:Initialize()
    end
    if BRutus.RaidTracker and modEnabled("raidTracker") then
        BRutus.RaidTracker:Initialize()
    end
    if BRutus.LootTracker and modEnabled("lootTracker") then
        BRutus.LootTracker:Initialize()
    end
    if BRutus.LootMaster and modEnabled("lootMaster") then
        BRutus.LootMaster:Initialize()
    end
    if BRutus.ConsumableChecker and modEnabled("consumableChecker") then
        BRutus.ConsumableChecker:Initialize()
    end
    if BRutus.RecipeTracker then
        BRutus.RecipeTracker:Initialize()
    end

    -- Officer-only modules: defer init until guild info is available
    C_Timer.After(5, function()
        if not BRutus:IsOfficer() then return end

        if BRutus.Recruitment and modEnabled("recruitment") then
            BRutus.Recruitment:Initialize()
        end
        if BRutus.OfficerNotes and modEnabled("officerNotes") then
            BRutus.OfficerNotes:Initialize()
        end
        if BRutus.TrialTracker and modEnabled("trialTracker") then
            BRutus.TrialTracker:Initialize()
            BRutus.TrialTracker:CheckExpired()
        end
    end)


    -- Hook chat player links for guild invite
    BRutus:HookChatInvite()

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
        -- Check profession freshness after data is collected
        C_Timer.After(4, function()
            BRutus:CheckProfessionFreshness()
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
    elseif msg == "consumables" or msg == "cons" then
        if BRutus.ConsumableChecker then
            local results = BRutus.ConsumableChecker:CheckRaid()
            if results then
                local missing = BRutus.ConsumableChecker:GetMissingCount(results)
                BRutus:Print("Consumable check done. " .. missing .. " players missing buffs.")
            end
        end
    elseif msg == "consreport" then
        if BRutus.ConsumableChecker then
            BRutus.ConsumableChecker:ReportToChat("RAID")
        end
    elseif msg:match("^trial") then
        local rest = msg:gsub("^trial%s*", "")
        local name = rest:match("^(%S+)")
        if name and BRutus.TrialTracker then
            local realm = GetRealmName()
            local key = name .. "-" .. realm
            BRutus.TrialTracker:AddTrial(key)
        else
            BRutus:Print("Usage: /brutus trial <PlayerName>")
        end
    elseif msg:match("^note") then
        local rest = msg:gsub("^note%s*", "")
        local target, noteText = rest:match("^(%S+)%s+(.+)$")
        if target and noteText and BRutus.OfficerNotes then
            local realm = GetRealmName()
            local key = target .. "-" .. realm
            if BRutus.OfficerNotes:AddNote(key, noteText) then
                BRutus:Print("Note added for " .. target)
            end
        else
            BRutus:Print("Usage: /brutus note <PlayerName> <text>")
        end
    elseif msg == "lm" or msg == "lootmaster" then
        if BRutus.LootMaster then
            if BRutus.LootMaster:IsMasterLooter() then
                BRutus:Print("Loot Master mode active. Open loot to start.")
            else
                BRutus:Print("You are not the Master Looter.")
            end
        end
    elseif msg:match("^lm announce") then
        -- /brutus lm announce - manually announce item from target tooltip
        BRutus:Print("Open loot window as Master Looter to announce items.")
    elseif msg == "exportatt" or msg == "exportattendance" then
        if BRutus.RaidTracker then
            local json, err = BRutus.RaidTracker:ExportForTMB()
            if json then
                BRutus:ShowExportPopup("TMB Attendance Export", json)
            else
                BRutus:Print("|cffFF4444Export failed:|r " .. (err or "unknown error"))
            end
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
        -- Reset to roster if current tab is officer-only and player isn't officer
        local currentTab = self.RosterFrame.activeTab or "roster"
        for _, tab in ipairs(self.RosterFrame.tabs) do
            if tab.key == currentTab and tab.officerOnly and not self:IsOfficer() then
                currentTab = "roster"
                break
            end
        end
        self.RosterFrame:SetActiveTab(currentTab)
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
    -- Ranks 0-2: GM Estrategista, Doutrinador, Oficial
    return rankIndex <= 2
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

----------------------------------------------------------------------
-- Chat Player Link: Guild Invite
-- Alt+Click a player name in chat to send a guild invite
----------------------------------------------------------------------
function BRutus:HookChatInvite()
    hooksecurefunc("SetItemRef", function(link, _, button)
        if not CanGuildInvite() then return end
        if button ~= "LeftButton" or not IsAltKeyDown() then return end
        if not link then return end

        local name = link:match("^player:([^:]+)")
        if name and name ~= "" then
            GuildInvite(name)
            BRutus:Print("Guild invite sent to " .. name .. ". (Alt+Click)")
        end
    end)
end

----------------------------------------------------------------------
-- Profession Freshness Check & Reminder
----------------------------------------------------------------------
local STALE_THRESHOLD = 86400 -- 24 hours

function BRutus:GetStaleProfessions()
    local myData = self.db and self.db.myData
    if not myData or not myData.professions then return {} end

    local scanTimes = BRutusDB.recipeScanTimes or {}
    local stale = {}
    local now = time()

    local DC = self.DataCollector
    for _, prof in ipairs(myData.professions) do
        local isGathering = DC and DC.IsGatheringProfession and DC:IsGatheringProfession(prof.name)
        if prof.isPrimary and prof.name and not isGathering then
            local lastScan = scanTimes[prof.name]
            if not lastScan or (now - lastScan) > STALE_THRESHOLD then
                table.insert(stale, prof.name)
            end
        end
    end

    return stale
end

function BRutus:CheckProfessionFreshness()
    local stale = self:GetStaleProfessions()
    if #stale == 0 then return end

    self:ShowProfessionReminder(stale)
    self:Print("|cffFFAA00You have " .. #stale .. " profession(s) with outdated recipe data.|r Open them to sync!")
end

function BRutus:ShowProfessionReminder(staleProfessions)
    if self.profReminderFrame then
        self.profReminderFrame:Hide()
        self.profReminderFrame = nil
    end

    local C = self.Colors

    local frame = CreateFrame("Frame", "BRutusProfReminder", UIParent, "BackdropTemplate")
    frame:SetSize(420, 70)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -80)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.06, 0.06, 0.10, 0.95)
    frame:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.8)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Accent stripe on top
    local stripe = frame:CreateTexture(nil, "ARTWORK")
    stripe:SetTexture("Interface\\Buttons\\WHITE8x8")
    stripe:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.9)
    stripe:SetHeight(2)
    stripe:SetPoint("TOPLEFT", 1, -1)
    stripe:SetPoint("TOPRIGHT", -1, -1)

    -- Icon (trade skill icon)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 12, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")

    -- Title
    local titleFS = frame:CreateFontString(nil, "OVERLAY")
    titleFS:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    titleFS:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
    titleFS:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    titleFS:SetText("BRutus — Profession Sync Required")

    -- Description
    local profNames = table.concat(staleProfessions, ", ")
    local descFS = frame:CreateFontString(nil, "OVERLAY")
    descFS:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    descFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -4)
    descFS:SetWidth(320)
    descFS:SetJustifyH("LEFT")
    descFS:SetWordWrap(true)
    descFS:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    descFS:SetText("Open your profession windows to update recipe data:\n|cffFFFFFF" .. profNames .. "|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetNormalFontObject(GameFontNormalSmall)

    local closeFS = closeBtn:CreateFontString(nil, "OVERLAY")
    closeFS:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    closeFS:SetPoint("CENTER", 0, 0)
    closeFS:SetText("x")
    closeFS:SetTextColor(C.silver.r, C.silver.g, C.silver.b)

    closeBtn:SetScript("OnEnter", function()
        closeFS:SetTextColor(C.red.r, C.red.g, C.red.b)
    end)
    closeBtn:SetScript("OnLeave", function()
        closeFS:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    end)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
        BRutus.profReminderFrame = nil
    end)

    -- Fade in
    frame:SetAlpha(0)
    frame:Show()
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < 0.3 then
            self:SetAlpha(elapsed / 0.3)
        else
            self:SetAlpha(1)
            self:SetScript("OnUpdate", nil)
        end
    end)

    self.profReminderFrame = frame
    self.profReminderStale = {}
    for _, name in ipairs(staleProfessions) do
        self.profReminderStale[name] = true
    end
end

function BRutus:CheckAndDismissProfessionReminder()
    if not self.profReminderFrame or not self.profReminderStale then return end

    local scanTimes = BRutusDB.recipeScanTimes or {}
    local now = time()

    for profName, _ in pairs(self.profReminderStale) do
        local lastScan = scanTimes[profName]
        if lastScan and (now - lastScan) <= STALE_THRESHOLD then
            self.profReminderStale[profName] = nil
        end
    end

    -- Check if any are still stale
    if not next(self.profReminderStale) then
        local frame = self.profReminderFrame
        -- Fade out
        local elapsed = 0
        frame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed < 0.5 then
                self:SetAlpha(1 - (elapsed / 0.5))
            else
                self:Hide()
                self:SetScript("OnUpdate", nil)
                BRutus.profReminderFrame = nil
                BRutus.profReminderStale = nil
            end
        end)
        BRutus:Print("|cff00ff00All professions synced!|r Recipe data is up to date.")
    end
end

function BRutus:DismissProfessionReminder()
    if self.profReminderFrame then
        self.profReminderFrame:Hide()
        self.profReminderFrame = nil
        self.profReminderStale = nil
    end
end
