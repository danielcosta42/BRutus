----------------------------------------------------------------------
-- BRutus Guild Manager - Trial Member Tracker
-- Tracks trial/recruit members: start date, evaluation notes, status
-- Progress snapshots for iLvl and attunement tracking
----------------------------------------------------------------------
local TrialTracker = {}
BRutus.TrialTracker = TrialTracker

-- Trial status values
TrialTracker.STATUS = {
    TRIAL    = "trial",
    APPROVED = "approved",
    DENIED   = "denied",
    EXPIRED  = "expired",
}

-- Default trial duration (30 days in seconds)
TrialTracker.DEFAULT_DURATION = 30 * 24 * 60 * 60

function TrialTracker:Initialize()
    if not BRutus.db.trials then
        BRutus.db.trials = {}  -- [playerKey] = { startDate, endDate, status, notes, sponsor, snapshots }
    end
    -- Migrate old trials missing snapshots
    for _, trial in pairs(BRutus.db.trials) do
        if not trial.snapshots then trial.snapshots = {} end
    end
end

function TrialTracker:AddTrial(playerKey, sponsor)
    if not BRutus:IsOfficer() then return false end

    local now = GetServerTime()
    BRutus.db.trials[playerKey] = {
        startDate = now,
        endDate = now + self.DEFAULT_DURATION,
        status = self.STATUS.TRIAL,
        notes = {},
        sponsor = sponsor or UnitName("player"),
        snapshots = {},
    }

    -- Take initial snapshot
    self:TakeSnapshot(playerKey)

    BRutus:Print(playerKey .. " marcado como trial por " .. (sponsor or UnitName("player")))
    return true
end

function TrialTracker:UpdateStatus(playerKey, newStatus)
    if not BRutus:IsOfficer() then return end
    local trial = BRutus.db.trials[playerKey]
    if not trial then return end

    trial.status = newStatus
    if newStatus == self.STATUS.APPROVED or newStatus == self.STATUS.DENIED then
        trial.resolvedDate = GetServerTime()
        trial.resolvedBy = UnitName("player")
    end
end

function TrialTracker:AddTrialNote(playerKey, text)
    if not BRutus:IsOfficer() then return end
    local trial = BRutus.db.trials[playerKey]
    if not trial then return end

    table.insert(trial.notes, {
        text = text,
        author = UnitName("player"),
        timestamp = GetServerTime(),
    })
end

function TrialTracker:GetTrial(playerKey)
    return BRutus.db.trials[playerKey]
end

function TrialTracker:GetAllTrials()
    local result = {}
    for key, trial in pairs(BRutus.db.trials) do
        table.insert(result, { key = key, data = trial })
    end
    table.sort(result, function(a, b) return a.data.startDate > b.data.startDate end)
    return result
end

function TrialTracker:GetActiveTrials()
    local result = {}
    for key, trial in pairs(BRutus.db.trials) do
        if trial.status == self.STATUS.TRIAL then
            table.insert(result, { key = key, data = trial })
        end
    end
    table.sort(result, function(a, b) return a.data.startDate > b.data.startDate end)
    return result
end

function TrialTracker:IsTrial(playerKey)
    local trial = BRutus.db.trials[playerKey]
    return trial and trial.status == self.STATUS.TRIAL
end

function TrialTracker:GetDaysRemaining(playerKey)
    local trial = BRutus.db.trials[playerKey]
    if not trial or trial.status ~= self.STATUS.TRIAL then return nil end
    local remaining = trial.endDate - GetServerTime()
    return math.max(0, math.floor(remaining / 86400))
end

function TrialTracker:GetDaysSinceStart(playerKey)
    local trial = BRutus.db.trials[playerKey]
    if not trial then return nil end
    return math.floor((GetServerTime() - trial.startDate) / 86400)
end

function TrialTracker:CheckExpired()
    local now = GetServerTime()
    local expired = {}
    for key, trial in pairs(BRutus.db.trials) do
        if trial.status == self.STATUS.TRIAL and now > trial.endDate then
            trial.status = self.STATUS.EXPIRED
            table.insert(expired, key)
        end
    end
    if #expired > 0 and BRutus:IsOfficer() then
        BRutus:Print("|cffFF6600" .. #expired .. " trial(s) expiraram!|r Use /brutus para revisar.")
    end
end

function TrialTracker:RemoveTrial(playerKey)
    BRutus.db.trials[playerKey] = nil
end

----------------------------------------------------------------------
-- Progress Snapshots
-- Records iLvl and attunement completion at a point in time
----------------------------------------------------------------------
function TrialTracker:TakeSnapshot(playerKey)
    local trial = BRutus.db.trials[playerKey]
    if not trial then return end
    if not trial.snapshots then trial.snapshots = {} end

    local memberData = BRutus.db.members[playerKey]
    if not memberData then return end

    local attDone, attTotal = 0, 0
    if memberData.attunements then
        for _, att in ipairs(memberData.attunements) do
            attTotal = attTotal + 1
            if att.complete then
                attDone = attDone + 1
            end
        end
    end

    local profData = {}
    if memberData.professions then
        for _, prof in ipairs(memberData.professions) do
            table.insert(profData, { name = prof.name, rank = prof.rank, maxRank = prof.maxRank })
        end
    end

    table.insert(trial.snapshots, {
        timestamp   = GetServerTime(),
        avgIlvl     = memberData.avgIlvl or 0,
        attDone     = attDone,
        attTotal    = attTotal,
        professions = profData,
        level       = memberData.level or 0,
    })
end

function TrialTracker:GetProgress(playerKey)
    local trial = BRutus.db.trials[playerKey]
    if not trial or not trial.snapshots or #trial.snapshots == 0 then
        return nil
    end

    local first = trial.snapshots[1]
    local last = trial.snapshots[#trial.snapshots]
    local memberData = BRutus.db.members[playerKey]

    -- Current live values
    local curIlvl = memberData and memberData.avgIlvl or last.avgIlvl
    local curAttDone, curAttTotal = 0, 0
    if memberData and memberData.attunements then
        for _, att in ipairs(memberData.attunements) do
            curAttTotal = curAttTotal + 1
            if att.complete then curAttDone = curAttDone + 1 end
        end
    else
        curAttDone = last.attDone
        curAttTotal = last.attTotal
    end

    return {
        startIlvl    = first.avgIlvl,
        currentIlvl  = curIlvl,
        ilvlDelta    = curIlvl - first.avgIlvl,
        startAttDone = first.attDone,
        currentAttDone = curAttDone,
        attTotal     = curAttTotal,
        attDelta     = curAttDone - first.attDone,
        startLevel   = first.level,
        currentLevel = memberData and memberData.level or last.level,
        snapCount    = #trial.snapshots,
    }
end

-- Auto-snapshot active trials (call periodically, e.g. on data sync)
function TrialTracker:UpdateSnapshots()
    if not BRutus:IsOfficer() then return end
    local now = GetServerTime()
    for key, trial in pairs(BRutus.db.trials) do
        if trial.status == self.STATUS.TRIAL then
            if not trial.snapshots then trial.snapshots = {} end
            local lastSnap = trial.snapshots[#trial.snapshots]
            -- Take at most one snapshot per day (86400s)
            if not lastSnap or (now - lastSnap.timestamp) > 86400 then
                self:TakeSnapshot(key)
            end
        end
    end
end
