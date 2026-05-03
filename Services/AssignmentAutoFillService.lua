----------------------------------------------------------------------
-- BRutus Guild Manager - Services/AssignmentAutoFillService
-- Generates assignment drafts from templates + available roster.
--
-- Scoring is additive; higher score = better candidate for a slot.
-- Never mutates BRutus.db or AssignmentService — returns raw result
-- tables for the caller to store or preview as needed.
----------------------------------------------------------------------
local AutoFill = {}
BRutus.AssignmentAutoFillService = AutoFill

-- Scoring weights
local SCORE_ROLE_MATCH       =  100
local SCORE_CLASS_MATCH      =   50
local SCORE_IN_RAID          =   40
local SCORE_ONLINE           =   30
local SCORE_ATTUNED          =   30
local SCORE_OFFICER_RANK     =   20
local SCORE_HAS_ADDON        =   10
local PENALTY_OFFLINE        = -100
local PENALTY_NOT_ATTUNED    = -100
local PENALTY_TRIAL_CRITICAL =  -50
local PENALTY_SLOT_CONFLICT  =  -30

----------------------------------------------------------------------
-- Role inference table: class (upper) → { [specTreeName] = role }
-- role = "tank" | "healer" | "ranged" | "melee"
----------------------------------------------------------------------
local CLASS_SPEC_ROLE = {
    WARRIOR = { Arms = "melee",    Fury = "melee",          Protection = "tank"   },
    PALADIN = { Holy = "healer",   Protection = "tank",     Retribution = "melee" },
    HUNTER  = { ["Beast Mastery"] = "ranged", Marksmanship = "ranged", Survival = "ranged" },
    ROGUE   = { Assassination = "melee", Combat = "melee",  Subtlety = "melee"    },
    PRIEST  = { Discipline = "healer", Holy = "healer",     Shadow = "ranged"     },
    SHAMAN  = { Elemental = "ranged", Enhancement = "melee", Restoration = "healer" },
    MAGE    = { Arcane = "ranged", Fire = "ranged",         Frost = "ranged"      },
    WARLOCK = { Affliction = "ranged", Demonology = "ranged", Destruction = "ranged" },
    DRUID   = { Balance = "ranged", ["Feral Combat"] = "melee", Restoration = "healer" },
}

-- Fallback role when no spec data is available (class-level guess)
local CLASS_DEFAULT_ROLE = {
    WARRIOR = "melee",  PALADIN = "healer", HUNTER  = "ranged",
    ROGUE   = "melee",  PRIEST  = "healer", SHAMAN  = "healer",
    MAGE    = "ranged", WARLOCK = "ranged", DRUID   = "healer",
}

----------------------------------------------------------------------
-- Infer a player's functional role from spec.tree + class.
----------------------------------------------------------------------
local function InferRole(member)
    local class = (member.class or ""):upper()
    if member.spec and member.spec.tree then
        local treeMap = CLASS_SPEC_ROLE[class]
        if treeMap then
            local r = treeMap[member.spec.tree]
            if r then return r end
        end
    end
    return CLASS_DEFAULT_ROLE[class]
end

-- Check if a member is attuned to a raid by attunementShort.
local function IsAttuned(member, raidAttunementShort)
    if not raidAttunementShort then return true end
    for _, att in ipairs(member.attunements or {}) do
        if att.short == raidAttunementShort and att.complete then
            return true
        end
    end
    return false
end

-- Check if a member is an active trial.
local function IsTrial(member)
    if not BRutus.db or not BRutus.db.trials then return false end
    local t = BRutus.db.trials[member.playerKey]
    return t ~= nil and t.status == "active"
end

----------------------------------------------------------------------
-- Build a roster from the live raid (if in raid) or from db.members
-- (test mode when not in raid).
-- Returns array of entries: { name, playerKey, class, spec,
--   inferredRole, isOnline, isInRaid, attunements, rank, hasAddon }
----------------------------------------------------------------------
function AutoFill:BuildRoster()
    local roster = {}
    if IsInRaid and IsInRaid() then
        local realm = GetRealmName() or ""
        for i = 1, GetNumGroupMembers() do
            local name, rank, _, _, _, fileName, _, online = GetRaidRosterInfo(i)
            if name then
                local playerKey = name:find("-") and name or (name .. "-" .. realm)
                local mData = (BRutus.db and BRutus.db.members and
                               BRutus.db.members[playerKey]) or {}
                local entry = {
                    name         = name,
                    playerKey    = playerKey,
                    class        = (mData.class or fileName or ""):upper(),
                    spec         = mData.spec,
                    isOnline     = online == 1 or online == true,
                    isInRaid     = true,
                    attunements  = mData.attunements or {},
                    rank         = rank or 0,
                    hasAddon     = mData.addonVersion ~= nil,
                }
                entry.inferredRole = InferRole(entry)
                tinsert(roster, entry)
            end
        end
    else
        -- Pre-raid planning mode: build from stored guild members.
        -- isOnline reflects the last-seen status stored by DataCollector.
        if BRutus.db and BRutus.db.members then
            for playerKey, member in pairs(BRutus.db.members) do
                local entry = {
                    name         = member.name or playerKey,
                    playerKey    = playerKey,
                    class        = (member.class or ""):upper(),
                    spec         = member.spec,
                    isOnline     = member.online == true,
                    isInRaid     = false,
                    attunements  = member.attunements or {},
                    rank         = member.rankIndex or 0,
                    hasAddon     = member.addonVersion ~= nil,
                }
                entry.inferredRole = InferRole(entry)
                tinsert(roster, entry)
            end
        end
    end
    return roster
end

----------------------------------------------------------------------
-- Score a roster member against a slot definition.
-- Higher total = better candidate.
----------------------------------------------------------------------
function AutoFill:ScorePlayer(member, slotDef, raidAttunementShort, usedCritical)
    local score = 0

    -- Role match
    if slotDef.role and slotDef.role ~= "any" then
        local ir = member.inferredRole
        local sr = slotDef.role
        if ir == sr then
            score = score + SCORE_ROLE_MATCH
        elseif sr == "dps" and (ir == "ranged" or ir == "melee") then
            score = score + SCORE_ROLE_MATCH
        end
    end

    -- Class-specific requirements
    local req = slotDef.requirements
    if req then
        local cls = member.class
        if req.warlockTank then
            if cls == "WARLOCK" then
                score = score + SCORE_CLASS_MATCH
            else
                score = score - SCORE_CLASS_MATCH
            end
        end
        if req.preferPaladin and cls == "PALADIN" then
            score = score + SCORE_CLASS_MATCH / 2
        end
        if req.priest then
            if cls == "PRIEST" then
                score = score + SCORE_CLASS_MATCH
            else
                score = score - SCORE_CLASS_MATCH
            end
        end
    end

    -- Live presence
    if member.isInRaid  then score = score + SCORE_IN_RAID end
    if member.isOnline  then
        score = score + SCORE_ONLINE
    else
        score = score + PENALTY_OFFLINE
    end

    -- Attunement
    if IsAttuned(member, raidAttunementShort) then
        score = score + SCORE_ATTUNED
    else
        score = score + PENALTY_NOT_ATTUNED
    end

    -- Raid rank (assist/leader = known raider)
    if member.rank and member.rank >= 1 then
        score = score + SCORE_OFFICER_RANK
    end

    -- Has addon (data quality signal)
    if member.hasAddon then score = score + SCORE_HAS_ADDON end

    -- Trial in a critical slot
    if slotDef.critical and IsTrial(member) then
        score = score + PENALTY_TRIAL_CRITICAL
    end

    -- Already used in a conflicting critical slot
    if usedCritical and usedCritical[member.name] then
        score = score + PENALTY_SLOT_CONFLICT
    end

    return score
end

----------------------------------------------------------------------
-- Generate assignments for a single boss.
-- Returns result table on success, or nil + errorMsg on failure.
----------------------------------------------------------------------
function AutoFill:GenerateForBoss(raidId, bossId)
    if not BRutus.AssignmentTemplateService then
        return nil, "AssignmentTemplateService not available"
    end

    local boss = BRutus.AssignmentTemplateService:GetBoss(raidId, bossId)
    if not boss then
        return nil, "Boss template not found: " .. (raidId or "?") .. "/" .. (bossId or "?")
    end

    local raid               = BRutus.AssignmentTemplateService:GetRaid(raidId)
    local raidAttunementShort = raid and raid.attunementShort
    local roster             = self:BuildRoster()

    local result = {
        raidId      = raidId,
        bossId      = bossId,
        bossName    = boss.name,
        generatedAt = GetTime(),
        generatedBy = UnitName("player") or "Unknown",
        source      = "generated",
        slots       = {},
        missing     = {},
        warnings    = {},
    }

    local criticalAllFilled = true
    local hasWarnings       = false
    local usedCritical      = {}  -- { [playerName] = slotId }

    for _, slotDef in ipairs(boss.slots or {}) do
        local need         = slotDef.count or 1
        local assigned     = {}
        local slotWarnings = {}

        -- Score every roster member for this slot
        local candidates = {}
        for _, member in ipairs(roster) do
            local s = self:ScorePlayer(member, slotDef, raidAttunementShort, usedCritical)
            tinsert(candidates, { member = member, score = s })
        end
        table.sort(candidates, function(a, b) return a.score > b.score end)

        -- Pick the top `need` candidates; score is used for ranking only.
        -- MISSING is only added when the roster has fewer players than needed.
        local picked = 0
        for _, cand in ipairs(candidates) do
            if picked >= need then break end
            tinsert(assigned, cand.member.name)
            if slotDef.critical then
                usedCritical[cand.member.name] = slotDef.id
            end
            picked = picked + 1
        end

        -- Fill remaining unfilled slots with MISSING
        for _ = picked + 1, need do
            tinsert(assigned, "MISSING")
            if slotDef.critical then
                criticalAllFilled = false
                tinsert(result.missing, { slotId = slotDef.id, label = slotDef.label })
            end
            hasWarnings = true
        end

        -- Slot-level warnings for class requirements
        local req = slotDef.requirements
        if req and req.warlockTank and assigned[1] and assigned[1] ~= "MISSING" then
            local assignedName = assigned[1]
            local foundWarlock = false
            for _, m in ipairs(roster) do
                if m.name == assignedName and m.class == "WARLOCK" then
                    foundWarlock = true
                    break
                end
            end
            if not foundWarlock then
                tinsert(slotWarnings, "Assigned player may not be a Warlock")
                hasWarnings = true
            end
        end

        -- Per-slot confidence
        local slotConf = "HIGH"
        for _, a in ipairs(assigned) do
            if a == "MISSING" then
                slotConf = slotDef.critical and "LOW" or "MEDIUM"
                break
            end
        end

        tinsert(result.slots, {
            slotId     = slotDef.id,
            label      = slotDef.label,
            priority   = slotDef.priority,
            phase      = slotDef.phase,
            assigned   = assigned,
            confidence = slotConf,
            warnings   = slotWarnings,
            notes      = slotDef.notes,
        })
    end

    -- Overall confidence
    if criticalAllFilled and not hasWarnings then
        result.confidence = "HIGH"
    elseif criticalAllFilled then
        result.confidence = "MEDIUM"
    else
        result.confidence = "LOW"
    end

    return result
end

----------------------------------------------------------------------
-- Generate assignments for every boss in a raid.
-- Returns an array of boss result tables (may be empty on error).
----------------------------------------------------------------------
function AutoFill:GenerateForRaid(raidId)
    if not BRutus.AssignmentTemplateService then return {} end
    local raid = BRutus.AssignmentTemplateService:GetRaid(raidId)
    if not raid then return {} end

    local results = {}
    for _, bossId in ipairs(raid.bossOrder or {}) do
        local res = self:GenerateForBoss(raidId, bossId)
        if res then
            tinsert(results, res)
        end
    end
    return results
end
