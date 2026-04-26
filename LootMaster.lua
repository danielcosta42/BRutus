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
LootMaster.activeLoot        = nil    -- currently announced item
LootMaster.rolls             = {}     -- [playerKey] = { name, class, rollType, roll, tmb }
LootMaster.rollTimer         = nil
LootMaster.isMLSession       = false
LootMaster.lootWindowOpen    = false  -- tracks whether loot window is open
LootMaster.listeningForRolls = false  -- true while capturing /roll results from CHAT_MSG_SYSTEM
LootMaster.restrictedRollers = nil    -- set of lowercased names allowed to roll in a tied session; nil = everyone
LootMaster.awardHistory      = {}     -- recent awards for undo
LootMaster.pendingTrades     = {}     -- items awaiting trade: [itemId] = { player, link, itemId, timestamp }
LootMaster.testMode          = false  -- when true, bypasses raid/ML checks for local testing
LootMaster.rollPattern       = nil    -- built in Initialize() from RANDOM_ROLL_RESULT

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

    -- Ensure loot-distribution settings exist (added in v2)
    local lmdb = BRutus.db.lootMaster
    if lmdb.minAttendancePct == nil then lmdb.minAttendancePct = 0    end
    if lmdb.attTiebreaker    == nil then lmdb.attTiebreaker    = true end
    if lmdb.recvPenalty      == nil then lmdb.recvPenalty      = true end

    -- Build /roll detection pattern from localized RANDOM_ROLL_RESULT global
    -- e.g. EN: "%s rolls %d (%d-%d)."  → ^(.+) rolls (%d+) %((%d+)%-(%d+)%)%.$
    do
        local tmpl = RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)."
        local p = tmpl:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
        p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
        self.rollPattern = "^" .. p .. "$"
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("LOOT_CLOSED")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:RegisterEvent("CHAT_MSG_SYSTEM")  -- capture /roll results
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
        elseif event == "CHAT_MSG_SYSTEM" then
            LootMaster:OnSystemMessage(...)
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
-- Returns { att25, recvThisLockout } for a player — used for roll
-- gating, sort tiebreakers, and UI column display.
----------------------------------------------------------------------
function LootMaster:GetPlayerContext(playerName)
    local ctx = { att25 = 0, recvThisLockout = 0 }
    if not playerName then return ctx end

    -- 25-man attendance %
    if BRutus.RaidTracker then
        local pKey = BRutus:GetPlayerKey(playerName, GetRealmName())
        ctx.att25 = BRutus.RaidTracker:GetAttendance25ManPercent(pKey) or 0
    end

    -- Items received this lockout (same instance + TBC reset week)
    if BRutus.TMB then
        local _, _, _, _, _, _, _, instID = GetInstanceInfo()
        local wNum = BRutus.RaidTracker
            and BRutus.RaidTracker:GetWeekNum(GetServerTime()) or 0
        ctx.recvThisLockout = BRutus.TMB:GetReceivedThisLockout(playerName, instID, wNum)
    end

    return ctx
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

    -- 4. Fallback: only the raid LEADER counts as ML (assistants cannot start rolls)
    if IsInRaid() then
        local myName = UnitName("player")
        for i = 1, GetNumGroupMembers() do
            local name, rank = GetRaidRosterInfo(i)
            if name and name == myName then
                return rank == 2 -- leader only; assistants (rank 1) are NOT allowed
            end
        end
    end

    return false
end

----------------------------------------------------------------------
-- /roll capture: start/stop listening for CHAT_MSG_SYSTEM roll results
----------------------------------------------------------------------
function LootMaster:StartListeningForRolls()
    self.listeningForRolls = true
end

function LootMaster:StopListeningForRolls()
    self.listeningForRolls = false
end

-- Called on every CHAT_MSG_SYSTEM event
function LootMaster:OnSystemMessage(message)
    if not self.listeningForRolls or not self.activeLoot then return end
    self:ProcessSystemRoll(message)
end

----------------------------------------------------------------------
-- Parse a CHAT_MSG_SYSTEM /roll line and register it as MS or OS.
--   MS = RandomRoll(1, 100)  |  OS = RandomRoll(1, 99)
-- All other roll ranges are ignored.
----------------------------------------------------------------------
function LootMaster:ProcessSystemRoll(message)
    if not self.rollPattern then return end

    local roller, roll, low, high = string.match(message, self.rollPattern)
    if not roller then return end

    roll = tonumber(roll)
    low  = tonumber(low)
    high = tonumber(high)
    if not roll or not low or not high then return end

    -- Only the two agreed-upon ranges count; ignore all other /roll usage
    local rollType
    if low == 1 and high == 100 then
        rollType = "MS"
    elseif low == 1 and high == 99 then
        rollType = "OS"
    else
        return
    end

    -- Strip realm suffix that may appear in some client versions
    local cleanName = roller:match("^([^%-]+)") or roller

    -- Verify the roller is currently in the raid (or testMode)
    local inRaid = self.testMode
    if not inRaid then
        local numMembers = GetNumGroupMembers() or 0
        for i = 1, numMembers do
            local uName = UnitName("raid" .. i)
            if uName and (uName == cleanName or uName == roller) then
                inRaid = true
                break
            end
        end
        -- Also accept own roll (solo / testMode outside raid)
        if not inRaid and cleanName == UnitName("player") then
            inRaid = true
        end
    end

    if not inRaid then return end

    -- Restricted-roll session: only allowed players may roll; ignore everyone else silently
    if self.restrictedRollers and not self.restrictedRollers[strlower(cleanName)] then
        return
    end

    self:RegisterRoll(cleanName, rollType, roll)
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

    if #items > 0 then
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
-- Announce an item for rolling.
-- Priority logic (always active, regardless of TMB_ONLY_MODE):
--   ≥ 2 players tied at top TMB prio in raid → restricted roll (only they roll)
--   1 clear winner + TMB_ONLY_MODE           → AutoCouncilAward (direct award prompt)
--   otherwise                                 → open MS/OS roll for all
----------------------------------------------------------------------
function LootMaster:AnnounceItem(itemLink, lootSlot)
    if not IsInRaid() and not self.testMode then
        BRutus:Print("You must be in a raid to announce loot.")
        return
    end

    -- Clear previous session
    self.rolls             = {}
    self.restrictedRollers = nil
    self.activeLoot = {
        link      = itemLink,
        slot      = lootSlot,
        startTime = GetServerTime(),
        endTime   = GetServerTime() + self.ROLL_DURATION,
    }

    local itemId = tonumber(itemLink:match("item:(%d+)"))
    self.activeLoot.itemId = itemId

    -- Always check TMB for tied top-priority players currently in raid
    if itemId and itemId > 0 then
        local council = self:ResolveTMBCouncil(itemId)
        if council then
            local top  = council[1]
            local tied = {}
            for _, c in ipairs(council) do
                if c.tmbType == top.tmbType and c.order == top.order then
                    table.insert(tied, c)
                end
            end

            if #tied >= 2 then
                -- Tie at top priority: only those players roll
                self:StartRestrictedRoll(tied, council, itemLink, lootSlot, itemId)
                return
            elseif #tied == 1 and self.TMB_ONLY_MODE then
                -- Single clear winner + TMB-only mode: prompt ML for direct award
                self:AutoCouncilAward(top, itemLink, lootSlot, council)
                return
            end
            -- Single winner but TMB_ONLY_MODE off: open roll for all, mention winner
            self:DoNormalAnnounce(itemLink, lootSlot, itemId, top)
            return
        end
    end

    -- No TMB data for this item: open roll for all
    self:DoNormalAnnounce(itemLink, lootSlot, itemId, nil)
end

----------------------------------------------------------------------
-- Normal announce — open MS/OS roll for everyone in the raid.
-- topPrioEntry (optional): TMB entry of the single top-prio player, used
-- to post an info line about who has priority (without restricting rolls).
----------------------------------------------------------------------
function LootMaster:DoNormalAnnounce(itemLink, _lootSlot, itemId, topPrioEntry)
    -- Main announce
    local msg = format("{rt4} ROLL: %s {rt4}  |  /roll 1-100 = MS  |  /roll 1-99 = OS  |  %ds",
        itemLink, self.ROLL_DURATION)
    self:SafeSendChat(msg, "RAID_WARNING")

    -- If someone has TMB priority (but no tie), announce them as an info note
    if topPrioEntry then
        local infoMsg = format("[TMB] Prioridade: %s (%s #%d) — roll aberto para todos",
            topPrioEntry.name, topPrioEntry.tmbType, topPrioEntry.order)
        self:SafeSendChat(infoMsg, "RAID")
    end

    -- Send addon message so BRutus users get the roll popup
    local payload = format("ANNOUNCE|%s|%d|%d|0", itemLink, self.ROLL_DURATION, itemId or 0)
    self:SafeSendAddon("BRutusLM", payload, "RAID")

    -- Start capturing /roll results from CHAT_MSG_SYSTEM
    self:StartListeningForRolls()

    -- Start countdown timer
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
-- Restricted roll: only the tied top-priority players may roll.
-- Rolls from anyone else are silently ignored by ProcessSystemRoll.
----------------------------------------------------------------------
function LootMaster:StartRestrictedRoll(tied, allCandidates, itemLink, _lootSlot, itemId)
    -- Build restricted set (lowercase names for fast lookup)
    self.restrictedRollers = {}
    local names = {}
    for _, c in ipairs(tied) do
        self.restrictedRollers[strlower(c.name)] = true
        table.insert(names, c.name)
    end
    local tmbStr  = string.format("%s #%d", tied[1].tmbType, tied[1].order)
    local nameStr = table.concat(names, ", ")

    -- Announce in RAID_WARNING — only listed players should roll
    self:SafeSendChat(
        string.format("{rt4} ROLL: %s {rt4}  |  Prioridade empatada [%s]: %s  |  /roll 1-100 MS  |  /roll 1-99 OS  |  %ds",
            itemLink, tmbStr, nameStr, self.ROLL_DURATION),
        "RAID_WARNING"
    )

    -- Addon comm: show popup to BRutus users who have the item on TMB
    itemId = itemId or (self.activeLoot and self.activeLoot.itemId) or 0
    local payload = string.format("ANNOUNCE|%s|%d|%d|1", itemLink, self.ROLL_DURATION, itemId)
    self:SafeSendAddon("BRutusLM", payload, "RAID")

    -- Start capturing /roll (restricted list enforced in ProcessSystemRoll)
    self:StartListeningForRolls()

    -- Timer
    if self.rollTimer then self.rollTimer:Cancel() end
    self.rollTimer = C_Timer.NewTimer(self.ROLL_DURATION, function()
        LootMaster:EndRolling()
    end)

    -- Show roll tracker for ML
    self:ShowRollFrame()

    BRutus:Print(string.format("|cffFFD700TMB tie|r [%s]: %s — apenas eles podem rolar (%ds)",
        tmbStr, nameStr, self.ROLL_DURATION))
end

----------------------------------------------------------------------
-- Kept for compatibility: delegates to StartRestrictedRoll
----------------------------------------------------------------------
function LootMaster:AutoCouncilRoll(tied, itemLink, lootSlot, allCandidates)
    local itemId = self.activeLoot and self.activeLoot.itemId or 0
    self:StartRestrictedRoll(tied, allCandidates, itemLink, lootSlot, itemId)
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
    f:SetSize(460, 110 + numRows * 22)
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
            local ctx = LootMaster:GetPlayerContext(c.name)
            local attColor = ctx.att25 >= 60 and "00FF00" or ctx.att25 >= 40 and "FFFF00" or "FF4444"
            local recvColor = ctx.recvThisLockout >= 2 and "FF4444"
                or ctx.recvThisLockout == 1 and "FFFF00" or "888888"
            local row = f:CreateFontString(nil, "OVERLAY")
            row:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            row:SetPoint("TOPLEFT", 14, yOff)
            local tc = c.tmbType == "prio" and "|cffFF8000" or "|cff4CB8FF"
            local prefix = (i == 1) and "|cff00ff00>>|r " or "   "
            row:SetText(string.format(
                "%s|cff%02x%02x%02x%s|r  %s%s #%d|r  |cff%s%d%%|r  |cff%sR:%d|r",
                prefix, ccc.r * 255, ccc.g * 255, ccc.b * 255,
                c.name, tc, c.tmbType, c.order,
                attColor, ctx.att25,
                recvColor, ctx.recvThisLockout))
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

    elseif cmd == "AWARD" then
        -- ML awarded item (informational broadcast)
        local awardedTo, link = rest:match("^([^|]+)|(.+)$")
        if awardedTo and link then
            BRutus:Print(string.format("|cffFFD700Loot:|r %s awarded to |cff00ff00%s|r", link, awardedTo))
        end
    end
end

----------------------------------------------------------------------
-- Register a player's /roll result (called from ProcessSystemRoll).
-- name: bare player name (no realm);  rollType: "MS" or "OS";
-- roll: the actual number the player rolled.
----------------------------------------------------------------------
function LootMaster:RegisterRoll(name, rollType, roll)
    if not self.activeLoot then return end

    local key = name .. "-" .. (GetRealmName() or "")

    -- Attendance gate: auto-downgrade MS → OS if below minimum threshold
    local ctx = self:GetPlayerContext(name)
    local minAtt = BRutus.db.lootMaster.minAttendancePct or 0
    if rollType == "MS" and minAtt > 0 and ctx.att25 < minAtt then
        rollType = "OS"
        self:SafeSendChat(string.format(
            "[Loot] %s: MS downgraded to OS (attendance %d%% < required %d%%)",
            name, ctx.att25, minAtt), "RAID")
    end

    -- TMB lookup
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

    -- Class from raid unit or stored member data
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
    if class == "UNKNOWN" then
        local pKey = BRutus:GetPlayerKey(name, GetRealmName())
        local memberData = BRutus.db.members and BRutus.db.members[pKey]
        if memberData and memberData.class then
            class = memberData.class
        elseif name == UnitName("player") then
            class = select(2, UnitClass("player")) or "UNKNOWN"
        end
    end

    self.rolls[key] = {
        name      = name,
        class     = class,
        rollType  = rollType,
        roll      = roll,   -- actual /roll result (1-100 or 1-99)
        tmb       = tmbInfo,
        att25     = ctx.att25,
        recvCount = ctx.recvThisLockout,
    }

    -- Announce TMB tier to raid (the /roll number is already visible in system chat)
    if tmbInfo then
        self:SafeSendChat(string.format("[Loot] %s: %s [TMB: %s #%d]",
            name, rollType, tmbInfo.type, tmbInfo.order), "RAID")
    end

    -- Refresh ML roll frame
    if self.rollFrame and self.rollFrame:IsShown() then
        self:RefreshRollFrame()
    end
end

----------------------------------------------------------------------
-- End rolling and display results
----------------------------------------------------------------------
function LootMaster:EndRolling()
    if not self.activeLoot then return end

    self:StopListeningForRolls()
    self.restrictedRollers = nil

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
        -- Attendance tiebreaker: higher 25-man attendance wins
        if BRutus.db.lootMaster.attTiebreaker and (a.att25 or 0) ~= (b.att25 or 0) then
            return (a.att25 or 0) > (b.att25 or 0)
        end
        -- Received penalty: fewer items received this lockout ranks higher
        if BRutus.db.lootMaster.recvPenalty and (a.recvCount or 0) ~= (b.recvCount or 0) then
            return (a.recvCount or 0) < (b.recvCount or 0)
        end
        -- Final tiebreaker: higher roll
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

    -- Record in TMB local data for lockout-received tracking
    if BRutus.TMB and itemId then
        local _, _, _, _, _, _, _, instID = GetInstanceInfo()
        local wNum = BRutus.RaidTracker
            and BRutus.RaidTracker:GetWeekNum(GetServerTime()) or 0
        BRutus.TMB:RecordReceived(playerName, itemId, itemLink, instID, wNum)
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
    self:StopListeningForRolls()
    self.restrictedRollers = nil
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
-- Raider: perform /roll (MS = 1-100, OS = 1-99).
-- The ML captures the result via CHAT_MSG_SYSTEM — no addon comm needed.
----------------------------------------------------------------------
function LootMaster:SendMyRoll(rollType)
    if rollType == "MS" then
        RandomRoll(1, 100)
    elseif rollType == "OS" then
        RandomRoll(1, 99)
    end
    -- PASS: nothing to send — simply not rolling is sufficient
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
        RandomRoll(1, 100)  -- MS = /roll 1-100  (captured by ML via CHAT_MSG_SYSTEM)
        f:Hide()
        BRutus:Print("Rolled |cff00ff00MS|r on " .. (itemLink or "item") .. " — /roll 1-100")
    end)

    local osBtn = UI:CreateButton(f, "OS", 80, 26)
    osBtn:SetPoint("BOTTOM", 0, 10)
    osBtn:SetBackdropColor(0.3, 0.3, 0.0, 0.6)
    osBtn:SetScript("OnClick", function()
        RandomRoll(1, 99)   -- OS = /roll 1-99
        f:Hide()
        BRutus:Print("Rolled |cffFFFF00OS|r on " .. (itemLink or "item") .. " — /roll 1-99")
    end)

    local passBtn = UI:CreateButton(f, "Pass", 80, 26)
    passBtn:SetPoint("BOTTOMRIGHT", -15, 10)
    passBtn:SetBackdropColor(0.4, 0.0, 0.0, 0.6)
    passBtn:SetScript("OnClick", function()
        f:Hide()  -- Just close — no roll needed to pass
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
-- Set active loot for direct award (without starting a roll session)
----------------------------------------------------------------------
function LootMaster:SetActiveLoot(link, slot, itemId)
    self.activeLoot = {
        link      = link,
        slot      = slot,
        itemId    = itemId,
        startTime = GetServerTime(),
        endTime   = GetServerTime(),
    }
    self.rolls = {}
end

----------------------------------------------------------------------
-- UI: Loot frame for ML — auto-opens on boss kill, shows TMB priority
-- per item; officer can award directly or open a roll for tied players.
----------------------------------------------------------------------
function LootMaster:ShowLootFrame(items)
    local C  = BRutus.Colors
    local UI = BRutus.UI

    if self.lootFrame then self.lootFrame:Hide() end

    local FRAME_W = 680
    local FRAME_H = 440
    local LEFT_W  = 178
    local RIGHT_X = LEFT_W + 12
    local rightW  = FRAME_W - LEFT_W - 22

    local f = CreateFrame("Frame", "BRutusMLLootFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_W, FRAME_H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    f:SetBackdropColor(0.06, 0.05, 0.10, 0.97)
    f:SetBackdropBorderColor(C.accent.r, C.accent.g, C.accent.b, 0.9)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)

    -- Title
    local titleText = f:CreateFontString(nil, "OVERLAY")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    titleText:SetPoint("TOPLEFT", 12, -10)
    titleText:SetTextColor(C.gold.r, C.gold.g, C.gold.b)
    titleText:SetText("Master Loot")

    -- Instance name
    local instText = f:CreateFontString(nil, "OVERLAY")
    instText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    instText:SetPoint("TOPLEFT", 132, -12)
    instText:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    local instName = GetInstanceInfo and (select(1, GetInstanceInfo())) or ""
    instText:SetText((instName and instName ~= "") and ("— " .. instName) or "")

    -- Close
    local closeBtn = UI:CreateCloseButton(f)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Title separator
    local titleSep = f:CreateTexture(nil, "ARTWORK")
    titleSep:SetTexture("Interface\\Buttons\\WHITE8x8")
    titleSep:SetHeight(1)
    titleSep:SetPoint("TOPLEFT",  8, -26)
    titleSep:SetPoint("TOPRIGHT", -8, -26)
    titleSep:SetVertexColor(C.accent.r, C.accent.g, C.accent.b, 0.4)

    -- Vertical divider between left and right
    local vDiv = f:CreateTexture(nil, "ARTWORK")
    vDiv:SetTexture("Interface\\Buttons\\WHITE8x8")
    vDiv:SetWidth(1)
    vDiv:SetPoint("TOPLEFT",    LEFT_W + 4, -28)
    vDiv:SetPoint("BOTTOMLEFT", LEFT_W + 4, 42)
    vDiv:SetVertexColor(C.border.r, C.border.g, C.border.b, 0.5)

    ----------------------------------------------------------------
    -- Left panel: items list
    ----------------------------------------------------------------
    local itemsLabel = f:CreateFontString(nil, "OVERLAY")
    itemsLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    itemsLabel:SetPoint("TOPLEFT", 8, -30)
    itemsLabel:SetTextColor(C.accent.r, C.accent.g, C.accent.b)
    itemsLabel:SetText("LOOT  (" .. #items .. ")")

    local selectedBtn  = nil
    local selectedItem = nil
    local itemBtns     = {}

    ----------------------------------------------------------------
    -- Right panel: selected item header + column headers
    ----------------------------------------------------------------
    local selItemText = f:CreateFontString(nil, "OVERLAY")
    selItemText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    selItemText:SetPoint("TOPLEFT", RIGHT_X, -30)
    selItemText:SetWidth(rightW - 10)
    selItemText:SetJustifyH("LEFT")
    selItemText:SetText("|cff888888Select an item from the left.|r")

    -- Column headers
    local prioHdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
    prioHdr:SetSize(rightW, 16)
    prioHdr:SetPoint("TOPLEFT", RIGHT_X, -48)
    prioHdr:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    prioHdr:SetBackdropColor(0.04, 0.04, 0.08, 1)
    local function PH(txt, x)
        local t = prioHdr:CreateFontString(nil, "OVERLAY")
        t:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        t:SetPoint("LEFT", x, 0)
        t:SetTextColor(C.accent.r, C.accent.g, C.accent.b)
        t:SetText(txt)
    end
    PH("#", 4); PH("TYPE", 22); PH("ORDER", 64); PH("PLAYER", 106); PH("ATT%", 210); PH("RECV", 255); PH("IN RAID", 295)

    -- Priority scroll area
    local prioContainer = CreateFrame("Frame", nil, f)
    prioContainer:SetPoint("TOPLEFT",     RIGHT_X, -66)
    prioContainer:SetPoint("BOTTOMRIGHT", -8,       42)

    local prioScroll = CreateFrame("ScrollFrame", "BRutusMLPrioScroll", prioContainer, "UIPanelScrollFrameTemplate")
    prioScroll:SetPoint("TOPLEFT",     0, 0)
    prioScroll:SetPoint("BOTTOMRIGHT", 0, 0)
    UI:SkinScrollBar(prioScroll, "BRutusMLPrioScroll")

    local prioChild = CreateFrame("Frame", nil, prioScroll)
    prioChild:SetWidth(rightW - 20)
    prioChild:SetHeight(1)
    prioScroll:SetScrollChild(prioChild)

    prioContainer:SetScript("OnSizeChanged", function(self)
        prioChild:SetWidth(math.max(1, self:GetWidth() - 20))
    end)

    -- Bottom row: status text + Roll + Award buttons
    local statusText = f:CreateFontString(nil, "OVERLAY")
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    statusText:SetPoint("BOTTOMLEFT", RIGHT_X, 14)
    statusText:SetWidth(rightW - 290)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("")

    local awardTopBtn = UI:CreateButton(f, "Award #1", 140, 26)
    awardTopBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    awardTopBtn:Disable()

    local openRollBtn = UI:CreateButton(f, "Open Roll", 120, 26)
    openRollBtn:SetPoint("RIGHT", awardTopBtn, "LEFT", -6, 0)

    local topCandidate = nil
    local tiedCount    = 0

    ----------------------------------------------------------------
    -- Helper: build raid-member name→class lookup
    ----------------------------------------------------------------
    local function BuildRaidMap()
        local map = {}
        local n = GetNumGroupMembers()
        for i = 1, n do
            local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
            local name = UnitName(unit)
            if name then
                map[strlower(name)] = select(2, UnitClass(unit)) or "UNKNOWN"
            end
        end
        local myName = UnitName("player")
        if myName then
            map[strlower(myName)] = select(2, UnitClass("player")) or "UNKNOWN"
        end
        return map
    end

    ----------------------------------------------------------------
    -- Helper: do the award + TMB record + UI update
    ----------------------------------------------------------------
    local function DoAward(item, entryName)
        local iId = tonumber(item.link:match("item:(%d+)"))
        LootMaster:SetActiveLoot(item.link, item.slot, iId)
        LootMaster:AwardLoot(entryName)  -- RecordReceived is called inside AwardLoot
        statusText:SetText("|cff4CFF4CAwarded to " .. entryName .. "!|r")
        if itemBtns[item.slot] then
            itemBtns[item.slot].awardedText:Show()
        end
    end

    ----------------------------------------------------------------
    -- Load priority list for a selected item
    ----------------------------------------------------------------
    local function LoadItem(item)
        selectedItem = item
        topCandidate = nil
        tiedCount    = 0
        statusText:SetText("")

        selItemText:SetText(item.link)

        -- Clear previous list
        for _, ch in ipairs({ prioChild:GetChildren() }) do ch:Hide() end
        for _, rg in ipairs({ prioChild:GetRegions() }) do rg:Hide() end

        local itemId = tonumber(item.link:match("item:(%d+)"))

        local function NoData(msg)
            local t = prioChild:CreateFontString(nil, "OVERLAY")
            t:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
            t:SetPoint("TOPLEFT", 6, -14)
            t:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
            t:SetText(msg)
            prioChild:SetHeight(40)
            awardTopBtn:SetText("Award #1")
            awardTopBtn:Disable()
            openRollBtn:SetText("Roll for All")
        end

        if not itemId then
            NoData("Could not parse item ID.")
            return
        end

        -- Full TMB interest list (unfiltered; we apply raid filter ourselves)
        local interest = BRutus.TMB and BRutus.TMB:GetItemInterest(itemId) or nil
        local candidates = {}
        if interest then
            for _, e in ipairs(interest) do
                if e.type ~= "received" then
                    table.insert(candidates, e)
                end
            end
        end

        if #candidates == 0 then
            NoData("No TMB data for this item — use Open Roll.")
            return
        end

        local raidMap = BuildRaidMap()

        -- Find first in-raid candidate (candidates already sorted prio→wish→order)
        for _, e in ipairs(candidates) do
            if raidMap[strlower(e.name)] then
                if not topCandidate then topCandidate = e end
            end
        end

        -- Count how many share the exact same top tier
        if topCandidate then
            for _, e in ipairs(candidates) do
                if raidMap[strlower(e.name)]
                    and e.type  == topCandidate.type
                    and e.order == topCandidate.order then
                    tiedCount = tiedCount + 1
                end
            end
        end

        -- Update bottom buttons
        if topCandidate then
            if tiedCount == 1 then
                awardTopBtn:SetText("Award → " .. topCandidate.name)
                awardTopBtn:Enable()
                openRollBtn:SetText("Open Roll")
            else
                awardTopBtn:SetText("Tied " .. tiedCount .. " — Roll")
                awardTopBtn:Disable()
                openRollBtn:SetText("Roll Tied (" .. tiedCount .. ")")
            end
        else
            awardTopBtn:SetText("Award #1")
            awardTopBtn:Disable()
            openRollBtn:SetText("Roll for All")
        end

        -- Render priority rows
        local yOff = 0
        local rowW = math.max(10, prioChild:GetWidth())
        if rowW < 10 then rowW = rightW - 24 end

        for idx, e in ipairs(candidates) do
            local isPresent = raidMap[strlower(e.name)] ~= nil
            local isTopTier = topCandidate
                and e.type  == topCandidate.type
                and e.order == topCandidate.order
            local rowH = 22

            local row = CreateFrame("Frame", nil, prioChild, "BackdropTemplate")
            row:SetSize(rowW, rowH)
            row:SetPoint("TOPLEFT", 0, -yOff)
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

            local bg = (idx % 2 == 1) and C.row1 or C.row2
            local bgA = isPresent and (bg.a or 1) or (bg.a or 1) * 0.4

            if isTopTier and isPresent then
                row:SetBackdropColor(0.10, 0.12, 0.22, 1.0)
                -- accent bar on left edge
                local bar = row:CreateTexture(nil, "ARTWORK")
                bar:SetTexture("Interface\\Buttons\\WHITE8x8")
                bar:SetPoint("TOPLEFT",    0, 0)
                bar:SetPoint("BOTTOMLEFT", 0, 0)
                bar:SetWidth(3)
                local tc = e.type == "prio" and C.accent or C.gold
                bar:SetVertexColor(tc.r, tc.g, tc.b, 0.9)
            else
                row:SetBackdropColor(bg.r, bg.g, bg.b, bgA)
            end

            -- Column: index
            local idxT = row:CreateFontString(nil, "OVERLAY")
            idxT:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            idxT:SetPoint("LEFT", 4, 0)
            idxT:SetText(idx)
            idxT:SetTextColor(
                isPresent and C.gold.r or 0.35,
                isPresent and C.gold.g or 0.35,
                isPresent and C.gold.b or 0.35)

            -- Column: type
            local typeT = row:CreateFontString(nil, "OVERLAY")
            typeT:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
            typeT:SetPoint("LEFT", 22, 0)
            typeT:SetText(e.type == "prio" and "PRIO" or "WISH")
            local tc2 = e.type == "prio" and C.accent or C.gold
            typeT:SetTextColor(
                isPresent and tc2.r or 0.3,
                isPresent and tc2.g or 0.3,
                isPresent and tc2.b or 0.3)

            -- Column: order
            local ordT = row:CreateFontString(nil, "OVERLAY")
            ordT:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
            ordT:SetPoint("LEFT", 64, 0)
            ordT:SetText("#" .. (e.order or "?"))
            ordT:SetTextColor(
                isPresent and 0.65 or 0.3,
                isPresent and 0.65 or 0.3,
                isPresent and 0.65 or 0.3)

            -- Column: player name (class-colored if in raid)
            local nameT = row:CreateFontString(nil, "OVERLAY")
            nameT:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            nameT:SetPoint("LEFT", 106, 0)
            nameT:SetWidth(100)
            if isPresent then
                local rClass = raidMap[strlower(e.name)]
                local cr, cg, cb = BRutus:GetClassColor(rClass or e.class)
                nameT:SetTextColor(cr, cg, cb)
            else
                nameT:SetTextColor(0.4, 0.4, 0.4)
            end
            nameT:SetText(e.name)

            -- Column: ATT% (25-man attendance)
            local attCtx = LootMaster:GetPlayerContext(e.name)
            local attT = row:CreateFontString(nil, "OVERLAY")
            attT:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            attT:SetPoint("LEFT", 210, 0)
            attT:SetWidth(40)
            attT:SetJustifyH("CENTER")
            if attCtx.att25 >= 60 then
                attT:SetTextColor(0.3, 1.0, 0.3)
            elseif attCtx.att25 >= 40 then
                attT:SetTextColor(1.0, 1.0, 0.3)
            else
                attT:SetTextColor(1.0, 0.3, 0.3)
            end
            attT:SetText(attCtx.att25 .. "%")

            -- Column: RECV (items received this lockout)
            local recvT = row:CreateFontString(nil, "OVERLAY")
            recvT:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            recvT:SetPoint("LEFT", 255, 0)
            recvT:SetWidth(35)
            recvT:SetJustifyH("CENTER")
            if attCtx.recvThisLockout == 0 then
                recvT:SetTextColor(0.4, 0.4, 0.4)
            elseif attCtx.recvThisLockout == 1 then
                recvT:SetTextColor(1.0, 1.0, 0.3)
            else
                recvT:SetTextColor(1.0, 0.3, 0.3)
            end
            recvT:SetText(tostring(attCtx.recvThisLockout))

            -- Column: in-raid indicator
            local raidT = row:CreateFontString(nil, "OVERLAY")
            raidT:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
            raidT:SetPoint("LEFT", 295, 0)
            if isPresent then
                raidT:SetTextColor(0.3, 1.0, 0.3)
                raidT:SetText("IN RAID")
            else
                raidT:SetTextColor(0.4, 0.4, 0.4)
                raidT:SetText("absent")
            end

            -- Award button (in-raid + ML only)
            if isPresent and LootMaster:IsMasterLooter() then
                local aBtn = UI:CreateButton(row, "Award", 58, 18)
                aBtn:SetPoint("RIGHT", -4, 0)
                local capturedEntry = e
                local capturedItem  = item
                aBtn:SetScript("OnClick", function()
                    DoAward(capturedItem, capturedEntry.name)
                    C_Timer.After(0.3, function()
                        if selectedItem == capturedItem then
                            LoadItem(capturedItem)
                        end
                    end)
                end)
            end

            -- Row hover
            local capturedBg   = bg
            local capturedBgA  = bgA
            local capturedTop  = isTopTier and isPresent
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                self:SetBackdropColor(C.rowHover.r, C.rowHover.g, C.rowHover.b, C.rowHover.a)
            end)
            row:SetScript("OnLeave", function(self)
                if capturedTop then
                    self:SetBackdropColor(0.10, 0.12, 0.22, 1.0)
                else
                    self:SetBackdropColor(capturedBg.r, capturedBg.g, capturedBg.b, capturedBgA)
                end
            end)

            yOff = yOff + rowH + 2
        end

        -- "Already received by" section
        if interest then
            local recvList = {}
            for _, e in ipairs(interest) do
                if e.type == "received" then table.insert(recvList, e) end
            end
            if #recvList > 0 then
                yOff = yOff + 6
                local recvHdr = prioChild:CreateFontString(nil, "OVERLAY")
                recvHdr:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
                recvHdr:SetPoint("TOPLEFT", 4, -yOff)
                recvHdr:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
                recvHdr:SetText("Already received:")
                yOff = yOff + 16
                for _, e in ipairs(recvList) do
                    local rt = prioChild:CreateFontString(nil, "OVERLAY")
                    rt:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
                    rt:SetPoint("TOPLEFT", 12, -yOff)
                    rt:SetTextColor(0.5, 0.5, 0.5)
                    rt:SetText(e.name .. (e.receivedAt and " (" .. e.receivedAt .. ")" or ""))
                    yOff = yOff + 16
                end
            end
        end

        prioChild:SetHeight(math.max(1, yOff + 8))
    end

    ----------------------------------------------------------------
    -- Left panel: one button per loot item
    ----------------------------------------------------------------
    local leftYOff = 34
    for _, item in ipairs(items) do
        local btn = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(LEFT_W - 10, 32)
        btn:SetPoint("TOPLEFT", 5, -leftYOff)
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.09, 0.07, 0.14, 0.7)
        btn:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.3)

        -- Quality-colored item name
        local qc = BRutus.QualityColors[item.quality] or BRutus.QualityColors[4]
        local nameT = btn:CreateFontString(nil, "OVERLAY")
        nameT:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        nameT:SetPoint("TOPLEFT", 6, -4)
        nameT:SetWidth(LEFT_W - 24)
        nameT:SetJustifyH("LEFT")
        nameT:SetTextColor(qc.r, qc.g, qc.b)
        nameT:SetText(item.name or item.link)

        -- "✓ awarded" badge (hidden initially)
        local aText = btn:CreateFontString(nil, "OVERLAY")
        aText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        aText:SetPoint("BOTTOMLEFT", 6, 3)
        aText:SetTextColor(0.3, 1.0, 0.3)
        aText:SetText("awarded")
        aText:Hide()
        btn.awardedText = aText

        -- Tooltip
        local capturedItem = item
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C.rowHover.r, C.rowHover.g, C.rowHover.b, C.rowHover.a)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(capturedItem.link)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            if selectedItem == capturedItem then
                self:SetBackdropColor(0.16, 0.10, 0.26, 0.9)
            else
                self:SetBackdropColor(0.09, 0.07, 0.14, 0.7)
            end
            GameTooltip:Hide()
        end)
        btn:SetScript("OnClick", function(self)
            if selectedBtn then
                selectedBtn:SetBackdropColor(0.09, 0.07, 0.14, 0.7)
            end
            selectedBtn = self
            self:SetBackdropColor(0.16, 0.10, 0.26, 0.9)
            LoadItem(capturedItem)
        end)

        itemBtns[item.slot] = btn
        leftYOff = leftYOff + 34
    end

    -- TMB Council toggle (bottom-left)
    local tmbCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    tmbCheck:SetSize(22, 22)
    tmbCheck:SetPoint("BOTTOMLEFT", 5, 14)
    tmbCheck:SetChecked(self.TMB_ONLY_MODE)
    tmbCheck:SetScript("OnClick", function(cb)
        local val = cb:GetChecked()
        LootMaster.TMB_ONLY_MODE = val
        BRutus.db.lootMaster.tmbOnlyMode = val
    end)
    local tmbLabel = f:CreateFontString(nil, "OVERLAY")
    tmbLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    tmbLabel:SetPoint("LEFT", tmbCheck, "RIGHT", 2, 0)
    tmbLabel:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    tmbLabel:SetText("TMB Council")

    ----------------------------------------------------------------
    -- Bottom button handlers
    ----------------------------------------------------------------
    awardTopBtn:SetScript("OnClick", function()
        if not topCandidate or not selectedItem then
            statusText:SetText("|cffFF4444No top priority candidate.|r")
            return
        end
        DoAward(selectedItem, topCandidate.name)
        C_Timer.After(0.3, function()
            if selectedItem then LoadItem(selectedItem) end
        end)
    end)

    openRollBtn:SetScript("OnClick", function()
        if not selectedItem then
            statusText:SetText("|cffFF4444Select an item first.|r")
            return
        end
        LootMaster:AnnounceItem(selectedItem.link, selectedItem.slot)
        LootMaster:ShowRollFrame()
        statusText:SetText("|cffFFFF00Roll opened!|r")
    end)

    ----------------------------------------------------------------
    -- Auto-select first item
    ----------------------------------------------------------------
    if #items > 0 then
        local firstBtn = itemBtns[items[1].slot]
        if firstBtn then
            selectedBtn = firstBtn
            firstBtn:SetBackdropColor(0.16, 0.10, 0.26, 0.9)
        end
        LoadItem(items[1])
    end

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
    f:SetSize(520, 350)
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
    local headers = { { "Player", 6 }, { "Type", 145 }, { "Roll", 195 }, { "TMB", 245 }, { "ATT%", 325 }, { "RECV", 375 } }
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
    scrollContent:SetSize(480, 1)
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

    -- Roll buttons for the initiator (ML can also compete for the item)
    -- OS button (right-most)
    local osRollBtn = UI:CreateButton(f, "OS", 64, 24)
    osRollBtn:SetPoint("BOTTOMRIGHT", -10, 12)
    osRollBtn:SetBackdropColor(0.3, 0.3, 0.0, 0.6)
    osRollBtn:SetScript("OnClick", function()
        RandomRoll(1, 99)   -- /roll 1-99 = OS; captured by ProcessSystemRoll
    end)
    osRollBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Roll Off-Spec\n|cff888888/roll 1-99|r", 1, 1, 1)
        GameTooltip:Show()
    end)
    osRollBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- MS button (left of OS)
    local msRollBtn = UI:CreateButton(f, "MS", 64, 24)
    msRollBtn:SetPoint("RIGHT", osRollBtn, "LEFT", -4, 0)
    msRollBtn:SetBackdropColor(0.0, 0.35, 0.0, 0.6)
    msRollBtn:SetScript("OnClick", function()
        RandomRoll(1, 100)  -- /roll 1-100 = MS; captured by ProcessSystemRoll
    end)
    msRollBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Roll Main Spec\n|cff888888/roll 1-100|r", 1, 1, 1)
        GameTooltip:Show()
    end)
    msRollBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Roll label
    local rollLabel = f:CreateFontString(nil, "OVERLAY")
    rollLabel:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
    rollLabel:SetPoint("BOTTOM", msRollBtn, "TOP", 32, 2)
    rollLabel:SetTextColor(C.silver.r, C.silver.g, C.silver.b)
    rollLabel:SetText("Your roll:")

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
        row:SetSize(480, 22)
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
        typeText:SetPoint("LEFT", 150, 0)
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
        rollText:SetPoint("LEFT", 200, 0)
        rollText:SetTextColor(1, 1, 1)
        rollText:SetText(r.rollType ~= "PASS" and tostring(r.roll) or "-")

        -- TMB info
        local tmbText = row:CreateFontString(nil, "OVERLAY")
        tmbText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        tmbText:SetPoint("LEFT", 250, 0)
        if r.tmb then
            local tc = r.tmb.type == "prio" and "|cffFF8000" or "|cff4CB8FF"
            tmbText:SetText(tc .. r.tmb.type .. " #" .. r.tmb.order .. "|r")
        else
            tmbText:SetTextColor(0.4, 0.4, 0.4)
            tmbText:SetText("-")
        end

        -- ATT% (25-man attendance)
        local attText = row:CreateFontString(nil, "OVERLAY")
        attText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        attText:SetPoint("LEFT", 330, 0)
        attText:SetWidth(42)
        attText:SetJustifyH("RIGHT")
        local att25 = r.att25 or 0
        if att25 >= 60 then
            attText:SetTextColor(0.3, 1.0, 0.3)
        elseif att25 >= 40 then
            attText:SetTextColor(1.0, 1.0, 0.3)
        else
            attText:SetTextColor(1.0, 0.3, 0.3)
        end
        attText:SetText(att25 .. "%")

        -- RECV (items received this lockout)
        local recvText = row:CreateFontString(nil, "OVERLAY")
        recvText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        recvText:SetPoint("LEFT", 378, 0)
        recvText:SetWidth(32)
        recvText:SetJustifyH("CENTER")
        local recvN = r.recvCount or 0
        if recvN == 0 then
            recvText:SetTextColor(0.4, 0.4, 0.4)
        elseif recvN == 1 then
            recvText:SetTextColor(1.0, 1.0, 0.3)
        else
            recvText:SetTextColor(1.0, 0.3, 0.3)
        end
        recvText:SetText(tostring(recvN))

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
