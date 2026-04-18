----------------------------------------------------------------------
-- BRutus Guild Manager - Recruitment System
-- Automatic recruitment messages + right-click guild invite
-- Only officers (rank index <= 1) or configurable rank can use this
----------------------------------------------------------------------
local Recruitment = {}
BRutus.Recruitment = Recruitment

-- Defaults
Recruitment.DEFAULT_SETTINGS = {
    enabled = false,
    interval = 120,           -- seconds between messages
    message = "",             -- recruitment message text
    channels = {},            -- list of channel names to post to (e.g. {"LookingForGroup", "Trade"})
    minRankIndex = 2,         -- max rank index allowed (0 = GM, 1 = first officer, 2 = second officer, etc.)
    welcomeEnabled = true,
    welcomeMessage = "",      -- auto-filled on init
    discord = "https://discord.gg/6bcyPZ2UUC",
}

Recruitment.ticker = nil
Recruitment.lastSend = 0

----------------------------------------------------------------------
-- Initialize
----------------------------------------------------------------------
function Recruitment:Initialize()
    -- Ensure DB settings exist
    if not BRutus.db.recruitment then
        BRutus.db.recruitment = BRutus:DeepCopy(self.DEFAULT_SETTINGS)
    end
    local r = BRutus.db.recruitment
    -- Fill missing keys
    for k, v in pairs(self.DEFAULT_SETTINGS) do
        if r[k] == nil then
            if type(v) == "table" then
                r[k] = BRutus:DeepCopy(v)
            else
                r[k] = v
            end
        end
    end

    -- Set default channels if empty
    if #r.channels == 0 then
        r.channels = { "LookingForGroup" }
    end

    -- Set default message if empty
    if r.message == "" then
        local guildName = GetGuildInfo("player") or "our guild"
        r.message = guildName .. " is recruiting! All classes and roles welcome. Whisper me for info or invite!"
    end

    -- Hook right-click menu for guild invite
    self:HookChatInvite()

    -- Set default welcome message if empty
    if r.welcomeMessage == "" then
        local guildName = GetGuildInfo("player") or "our guild"
        r.welcomeMessage = "Welcome to " .. guildName .. "! Join our Discord: " .. r.discord .. " — Have fun!"
    end

    -- Listen for new guild members joining
    self:RegisterWelcomeEvent()

    -- Resume if was enabled
    if r.enabled and self:CanUseRecruitment() then
        self:StartAutoRecruit()
    end
end

----------------------------------------------------------------------
-- Permission check: is the player officer or above?
----------------------------------------------------------------------
function Recruitment:CanUseRecruitment()
    if not IsInGuild() then return false end
    local _, _, rankIndex = GetGuildInfo("player")
    if not rankIndex then return false end
    return rankIndex <= (BRutus.db.recruitment.minRankIndex or 2) or CanGuildInvite()
end

----------------------------------------------------------------------
-- Start automatic recruitment
----------------------------------------------------------------------
function Recruitment:StartAutoRecruit()
    if not self:CanUseRecruitment() then
        BRutus:Print("|cffFF4444You don't have permission to use recruitment.|r")
        return false
    end

    local settings = BRutus.db.recruitment
    settings.enabled = true

    -- Stop existing ticker
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end

    local interval = math.max(settings.interval, 60) -- minimum 60s safety

    self.ticker = C_Timer.NewTicker(interval, function()
        self:SendRecruitmentMessage()
    end)

    -- Send first message after a short delay
    C_Timer.After(2, function()
        self:SendRecruitmentMessage()
    end)

    BRutus:Print("Recruitment |cff4CFF4Cstarted|r — posting every " .. interval .. "s.")
    return true
end

----------------------------------------------------------------------
-- Stop automatic recruitment
----------------------------------------------------------------------
function Recruitment:StopAutoRecruit()
    BRutus.db.recruitment.enabled = false
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    BRutus:Print("Recruitment |cffFF4444stopped|r.")
end

----------------------------------------------------------------------
-- Toggle recruitment
----------------------------------------------------------------------
function Recruitment:Toggle()
    if BRutus.db.recruitment.enabled then
        self:StopAutoRecruit()
    else
        self:StartAutoRecruit()
    end
    return BRutus.db.recruitment.enabled
end

----------------------------------------------------------------------
-- Send the recruitment message to configured channels
-- Uses a secure frame to avoid taint issues with SendChatMessage
----------------------------------------------------------------------
function Recruitment:SendRecruitmentMessage()
    if not IsInGuild() then return end
    if not self:CanUseRecruitment() then
        self:StopAutoRecruit()
        return
    end
    if InCombatLockdown() then return end -- never send during combat

    local settings = BRutus.db.recruitment
    local msg = settings.message
    if not msg or msg == "" then return end

    -- Throttle safety
    local now = GetTime()
    if now - self.lastSend < 30 then return end
    self.lastSend = now

    -- Queue messages through OnUpdate to avoid taint from C_Timer
    if not self.sendFrame then
        self.sendFrame = CreateFrame("Frame")
    end
    self.pendingSends = {}
    for _, channelName in ipairs(settings.channels) do
        local channelNum = GetChannelName(channelName)
        if channelNum and channelNum > 0 then
            table.insert(self.pendingSends, { msg = msg, channel = channelNum })
        end
    end

    if #self.pendingSends > 0 then
        self.sendFrame:SetScript("OnUpdate", function(frame)
            frame:SetScript("OnUpdate", nil)
            if InCombatLockdown() then return end
            for _, info in ipairs(self.pendingSends) do
                SendChatMessage(info.msg, "CHANNEL", nil, info.channel)
            end
            self.pendingSends = nil
        end)
    end
end

----------------------------------------------------------------------
-- Right-click guild invite (slash command based - no dropdown hook to avoid taint)
-- Usage: /brutus invite PlayerName
----------------------------------------------------------------------
function Recruitment:HookChatInvite()
    -- No dropdown hooks - they cause taint errors.
    -- Guild invite is available via /brutus invite <name>
end

----------------------------------------------------------------------
-- Slash command handler
----------------------------------------------------------------------
function Recruitment:HandleCommand(args)
    local cmd = args[1]

    if cmd == "on" or cmd == "start" then
        self:StartAutoRecruit()
    elseif cmd == "off" or cmd == "stop" then
        self:StopAutoRecruit()
    elseif cmd == "msg" or cmd == "message" then
        table.remove(args, 1)
        local newMsg = table.concat(args, " ")
        if newMsg and newMsg ~= "" then
            BRutus.db.recruitment.message = newMsg
            BRutus:Print("Recruitment message set to: |cffFFFFFF" .. newMsg .. "|r")
        else
            BRutus:Print("Current message: |cffFFFFFF" .. (BRutus.db.recruitment.message or "(empty)") .. "|r")
        end
    elseif cmd == "interval" then
        local secs = tonumber(args[2])
        if secs and secs >= 60 then
            BRutus.db.recruitment.interval = secs
            BRutus:Print("Recruitment interval set to |cffFFFFFF" .. secs .. "s|r.")
            -- Restart if active
            if BRutus.db.recruitment.enabled then
                self:StopAutoRecruit()
                self:StartAutoRecruit()
            end
        else
            BRutus:Print("Usage: /brutus recruit interval <seconds> (min 60)")
        end
    elseif cmd == "channel" then
        local action = args[2]
        local chName = args[3]
        if action == "add" and chName then
            table.insert(BRutus.db.recruitment.channels, chName)
            BRutus:Print("Added channel: |cffFFFFFF" .. chName .. "|r")
        elseif action == "remove" and chName then
            local channels = BRutus.db.recruitment.channels
            for i = #channels, 1, -1 do
                if channels[i]:lower() == chName:lower() then
                    table.remove(channels, i)
                    BRutus:Print("Removed channel: |cffFFFFFF" .. chName .. "|r")
                    return
                end
            end
            BRutus:Print("Channel not found: " .. chName)
        elseif action == "list" then
            local list = table.concat(BRutus.db.recruitment.channels, ", ")
            BRutus:Print("Channels: |cffFFFFFF" .. (list ~= "" and list or "(none)") .. "|r")
        else
            BRutus:Print("Usage: /brutus recruit channel <add|remove|list> [name]")
        end
    elseif cmd == "status" then
        local s = BRutus.db.recruitment
        local status = s.enabled and "|cff4CFF4CON|r" or "|cffFF4444OFF|r"
        local wStatus = s.welcomeEnabled and "|cff4CFF4CON|r" or "|cffFF4444OFF|r"
        BRutus:Print("--- Recruitment Status ---")
        BRutus:Print("Active: " .. status)
        BRutus:Print("Interval: |cffFFFFFF" .. s.interval .. "s|r")
        BRutus:Print("Channels: |cffFFFFFF" .. table.concat(s.channels, ", ") .. "|r")
        BRutus:Print("Message: |cffFFFFFF" .. s.message .. "|r")
        BRutus:Print("Welcome: " .. wStatus)
        BRutus:Print("Welcome msg: |cffFFFFFF" .. s.welcomeMessage .. "|r")
        BRutus:Print("Discord: |cffFFFFFF" .. s.discord .. "|r")
    elseif cmd == "welcome" then
        local sub = args[2]
        if sub == "on" then
            BRutus.db.recruitment.welcomeEnabled = true
            BRutus:Print("Welcome message |cff4CFF4Cenabled|r.")
        elseif sub == "off" then
            BRutus.db.recruitment.welcomeEnabled = false
            BRutus:Print("Welcome message |cffFF4444disabled|r.")
        elseif sub == "msg" then
            table.remove(args, 1)
            table.remove(args, 1)
            local newMsg = table.concat(args, " ")
            if newMsg and newMsg ~= "" then
                BRutus.db.recruitment.welcomeMessage = newMsg
                BRutus:Print("Welcome message set to: |cffFFFFFF" .. newMsg .. "|r")
            else
                BRutus:Print("Current: |cffFFFFFF" .. BRutus.db.recruitment.welcomeMessage .. "|r")
            end
        else
            BRutus:Print("Usage: /brutus recruit welcome <on|off|msg> [text]")
        end
    elseif cmd == "discord" then
        local link = args[2]
        if link and link ~= "" then
            BRutus.db.recruitment.discord = link
            BRutus:Print("Discord link set to: |cffFFFFFF" .. link .. "|r")
        else
            BRutus:Print("Discord: |cffFFFFFF" .. BRutus.db.recruitment.discord .. "|r")
        end
    elseif cmd == "invite" then
        local target = args[2]
        if target and target ~= "" then
            if not CanGuildInvite() then
                BRutus:Print("|cffFF4444You don't have permission to invite.|r")
                return
            end
            GuildInvite(target)
            BRutus:Print("Guild invite sent to |cffFFFFFF" .. target .. "|r.")
        else
            BRutus:Print("Usage: /brutus recruit invite <PlayerName>")
        end
    else
        BRutus:Print("|cffFFD700Recruitment commands:|r")
        BRutus:Print("  /brutus recruit on/off")
        BRutus:Print("  /brutus recruit status")
        BRutus:Print("  /brutus recruit msg <text>")
        BRutus:Print("  /brutus recruit interval <seconds>")
        BRutus:Print("  /brutus recruit channel add/remove/list <name>")
        BRutus:Print("  /brutus recruit welcome on/off/msg <text>")
        BRutus:Print("  /brutus recruit discord <link>")
        BRutus:Print("  /brutus recruit invite <PlayerName>")
    end
end

----------------------------------------------------------------------
-- Welcome message for new guild members
----------------------------------------------------------------------
function Recruitment:RegisterWelcomeEvent()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_SYSTEM")
    frame:SetScript("OnEvent", function(_, event, msg)
        if event ~= "CHAT_MSG_SYSTEM" then return end
        if not BRutus.db.recruitment.welcomeEnabled then return end
        if not IsInGuild() then return end

        -- Detect "PlayerName has joined the guild." pattern
        -- ERR_GUILD_JOIN_S = "%s has joined the guild."
        local joinPattern = ERR_GUILD_JOIN_S and ERR_GUILD_JOIN_S:gsub("%%s", "(.+)") or "(.+) has joined the guild%."
        local newMember = msg:match(joinPattern)
        if not newMember then return end

        -- Don't welcome ourselves
        local myName = UnitName("player")
        if newMember == myName then return end

        -- Send welcome whisper after a short delay
        C_Timer.After(3, function()
            local settings = BRutus.db.recruitment
            local welcomeMsg = settings.welcomeMessage
            if welcomeMsg and welcomeMsg ~= "" then
                SendChatMessage(welcomeMsg, "WHISPER", nil, newMember)
                BRutus:Print("Welcome message sent to |cffFFFFFF" .. newMember .. "|r.")
            end
        end)
    end)
end
