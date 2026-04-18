----------------------------------------------------------------------
-- BRutus Guild Manager - Trial Member Tracker
-- Tracks trial/recruit members: start date, evaluation notes, status
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
        BRutus.db.trials = {}  -- [playerKey] = { startDate, endDate, status, notes, sponsor }
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
    }

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
