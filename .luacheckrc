-- Luacheck configuration for BRutus WoW Addon

std = "lua51"
max_line_length = false

-- WoW global API and environment
globals = {
    -- Addon globals
    "BRutus",
    "BRutusDB",

    -- WoW API frames and widgets
    "CreateFrame",
    "UIParent",
    "GameTooltip",
    "GameFontNormal",
    "GameFontNormalSmall",
    "GameFontHighlight",
    "GameFontHighlightSmall",
    "GameFontNormalLarge",
    "ChatFontNormal",
    "UISpecialFrames",
    "BackdropTemplateMixin",
    "STANDARD_TEXT_FONT",
    "DEFAULT_CHAT_FRAME",
    "FACTION_BAR_COLORS",
    "RAID_CLASS_COLORS",

    -- WoW API functions
    "SendChatMessage",
    "SendAddonMessage",
    "RegisterAddonMessagePrefix",
    "C_GuildInfo",
    "C_Timer",
    "GetGuildRosterInfo",
    "GetNumGuildMembers",
    "GuildRoster",
    "GetGuildRosterMOTD",
    "GetInventoryItemLink",
    "GetInventoryItemTexture",
    "GetInventoryItemQuality",
    "GetItemInfo",
    "GetItemQualityColor",
    "IsInGuild",
    "CanGuildInvite",
    "GuildInvite",
    "GetRealmName",
    "UnitName",
    "UnitClass",
    "UnitRace",
    "UnitLevel",
    "UnitFactionGroup",
    "UnitGUID",
    "GetAverageItemLevel",
    "GetTime",
    "GetServerTime",
    "GetQuestLogTitle",
    "GetNumQuestLogEntries",
    "GetQuestLogIndexByID",
    "IsQuestFlaggedCompleted",
    "C_QuestLog",
    "GetFactionInfoByID",
    "PlaySound",
    "SOUNDKIT",
    "hooksecurefunc",
    "securecallfunction",
    "StaticPopup_Show",
    "StaticPopupDialogs",
    "ToggleGuildFrame",
    "ToggleFriendsFrame",
    "GuildFrame",
    "FriendsFrame",
    "ShowUIPanel",
    "HideUIPanel",
    "InterfaceOptionsFrame_OpenToCategory",

    -- WoW scroll frame API
    "FauxScrollFrame_Update",
    "FauxScrollFrame_GetOffset",
    "FauxScrollFrame_OnVerticalScroll",

    -- String/Table
    "strsplit",
    "strtrim",
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

    -- Slash commands
    "SlashCmdList",
    "SLASH_BRUTUS1",
    "SLASH_BRUTUS2",
    "hash_SlashCmdList",

    -- Chat
    "ChatFrame_AddMessageEventFilter",
    "JoinChannelByName",
    "GetChannelName",
    "EnumerateServerChannels",

    -- Libraries
    "LibStub",
}

-- Files in Libs/ are third-party and should not be linted
exclude_files = {
    "Libs/**",
}

-- Ignore unused self parameter (common in WoW event handlers)
ignore = {
    "212/self",
}
