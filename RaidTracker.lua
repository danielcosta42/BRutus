----------------------------------------------------------------------
-- BRutus Guild Manager - Raid Attendance Tracker
-- Tracks raid attendance, logs raid sessions, computes attendance %
----------------------------------------------------------------------
local RaidTracker = {}
BRutus.RaidTracker = RaidTracker

-- TBC Raid instance IDs
RaidTracker.RAID_INSTANCES = {
    [532]  = "Karazhan",
    [544]  = "Magtheridon",
    [565]  = "Gruul's Lair",
    [548]  = "Serpentshrine Cavern",
    [550]  = "Tempest Keep",
    [534]  = "Hyjal Summit",
    [564]  = "Black Temple",
    [580]  = "Sunwell Plateau",
    [509]  = "AQ20",
    [531]  = "AQ40",
    [533]  = "Naxxramas",
    [309]  = "Zul'Gurub",
    [469]  = "BWL",
    [409]  = "Molten Core",
}

-- Raids that count for attendance (25-man progression)
RaidTracker.RAID_25MAN = {
    [544] = true,  -- Magtheridon's Lair
    [565] = true,  -- Gruul's Lair
    [548] = true,  -- Serpentshrine Cavern
    [550] = true,  -- Tempest Keep
    [534] = true,  -- Hyjal Summit
    [564] = true,  -- Black Temple
    [580] = true,  -- Sunwell Plateau
}

function RaidTracker:Is25Man(instanceID)
    return self.RAID_25MAN[instanceID] == true
end

RaidTracker.currentRaid = nil
RaidTracker.trackingActive = false
RaidTracker.snapshotTimer = nil
RaidTracker.endTimer = nil       -- grace-period timer before ending a session

-- Attendance penalty weights
RaidTracker.PENALTIES = {
    LATE       = 10,  -- arrived after first snapshot
    LEFT_EARLY = 10,  -- absent from last snapshot
    NO_CONSUMES = 10, -- no consumables during raid
}
-- Max score per lockout = 100, penalties subtract from it

-- TBC weekly reset epoch: 2006-01-03 00:00 UTC (a known Tuesday)
local TUESDAY_EPOCH = 1136246400
local WEEK_SECS     = 7 * 86400

----------------------------------------------------------------------
-- Returns the TBC reset week number for a given server timestamp.
-- Week boundaries fall on Tuesday 00:00 UTC.
----------------------------------------------------------------------
function RaidTracker:GetWeekNum(timestamp)
    return math.floor(((timestamp or 0) - TUESDAY_EPOCH) / WEEK_SECS)
end

function RaidTracker:Initialize()
    if not BRutus.db.raidTracker then
        BRutus.db.raidTracker = { sessions = {}, attendance = {} }
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("RAID_ROSTER_UPDATE")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("ENCOUNTER_START")
    frame:RegisterEvent("ENCOUNTER_END")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "ZONE_CHANGED_NEW_AREA" then
            RaidTracker:CheckZone()
        elseif event == "RAID_ROSTER_UPDATE" or event == "GROUP_ROSTER_UPDATE" then
            if RaidTracker.trackingActive then
                RaidTracker:TakeSnapshot("roster_change")
            end
        elseif event == "ENCOUNTER_START" then
            local encounterID, encounterName = ...
            RaidTracker:OnEncounterStart(encounterID, encounterName)
        elseif event == "ENCOUNTER_END" then
            local encounterID, encounterName, _, _, success = ...
            RaidTracker:OnEncounterEnd(encounterID, encounterName, success)
        elseif event == "PLAYER_ENTERING_WORLD" then
            -- Runs after the world fully loads; safe to access all DB data here.
            -- Merge any leftover duplicate sessions from old sessions.
            C_Timer.After(2, function()
                RaidTracker:MergeDuplicateSessions()
            end)
            -- Only fire once per session
            frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        end
    end)
end

function RaidTracker:CheckZone()
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType == "raid" and self.RAID_INSTANCES[instanceID] then
        -- We're inside a raid instance
        if self.endTimer then
            -- There was a pending end-of-session timer
            if self.currentRaid and self.currentRaid.instanceID == instanceID then
                -- Same raid: cancel the pending end and resume
                self.endTimer:Cancel()
                self.endTimer = nil
                BRutus:Print("|cffFFAA00Raid resumed — session continuing.|r")
                self:TakeSnapshot("raid_resumed")
                return
            else
                -- Different raid: end the old session immediately then start new
                self.endTimer:Cancel()
                self.endTimer = nil
                self:EndSession()
            end
        end
        if not self.trackingActive then
            self:StartSession(instanceID)
        end
    else
        -- Outside any tracked raid instance
        if self.trackingActive and not self.endTimer then
            -- Start a 20-minute grace period before actually ending the session.
            -- This covers wipes (zone to graveyard + run back) and short DCs.
            BRutus:Print("|cffFFAA00Left raid zone — session ends in 20 min if you don't return.|r")
            self.endTimer = C_Timer.NewTimer(1200, function()
                self.endTimer = nil
                RaidTracker:EndSession()
            end)
        end
    end
end

function RaidTracker:StartSession(instanceID)
    local raidName = self.RAID_INSTANCES[instanceID] or "Unknown"
    self.trackingActive = true
    self.currentRaid = {
        instanceID = instanceID,
        name = raidName,
        startTime = GetServerTime(),
        endTime = nil,
        snapshots = {},
        encounters = {},
        players = {},
    }
    self:TakeSnapshot("session_start")

    -- Periodic snapshots every 5 minutes
    self.snapshotTimer = C_Timer.NewTicker(300, function()
        if self.trackingActive then
            self:TakeSnapshot("periodic")
        end
    end)

    BRutus:Print("Raid tracking started: |cffFFD700" .. raidName .. "|r")
end

function RaidTracker:IsGuildRaid(session)
    local myGuild = GetGuildInfo("player")
    if not myGuild then return false end

    local players = session.players or {}
    local total = 0
    local guildCount = 0

    for key in pairs(players) do
        total = total + 1
        local name = key:match("^([^-]+)") or key
        local memberData = BRutus.db.members and BRutus.db.members[key]
        -- Check via member DB (fastest path — already synced)
        if memberData then
            guildCount = guildCount + 1
        else
            -- Fallback: scan guild roster for this name
            local numMembers = GetNumGuildMembers() or 0
            for i = 1, numMembers do
                local fullName = GetGuildRosterInfo(i)
                if fullName then
                    local short = fullName:match("^([^-]+)") or fullName
                    if short == name then
                        guildCount = guildCount + 1
                        break
                    end
                end
            end
        end
    end

    if total == 0 then return false end
    -- Require at least 50% guild members
    return (guildCount / total) >= 0.5
end

function RaidTracker:EndSession()
    if not self.currentRaid then return end

    self:TakeSnapshot("session_end")
    local endTime = GetServerTime()
    self.currentRaid.endTime = endTime
    self.currentRaid.duration = endTime - (self.currentRaid.startTime or endTime)
    self.trackingActive = false

    if self.snapshotTimer then
        self.snapshotTimer:Cancel()
        self.snapshotTimer = nil
    end

    -- Discard sessions shorter than 10 minutes (likely disconnects / quick zone-ins)
    local MIN_SESSION_DURATION = 600
    if self.currentRaid.duration < MIN_SESSION_DURATION then
        BRutus:Print("|cffFFAA00Raid session discarded (too short: "
            .. self.currentRaid.duration .. "s < " .. MIN_SESSION_DURATION .. "s).|r")
        self.currentRaid = nil
        return
    end

    -- Save session
    local sessionID = self.currentRaid.startTime
    BRutus.db.raidTracker.sessions[sessionID] = self.currentRaid

    -- Only count attendance if this was a guild raid (≥50% guild members)
    if self:IsGuildRaid(self.currentRaid) then
        self.currentRaid.isGuildRaid = true
        -- Rebuild from scratch so lockout-dedup logic always applies
        self:RebuildAttendanceFromSessions()
    else
        self.currentRaid.isGuildRaid = false
        BRutus:Print("|cffFF9900Raid ended — less than 50% guild members, attendance not counted.|r")
    end

    BRutus:Print("Raid tracking ended: |cffFFD700" .. self.currentRaid.name .. "|r")
    self.currentRaid = nil

    -- Broadcast updated raid data to all officer clients
    C_Timer.After(1, function()
        RaidTracker:BroadcastRaidData()
    end)
end

function RaidTracker:TakeSnapshot(reason)
    if not self.currentRaid then return end

    local members = {}
    local numMembers = GetNumGroupMembers()
    if numMembers == 0 then return end

    local isRaid = IsInRaid()
    for i = 1, numMembers do
        local unit = isRaid and ("raid" .. i) or ("party" .. i)
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            if name then
                realm = realm and realm ~= "" and realm or GetRealmName()
                local key = name .. "-" .. realm
                members[key] = {
                    name = name,
                    class = select(2, UnitClass(unit)) or "UNKNOWN",
                    online = UnitIsConnected(unit),
                    hasConsumes = self:CheckPlayerConsumes(unit),
                }
                self.currentRaid.players[key] = true
            end
        end
    end

    -- Include self
    local myName = UnitName("player")
    local myRealm = GetRealmName()
    local myKey = myName .. "-" .. myRealm
    members[myKey] = {
        name = myName,
        class = select(2, UnitClass("player")),
        online = true,
        hasConsumes = self:CheckPlayerConsumes("player"),
    }
    self.currentRaid.players[myKey] = true

    table.insert(self.currentRaid.snapshots, {
        time = GetServerTime(),
        reason = reason,
        members = members,
        count = self:CountTable(members),
    })
end

----------------------------------------------------------------------
-- Check if a unit has at least flask/elixir + food active
----------------------------------------------------------------------
function RaidTracker:CheckPlayerConsumes(unit)
    if not BRutus.ConsumableChecker then return true end

    local CC = BRutus.ConsumableChecker
    local hasFlaskOrElixir = false
    local hasFood = false

    -- Check flask
    for buffID in pairs(CC.CONSUMABLES.flask.buffs) do
        if CC:UnitHasBuff(unit, buffID) then
            hasFlaskOrElixir = true
            break
        end
    end

    -- If no flask, check battle elixir as alternative
    if not hasFlaskOrElixir then
        for buffID in pairs(CC.CONSUMABLES.battleElixir.buffs) do
            if CC:UnitHasBuff(unit, buffID) then
                hasFlaskOrElixir = true
                break
            end
        end
    end

    -- Check food
    for buffID in pairs(CC.CONSUMABLES.food.buffs) do
        if CC:UnitHasBuff(unit, buffID) then
            hasFood = true
            break
        end
    end

    return hasFlaskOrElixir and hasFood
end

function RaidTracker:OnEncounterStart(encounterID, encounterName)
    if not self.currentRaid then return end
    self:TakeSnapshot("encounter_start")
    table.insert(self.currentRaid.encounters, {
        id = encounterID,
        name = encounterName,
        startTime = GetServerTime(),
        endTime = nil,
        success = nil,
    })
end

function RaidTracker:OnEncounterEnd(encounterID, encounterName, success)
    if not self.currentRaid then return end
    self:TakeSnapshot("encounter_end")

    -- Update the last encounter with this ID
    for i = #self.currentRaid.encounters, 1, -1 do
        local enc = self.currentRaid.encounters[i]
        if enc.id == encounterID and not enc.endTime then
            enc.endTime = GetServerTime()
            enc.success = (success == 1)
            break
        end
    end

    local status = (success == 1) and "|cff00ff00KILL|r" or "|cffff3333WIPE|r"
    BRutus:Print(encounterName .. " - " .. status)
end

function RaidTracker:GetAttendance(playerKey)
    local att = BRutus.db.raidTracker.attendance
    if att and att[playerKey] then
        return att[playerKey]
    end
    return { raids = 0, lastRaid = 0 }
end

function RaidTracker:GetTotalSessions()
    -- Count unique guild-raid lockouts (instance + reset week), not raw sessions.
    local seen = {}
    for _, session in pairs(BRutus.db.raidTracker.sessions) do
        if session.isGuildRaid then
            local key = (session.instanceID or 0) .. "_" .. self:GetWeekNum(session.startTime or 0)
            seen[key] = true
        end
    end
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    return count
end

function RaidTracker:GetTotal25ManSessions()
    -- Count unique 25-man guild-raid lockouts (instance + reset week).
    local seen = {}
    for _, session in pairs(BRutus.db.raidTracker.sessions) do
        if session.isGuildRaid and self:Is25Man(session.instanceID) then
            local key = session.instanceID .. "_" .. self:GetWeekNum(session.startTime or 0)
            seen[key] = true
        end
    end
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    return count
end

function RaidTracker:GetAttendancePercent(playerKey)
    local total = self:GetTotalSessions()
    if total == 0 then return 0 end
    local att = self:GetAttendance(playerKey)
    if att.raids == 0 then return 0 end

    -- Use weighted score if available (100 = perfect session)
    if att.totalScore then
        -- Average score across ALL sessions (absent sessions count as 0)
        return math.floor(att.totalScore / (total * 100) * 100 + 0.5)
    end

    -- Fallback for old data without scores
    return math.floor((att.raids / total) * 100 + 0.5)
end

function RaidTracker:GetAttendance25ManPercent(playerKey)
    local total = self:GetTotal25ManSessions()
    if total == 0 then return 0 end
    local att = self:GetAttendance(playerKey)
    local raids25 = att.raids25 or 0
    if raids25 == 0 then return 0 end
    if att.totalScore25 then
        return math.floor(att.totalScore25 / (total * 100) * 100 + 0.5)
    end
    return math.floor((raids25 / total) * 100 + 0.5)
end

function RaidTracker:GetRecentSessions(limit, only25)
    limit = limit or 20
    local sessions = {}
    for id, session in pairs(BRutus.db.raidTracker.sessions) do
        if not only25 or self:Is25Man(session.instanceID) then
            table.insert(sessions, { id = id, data = session })
        end
    end
    table.sort(sessions, function(a, b) return a.id > b.id end)
    local result = {}
    for i = 1, math.min(limit, #sessions) do
        result[i] = sessions[i]
    end
    return result
end

----------------------------------------------------------------------
-- Merge duplicate sessions: same instanceID within a 2-hour window
-- (repairs old DB data from before the grace-period fix was added)
--
-- IMPORTANT: we group by instanceID FIRST, then do adjacent-pair merge
-- within each group. The naive all-sessions-sorted approach fails when
-- sessions from different instances interleave chronologically (e.g.
-- Karazhan run between two Magtheridon wipe sessions).
----------------------------------------------------------------------
function RaidTracker:MergeDuplicateSessions()
    local sessions = BRutus.db.raidTracker.sessions
    if not sessions then return 0 end

    local MERGE_WINDOW = 7200  -- sessions within 2h gap = same raid night
    local totalMerged = 0

    -- Group sessions by instanceID
    local byInstance = {}
    for id, s in pairs(sessions) do
        if s and s.instanceID then
            if not byInstance[s.instanceID] then
                byInstance[s.instanceID] = {}
            end
            table.insert(byInstance[s.instanceID], { id = id, data = s })
        end
    end

    -- For each instance, sort chronologically and merge overlapping/close sessions
    for _, list in pairs(byInstance) do
        table.sort(list, function(a, b) return a.id < b.id end)

        local changed = true
        while changed do
            changed = false
            -- Rebuild list from current sessions (removes deleted entries)
            local fresh = {}
            for _, entry in ipairs(list) do
                if sessions[entry.id] then
                    table.insert(fresh, entry)
                end
            end
            list = fresh

            for i = 1, #list - 1 do
                local a = list[i]
                local b = list[i + 1]
                if a.data and b.data then
                    local aEnd   = a.data.endTime or (a.id + (a.data.duration or 0))
                    local bStart = b.data.startTime or b.id

                    if bStart - aEnd <= MERGE_WINDOW then
                        -- Extend time range to cover both sessions
                        local newEnd = math.max(
                            a.data.endTime or a.id,
                            b.data.endTime or b.id
                        )
                        a.data.endTime  = newEnd
                        a.data.duration = newEnd - (a.data.startTime or a.id)

                        -- Merge player sets
                        for k in pairs(b.data.players or {}) do
                            a.data.players[k] = true
                        end

                        -- Normalise nil fields on old DB records
                        if not a.data.encounters then a.data.encounters = {} end
                        if not a.data.snapshots  then a.data.snapshots  = {} end
                        if not b.data.encounters then b.data.encounters = {} end
                        if not b.data.snapshots  then b.data.snapshots  = {} end

                        -- Merge encounters (deduplicate by id + startTime)
                        local encSeen = {}
                        for _, enc in ipairs(a.data.encounters) do
                            encSeen[enc.id .. "_" .. (enc.startTime or 0)] = true
                        end
                        for _, enc in ipairs(b.data.encounters) do
                            local ekey = enc.id .. "_" .. (enc.startTime or 0)
                            if not encSeen[ekey] then
                                table.insert(a.data.encounters, enc)
                                encSeen[ekey] = true
                            end
                        end
                        table.sort(a.data.encounters, function(x, y)
                            return (x.startTime or 0) < (y.startTime or 0)
                        end)

                        -- Merge snapshots
                        for _, snap in ipairs(b.data.snapshots) do
                            table.insert(a.data.snapshots, snap)
                        end
                        table.sort(a.data.snapshots, function(x, y)
                            return (x.time or 0) < (y.time or 0)
                        end)

                        sessions[b.id] = nil
                        totalMerged = totalMerged + 1
                        changed = true
                        break
                    end
                end
            end
        end
    end

    if totalMerged > 0 then
        BRutus:Print("|cff00FF00BRutus: merged " .. totalMerged
            .. " duplicate raid session(s). Rebuilding attendance…|r")
        self:RebuildAttendanceFromSessions()
    else
        BRutus:Print("|cffAAAAAA[BRutus] No duplicate raid sessions found.|r")
    end
    return totalMerged
end

----------------------------------------------------------------------
-- Rebuild attendance table from scratch using saved sessions.
-- Sessions are grouped by lockout (instanceID + reset week) so that
-- multiple sessions in the same raid week count as ONE attendance event.
----------------------------------------------------------------------
function RaidTracker:RebuildAttendanceFromSessions()
    BRutus.db.raidTracker.attendance = {}

    -- Group guild-raid sessions by lockout key
    local lockouts = {}
    local lockoutOrder = {}
    for _, session in pairs(BRutus.db.raidTracker.sessions) do
        if session.isGuildRaid then
            local weekNum    = self:GetWeekNum(session.startTime or 0)
            local lockoutKey = (session.instanceID or 0) .. "_" .. weekNum
            if not lockouts[lockoutKey] then
                lockouts[lockoutKey] = {
                    instanceID = session.instanceID,
                    sessions   = {},
                }
                table.insert(lockoutOrder, lockoutKey)
            end
            table.insert(lockouts[lockoutKey].sessions, session)
        end
    end

    for _, key in ipairs(lockoutOrder) do
        self:UpdateAttendanceForLockout(lockouts[key])
    end
end

----------------------------------------------------------------------
-- Compute attendance for ONE lockout (one raid per reset week).
-- All sessions in the lockout are merged; each player is counted once.
----------------------------------------------------------------------
function RaidTracker:UpdateAttendanceForLockout(lockout)
    local att        = BRutus.db.raidTracker.attendance
    local instanceID = lockout.instanceID

    -- Merge players and snapshots from every session in this lockout
    local allPlayers   = {}
    local allSnapshots = {}
    local lastRaid     = 0

    for _, session in ipairs(lockout.sessions) do
        for playerKey in pairs(session.players or {}) do
            allPlayers[playerKey] = true
        end
        for _, snap in ipairs(session.snapshots or {}) do
            table.insert(allSnapshots, snap)
        end
        if (session.startTime or 0) > lastRaid then
            lastRaid = session.startTime or 0
        end
    end

    -- Sort merged snapshots chronologically
    table.sort(allSnapshots, function(a, b) return (a.time or 0) < (b.time or 0) end)

    local firstSnap = allSnapshots[1]
    local lastSnap  = allSnapshots[#allSnapshots]

    for playerKey in pairs(allPlayers) do
        if not att[playerKey] then
            att[playerKey] = { raids = 0, lastRaid = 0, totalScore = 0 }
        end
        if not att[playerKey].totalScore then
            att[playerKey].totalScore = att[playerKey].raids * 100
        end

        att[playerKey].raids   = att[playerKey].raids + 1
        att[playerKey].lastRaid = math.max(att[playerKey].lastRaid, lastRaid)

        -- Score: start at 100, apply penalties across merged snapshot span
        local score = 100
        if firstSnap and firstSnap.members and not firstSnap.members[playerKey] then
            score = score - self.PENALTIES.LATE
        end
        if lastSnap and lastSnap.members and not lastSnap.members[playerKey] then
            score = score - self.PENALTIES.LEFT_EARLY
        end
        local consumeChecks, consumeHits = 0, 0
        for _, snap in ipairs(allSnapshots) do
            if snap.members and snap.members[playerKey] then
                consumeChecks = consumeChecks + 1
                if snap.members[playerKey].hasConsumes then
                    consumeHits = consumeHits + 1
                end
            end
        end
        if consumeChecks > 0 and (consumeHits / consumeChecks) < 0.5 then
            score = score - self.PENALTIES.NO_CONSUMES
        end
        score = math.max(0, math.min(100, score))
        att[playerKey].totalScore = att[playerKey].totalScore + score

        if self:Is25Man(instanceID) then
            att[playerKey].raids25      = (att[playerKey].raids25 or 0) + 1
            att[playerKey].totalScore25 = (att[playerKey].totalScore25 or 0) + score
        end
    end
end

function RaidTracker:DeleteSession(sessionID)
    local session = BRutus.db.raidTracker.sessions[sessionID]
    if not session then return end

    -- Decrement attendance for players in this session
    -- Since we don't store per-session scores, estimate 100 per removed session
    for playerKey in pairs(session.players) do
        local att = BRutus.db.raidTracker.attendance[playerKey]
        if att then
            att.raids = math.max(0, att.raids - 1)
            if att.totalScore then
                -- Approximate: remove average score per session for this player
                local avgScore = att.raids > 0 and (att.totalScore / (att.raids + 1)) or 100
                att.totalScore = math.max(0, att.totalScore - avgScore)
            end
            -- Also decrement 25-man counters if applicable
            if self:Is25Man(session.instanceID) then
                att.raids25 = math.max(0, (att.raids25 or 1) - 1)
                if att.totalScore25 then
                    local avg25 = att.raids25 > 0 and (att.totalScore25 / (att.raids25 + 1)) or 100
                    att.totalScore25 = math.max(0, att.totalScore25 - avg25)
                end
            end
        end
    end
    BRutus.db.raidTracker.sessions[sessionID] = nil
end

function RaidTracker:CountTable(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

----------------------------------------------------------------------
-- Sync raid data with other officer clients
----------------------------------------------------------------------
function RaidTracker:BroadcastRaidData()
    if not BRutus:IsOfficer() then return end
    if not BRutus.CommSystem then return end
    if not IsInGuild() then return end

    local raidDB = BRutus.db.raidTracker
    if not raidDB then return end

    -- Build a compact payload: full attendance + session metadata (no snapshots)
    local payload = {
        attendance = raidDB.attendance or {},
        sessions   = {},
    }
    for sessionID, session in pairs(raidDB.sessions or {}) do
        payload.sessions[sessionID] = {
            instanceID = session.instanceID,
            name       = session.name,
            startTime  = session.startTime,
            endTime    = session.endTime,
            players    = session.players,
            encounters = session.encounters,
        }
    end

    local LibSerialize = LibStub("LibSerialize")
    local serialized = LibSerialize:Serialize(payload)
    BRutus.CommSystem:SendMessage(BRutus.CommSystem.MSG_TYPES.RAID_DATA, serialized)
end

function RaidTracker:HandleIncoming(data)
    if not BRutus:IsOfficer() then return end

    local LibSerialize = LibStub("LibSerialize")
    local ok, payload = LibSerialize:Deserialize(data)
    if not ok or type(payload) ~= "table" then return end

    local raidDB = BRutus.db.raidTracker
    if not raidDB.attendance then raidDB.attendance = {} end
    if not raidDB.sessions   then raidDB.sessions   = {} end

    -- Merge attendance: keep higher raid count; on tie prefer most recent lastRaid
    for playerKey, incoming in pairs(payload.attendance or {}) do
        local existing = raidDB.attendance[playerKey]
        if not existing then
            raidDB.attendance[playerKey] = incoming
        else
            local inRaids = incoming.raids or 0
            local exRaids = existing.raids or 0
            if inRaids > exRaids then
                raidDB.attendance[playerKey] = incoming
            elseif inRaids == exRaids then
                local inTime = incoming.lastRaid or 0
                local exTime = existing.lastRaid or 0
                if inTime > exTime then
                    raidDB.attendance[playerKey] = incoming
                end
            end
        end
    end

    -- Merge sessions: add any session we don't already have
    for sessionID, session in pairs(payload.sessions or {}) do
        if not raidDB.sessions[sessionID] then
            raidDB.sessions[sessionID] = session
        end
    end
end

----------------------------------------------------------------------
-- Export attendance data as TMB-compatible JSON
-- TMB expects: { "character_name": { "attendance_percentage": N }, ... }
----------------------------------------------------------------------
function RaidTracker:ExportForTMB()
    local total = self:GetTotal25ManSessions()
    if total == 0 then return nil, "No 25-man raid sessions recorded." end

    local att = BRutus.db.raidTracker.attendance or {}
    local lines = {}
    table.insert(lines, "{")

    local entries = {}
    for playerKey, data in pairs(att) do
        local name = playerKey:match("^([^-]+)")
        local raids25 = data.raids25 or 0
        if name and raids25 > 0 then
            local pct = self:GetAttendance25ManPercent(playerKey)
            table.insert(entries, {
                name = name,
                pct = pct,
                raids = raids25,
            })
        end
    end
    table.sort(entries, function(a, b) return a.name < b.name end)

    for i, e in ipairs(entries) do
        local comma = (i < #entries) and "," or ""
        table.insert(lines, string.format('  "%s": {"attendance_percentage": %d, "raids_attended": %d, "raids_total": %d}%s',
            e.name, e.pct, e.raids, total, comma))
    end

    table.insert(lines, "}")
    return table.concat(lines, "\n"), nil
end
