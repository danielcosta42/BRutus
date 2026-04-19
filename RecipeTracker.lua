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

    -- Hook tooltips to show crafters
    self:HookTooltips()
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

    local rawSkillName = GetTradeSkillLine()
    if not rawSkillName or rawSkillName == "" or rawSkillName == "UNKNOWN" then return end

    local skillName = BRutus.DataCollector:GetCanonicalProfName(rawSkillName)

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
            -- Fallback: extract enchant ID from item link if it's an enchant link
            if not spellId and itemLink then
                spellId = tonumber(itemLink:match("enchant:(%d+)"))
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

    local rawSkillName = GetCraftDisplaySkillLine()
    if not rawSkillName or rawSkillName == "" or rawSkillName == "UNKNOWN" then return end

    local skillName = BRutus.DataCollector:GetCanonicalProfName(rawSkillName)

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
            -- Try spell link first
            if spellLink then
                spellId = tonumber(spellLink:match("enchant:(%d+)") or spellLink:match("spell:(%d+)"))
            end
            -- Enchanting: GetCraftItemLink returns enchant:XXXXX, extract as spellId
            if not spellId and itemLink then
                spellId = tonumber(itemLink:match("enchant:(%d+)"))
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

    -- Remove old localized keys that map to the same canonical profession
    local DC = BRutus.DataCollector
    if DC and DC.GetCanonicalProfName then
        for oldKey, _ in pairs(BRutusDB.recipes[key]) do
            if oldKey ~= profName and DC:GetCanonicalProfName(oldKey) == profName then
                BRutusDB.recipes[key][oldKey] = nil
            end
        end
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

    -- Normalize profession name to canonical English
    local DC = BRutus.DataCollector
    if DC and DC.GetCanonicalProfName then
        profName = DC:GetCanonicalProfName(profName)
    end

    -- Build player key from sender
    local senderName = sender:match("^([^-]+)") or sender
    local realm = sender:match("-(.+)$") or GetRealmName()
    local key = BRutus:GetPlayerKey(senderName, realm)

    if not BRutusDB.recipes[key] then
        BRutusDB.recipes[key] = {}
    end

    -- Remove old localized keys that map to the same canonical profession
    for oldKey, _ in pairs(BRutusDB.recipes[key]) do
        if oldKey ~= profName and DC and DC:GetCanonicalProfName(oldKey) == profName then
            BRutusDB.recipes[key][oldKey] = nil
        end
    end

    BRutusDB.recipes[key][profName] = recipes
end

----------------------------------------------------------------------
-- Get all known professions across the guild
----------------------------------------------------------------------
function RecipeTracker:GetAllProfessions()
    local profs = {}
    local seen = {}
    local DC = BRutus.DataCollector
    for _, playerRecipes in pairs(BRutusDB.recipes or {}) do
        for profName, _ in pairs(playerRecipes) do
            local canonical = DC and DC.GetCanonicalProfName and DC:GetCanonicalProfName(profName) or profName
            if not seen[canonical] then
                seen[canonical] = true
                table.insert(profs, canonical)
            end
        end
    end
    table.sort(profs)
    return profs
end

----------------------------------------------------------------------
-- Build a flat searchable list of all recipes (grouped by ID)
-- Groups by spellId or itemId to be locale-independent.
-- Resolves display name via GetSpellInfo/GetItemInfo for the local client.
----------------------------------------------------------------------
function RecipeTracker:BuildRecipeIndex()
    local grouped = {}
    local DC = BRutus.DataCollector
    for playerKey, professions in pairs(BRutusDB.recipes or {}) do
        local playerName = playerKey:match("^([^-]+)") or playerKey
        for profName, recipes in pairs(professions) do
            local canonical = DC and DC.GetCanonicalProfName and DC:GetCanonicalProfName(profName) or profName
            for _, recipe in ipairs(recipes) do
                -- Use spellId as primary key, fall back to itemId, then name
                local recipeKey
                if recipe.spellId then
                    recipeKey = "s" .. recipe.spellId .. "|" .. canonical
                elseif recipe.itemId then
                    recipeKey = "i" .. recipe.itemId .. "|" .. canonical
                else
                    recipeKey = "n" .. (recipe.name or "") .. "|" .. canonical
                end

                if not grouped[recipeKey] then
                    -- Resolve localized display name for local client
                    local displayName = recipe.name -- fallback
                    if recipe.spellId then
                        local spellName = GetSpellInfo(recipe.spellId)
                        if spellName and spellName ~= "" then
                            displayName = spellName
                        end
                    end
                    if recipe.itemId and (not displayName or displayName == recipe.name) then
                        local itemName = GetItemInfo(recipe.itemId)
                        if itemName and itemName ~= "" then
                            displayName = itemName
                        end
                    end

                    grouped[recipeKey] = {
                        name = displayName or recipe.name or "?",
                        itemId = recipe.itemId,
                        spellId = recipe.spellId,
                        profName = canonical,
                        crafters = {},
                        _crafterSeen = {},
                    }
                end
                -- Deduplicate: skip if this player already added for this recipe
                if not grouped[recipeKey]._crafterSeen[playerKey] then
                    grouped[recipeKey]._crafterSeen[playerKey] = true
                    table.insert(grouped[recipeKey].crafters, {
                        playerKey = playerKey,
                        playerName = playerName,
                    })
                end
            end
        end
    end

    -- Second pass: merge entries with the same display name + profession
    -- (handles locale duplication when some entries lack spellId/itemId)
    local byDisplayKey = {}
    local mergeTargets = {}
    for key, entry in pairs(grouped) do
        local displayKey = (entry.name or "") .. "|" .. (entry.profName or "")
        if byDisplayKey[displayKey] then
            -- Merge crafters into the existing entry
            local target = byDisplayKey[displayKey]
            for _, crafter in ipairs(entry.crafters) do
                if not grouped[target]._crafterSeen[crafter.playerKey] then
                    grouped[target]._crafterSeen[crafter.playerKey] = true
                    table.insert(grouped[target].crafters, crafter)
                end
            end
            -- Prefer the entry that has an ID
            if not grouped[target].spellId and entry.spellId then
                grouped[target].spellId = entry.spellId
            end
            if not grouped[target].itemId and entry.itemId then
                grouped[target].itemId = entry.itemId
            end
            mergeTargets[key] = true
        else
            byDisplayKey[displayKey] = key
        end
    end
    for key in pairs(mergeTargets) do
        grouped[key] = nil
    end

    local index = {}
    for _, entry in pairs(grouped) do
        entry._crafterSeen = nil -- clean up temp field
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

----------------------------------------------------------------------
-- Build a cached itemId → crafters lookup from recipe data
----------------------------------------------------------------------
function RecipeTracker:BuildItemCrafterIndex()
    local index = {}
    local DC = BRutus.DataCollector
    for playerKey, professions in pairs(BRutusDB.recipes or {}) do
        local playerName = playerKey:match("^([^-]+)") or playerKey
        for profName, recipes in pairs(professions) do
            local canonical = DC and DC.GetCanonicalProfName and DC:GetCanonicalProfName(profName) or profName
            for _, recipe in ipairs(recipes) do
                if recipe.itemId then
                    if not index[recipe.itemId] then
                        index[recipe.itemId] = {}
                    end
                    local found = false
                    for _, c in ipairs(index[recipe.itemId]) do
                        if c.playerKey == playerKey then found = true break end
                    end
                    if not found then
                        local memberData = BRutus.db and BRutus.db.members and BRutus.db.members[playerKey]
                        table.insert(index[recipe.itemId], {
                            playerKey = playerKey,
                            playerName = playerName,
                            class = memberData and memberData.class,
                            profName = canonical,
                        })
                    end
                end
            end
        end
    end
    self._itemCrafterIndex = index
    self._itemCrafterIndexTime = GetTime()
    return index
end

function RecipeTracker:GetCraftersForItem(itemId)
    if not itemId then return nil end
    -- Rebuild cache every 30 seconds
    if not self._itemCrafterIndex or not self._itemCrafterIndexTime
       or (GetTime() - self._itemCrafterIndexTime) > 30 then
        self:BuildItemCrafterIndex()
    end
    local crafters = self._itemCrafterIndex[itemId]
    if not crafters or #crafters == 0 then return nil end
    return crafters
end

----------------------------------------------------------------------
-- Hook GameTooltip to show crafters for items
----------------------------------------------------------------------
function RecipeTracker:HookTooltips()
    local C = BRutus.Colors
    local onlineSet

    local function OnTooltipSetItem(tooltip)
        if not BRutusDB.recipes then return end

        local _, link = tooltip:GetItem()
        if not link then return end

        local itemId = tonumber(link:match("item:(%d+)"))
        if not itemId then return end

        local crafters = RecipeTracker:GetCraftersForItem(itemId)
        if not crafters then return end

        -- Refresh online set (cached per tooltip show)
        if not onlineSet then
            onlineSet = RecipeTracker:GetOnlineSet()
        end

        -- Sort: online first, then alphabetical
        local sorted = {}
        for _, c in ipairs(crafters) do
            table.insert(sorted, c)
        end
        table.sort(sorted, function(a, b)
            local aOn = onlineSet[a.playerName] and 1 or 0
            local bOn = onlineSet[b.playerName] and 1 or 0
            if aOn ~= bOn then return aOn > bOn end
            return a.playerName < b.playerName
        end)

        tooltip:AddLine(" ")
        tooltip:AddLine("Fabricado por:", C.accent.r, C.accent.g, C.accent.b)
        for _, c in ipairs(sorted) do
            local cc = c.class and BRutus.ClassColors[c.class] or C.white
            local status = onlineSet[c.playerName] and " |cff00ff00(online)|r" or " |cff666666(offline)|r"
            tooltip:AddDoubleLine("  " .. c.playerName .. status, c.profName, cc.r, cc.g, cc.b, 0.6, 0.6, 0.6)
        end

        tooltip:Show()
    end

    -- Clear online cache when tooltip hides
    GameTooltip:HookScript("OnTooltipCleared", function()
        onlineSet = nil
    end)

    GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)

    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end
    if ShoppingTooltip1 then
        ShoppingTooltip1:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end
    if ShoppingTooltip2 then
        ShoppingTooltip2:HookScript("OnTooltipSetItem", OnTooltipSetItem)
    end
end
