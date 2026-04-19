----------------------------------------------------------------------
-- BRutus Guild Manager - Recipe Tracker
-- Scans and shares tradeskill recipes across the guild
----------------------------------------------------------------------
local RecipeTracker = {}
BRutus.RecipeTracker = RecipeTracker

----------------------------------------------------------------------
-- Initialize
----------------------------------------------------------------------
function RecipeTracker:Initialize()
    self.scanPending = false
    self.lastScanTime = {}

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:RegisterEvent("TRADE_SKILL_CLOSE")
    -- Craft API events (Enchanting in some clients)
    frame:RegisterEvent("CRAFT_SHOW")
    frame:RegisterEvent("CRAFT_CLOSE")
    frame:SetScript("OnEvent", function(_, event)
        if event == "TRADE_SKILL_SHOW" then
            RecipeTracker:DebounceScan("trade")
        elseif event == "CRAFT_SHOW" then
            RecipeTracker:DebounceScan("craft")
        end
    end)

    -- Ensure DB table exists
    if not BRutusDB.recipes then
        BRutusDB.recipes = {}
    end
end

local SCAN_COOLDOWN = 5 -- seconds between scans of the same type

function RecipeTracker:DebounceScan(scanType)
    local now = GetTime()
    if self.lastScanTime[scanType] and (now - self.lastScanTime[scanType]) < SCAN_COOLDOWN then
        return
    end
    self.lastScanTime[scanType] = now

    C_Timer.After(0.3, function()
        if scanType == "trade" then
            RecipeTracker:ScanTradeSkill()
        elseif scanType == "craft" then
            RecipeTracker:ScanCraft()
        end
    end)
end

----------------------------------------------------------------------
-- Scan the currently open TradeSkill window
----------------------------------------------------------------------
function RecipeTracker:ScanTradeSkill()
    if not GetTradeSkillLine then return end

    local skillName = GetTradeSkillLine()
    if not skillName or skillName == "" or skillName == "UNKNOWN" then return end

    local numSkills = GetNumTradeSkills and GetNumTradeSkills() or 0
    if numSkills == 0 then return end

    local recipes = {}
    for i = 1, numSkills do
        local name, skillType = GetTradeSkillInfo(i)
        -- skillType: "header"/"subheader" = category, otherwise it's a recipe
        if name and skillType ~= "header" and skillType ~= "subheader" then
            local itemLink = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
            local recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
            local itemId
            if itemLink then
                itemId = tonumber(itemLink:match("item:(%d+)"))
            end
            local spellId
            if recipeLink then
                spellId = tonumber(recipeLink:match("enchant:(%d+)") or recipeLink:match("spell:(%d+)"))
            end
            table.insert(recipes, {
                name = name,
                itemId = itemId,
                spellId = spellId,
            })
        end
    end

    self:StoreMyRecipes(skillName, recipes)
end

----------------------------------------------------------------------
-- Scan Craft window (Enchanting in some TBC clients)
----------------------------------------------------------------------
function RecipeTracker:ScanCraft()
    if not GetCraftDisplaySkillLine then return end

    local skillName = GetCraftDisplaySkillLine()
    if not skillName or skillName == "" or skillName == "UNKNOWN" then return end

    local numCrafts = GetNumCrafts and GetNumCrafts() or 0
    if numCrafts == 0 then return end

    local recipes = {}
    for i = 1, numCrafts do
        local name, _, craftType = GetCraftInfo(i)
        if name and craftType ~= "header" and craftType ~= "subheader" then
            local itemLink = GetCraftItemLink and GetCraftItemLink(i)
            local spellLink = GetCraftSpellLink and GetCraftSpellLink(i)
            local itemId
            if itemLink then
                itemId = tonumber(itemLink:match("item:(%d+)"))
            end
            local spellId
            if spellLink then
                spellId = tonumber(spellLink:match("enchant:(%d+)") or spellLink:match("spell:(%d+)"))
            end
            table.insert(recipes, {
                name = name,
                itemId = itemId,
                spellId = spellId,
            })
        end
    end

    self:StoreMyRecipes(skillName, recipes)
end

----------------------------------------------------------------------
-- Store scanned recipes for local player
----------------------------------------------------------------------
function RecipeTracker:StoreMyRecipes(profName, recipes)
    local name = UnitName("player")
    local realm = GetRealmName()
    local key = BRutus:GetPlayerKey(name, realm)

    if not BRutusDB.recipes[key] then
        BRutusDB.recipes[key] = {}
    end
    BRutusDB.recipes[key][profName] = recipes

    -- Track scan timestamps per profession
    if not BRutusDB.recipeScanTimes then
        BRutusDB.recipeScanTimes = {}
    end
    BRutusDB.recipeScanTimes[profName] = time()

    BRutus:Print(string.format("|cff00ff00Recipes scanned:|r %d %s recipes indexed.", #recipes, profName))

    -- Dismiss the profession reminder if all professions are now scanned
    if BRutus.profReminderFrame then
        BRutus:CheckAndDismissProfessionReminder()
    end

    -- Broadcast to guild
    self:BroadcastRecipes(profName, recipes)
end

----------------------------------------------------------------------
-- Broadcast recipes via CommSystem
----------------------------------------------------------------------
function RecipeTracker:BroadcastRecipes(profName, recipes)
    if not BRutus.CommSystem then return end
    if not IsInGuild() then return end

    local LibSerialize = LibStub("LibSerialize")
    local data = {
        prof = profName,
        recipes = recipes,
    }
    local serialized = LibSerialize:Serialize(data)
    BRutus.CommSystem:SendMessage("RC", serialized)
end

----------------------------------------------------------------------
-- Handle incoming recipe data from another guild member
----------------------------------------------------------------------
function RecipeTracker:HandleIncoming(sender, data)
    local LibSerialize = LibStub("LibSerialize")
    local ok, recipeData = LibSerialize:Deserialize(data)
    if not ok or type(recipeData) ~= "table" then return end

    local profName = recipeData.prof
    local recipes = recipeData.recipes
    if not profName or not recipes then return end

    -- Build player key from sender
    local senderName = sender:match("^([^-]+)") or sender
    local realm = sender:match("-(.+)$") or GetRealmName()
    local key = BRutus:GetPlayerKey(senderName, realm)

    if not BRutusDB.recipes[key] then
        BRutusDB.recipes[key] = {}
    end
    BRutusDB.recipes[key][profName] = recipes
end

----------------------------------------------------------------------
-- Get all known professions across the guild
----------------------------------------------------------------------
function RecipeTracker:GetAllProfessions()
    local profs = {}
    local seen = {}
    for _, playerRecipes in pairs(BRutusDB.recipes or {}) do
        for profName, _ in pairs(playerRecipes) do
            if not seen[profName] then
                seen[profName] = true
                table.insert(profs, profName)
            end
        end
    end
    table.sort(profs)
    return profs
end

----------------------------------------------------------------------
-- Build a flat searchable list of all recipes
-- Returns: { { recipeName, itemId, spellId, playerKey, playerName, profName }, ... }
----------------------------------------------------------------------
function RecipeTracker:BuildRecipeIndex()
    local grouped = {}
    for playerKey, professions in pairs(BRutusDB.recipes or {}) do
        local playerName = playerKey:match("^([^-]+)") or playerKey
        for profName, recipes in pairs(professions) do
            for _, recipe in ipairs(recipes) do
                local key = (recipe.name or "") .. "|" .. profName
                if not grouped[key] then
                    grouped[key] = {
                        name = recipe.name,
                        itemId = recipe.itemId,
                        spellId = recipe.spellId,
                        profName = profName,
                        crafters = {},
                    }
                end
                table.insert(grouped[key].crafters, {
                    playerKey = playerKey,
                    playerName = playerName,
                })
            end
        end
    end

    local index = {}
    for _, entry in pairs(grouped) do
        table.insert(index, entry)
    end
    return index
end

----------------------------------------------------------------------
-- Search recipes by query, optional profession filter
-- Returns results sorted: online first, then by recipe name
----------------------------------------------------------------------
function RecipeTracker:Search(query, profFilter)
    local index = self:BuildRecipeIndex()
    local results = {}
    local lowerQuery = query and strlower(strtrim(query)) or ""

    -- Build online set from guild roster
    local onlineSet = self:GetOnlineSet()

    for _, entry in ipairs(index) do
        local passProf = (not profFilter or profFilter == "All" or entry.profName == profFilter)
        local passQuery = true
        if lowerQuery ~= "" then
            passQuery = strlower(entry.name):find(lowerQuery, 1, true) ~= nil
        end

        if passProf and passQuery then
            -- Mark which crafters are online
            local hasOnline = false
            for _, crafter in ipairs(entry.crafters) do
                crafter.isOnline = onlineSet[crafter.playerName] or false
                if crafter.isOnline then hasOnline = true end
            end
            -- Sort crafters: online first, then alphabetical
            table.sort(entry.crafters, function(a, b)
                if a.isOnline ~= b.isOnline then return a.isOnline end
                return a.playerName < b.playerName
            end)
            entry.hasOnline = hasOnline
            table.insert(results, entry)
        end
    end

    -- Sort: recipes with online crafters first, then by name
    table.sort(results, function(a, b)
        if a.hasOnline ~= b.hasOnline then return a.hasOnline end
        return a.name < b.name
    end)

    return results
end

----------------------------------------------------------------------
-- Build a set of online guild member names
----------------------------------------------------------------------
function RecipeTracker:GetOnlineSet()
    local set = {}
    local numMembers = GetNumGuildMembers() or 0
    for i = 1, numMembers do
        local fullName, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(i)
        if fullName and isOnline then
            local shortName = fullName:match("^([^-]+)") or fullName
            set[shortName] = true
        end
    end
    return set
end
