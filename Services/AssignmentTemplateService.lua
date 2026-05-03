----------------------------------------------------------------------
-- BRutus Guild Manager - Services/AssignmentTemplateService
-- Thin accessor layer for BRutus.RaidAssignmentTemplates.
-- Provides GetRaid, GetBoss, ListBosses, ListRaids.
----------------------------------------------------------------------
local TemplateService = {}
BRutus.AssignmentTemplateService = TemplateService

-- Return the full raid template table for raidId ("SSC" or "TK"), or nil.
function TemplateService:GetRaid(raidId)
    if not BRutus.RaidAssignmentTemplates then return nil end
    return BRutus.RaidAssignmentTemplates[raidId]
end

-- Return the boss template for a specific raidId + bossId, or nil.
function TemplateService:GetBoss(raidId, bossId)
    local raid = self:GetRaid(raidId)
    if not raid or not raid.bosses then return nil end
    return raid.bosses[bossId]
end

-- Return an ordered array of { id, name } for all bosses in raidId.
function TemplateService:ListBosses(raidId)
    local raid = self:GetRaid(raidId)
    if not raid then return {} end
    local result = {}
    for _, bossId in ipairs(raid.bossOrder or {}) do
        local boss = raid.bosses[bossId]
        if boss then
            tinsert(result, { id = bossId, name = boss.name })
        end
    end
    return result
end

-- Return an array of { id, name, short } for all available raids.
function TemplateService:ListRaids()
    if not BRutus.RaidAssignmentTemplates then return {} end
    local result = {}
    for raidId, raid in pairs(BRutus.RaidAssignmentTemplates) do
        tinsert(result, { id = raidId, name = raid.name, short = raid.short })
    end
    return result
end
