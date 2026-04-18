-- Luacheck configuration for BRutus WoW Addon

std = "lua51"
max_line_length = false

-- Globals that the addon WRITES to
globals = {
    -- Addon tables
    "BRutus",
    "BRutusDB",

    -- Slash commands
    "SlashCmdList",
    "SLASH_BRUTUS1",
    "SLASH_BRUTUS2",

    -- Hooked/overwritten globals
    "ToggleGuildFrame",
    "ToggleFriendsFrame",

    -- Implicit globals defined across files (functions shared between modules)
    "CreateRosterRow",
    "UpdateRosterRow",
    "ShowRowTooltip",
    "CreateDetailFrame",
    "PopulateDetail",
    "CreateSectionHeader",
    "CreateGearRow",
    "CreateProfessionRow",
    "CreateAttunementRow",

    -- Tables written to
    "UISpecialFrames",
}

-- Globals that the addon READS (WoW environment)
read_globals = {
    -- WoW API: Frames & UI
    "CreateFrame",
    "CreateColor",
    "UIParent",
    "GameTooltip",
    "GameFontNormal",
    "GameFontNormalSmall",
    "GameFontHighlight",
    "GameFontHighlightSmall",
    "GameFontNormalLarge",
    "ChatFontNormal",
    "BackdropTemplateMixin",
    "STANDARD_TEXT_FONT",
    "DEFAULT_CHAT_FRAME",

    -- WoW API: C_ namespaces
    "C_Timer",
    "C_ChatInfo",
    "C_GuildInfo",
    "C_QuestLog",

    -- WoW API: Unit functions
    "UnitName",
    "UnitClass",
    "UnitLevel",
    "UnitRace",
    "UnitFactionGroup",
    "UnitGUID",
    "UnitHealthMax",
    "UnitPowerMax",
    "UnitStat",

    -- WoW API: Guild functions
    "IsInGuild",
    "CanGuildInvite",
    "GuildInvite",
    "GetGuildInfo",
    "GetGuildRosterInfo",
    "GetNumGuildMembers",
    "GetGuildRosterMOTD",
    "GuildRoster",

    -- WoW API: Inventory & Items
    "GetInventoryItemLink",
    "GetInventoryItemTexture",
    "GetInventoryItemQuality",
    "GetItemInfo",
    "GetItemQualityColor",
    "GetAverageItemLevel",

    -- WoW API: Skills & Professions
    "GetNumSkillLines",
    "GetSkillLineInfo",

    -- WoW API: Quest & Reputation
    "GetQuestLogTitle",
    "GetNumQuestLogEntries",
    "GetQuestLogIndexByID",
    "IsQuestFlaggedCompleted",
    "GetFactionInfoByID",

    -- WoW API: Chat & Communication
    "SendChatMessage",
    "SendAddonMessage",
    "RegisterAddonMessagePrefix",
    "GetChannelName",
    "JoinChannelByName",
    "EnumerateServerChannels",
    "ChatFrame_AddMessageEventFilter",

    -- WoW API: Miscellaneous
    "GetRealmName",
    "GetTime",
    "GetServerTime",
    "ReloadUI",
    "InCombatLockdown",
    "PlaySound",
    "hooksecurefunc",
    "securecallfunction",
    "StaticPopup_Show",

    -- WoW API: Scroll frames
    "FauxScrollFrame_Update",
    "FauxScrollFrame_GetOffset",
    "FauxScrollFrame_OnVerticalScroll",

    -- WoW API: Frame management
    "GuildFrame",
    "FriendsFrame",
    "ShowUIPanel",
    "HideUIPanel",
    "InterfaceOptionsFrame_OpenToCategory",

    -- WoW Global constants & tables
    "SOUNDKIT",
    "CLASS_ICON_TCOORDS",
    "FACTION_BAR_COLORS",
    "RAID_CLASS_COLORS",
    "ERR_GUILD_JOIN_S",
    "StaticPopupDialogs",

    -- WoW Lua aliases (not in std lua51)
    "strsplit",
    "strtrim",
    "strlower",
    "strjoin",
    "tinsert",
    "tremove",
    "wipe",
    "date",
    "time",
    "format",
    "floor",
    "ceil",
    "min",
    "max",
    "abs",
    "random",
    "tContains",
    "CopyTable",

    -- WoW API: Key modifiers
    "IsAltKeyDown",
    "SetItemRef",

    -- Tooltip frames
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",

    -- Libraries
    "LibStub",
    "ChatThrottleLib",
}

-- Third-party libraries — skip
exclude_files = {
    "Libs/**",
}

-- Ignore unused self and shadowing of self (common in WoW callbacks/event handlers)
ignore = {
    "212/self",  -- unused argument self
    "431/self",  -- shadowing upvalue self
    "432/self",  -- shadowing upvalue argument self
}
