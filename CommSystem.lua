----------------------------------------------------------------------
-- BRutus Guild Manager - Communication System
-- Handles addon-to-addon communication for syncing member data
----------------------------------------------------------------------
local CommSystem = {}
BRutus.CommSystem = CommSystem

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

-- Message types
CommSystem.MSG_TYPES = {
    BROADCAST = "BC",    -- Full data broadcast
    REQUEST   = "RQ",    -- Request data from someone
    RESPONSE  = "RS",    -- Response to a request
    PING      = "PI",    -- Presence ping
    PONG      = "PO",    -- Presence response
    VERSION   = "VR",    -- Version check
    ALT_LINK  = "AL",    -- Alt/main link table sync (officer only)
}

-- Throttle settings
CommSystem.THROTTLE_INTERVAL = 5  -- seconds between broadcasts
CommSystem.lastBroadcast = 0

function CommSystem:Initialize()
    -- Register for addon messages
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, _, prefix, msg, channel, sender)
        if prefix == BRutus.PREFIX then
            CommSystem:OnMessageReceived(msg, channel, sender)
        end
    end)

    -- Periodic sync timer (every 5 minutes)
    C_Timer.NewTicker(300, function()
        if IsInGuild() then
            CommSystem:BroadcastMyData()
            -- Officers also re-broadcast trial data periodically
            if BRutus:IsOfficer() and BRutus.TrialTracker then
                C_Timer.After(5, function()
                    BRutus.TrialTracker:BroadcastTrials()
                end)
            end
        end
    end)

    -- Request data from online guildies after init
    C_Timer.After(8, function()
        CommSystem:RequestAllData()
    end)
end

-- Chunking settings
CommSystem.CHUNK_SIZE = 230  -- Leave room for chunk header + "M:xxxx:nn:nn:"
CommSystem.pendingMessages = {}  -- [sender] = { chunks = {}, total = 0, received = 0 }

----------------------------------------------------------------------
-- Send a message to guild (with chunking for large payloads)
----------------------------------------------------------------------
function CommSystem:SendMessage(msgType, data, target)
    local payload = msgType .. ":" .. (data or "")

    -- Compress
    local compressed = LibDeflate:CompressDeflate(payload)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)

    local len = #encoded
    if len <= 253 then
        -- Single message, no chunking needed (prefix with "S:")
        local msg = "S:" .. encoded
        self:SendRaw(msg, target)
    else
        -- Multi-chunk: prefix each with "M:chunkIndex:totalChunks:msgId:"
        local msgId = string.format("%X", math.random(0, 0xFFFF))
        local totalChunks = math.ceil(len / self.CHUNK_SIZE)
        for i = 1, totalChunks do
            local startPos = (i - 1) * self.CHUNK_SIZE + 1
            local endPos = math.min(i * self.CHUNK_SIZE, len)
            local chunk = encoded:sub(startPos, endPos)
            local header = string.format("M:%s:%d:%d:", msgId, i, totalChunks)
            C_Timer.After((i - 1) * 0.1, function()
                self:SendRaw(header .. chunk, target)
            end)
        end
    end
end

function CommSystem:SendRaw(msg, target)
    if target then
        ChatThrottleLib:SendAddonMessage("NORMAL", BRutus.PREFIX, msg, "WHISPER", target)
    else
        ChatThrottleLib:SendAddonMessage("BULK", BRutus.PREFIX, msg, "GUILD")
    end
end

----------------------------------------------------------------------
-- Receive a message
----------------------------------------------------------------------
function CommSystem:OnMessageReceived(msg, _, sender)
    -- Don't process our own messages
    local myName = UnitName("player")
    if sender == myName or sender == myName .. "-" .. GetRealmName() then
        return
    end

    local encoded
    local prefix = msg:sub(1, 2)

    if prefix == "S:" then
        -- Single (non-chunked) message
        encoded = msg:sub(3)
    elseif prefix == "M:" then
        -- Multi-chunk message: "M:msgId:chunkIndex:totalChunks:data"
        local msgId, idx, total, chunkData = msg:match("^M:(%x+):(%d+):(%d+):(.+)$")
        if not msgId then return end
        idx = tonumber(idx)
        total = tonumber(total)

        local key = sender .. ":" .. msgId
        if not self.pendingMessages[key] then
            self.pendingMessages[key] = { chunks = {}, total = total, received = 0 }
            -- Timeout: clean up after 30s
            C_Timer.After(30, function()
                self.pendingMessages[key] = nil
            end)
        end

        local pending = self.pendingMessages[key]
        if not pending.chunks[idx] then
            pending.chunks[idx] = chunkData
            pending.received = pending.received + 1
        end

        if pending.received < pending.total then
            return  -- Still waiting for more chunks
        end

        -- All chunks received, reassemble
        local parts = {}
        for i = 1, pending.total do
            parts[i] = pending.chunks[i] or ""
        end
        encoded = table.concat(parts)
        self.pendingMessages[key] = nil
    else
        -- Legacy (untagged) message — treat as single
        encoded = msg
    end

    -- Decode and decompress
    local decoded = LibDeflate:DecodeForWoWAddonChannel(encoded)
    if not decoded then return end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return end

    -- Parse message type
    local msgType, data = decompressed:match("^(%w+):(.*)$")
    if not msgType then return end

    if msgType == CommSystem.MSG_TYPES.BROADCAST then
        self:HandleBroadcast(sender, data)
    elseif msgType == CommSystem.MSG_TYPES.REQUEST then
        self:HandleRequest(sender, data)
    elseif msgType == CommSystem.MSG_TYPES.RESPONSE then
        self:HandleResponse(sender, data)
    elseif msgType == CommSystem.MSG_TYPES.PING then
        self:HandlePing(sender)
    elseif msgType == CommSystem.MSG_TYPES.VERSION then
        self:HandleVersionCheck(sender, data)
    elseif msgType == "TM" then
        if BRutus.TMB then
            BRutus.TMB:HandleTMBData(data)
        end
    elseif msgType == "ON" then
        if BRutus.OfficerNotes then
            BRutus.OfficerNotes:HandleIncoming(data)
        end
    elseif msgType == "RC" then
        if BRutus.RecipeTracker then
            BRutus.RecipeTracker:HandleIncoming(sender, data)
        end
    elseif msgType == "TR" then
        if BRutus.TrialTracker and BRutus:IsOfficer() then
            BRutus.TrialTracker:HandleIncoming(data)
        end
    elseif msgType == CommSystem.MSG_TYPES.ALT_LINK then
        if BRutus:IsOfficer() then
            local ok, links = LibSerialize:Deserialize(data)
            if ok and type(links) == "table" then
                BRutus.db.altLinks = links
            end
        end
    end
end

----------------------------------------------------------------------
-- Broadcast own data
----------------------------------------------------------------------
function CommSystem:BroadcastMyData()
    if not IsInGuild() then return end

    -- Throttle
    local now = GetTime()
    if now - self.lastBroadcast < self.THROTTLE_INTERVAL then return end
    self.lastBroadcast = now

    -- Collect fresh data
    if BRutus.DataCollector then
        BRutus.DataCollector:CollectMyData()
    end
    if BRutus.AttunementTracker then
        BRutus.AttunementTracker:ScanAttunements()
    end

    local data = BRutus.DataCollector:GetBroadcastData()
    local serialized = LibSerialize:Serialize(data)

    self:SendMessage(self.MSG_TYPES.BROADCAST, serialized)
end

----------------------------------------------------------------------
-- Handle incoming broadcast
----------------------------------------------------------------------
function CommSystem:HandleBroadcast(sender, data)
    local ok, playerData = LibSerialize:Deserialize(data)
    if not ok or type(playerData) ~= "table" then return end

    -- Build player key
    local realm = playerData.realm or GetRealmName()
    local name = playerData.name or sender:match("^([^-]+)")
    local key = BRutus:GetPlayerKey(name, realm)

    -- Store the data
    BRutus.DataCollector:StoreReceivedData(key, playerData)
end

----------------------------------------------------------------------
-- Request data from all online guildies
----------------------------------------------------------------------
function CommSystem:RequestAllData()
    if not IsInGuild() then return end
    self:SendMessage(self.MSG_TYPES.REQUEST, "ALL")
end

----------------------------------------------------------------------
-- Handle data request
----------------------------------------------------------------------
function CommSystem:HandleRequest(sender, _data)
    -- Someone is requesting our data, send it back
    C_Timer.After(math.random() * 3, function()  -- Stagger responses
        local myData = BRutus.DataCollector:GetBroadcastData()
        local serialized = LibSerialize:Serialize(myData)
        self:SendMessage(self.MSG_TYPES.RESPONSE, serialized, sender)

        -- Officers also send trial data
        if BRutus:IsOfficer() and BRutus.TrialTracker then
            C_Timer.After(1, function()
                BRutus.TrialTracker:BroadcastTrials()
            end)
        end
    end)
end

----------------------------------------------------------------------
-- Handle data response
----------------------------------------------------------------------
function CommSystem:HandleResponse(sender, data)
    -- Same as broadcast handling
    self:HandleBroadcast(sender, data)
end

----------------------------------------------------------------------
-- Handle ping (presence check)
----------------------------------------------------------------------
function CommSystem:HandlePing(sender)
    self:SendMessage(self.MSG_TYPES.PONG, BRutus.VERSION, sender)
end

----------------------------------------------------------------------
-- Handle version check
----------------------------------------------------------------------
function CommSystem:HandleVersionCheck(_sender, data)
    -- Could notify user of newer versions
    if data and data ~= BRutus.VERSION then
        BRutus:Print("A different BRutus version detected: " .. tostring(data))
    end
end

----------------------------------------------------------------------
-- Broadcast alt link table to all officers in guild
----------------------------------------------------------------------
function CommSystem:BroadcastAltLinks()
    if not BRutus:IsOfficer() then return end
    if not IsInGuild() then return end
    local serialized = LibSerialize:Serialize(BRutus.db.altLinks or {})
    self:SendMessage(self.MSG_TYPES.ALT_LINK, serialized)
end
