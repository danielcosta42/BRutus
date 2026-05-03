----------------------------------------------------------------------
-- BRutus Guild Manager - Services/PrePullService
-- Validates raid state before a pull: dead, offline, consumables.
-- Reports issues to chat and pushes alerts via AlertService.
----------------------------------------------------------------------
local PrePullService = {}
BRutus.PrePullService = PrePullService

local ALERT_TTL = 60  -- seconds; pre-pull alerts survive 1 minute

-- Run a full pre-pull validation check.
-- Prints a summary to the player's chat and pushes HIGH/MEDIUM alerts.
-- Returns { issues, summary } or nil if not in a raid.
function PrePullService:RunCheck()
    if not IsInRaid() then
        BRutus:Print("|cffFFD700[Pre-Pull]|r Not in a raid.")
        return nil
    end

    local issues          = {}
    local deadCount       = 0
    local offlineCount    = 0
    local noConsumesCount = 0

    local total = GetNumGroupMembers()
    for i = 1, total do
        local name, _, _, _, _, _, _, online, isDead = GetRaidRosterInfo(i)
        if name then
            if not online then
                offlineCount = offlineCount + 1
                tinsert(issues, { type = "offline", player = name })
                if BRutus.AlertService then
                    BRutus.AlertService:PushMedium(name .. " offline", "prepull", ALERT_TTL)
                end
            elseif isDead then
                deadCount = deadCount + 1
                tinsert(issues, { type = "dead", player = name })
                if BRutus.AlertService then
                    BRutus.AlertService:PushHigh(name .. " dead", "prepull", ALERT_TTL)
                end
            end
        end
    end

    -- Consumable check uses the last stored results from ConsumableChecker.
    if BRutus.ConsumableChecker then
        local lastResults = BRutus.ConsumableChecker:GetLastResults()
        if lastResults then
            for _, entry in ipairs(lastResults) do
                if entry.missing and #entry.missing > 0 then
                    noConsumesCount = noConsumesCount + 1
                    tinsert(issues, { type = "consumable", player = entry.name })
                end
            end
        end
    end

    local totalIssues = #issues

    if totalIssues == 0 then
        BRutus:Print("|cff00FF00[Pre-Pull]|r Raid ready. No issues found.")
    else
        BRutus:Print(format("|cffFFD700[Pre-Pull]|r %d problem(s) found:", totalIssues))
        if deadCount > 0 then
            BRutus:Print(format("  |cffFF4444- %d player(s) dead|r", deadCount))
        end
        if offlineCount > 0 then
            BRutus:Print(format("  |cffFF8800- %d player(s) offline|r", offlineCount))
        end
        if noConsumesCount > 0 then
            BRutus:Print(format("  |cffFFAA00- %d player(s) missing consumables|r", noConsumesCount))
        end
    end

    return {
        issues  = issues,
        summary = {
            totalIssues  = totalIssues,
            deadCount    = deadCount,
            offlineCount = offlineCount,
            noConsumes   = noConsumesCount,
        },
    }
end
