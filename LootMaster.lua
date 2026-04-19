----------------------------------------------------------------------
-- BRutus Guild Manager - Loot Master (Gargul-style)
-- Master Looter announces items, players roll MS/OS, ML awards loot.
-- Integrates with TMB wishlists to show prio/interest on items.
----------------------------------------------------------------------
local LootMaster = {}
BRutus.LootMaster = LootMaster

-- Roll types
LootMaster.ROLL_MS     = "MS"    -- Main Spec
LootMaster.ROLL_OS     = "OS"    -- Off Spec
LootMaster.ROLL_PASS   = "PASS"

-- State
LootMaster.activeLoot   = nil     -- currently announced item
LootMaster.rolls        = {}      -- [playerKey] = { name, class, rollType, roll, tmb }
LootMaster.rollTimer    = nil
LootMaster.isMLSession  = false
LootMaster.lootWindowOpen = false  -- tracks whether loot window is open
LootMaster.awardHistory = {}      -- recent awards for undo
LootMaster.pendingTrades = {}     -- items awaiting trade: [itemId] = { player, link, itemId, timestamp }
LootMaster.testMode     = false   -- when true, bypasses raid/ML checks for local testing

-- Config defaults
LootMaster.ROLL_DURATION = 30     -- seconds to wait for rolls
LootMaster.AUTO_ANNOUNCE = true   -- auto-announce when ML loot window opens
LootMaster.TMB_ONLY_MODE = false  -- only show roll popup to players with item at top of TMB list

----------------------------------------------------------------------
-- Safe wrappers: send to raid if in raid, else print locally
----------------------------------------------------------------------
function LootMaster:SafeSendChat(msg, channel)
    if IsInRaid() then
        SendChatMessage(msg, channel)
    else
        BRutus:Print("|cff888888[" .. (channel or "CHAT") .. "]|r " .. msg)
    end
end

function LootMaster:SafeSendAddon(prefix, payload, channel)
    if IsInRaid() then
        C_ChatInfo.SendAddonMessage(prefix, payload, channel)
    end
end

----------------------------------------------------------------------
-- Initialize
----------------------------------------------------------------------
function LootMaster:Initialize()
    if not BRutus.db.lootMaster then
        BRutus.db.lootMaster = {
            rollDuration = 30,
            autoAnnounce = true,
            tmbOnlyMode = false,
            awardHistory = {},
        }
    end

    self.ROLL_DURATION = BRutus.db.lootMaster.rollDuration or 30
    self.AUTO_ANNOUNCE = BRutus.db.lootMaster.autoAnnounce
    self.TMB_ONLY_MODE = BRutus.db.lootMaster.tmbOnlyMode or false
    self.pendingTrades = {}

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("LOOT_CLOSED")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("TRADE_SHOW")
    frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
    frame:RegisterEvent("UI_ERROR_MESSAGE")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "LOOT_OPENED" then
            LootMaster:OnLootOpened()
        elseif event == "LOOT_CLOSED" then
            LootMaster:OnLootClosed()
        elseif event == "CHAT_MSG_ADDON" then
            LootMaster:OnAddonMessage(...)
        elseif event == "TRADE_SHOW" then
            LootMaster:OnTradeShow()
        elseif event == "TRADE_ACCEPT_UPDATE" then
            LootMaster:OnTradeAcceptUpdate(...)
        end
    end)

    C_ChatInfo.RegisterAddonMessagePrefix("BRutusLM")
    self.eventFrame = frame
end

----------------------------------------------------------------------
-- Check if player is the loot manager
-- Priority: WoW IsMasterLooter() > GetLootMethod > C_PartyInfo > raid rank
----------------------------------------------------------------------
function LootMaster:IsMasterLooter()
    -- Test mode: always consider player as ML
    if self.testMode then return true end

    -- 1. WoW built-in IsMasterLooter() (exists in most clients)
    if IsMasterLooter and IsMasterLooter() then
        return true
    end

    -- 2. Legacy GetLootMethod API
    if GetLootMethod then
        local method, partyID = GetLootMethod()
        if method == "master" and partyID == 0 then return true end
    end

    -- 3. C_PartyInfo shim (Retail / Anniversary)
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        local method = C_PartyInfo.GetLootMethod()
        -- method 2 = master loot
        if method == 2 then
            -- Check if we're the ML via IsMasterLooter or raid info
            if IsMasterLooter and IsMasterLooter() then return true end
        end
    end

    -- 4. Fallback: raid leader or assistant can manage loot
    if IsInRaid() then
        local myName = UnitName("player")
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name and name == myName then
                return rank >= 1 -- 1 = assistant, 2 = leader
            end
        end
    end

    return false
end

----------------------------------------------------------------------
-- Loot window events
----------------------------------------------------------------------
function LootMaster:OnLootOpened()
    if not self:IsMasterLooter() then return end
    if not IsInRaid() and not self.testMode then return end

    self.isMLSession = true
    self.lootWindowOpen = true

    -- Collect lootable items (Rare+)
    local numItems = GetNumLootItems()
    local items = {}
    for i = 1, numItems do
        local _, itemName, _, _, quality = GetLootSlotInfo(i)
        if quality and quality >= 3 then
            local link = GetLootSlotLink(i)
            if link then
                table.insert(items, {
                    slot = i,
                    link = link,
                    name = itemName,
                    quality = quality,
                })
            end
        end
    end

    if #items > 0 and self.AUTO_ANNOUNCE then
        -- Show ML frame with available items
        BRutus.LootMaster:ShowLootFrame(items)
    end
end

function LootMaster:OnLootClosed()
    self.isMLSession = false
    self.lootWindowOpen = false
end

----------------------------------------------------------------------
-- Check if current player has itemId ANYWHERE in their TMB prio or wishlist
----------------------------------------------------------------------
function LootMaster:PlayerHasItemOnTMB(itemId)
    if not BRutus.TMB then return false end
    local myName = UnitName("player")
    if not myName then return false end

    local charData = BRutus.TMB:GetCharacterData(myName)
    if not charData then return false end

    -- Check prio list
    if charData.prios then
        for _, entry in ipairs(charData.prios) do
            if entry.itemId == itemId then return true end
        end
    end

    -- Check wishlist
    if charData.wishlists then
        for _, entry in ipairs(charData.wishlists) do
            if entry.itemId == itemId then return true end
        end
    end

    return false
end

----------------------------------------------------------------------
-- Resolve TMB council for an item: returns sorted list of interested
-- raiders currently in raid, or nil if no TMB data.
-- Each entry: { name, class, type ("prio"/"wishlist"), order }
----------------------------------------------------------------------
function LootMaster:ResolveTMBCouncil(itemId)
    if not BRutus.TMB or not itemId or itemId == 0 then return nil end

    local interest = BRutus.TMB:GetItemInterest(itemId)
    if not interest or #interest == 0 then return nil end

    -- Build set of players currently in raid
    local inRaid = {}
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local name = UnitName("raid" .. i)
        if name then
            inRaid[strlower(name)] = select(2, UnitClass("raid" .. i)) or "UNKNOWN"
        end
    end

    -- Filter TMB interest to only raiders present, exclude "received"
    local candidates = {}
    for _, entry in ipairs(interest) do
        if entry.type ~= "received" and inRaid[strlower(entry.name)] then
            table.insert(candidates, {
                name = entry.name,
                class = inRaid[strlower(entry.name)],
                tmbType = entry.type,
                order = entry.order or 999,
            })
        end
    end

    -- Already sorted by itemIndex (prio first, then wishlist, by order)
    return (#candidates > 0) and candidates or nil
end

----------------------------------------------------------------------
-- Announce an item for rolling
----------------------------------------------------------------------
function LootMaster:AnnounceItem(itemLink, lootSlot)
    if not IsInRaid() and not self.testMode then
        BRutus:Print("You must be in a raid to announce loot.")
        return
    end

    -- Clear previous session
    self.rolls = {}
    self.activeLoot = {
        link = itemLink,
        slot = lootSlot,
        startTime = GetServerTime(),
        endTime = GetServerTime() + self.ROLL_DURATION,
    }

    -- Extract item ID for TMB lookup
    local itemId = tonumber(itemLink:match("item:(%d+)"))
    self.activeLoot.itemId = itemId

    -- TMB Auto-Council: resolve before announcing rolls
    if self.TMB_ONLY_MODE and itemId and itemId > 0 then
        local council = self:ResolveTMBCouncil(itemId)
        if council then
            -- Check if there's a single clear winner at the highest priority
            local top = council[1]
            -- Collect all candidates sharing the same tier + order as the top
            local tied = {}
            for _, c in ipairs(council) do
                if c.tmbType == top.tmbType and c.order == top.order then
                    table.insert(tied, c)
                end
            end

            if #tied == 1 then
                -- Single clear winner: auto-award
                self:AutoCouncilAward(top, itemLink, lootSlot, council)
                return
            else
                -- Multiple players at same priority: they roll among themselves
                self:AutoCouncilRoll(tied, itemLink, lootSlot, council)
                return
            end
        end
        -- No TMB data for this item: fall through to normal announce
        BRutus:Print("|cffFFFF00No TMB data for this item - opening normal roll.|r")
    end

    self:DoNormalAnnounce(itemLink, lootSlot, itemId)
end

----------------------------------------------------------------------
-- Normal announce (no auto-council)
----------------------------------------------------------------------
function LootMaster:DoNormalAnnounce(itemLink, _lootSlot, itemId)
    -- Announce in raid chat
    local msg = string.format("{rt4} ROLL: %s {rt4}  -  /w ML: MS / OS / PASS  -  %ds", itemLink, self.ROLL_DURATION)
    self:SafeSendChat(msg, "RAID_WARNING")

    -- Send addon message to all raiders with BRutus
    local tmbFlag = self.TMB_ONLY_MODE and "1" or "0"
    local payload = string.format("ANNOUNCE|%s|%d|%d|%s", itemLink, self.ROLL_DURATION, itemId or 0, tmbFlag)
    self:SafeSendAddon("BRutusLM", payload, "RAID")

    -- Start timer
    if self.rollTimer then self.rollTimer:Cancel() end
    self.rollTimer = C_Timer.NewTimer(self.ROLL_DURATION, function()
        LootMaster:EndRolling()
    end)

    -- Update UI
    if self.rollFrame and self.rollFrame:IsShown() then
        self:RefreshRollFrame()
    end

    BRutus:Print("Loot announced: " .. itemLink .. " (" .. self.ROLL_DURATION .. "s)")
end

----------------------------------------------------------------------
-- Auto-Council: single clear TMB winner - award directly
----------------------------------------------------------------------
function LootMaster:AutoCouncilAward(winner, itemLink, lootSlot, allCandidates)
    local tmbStr = string.format("%s #%d", winner.tmbType, winner.order)

    -- Announce in raid
    self:SafeSendChat(
        string.format("{rt4} TMB Council: %s >> %s [%s] {rt4}", itemLink, winner.name, tmbStr),
        "RAID_WARNING"
    )

    -- Show council result popup for ML to confirm
    self:ShowCouncilResultFrame(winner, itemLink, lootSlot, allCandidates)
end

----------------------------------------------------------------------
-- Auto-Council: multiple players tied at same TMB priority - they roll
----------------------------------------------------------------------
function LootMaster:AutoCouncilRoll(tied, itemLink, _lootSlot, _allCandidates)
    -- Build names string
    local names = {}
    for _, c in ipairs(tied) do table.insert(names, c.name) end
    local tmbStr = string.format("%s #%d", tied[1].tmbType, tied[1].order)

    -- Announce tied roll in raid
    self:SafeSendChat(
        string.format("{rt4} TMB Council: %s - Tied [%s]: %s - Rolling! {rt4}",
            itemLink, tmbStr, table.concat(names, ", ")),
        "RAID_WARNING"
    )

    -- Send ANNOUNCE only to those tied players
    local itemId = self.activeLoot.itemId or 0
    local payload = string.format("ANNOUNCE|%s|%d|%d|1", itemLink, self.ROLL_DURATION, itemId)
    self:SafeSendAddon("BRutusLM", payload, "RAID")

    -- Start timer
    if self.rollTimer then self.rollTimer:Cancel() end
    self.rollTimer = C_Timer.NewTimer(self.ROLL_DURATION, function()
        LootMaster:EndRolling()
    end)

    -- Show roll frame for ML
    self:ShowRollFrame()

    BRutus:Print(string.format("TMB tie: %d players at [%s] rolling for %s",
        #tied, tmbStr, itemLink))
end

----------------------------------------------------------------------
-- Council result frame: ML confirms or overrides auto-award
----------------------------------------------------------------------
function LootMaster:ShowCouncilResultFrame(winner, itemLink, lootSlot, allCandidates)
    local C = BRutus.Colors
    local UI = BRutus.UI

    if self.councilFrame then self.councilFrame:Hide() end

    local numRows = allCandidates and #allCandidates or 0
    local f = CreateFrame("Frame", "BRutusCouncilFrame", UIParent, "BackdropTemplate")
    f:SetSize(380, 110 + numRows * 22)
    f:SetPoint("CENTER")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.06, 0.05, 0.10, 0.98)
    f:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.8)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    title:SetPoint("TOP", 0, -8)
    title:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    title:SetText("TMB Council")

    -- Item
    local itemText = f:CreateFontString(nil, "OVERLAY")
    itemText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    itemText:SetPoint("TOP", 0, -26)
    itemText:SetText(itemLink or "Unknown Item")

    -- Winner line
    local CLASS_COLORS = RAID_CLASS_COLORS
    local cc = CLASS_COLORS[winner.class] or { r = 0.8, g = 0.8, b = 0.8 }
    local winText = f:CreateFontString(nil, "OVERLAY")
    winText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    winText:SetPoint("TOP", 0, -44)
    local tColor = winner.tmbType == "prio" and "|cffFF8000" or "|cff4CB8FF"
    winText:SetText(string.format(">> |cff%02x%02x%02x%s|r - %s%s #%d|r",
        cc.r * 255, cc.g * 255, cc.b * 255,
        winner.name, tColor, winner.tmbType, winner.order))

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\Buttons\\WHITE8x8")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 10, -60)
    sep:SetPoint("TOPRIGHT", -10, -60)
    sep:SetVertexColor(C.border.r, C.border.g, C.border.b, 0.4)

    -- Full priority list
    local yOff = -66
    if allCandidates then
        for i, c in ipairs(allCandidates) do
            local ccc = CLASS_COLORS[c.class] or { r = 0.8, g = 0.8, b = 0.8 }
            local row = f:CreateFontString(nil, "OVERLAY")
            row:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            row:SetPoint("TOPLEFT", 14, yOff)
            local tc = c.tmbType == "prio" and "|cffFF8000" or "|cff4CB8FF"
            local prefix = (i == 1) and "|cff00ff00>>|r " or "   "
            row:SetText(string.format("%s|cff%02x%02x%02x%s|r  %s%s #%d|r",
                prefix, ccc.r * 255, ccc.g * 255, ccc.b * 255,
                c.name, tc, c.tmbType, c.order))
            yOff = yOff - 18
        end
    end

    -- Buttons
    local awardBtn = UI:CreateButton(f, "Award to " .. winner.name, 160, 26)
    awardBtn:SetPoint("BOTTOMLEFT", 10, 10)
    awardBtn:SetBackdropColor(0.0, 0.4, 0.0, 0.6)
    awardBtn:SetScript("OnClick", function()
        LootMaster:AwardLoot(winner.name)
        f:Hide()
    end)

    local rollBtn = UI:CreateButton(f, "Open Roll Instead", 140, 26)
    rollBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    rollBtn:SetScript("OnClick", function()
        f:Hide()
        -- Fall back to normal announce
        LootMaster:DoNormalAnnounce(itemLink, lootSlot, LootMaster.activeLoot.itemId)
        LootMaster:ShowRollFrame()
    end)

    -- Close
    local closeBtn = UI:CreateCloseButton(f)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnHide", function()
        LootMaster.testMode = false
    end)

    f:Show()
    self.councilFrame = f
end

----------------------------------------------------------------------
-- Handle incoming addon messages
----------------------------------------------------------------------
function LootMaster:OnAddonMessage(prefix, msg, channel, sender)
    if prefix ~= "BRutusLM" then return end
    if channel ~= "RAID" and channel ~= "RAID_LEADER" then return end

    local cmd, rest = msg:match("^(%w+)|(.+)$")
    if not cmd then return end

    if cmd == "ANNOUNCE" then
        -- Another ML announced an item - show roll popup if we're not ML
        if not self:IsMasterLooter() then
            local link, duration, itemId, tmbOnly = rest:match("^(.+)|(%d+)|(%d+)|([01])$")
            if not link then
                -- Backwards compat: old format without tmbOnly flag
                link, duration, itemId = rest:match("^(.+)|(%d+)|(%d+)$")
                tmbOnly = "0"
            end
            duration = tonumber(duration) or 30
            itemId = tonumber(itemId) or 0

            -- TMB-only filter: only show popup if player has item on their TMB list
            if tmbOnly == "1" and itemId > 0 then
                if not self:PlayerHasItemOnTMB(itemId) then
                    return
                end
            end

            self:ShowRollPopup(link, duration, itemId)
        end

    elseif cmd == "ROLL" then
        -- A raider sent their roll choice
        if self:IsMasterLooter() and self.activeLoot then
            local rollType = rest -- MS, OS, or PASS
            if rollType == "MS" or rollType == "OS" or rollType == "PASS" then
                self:RegisterRoll(sender, rollType)
            end
        end

    elseif cmd == "AWARD" then
        -- ML awarded item (informational broadcast)
        local awardedTo, link = rest:match("^([^|]+)|(.+)$")
        if awardedTo and link then
            BRutus:Print(string.format("|cffFFD700Loot:|r %s awarded to |cff00ff00%s|r", link, awardedTo))
        end
    end
end

----------------------------------------------------------------------
-- Register a player's roll
----------------------------------------------------------------------
function LootMaster:RegisterRoll(sender, rollType)
    if not self.activeLoot then return end

    -- Normalize sender name
    local name = sender:match("^([^-]+)")
    local realm = sender:match("-(.+)$") or GetRealmName()
    local key = name .. "-" .. realm

    -- Generate random roll
    local roll = 0
    if rollType == "MS" then
        roll = math.random(1, 100)
    elseif rollType == "OS" then
        roll = math.random(1, 100)
    end

    -- Get TMB data if available
    local tmbInfo = nil
    if BRutus.TMB and self.activeLoot.itemId then
        local interest = BRutus.TMB:GetItemInterest(self.activeLoot.itemId)
        if interest then
            for _, entry in ipairs(interest) do
                if strlower(entry.name) == strlower(name) then
                    tmbInfo = { type = entry.type, order = entry.order }
                    break
                end
            end
        end
    end

    -- Get class
    local class = "UNKNOWN"
    local numMembers = GetNumGroupMembers() or 0
    if numMembers > 0 then
        for i = 1, numMembers do
            local unit = "raid" .. i
            local uName = UnitName(unit)
            if uName and uName == name then
                class = select(2, UnitClass(unit)) or "UNKNOWN"
                break
            end
        end
    end
    -- Fallback: check stored addon data or player's own class
    if class == "UNKNOWN" then
        local playerRealm = GetRealmName()
        local pKey = BRutus:GetPlayerKey(name, playerRealm)
        local memberData = BRutus.db.members[pKey]
        if memberData and memberData.class then
            class = memberData.class
        elseif name == UnitName("player") then
            class = select(2, UnitClass("player")) or "UNKNOWN"
        end
    end

    self.rolls[key] = {
        name = name,
        class = class,
        rollType = rollType,
        roll = roll,
        tmb = tmbInfo,
    }

    -- Notify raid of the roll
    if rollType ~= "PASS" then
        local tmbStr = ""
        if tmbInfo then
            tmbStr = string.format(" [TMB: %s #%d]", tmbInfo.type, tmbInfo.order)
        end
        self:SafeSendChat(string.format("%s rolls %d (%s)%s", name, roll, rollType, tmbStr), "RAID")
    end

    -- Refresh UI
    if self.rollFrame and self.rollFrame:IsShown() then
        self:RefreshRollFrame()
    end
end

----------------------------------------------------------------------
-- End rolling and display results
----------------------------------------------------------------------
function LootMaster:EndRolling()
    if not self.activeLoot then return end

    if self.rollTimer then
        self.rollTimer:Cancel()
        self.rollTimer = nil
    end

    -- Sort rolls: MS first (by TMB prio > roll), then OS (by roll)
    local sorted = {}
    for _, r in pairs(self.rolls) do
        if r.rollType ~= "PASS" then
            table.insert(sorted, r)
        end
    end

    table.sort(sorted, function(a, b)
        -- MS beats OS
        if a.rollType ~= b.rollType then
            return a.rollType == "MS"
        end
        -- Within same type: TMB prio > wishlist > no TMB
        local aPrio = (a.tmb and a.tmb.type == "prio") and 1 or (a.tmb and a.tmb.type == "wishlist") and 2 or 3
        local bPrio = (b.tmb and b.tmb.type == "prio") and 1 or (b.tmb and b.tmb.type == "wishlist") and 2 or 3
        if aPrio ~= bPrio then return aPrio < bPrio end
        -- Same TMB tier: lower order number wins
        if a.tmb and b.tmb and a.tmb.order ~= b.tmb.order then
            return a.tmb.order < b.tmb.order
        end
        -- Tiebreaker: higher roll
        return a.roll > b.roll
    end)

    self.activeLoot.sortedResults = sorted
    self.activeLoot.ended = true

    -- Announce winner in raid
    if #sorted > 0 then
        local winner = sorted[1]
        local tmbStr = ""
        if winner.tmb then
            tmbStr = string.format(" [TMB: %s #%d]", winner.tmb.type, winner.tmb.order)
        end
        self:SafeSendChat(string.format("{rt4} WINNER: %s (%s - %d)%s for %s",
            winner.name, winner.rollType, winner.roll, tmbStr, self.activeLoot.link), "RAID_WARNING")
    else
        self:SafeSendChat("{rt4} No rolls received for " .. self.activeLoot.link, "RAID_WARNING")
    end

    -- Refresh UI
    if self.rollFrame and self.rollFrame:IsShown() then
        self:RefreshRollFrame()
    end
end

----------------------------------------------------------------------
-- Award loot to a player (Gargul-style two-path distribution)
----------------------------------------------------------------------
function LootMaster:AwardLoot(playerName)
    if not self.activeLoot then return end
    if not self:IsMasterLooter() then
        BRutus:Print("You are not the Master Looter.")
        return
    end

    local itemLink = self.activeLoot.link
    local itemId = self.activeLoot.itemId
    local slot = self.activeLoot.slot
    local awarded = false

    -- Path 1: ML loot window open + ML API available -> GiveMasterLoot
    if self.lootWindowOpen and slot and GiveMasterLoot and GetMasterLootCandidate then
        local numCandidates = 40
        for i = 1, numCandidates do
            local candidateName = GetMasterLootCandidate(slot, i)
            if candidateName then
                local cName = candidateName:match("^([^-]+)")
                if cName == playerName then
                    GiveMasterLoot(slot, i)
                    awarded = true
                    break
                end
            end
        end
    end

    -- Path 2: No ML API or loot window closed -> queue for trade
    if not awarded then
        local isMe = (playerName == UnitName("player"))
        if not isMe then
            self:QueueForTrade(playerName, itemLink, itemId)
        end
    end

    -- Broadcast award
    local payload = string.format("AWARD|%s|%s", playerName, itemLink)
    self:SafeSendAddon("BRutusLM", payload, "RAID")

    -- Announce
    self:SafeSendChat(string.format("{rt4} %s awarded to %s", itemLink, playerName), "RAID")

    -- Save to award history
    table.insert(BRutus.db.lootMaster.awardHistory, 1, {
        link = itemLink,
        itemId = itemId,
        player = playerName,
        timestamp = GetServerTime(),
        received = awarded,
    })
    -- Cap history
    while #BRutus.db.lootMaster.awardHistory > 200 do
        table.remove(BRutus.db.lootMaster.awardHistory)
    end

    if awarded then
        BRutus:Print(itemLink .. " given to |cff00ff00" .. playerName .. "|r")
    else
        BRutus:Print(itemLink .. " awarded to |cff00ff00" .. playerName .. "|r - trade to deliver.")
    end

    self.activeLoot = nil
    self.rolls = {}
end

----------------------------------------------------------------------
-- Trade-based loot delivery (Gargul-style)
----------------------------------------------------------------------

-- Queue an item to be traded to a player
function LootMaster:QueueForTrade(playerName, itemLink, itemId)
    table.insert(self.pendingTrades, {
        player = playerName,
        link = itemLink,
        itemId = itemId,
        timestamp = GetServerTime(),
    })
    BRutus:Print(string.format("|cffFFFF00Trade queued:|r %s for %s. Open trade with them.", itemLink, playerName))
end

-- Find an item in bags by itemId
function LootMaster:FindItemInBags(itemId)
    for bag = 0, 4 do
        local numSlots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
            or GetContainerNumSlots and GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemId then
                return bag, slot
            else
                -- Fallback for older API
                if GetContainerItemInfo then
                    local link = select(7, GetContainerItemInfo(bag, slot))
                    if link then
                        local id = tonumber(link:match("item:(%d+)"))
                        if id == itemId then
                            return bag, slot
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

-- When trade window opens, try to auto-add pending items
function LootMaster:OnTradeShow()
    local tradeName = UnitName("NPC") or GetUnitName("NPC", false)
    if not tradeName then
        -- Try TradeFrame target
        tradeName = TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText()
    end
    if not tradeName or tradeName == "" then return end

    local itemsAdded = 0
    local tradeSlot = 1

    for i = #self.pendingTrades, 1, -1 do
        local pending = self.pendingTrades[i]
        if pending.player == tradeName then
            local bag, slot = self:FindItemInBags(pending.itemId)
            if bag and slot and tradeSlot <= 6 then
                -- Place item in trade window
                if C_Container and C_Container.UseContainerItem then
                    C_Container.UseContainerItem(bag, slot)
                elseif UseContainerItem then
                    UseContainerItem(bag, slot)
                end
                BRutus:Print(string.format("|cff00ff00Auto-added:|r %s to trade.", pending.link))
                pending.addedToTrade = true
                itemsAdded = itemsAdded + 1
                tradeSlot = tradeSlot + 1
            end
        end
    end

    if itemsAdded > 0 then
        BRutus:Print(string.format("%d item(s) added to trade with %s.", itemsAdded, tradeName))
    end
end

-- When trade completes, mark pending items as received
function LootMaster:OnTradeAcceptUpdate(playerAccepted, targetAccepted)
    if playerAccepted == 1 and targetAccepted == 1 then
        local tradeName = TradeFrameRecipientNameText and TradeFrameRecipientNameText:GetText()
        if not tradeName then return end

        for i = #self.pendingTrades, 1, -1 do
            local pending = self.pendingTrades[i]
            if pending.player == tradeName and pending.addedToTrade then
                -- Mark as received in award history
                for _, award in ipairs(BRutus.db.lootMaster.awardHistory) do
                    if award.itemId == pending.itemId
                        and award.player == pending.player
                        and not award.received then
                        award.received = true
                        break
                    end
                end
                BRutus:Print(string.format("|cff00ff00Trade complete:|r %s delivered to %s.", pending.link, pending.player))
                table.remove(self.pendingTrades, i)
            end
        end
    end
end

-- Get pending trades (for UI display)
function LootMaster:GetPendingTrades()
    return self.pendingTrades
end

----------------------------------------------------------------------
-- Cancel current rolling session
----------------------------------------------------------------------
function LootMaster:CancelRolling()
    if self.rollTimer then
        self.rollTimer:Cancel()
        self.rollTimer = nil
    end
    if self.activeLoot then
        self:SafeSendChat("{rt4} Rolling cancelled for " .. self.activeLoot.link, "RAID")
    end
    self.activeLoot = nil
    self.rolls = {}

    if self.rollFrame and self.rollFrame:IsShown() then
        self:RefreshRollFrame()
    end
end

----------------------------------------------------------------------
-- Raider: send roll choice to ML via addon message
----------------------------------------------------------------------
function LootMaster:SendMyRoll(rollType)
    self:SafeSendAddon("BRutusLM", "ROLL|" .. rollType, "RAID")
end

----------------------------------------------------------------------
-- UI: Roll popup for raiders (non-ML)
----------------------------------------------------------------------
function LootMaster:ShowRollPopup(itemLink, duration, itemId)
    local C = BRutus.Colors

    if self.rollPopup then
        self.rollPopup:Hide()
    end

    local f = CreateFrame("Frame", "BRutusRollPopup", UIParent, "BackdropTemplate")
    f:SetSize(320, 100)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.08, 0.06, 0.14, 0.95)
    f:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.8)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    title:SetPoint("TOP", 0, -8)
    title:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    title:SetText("BRutus Loot Master")

    -- Item link
    local itemText = f:CreateFontString(nil, "OVERLAY")
    itemText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    itemText:SetPoint("TOP", 0, -26)
    itemText:SetText(itemLink or "Unknown Item")

    -- TMB info
    local tmbText = f:CreateFontString(nil, "OVERLAY")
    tmbText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    tmbText:SetPoint("TOP", 0, -42)
    tmbText:SetTextColor(C.silver.r, C.silver.g, C.silver.b)

    if itemId and itemId > 0 and BRutus.TMB then
        local myName = UnitName("player")
        local interest = BRutus.TMB:GetItemInterest(itemId)
        local myEntry = nil
        if interest then
            for _, e in ipairs(interest) do
                if strlower(e.name) == strlower(myName) then
                    myEntry = e
                    break
                end
            end
        end
        if myEntry then
            local color = myEntry.type == "prio" and "|cffFF8000" or "|cff4CB8FF"
            tmbText:SetText("TMB: " .. color .. myEntry.type .. " #" .. myEntry.order .. "|r")
        else
            tmbText:SetText("|cff666666Not on your TMB list|r")
        end
    else
        tmbText:SetText("")
    end

    -- Buttons
    local UI = BRutus.UI
    local msBtn = UI:CreateButton(f, "MS", 80, 26)
    msBtn:SetPoint("BOTTOMLEFT", 15, 10)
    msBtn:SetBackdropColor(0.0, 0.4, 0.0, 0.6)
    msBtn:SetScript("OnClick", function()
        LootMaster:SendMyRoll("MS")
        f:Hide()
        BRutus:Print("Rolled |cff00ff00MS|r on " .. (itemLink or "item"))
    end)

    local osBtn = UI:CreateButton(f, "OS", 80, 26)
    osBtn:SetPoint("BOTTOM", 0, 10)
    osBtn:SetBackdropColor(0.3, 0.3, 0.0, 0.6)
    osBtn:SetScript("OnClick", function()
        LootMaster:SendMyRoll("OS")
        f:Hide()
        BRutus:Print("Rolled |cffFFFF00OS|r on " .. (itemLink or "item"))
    end)

    local passBtn = UI:CreateButton(f, "Pass", 80, 26)
    passBtn:SetPoint("BOTTOMRIGHT", -15, 10)
    passBtn:SetBackdropColor(0.4, 0.0, 0.0, 0.6)
    passBtn:SetScript("OnClick", function()
        LootMaster:SendMyRoll("PASS")
        f:Hide()
    end)

    -- Timer bar
    local timerBar = CreateFrame("StatusBar", nil, f)
    timerBar:SetSize(290, 4)
    timerBar:SetPoint("BOTTOM", 0, 5)
    timerBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    timerBar:SetStatusBarColor(C.accent.r, C.accent.g, C.accent.b, 0.8)
    timerBar:SetMinMaxValues(0, duration)
    timerBar:SetValue(duration)

    local elapsed = 0
    local ticker = C_Timer.NewTicker(0.1, function()
        elapsed = elapsed + 0.1
        local remaining = duration - elapsed
        if remaining <= 0 then
            f:Hide()
        else
            timerBar:SetValue(remaining)
        end
    end)

    f:SetScript("OnHide", function()
        ticker:Cancel()
        LootMaster.testMode = false
    end)

    f:Show()
    self.rollPopup = f
end

----------------------------------------------------------------------
-- UI: Loot frame for ML showing available items
----------------------------------------------------------------------
function LootMaster:ShowLootFrame(items)
    local C = BRutus.Colors
    local UI = BRutus.UI

    if self.lootFrame then
        self.lootFrame:Hide()
    end

    local f = CreateFrame("Frame", "BRutusMLLootFrame", UIParent, "BackdropTemplate")
    f:SetSize(280, 80 + #items * 28)
    f:SetPoint("LEFT", UIParent, "LEFT", 20, 0)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.06, 0.05, 0.10, 0.95)
    f:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.8)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    title:SetPoint("TOP", 0, -8)
    title:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    title:SetText("Master Loot")

    local yOff = -30
    for _, item in ipairs(items) do
        local row = CreateFrame("Button", nil, f, "BackdropTemplate")
        row:SetSize(260, 24)
        row:SetPoint("TOPLEFT", 10, yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(0.10, 0.08, 0.16, 0.6)

        local itemText = row:CreateFontString(nil, "OVERLAY")
        itemText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetText(item.link)

        -- Click to announce
        row:SetScript("OnClick", function()
            LootMaster:AnnounceItem(item.link, item.slot)
            LootMaster:ShowRollFrame()
        end)
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.18, 0.14, 0.28, 0.8)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item.link)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.10, 0.08, 0.16, 0.6)
            GameTooltip:Hide()
        end)

        yOff = yOff - 28
    end

    -- TMB-only toggle
    local tmbCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    tmbCheck:SetSize(22, 22)
    tmbCheck:SetPoint("TOPLEFT", 10, yOff - 6)
    tmbCheck:SetChecked(self.TMB_ONLY_MODE)
    tmbCheck:SetScript("OnClick", function(cb)
        local val = cb:GetChecked()
        LootMaster.TMB_ONLY_MODE = val
        BRutus.db.lootMaster.tmbOnlyMode = val
        if val then
            BRutus:Print("TMB auto-council |cff00ff00ON|r - checks TMB priority before rolling.")
        else
            BRutus:Print("TMB auto-council |cffFF4444OFF|r - normal roll for everyone.")
        end
    end)
    local tmbLabel = f:CreateFontString(nil, "OVERLAY")
    tmbLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    tmbLabel:SetPoint("LEFT", tmbCheck, "RIGHT", 2, 0)
    tmbLabel:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    tmbLabel:SetText("TMB-only (auto-council)")

    -- Resize frame to fit toggle
    f:SetHeight(50 + #items * 28 + 30)

    -- Close
    local closeBtn = UI:CreateCloseButton(f)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f:Show()
    self.lootFrame = f
end

----------------------------------------------------------------------
-- UI: Roll tracking frame for ML
----------------------------------------------------------------------
function LootMaster:ShowRollFrame()
    local C = BRutus.Colors
    local UI = BRutus.UI

    if self.rollFrame then
        self.rollFrame:Hide()
    end

    local f = CreateFrame("Frame", "BRutusMLRollFrame", UIParent, "BackdropTemplate")
    f:SetSize(420, 350)
    f:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.06, 0.05, 0.10, 0.95)
    f:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.8)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    title:SetPoint("TOP", 0, -8)
    title:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    title:SetText("Roll Tracker")

    -- Item display
    local itemText = f:CreateFontString(nil, "OVERLAY")
    itemText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    itemText:SetPoint("TOP", 0, -28)
    f.itemText = itemText

    -- Timer
    local timerText = f:CreateFontString(nil, "OVERLAY")
    timerText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    timerText:SetPoint("TOP", 0, -44)
    timerText:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    f.timerText = timerText

    -- Separator
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\Buttons\\WHITE8x8")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 10, -56)
    sep:SetPoint("TOPRIGHT", -10, -56)
    sep:SetVertexColor(C.border.r, C.border.g, C.border.b, 0.4)

    -- Column headers
    local headers = { { "Player", 10 }, { "Type", 200 }, { "Roll", 260 }, { "TMB", 320 } }
    for _, h in ipairs(headers) do
        local ht = f:CreateFontString(nil, "OVERLAY")
        ht:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
        ht:SetPoint("TOPLEFT", h[2], -62)
        ht:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
        ht:SetText(h[1])
    end

    -- Scroll area for rolls
    local scrollFrame = CreateFrame("ScrollFrame", "BRutusRollScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -76)
    scrollFrame:SetPoint("BOTTOMRIGHT", -10, 50)
    UI:SkinScrollBar(scrollFrame, "BRutusRollScroll")
    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(380, 1)
    scrollFrame:SetScrollChild(scrollContent)
    f.scrollContent = scrollContent

    -- Bottom buttons
    local cancelBtn = UI:CreateButton(f, "Cancel", 80, 24)
    cancelBtn:SetPoint("BOTTOMLEFT", 10, 12)
    cancelBtn:SetBackdropColor(C.red.r * 0.3, C.red.g * 0.3, C.red.b * 0.3, 0.6)
    cancelBtn:SetScript("OnClick", function()
        LootMaster:CancelRolling()
    end)

    local endBtn = UI:CreateButton(f, "End Rolling", 100, 24)
    endBtn:SetPoint("BOTTOM", 0, 12)
    endBtn:SetScript("OnClick", function()
        LootMaster:EndRolling()
    end)
    f.endBtn = endBtn

    -- Close
    local closeBtn = UI:CreateCloseButton(f)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f:Show()
    self.rollFrame = f

    -- Timer ticker
    if f.ticker then f.ticker:Cancel() end
    f.ticker = C_Timer.NewTicker(1, function()
        LootMaster:UpdateRollTimer()
    end)
    f:SetScript("OnHide", function()
        if f.ticker then f.ticker:Cancel() end
        LootMaster.testMode = false
    end)

    self:RefreshRollFrame()
end

----------------------------------------------------------------------
-- Refresh the roll tracker display
----------------------------------------------------------------------
function LootMaster:RefreshRollFrame()
    if not self.rollFrame or not self.rollFrame:IsShown() then return end
    local f = self.rollFrame

    -- Update item
    if self.activeLoot then
        f.itemText:SetText(self.activeLoot.link or "No item")
    else
        f.itemText:SetText("|cff888888No active roll|r")
        f.timerText:SetText("")
    end

    -- Clear scroll content
    local content = f.scrollContent
    for _, child in pairs({ content:GetChildren() }) do child:Hide() end

    -- Build sorted list
    local sorted = {}
    for _, r in pairs(self.rolls) do
        table.insert(sorted, r)
    end
    -- Sort: MS first, then by TMB prio, then roll
    table.sort(sorted, function(a, b)
        if a.rollType ~= b.rollType then
            if a.rollType == "PASS" then return false end
            if b.rollType == "PASS" then return true end
            return a.rollType == "MS"
        end
        return a.roll > b.roll
    end)

    local CLASS_COLORS = RAID_CLASS_COLORS
    local yOff = 0
    for _, r in ipairs(sorted) do
        local row = CreateFrame("Button", nil, content, "BackdropTemplate")
        row:SetSize(380, 22)
        row:SetPoint("TOPLEFT", 0, -yOff)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:SetBackdropColor(0.08, 0.06, 0.14, 0.6)

        -- Player name (class colored)
        local cc = CLASS_COLORS[r.class] or { r = 0.8, g = 0.8, b = 0.8 }
        local nameText = row:CreateFontString(nil, "OVERLAY")
        nameText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        nameText:SetPoint("LEFT", 6, 0)
        nameText:SetTextColor(cc.r, cc.g, cc.b)
        nameText:SetText(r.name)

        -- Roll type
        local typeText = row:CreateFontString(nil, "OVERLAY")
        typeText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        typeText:SetPoint("LEFT", 190, 0)
        if r.rollType == "MS" then
            typeText:SetTextColor(0.3, 1.0, 0.3)
        elseif r.rollType == "OS" then
            typeText:SetTextColor(1.0, 1.0, 0.3)
        else
            typeText:SetTextColor(0.5, 0.5, 0.5)
        end
        typeText:SetText(r.rollType)

        -- Roll number
        local rollText = row:CreateFontString(nil, "OVERLAY")
        rollText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        rollText:SetPoint("LEFT", 250, 0)
        rollText:SetTextColor(1, 1, 1)
        rollText:SetText(r.rollType ~= "PASS" and tostring(r.roll) or "-")

        -- TMB info
        local tmbText = row:CreateFontString(nil, "OVERLAY")
        tmbText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        tmbText:SetPoint("LEFT", 310, 0)
        if r.tmb then
            local tc = r.tmb.type == "prio" and "|cffFF8000" or "|cff4CB8FF"
            tmbText:SetText(tc .. r.tmb.type .. " #" .. r.tmb.order .. "|r")
        else
            tmbText:SetTextColor(0.4, 0.4, 0.4)
            tmbText:SetText("-")
        end

        -- Award button (only when rolling ended and ML)
        if self.activeLoot and self.activeLoot.ended and self:IsMasterLooter() and r.rollType ~= "PASS" then
            local awardBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
            awardBtn:SetSize(50, 18)
            awardBtn:SetPoint("RIGHT", -2, 0)
            awardBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            awardBtn:SetBackdropColor(0.0, 0.3, 0.0, 0.6)
            awardBtn:SetBackdropBorderColor(0.0, 0.5, 0.0, 0.4)
            local aText = awardBtn:CreateFontString(nil, "OVERLAY")
            aText:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            aText:SetPoint("CENTER")
            aText:SetText("Award")
            aText:SetTextColor(0.3, 1.0, 0.3)
            local playerName = r.name
            awardBtn:SetScript("OnClick", function()
                LootMaster:AwardLoot(playerName)
                f:Hide()
            end)
            awardBtn:SetScript("OnEnter", function(self)
                self:SetBackdropColor(0.0, 0.5, 0.0, 0.8)
            end)
            awardBtn:SetScript("OnLeave", function(self)
                self:SetBackdropColor(0.0, 0.3, 0.0, 0.6)
            end)
        end

        yOff = yOff + 24
    end
    content:SetHeight(math.max(1, yOff))
end

----------------------------------------------------------------------
-- Update timer display
----------------------------------------------------------------------
function LootMaster:UpdateRollTimer()
    if not self.rollFrame or not self.activeLoot then return end

    if self.activeLoot.ended then
        self.rollFrame.timerText:SetText("|cffFF4444Rolling ended - click Award|r")
        return
    end

    if not self.activeLoot.endTime then
        self.rollFrame.timerText:SetText("|cff888888No timer|r")
        return
    end

    local remaining = self.activeLoot.endTime - GetServerTime()
    if remaining > 0 then
        self.rollFrame.timerText:SetText(string.format("|cffFFFF00%ds remaining|r  |  %d rolls", remaining, self:CountRolls()))
    else
        self.rollFrame.timerText:SetText("|cffFF4444Time's up!|r")
    end
end

function LootMaster:CountRolls()
    local n = 0
    for _ in pairs(self.rolls) do n = n + 1 end
    return n
end
