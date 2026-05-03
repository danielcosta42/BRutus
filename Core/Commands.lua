----------------------------------------------------------------------
-- BRutus Guild Manager - Slash Commands
-- /brutus and /br dispatch table.
----------------------------------------------------------------------

SLASH_BRUTUS1 = "/brutus"
SLASH_BRUTUS2 = "/br"
SlashCmdList["BRUTUS"] = function(msg)
    msg = strtrim(msg or "")
    if msg == "scan" then
        if BRutus.DataCollector then
            BRutus.DataCollector:CollectMyData()
            BRutus:Print("Data collected.")
        end
    elseif msg == "sync" then
        if BRutus.CommSystem then
            BRutus.CommSystem:FullSync()
        end
    elseif msg == "reset" then
        if BRutus.guildKey and BRutusDB then
            BRutusDB[BRutus.guildKey] = nil
        end
        ReloadUI()
    elseif msg:match("^recruit") then
        local rest = msg:gsub("^recruit%s*", "")
        local args = {}
        for word in rest:gmatch("%S+") do
            table.insert(args, word)
        end
        if BRutus.Recruitment then
            BRutus.Recruitment:HandleCommand(args)
        end
    elseif msg == "consumables" or msg == "cons" then
        if BRutus.ConsumableChecker then
            local results = BRutus.ConsumableChecker:CheckRaid()
            if results then
                local missing = BRutus.ConsumableChecker:GetMissingCount(results)
                BRutus:Print("Consumable check done. " .. missing .. " players missing buffs.")
            end
        end
    elseif msg == "consreport" then
        if BRutus.ConsumableChecker then
            BRutus.ConsumableChecker:ReportToChat("RAID")
        end
    elseif msg:match("^trial") then
        local rest = msg:gsub("^trial%s*", "")
        local name = rest:match("^(%S+)")
        if name and BRutus.TrialTracker then
            local realm = GetRealmName()
            local key = name .. "-" .. realm
            BRutus.TrialTracker:AddTrial(key)
        else
            BRutus:Print("Usage: /brutus trial <PlayerName>")
        end
    elseif msg:match("^note") then
        local rest = msg:gsub("^note%s*", "")
        local target, noteText = rest:match("^(%S+)%s+(.+)$")
        if target and noteText and BRutus.OfficerNotes then
            local realm = GetRealmName()
            local key = target .. "-" .. realm
            if BRutus.OfficerNotes:AddNote(key, noteText) then
                BRutus:Print("Note added for " .. target)
            end
        else
            BRutus:Print("Usage: /brutus note <PlayerName> <text>")
        end
    elseif msg == "lm" or msg == "lootmaster" then
        if BRutus.LootMaster then
            if BRutus.LootMaster:IsMasterLooter() then
                BRutus:Print("Loot Master mode active. Open loot to start.")
            else
                BRutus:Print("You are not the Master Looter.")
            end
        end
    elseif msg:match("^lm announce") then
        -- /brutus lm announce - manually announce item from target tooltip
        BRutus:Print("Open loot window as Master Looter to announce items.")
    elseif msg == "exportatt" or msg == "exportattendance" then
        if BRutus.RaidTracker then
            local json, err = BRutus.RaidTracker:ExportForTMB()
            if json then
                BRutus:ShowExportPopup("Export de Presença", json)
            else
                BRutus:Print("|cffFF4444Export failed:|r " .. (err or "unknown error"))
            end
        end
    elseif msg:match("^wish") then
        if not BRutus:IsOfficer() then
            BRutus:Print("|cffFF4444Lista de desejos disponível apenas para officers no momento.|r")
            return
        end
        local rest = strtrim(msg:gsub("^wish%s*", ""))
        if rest == "" or rest == "list" then
            -- Show wishlist frame
            BRutus:ShowWishlistFrame()
        elseif rest:match("^remove%s+") then
            local link = rest:match("^remove%s+(.+)$")
            local itemId = link and tonumber(link:match("item:(%d+)"))
            if itemId and BRutus.Wishlist then
                BRutus.Wishlist:RemoveFromWishlist(itemId)
            else
                BRutus:Print("Usage: /brutus wish remove [itemlink]")
            end
        else
            -- Treat remainder as an item link to add
            local itemId = tonumber(rest:match("item:(%d+)"))
            if itemId and BRutus.Wishlist then
                BRutus.Wishlist:AddToWishlist(itemId, rest, false)
            else
                BRutus:Print("Usage: /brutus wish [itemlink] | /brutus wish remove [itemlink]")
            end
        end
    elseif msg == "mergeraids" then
        if BRutus.RaidTracker then
            BRutus:Print("Merging duplicate raid sessions\226\128\166")
            local count = BRutus.RaidTracker:MergeDuplicateSessions()
            if count == 0 then
                BRutus:Print("|cffAAAAAA[BRutus] No duplicates found.|r")
            end
        end
    elseif msg == "ready" then
        -- /brutus ready — run pre-pull validation check
        if BRutus.PrePullService then
            BRutus.PrePullService:RunCheck()
        else
            BRutus:Print("PrePullService not available.")
        end
    elseif msg == "brain" then
        -- /brutus brain — toggle Raid Brain HUD
        if BRutus.RaidBrain then
            BRutus.RaidBrain:Toggle()
        end
    elseif msg == "specs" then
        if BRutus.SpecChecker then
            BRutus.SpecChecker:ScanGroup()
        end
    elseif msg == "attune" or msg == "attunements" then
        -- Print attunement status for the logged-in character to chat.
        if BRutus.AttunementTracker then
            local atts = BRutus.AttunementTracker:ScanAttunements()
            BRutus:Print("|cffFFD700Attunements:|r")
            for _, att in ipairs(atts) do
                if not att.alwaysComplete then
                    local status
                    if att.complete then
                        status = "|cff00FF00Done|r"
                    elseif att.progress and att.progress > 0 then
                        status = format("|cffFFD700%d%%|r", math.floor(att.progress * 100))
                    else
                        status = "|cffFF4444Not started|r"
                    end
                    BRutus:Print(format("  [%s] %s \226\128\148 %s", att.tier, att.name, status))
                end
            end
        end
    elseif msg == "attune debug" or msg == "attunements debug" then
        -- Debug mode: prints per-quest IsQuestFlaggedCompleted results.
        if BRutus.AttunementTracker then
            BRutus:Print("|cffFFD700Attunement debug (per quest):|r")
            for _, attDef in ipairs(BRutus.AttunementTracker.ATTUNEMENTS) do
                if not attDef.alwaysComplete and attDef.finalQuestId then
                    BRutus:Print(format("|cffAAAAAA--- %s (final=%d) ---|r", attDef.name, attDef.finalQuestId))
                    for _, q in ipairs(attDef.quests) do
                        local done = BRutus.AttunementTracker:IsQuestComplete(q.id)
                        local col = done and "|cff00FF00" or "|cffFF4444"
                        BRutus:Print(format("  %s[%d] %s|r", col, q.id, q.name))
                    end
                    if attDef.keyItemId then
                        local count = GetItemCount(attDef.keyItemId) or 0
                        local col = count > 0 and "|cff00FF00" or "|cffFF4444"
                        BRutus:Print(format("  %sKey item %d: %d in bags|r", col, attDef.keyItemId, count))
                    end
                end
            end
        end
    elseif msg:match("^assign") then
        -- /brutus assign <ssc|tk> [bossId]
        -- /brutus assign preview  — re-show last preview
        -- /brutus assign clear    — close preview
        if not BRutus:IsOfficer() then
            BRutus:Print("|cffFF4444Raid assignments are officer-only.|r")
            return
        end
        local rest = strtrim(msg:gsub("^assign%s*", ""))
        local args = {}
        for word in rest:gmatch("%S+") do
            tinsert(args, word)
        end
        local sub = (args[1] or ""):lower()
        if sub == "" then
            BRutus:Print("Usage: /brutus assign <ssc|tk> [bossId]")
            BRutus:Print("       /brutus assign preview")
            BRutus:Print("       /brutus assign clear")
        elseif sub == "preview" then
            if BRutus.ShowAssignmentPreview then
                BRutus:ShowAssignmentPreview(nil)
            end
        elseif sub == "clear" then
            if BRutus.HideAssignmentPreview then
                BRutus:HideAssignmentPreview()
            end
        elseif sub == "ssc" or sub == "tk" then
            if not BRutus.AssignmentAutoFillService then
                BRutus:Print("AssignmentAutoFillService not available.")
                return
            end
            local raidId = sub:upper()
            local bossId = args[2] and args[2]:lower()
            if bossId then
                local res, err = BRutus.AssignmentAutoFillService:GenerateForBoss(raidId, bossId)
                if res then
                    BRutus:Print(format("[Assign] %s / %s — Confidence: %s  Missing: %d",
                        raidId, res.bossName, res.confidence, #res.missing))
                    BRutus:ShowAssignmentPreview(res)
                else
                    BRutus:Print("|cffFF4444[Assign] " .. (err or "Unknown error") .. "|r")
                end
            else
                local results = BRutus.AssignmentAutoFillService:GenerateForRaid(raidId)
                if #results == 0 then
                    BRutus:Print("|cffFF4444[Assign] No templates found for " .. raidId .. ".|r")
                    return
                end
                local totalMissing, lowCount = 0, 0
                for _, r in ipairs(results) do
                    totalMissing = totalMissing + #r.missing
                    if r.confidence == "LOW" then lowCount = lowCount + 1 end
                end
                BRutus:Print(format("[Assign] %s — %d bosses. Missing slots: %d. Low confidence: %d",
                    raidId, #results, totalMissing, lowCount))
                BRutus:ShowAssignmentPreview(results[1])
            end
        else
            BRutus:Print("|cffFF4444[Assign] Unknown raid: '" .. sub .. "'. Use: ssc | tk|r")
        end
    elseif msg == "attune dumpquests" then
        -- Dumps all completed quest IDs in the TBC attunement range.
        -- Covers T4/T5/T6 + some headroom for anniversary-specific hidden flags.
        BRutus:Print("|cffFFD700Completed quests in range 9800-11500:|r")
        local found = 0
        for qid = 9800, 11500 do
            if BRutus.AttunementTracker:IsQuestComplete(qid) then
                -- Try to get the quest title (may be nil for hidden server-side quests)
                local title = nil
                if C_QuestLog and C_QuestLog.GetTitleForQuestID then
                    title = C_QuestLog.GetTitleForQuestID(qid)
                end
                if title and title ~= "" then
                    BRutus:Print(format("  |cff00FF00[%d]|r %s", qid, title))
                else
                    BRutus:Print(format("  |cff00FF00[%d]|r |cffAAAAAA(no title \226\128\148 hidden/anniversary quest)|r", qid))
                end
                found = found + 1
            end
        end
        if found == 0 then
            BRutus:Print("|cffFF4444No completed quests found in that range.|r")
        else
            BRutus:Print(format("|cffAAAAAA%d quests found. Run on main to compare IDs.|r", found))
        end
    else
        BRutus:ToggleRoster()
    end
end
