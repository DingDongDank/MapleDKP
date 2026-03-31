local addon = MapleDKP
if not addon then
    return
end

local function trimText(value)
    if not value then
        return ""
    end

    value = tostring(value)
    value = value:gsub("[\r\n\t]", " ")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function safeNumber(value, fallback)
    local numberValue = tonumber(value)
    if not numberValue then
        return fallback
    end

    return numberValue
end

function addon:ShowHistory()
    if not self.guild or #self.guild.history == 0 then
        self:Print("No DKP history recorded yet.")
        return
    end

    self:Print("Most recent DKP changes:")
    for index = math.max(1, #self.guild.history - 9), #self.guild.history do
        self:Print(self.guild.history[index])
    end
end

function addon:ShowActivityLog()
    if not self.guild or not self.guild.activityLog or #self.guild.activityLog == 0 then
        self:Print("No DKP activity log entries recorded yet.")
        return
    end

    self:Print("Most recent DKP activity entries:")
    for index = math.max(1, #self.guild.activityLog - 14), #self.guild.activityLog do
        self:Print(self:FormatActivityEntry(self.guild.activityLog[index]))
    end
end

function addon:ShowHelp()
    self:Print("Commands:")
    self:Print("/mdkp show [PlayerName]")
    self:Print("/mdkp standings")
    self:Print("/mdkp history")
    self:Print("/mdkp log")
    self:Print("/mdkp add PlayerName Amount Reason")
    self:Print("/mdkp sub PlayerName Amount Reason")
    self:Print("/mdkp set PlayerName Value Reason")
    self:Print("/mdkp award Amount Reason")
    self:Print("/mdkp boss add NpcID Amount Boss Name")
    self:Print("/mdkp boss list")
    self:Print("/mdkp auction start MinBid ItemLinkOrName")
    self:Print("/mdkp auction inv MinBid ItemNameOrLink (must be in your bags)")
    self:Print("/mdkp bid Amount")
    self:Print("/mdkp auction close [PlayerName] (use PlayerName to assign for free if no bids)")
    self:Print("/mdkp auction status")
    self:Print("/mdkp sync")
    self:Print("/mdkp defaultdkp [Value|status]")
    self:Print("/mdkp tracking [on|off|toggle|status]")
    self:Print("/mdkp quiet [on|off|toggle|status]")
    self:Print("/mdkp help")
    self:Print("/mdkp ui")
    if self:IsTestMode() then
        self:Print("/mdkp test (or /mdkp test help) - Show test commands")
    end
end

function addon:HandleSlashCommand(message)
    local input = trimText(message)
    if input == "" then
        self:ShowOptionsUI()
        return
    end

    local command, remainder = input:match("^(%S+)%s*(.-)$")
    command = string.lower(command or "")

    if command == "show" then
        local targetName = self:NormalizeName(remainder)
        if not targetName then
            targetName = self:GetPlayerName()
        end
        self:Print(string.format("%s has %d DKP.", targetName, self:GetPlayerDKP(targetName)))
        return
    end

    if command == "help" then
        self:ShowHelp()
        return
    end

    if command == "standings" then
        self:ListStandings()
        return
    end

    if command == "history" then
        self:ShowHistory()
        return
    end

    if command == "log" or command == "activity" then
        self:ShowActivityLog()
        return
    end

    if command == "add" then
        local playerName, amount, reason = remainder:match("^(%S+)%s+([%-]?%d+)%s*(.*)$")
        self:AdjustPlayer(playerName, amount, reason ~= "" and reason or "Manual adjustment")
        return
    end

    if command == "sub" or command == "subtract" then
        local playerName, amount, reason = remainder:match("^(%S+)%s+([%-]?%d+)%s*(.*)$")
        local resolvedAmount = math.abs(math.floor(safeNumber(amount, 0) + 0.5))
        self:AdjustPlayer(playerName, -resolvedAmount, reason ~= "" and reason or "Manual subtraction")
        return
    end

    if command == "set" then
        local playerName, amount, reason = remainder:match("^(%S+)%s+([%-]?%d+)%s*(.*)$")
        self:SetPlayerDKP(playerName, amount, reason ~= "" and reason or "Manual set")
        return
    end

    if command == "award" then
        local amount, reason = remainder:match("^([%-]?%d+)%s*(.*)$")
        self:AwardRaid(amount, reason ~= "" and reason or "Raid award")
        return
    end

    if command == "boss" then
        local subCommand, bossRemainder = remainder:match("^(%S+)%s*(.-)$")
        subCommand = string.lower(subCommand or "")

        if subCommand == "add" then
            local npcId, amount, bossName = bossRemainder:match("^(%d+)%s+([%-]?%d+)%s+(.+)$")
            self:ConfigureBoss(npcId, amount, bossName)
            return
        end

        if subCommand == "list" then
            self:ListBosses()
            return
        end
    end

    if command == "auction" then
        local subCommand, auctionRemainder = remainder:match("^(%S+)%s*(.-)$")
        subCommand = string.lower(subCommand or "")

        if subCommand == "start" then
            local minBid, itemLink = auctionRemainder:match("^([%-]?%d+)%s+(.+)$")
            self:StartAuction(minBid, itemLink)
            return
        end

        if subCommand == "inv" or subCommand == "bag" or subCommand == "inventory" then
            local minBid, itemQuery = auctionRemainder:match("^([%-]?%d+)%s+(.+)$")
            if not minBid or not itemQuery then
                self:Print("Usage: /mdkp auction inv MinBid ItemNameOrLink")
                return
            end

            self:StartAuctionFromInventory(minBid, itemQuery)
            return
        end

        if subCommand == "close" then
            self:CloseAuction(auctionRemainder ~= "" and auctionRemainder or nil)
            return
        end

        if subCommand == "status" then
            self:ShowAuctionStatus()
            return
        end

        if subCommand == "reopen" or subCommand == "window" then
            self:ReopenAuctionBidWindow(true)
            return
        end
    end

    if command == "ui" then
        self:ToggleOptionsUI()
        return
    end

    if command == "bid" then
        if self.activeAuction then
            self:RegisterBid(self:GetPlayerName(), remainder, false)
            return
        end

        local leaderName = self:GetGroupLeaderName()
        local bidAmount = math.floor(safeNumber(remainder, 0) + 0.5)
        if not leaderName or leaderName == self:GetPlayerName() then
            self:Print("There is no active auction.")
            return
        end

        self:SendMessage(table.concat({ "AUC", "BIDREQ", tostring(bidAmount) }, "\t"), "WHISPER", leaderName)
        self:Print(string.format("Sent bid request (%d DKP) to %s.", bidAmount, leaderName))
        return
    end

    if command == "sync" then
        if self:IsOfficer() then
            self:SendSnapshot(nil)
            self:Print("Broadcasted a DKP snapshot to the guild.")
        else
            self:RequestSync()
            self:Print("Requested the latest DKP snapshot from an officer.")
        end
        return
    end

    if command == "defaultdkp" or command == "newmemberdkp" then
        local mode = string.lower(trimText(remainder))
        if mode == "" or mode == "status" then
            self:Print(string.format("New-member default DKP is %d.", self:GetNewMemberDefaultDkp()), true)
            return
        end

        self:SetNewMemberDefaultDkp(remainder)
        return
    end

    if command == "tracking" then
        local mode = string.lower(trimText(remainder))
        if mode == "" or mode == "status" then
            self:Print(self:IsTrackingEnabled() and "Raid DKP tracking is ON." or "Raid DKP tracking is OFF.", true)
            return
        end
        if mode == "toggle" then
            self:SetTrackingEnabled(not self:IsTrackingEnabled())
            return
        end
        if mode == "on" then
            self:SetTrackingEnabled(true)
            return
        end
        if mode == "off" then
            self:SetTrackingEnabled(false)
            return
        end
        self:Print("Usage: /mdkp tracking [on|off|toggle|status]", true)
        return
    end

    if command == "quiet" then
        local mode = string.lower(trimText(remainder))
        if mode == "" or mode == "toggle" then
            self:SetQuietMode(not self:IsQuietMode())
        elseif mode == "on" then
            self:SetQuietMode(true)
        elseif mode == "off" then
            self:SetQuietMode(false)
        elseif mode == "status" then
            self:Print(self:IsQuietMode() and "Quiet mode is ON." or "Quiet mode is OFF.", true)
        else
            self:Print("Usage: /mdkp quiet [on|off|toggle|status]", true)
        end

        if self.ui and self.ui.initialized then
            self:RefreshOptionsUI()
        end
        return
    end

    if command == "test" then
        if not self:IsTestMode() then
            self:Print("Test mode is disabled.")
            return
        end

        local subCommand, testRemainder = remainder:match("^(%S+)%s*(.-)$")
        subCommand = string.lower(subCommand or "")

        if subCommand == "" or subCommand == "help" then
            self:Print("Test commands (work solo):")
            self:Print("/mdkp test boss [NpcID] - Simulate a boss kill")
            self:Print("/mdkp test claim NpcID [raid|party|guild] [OfficerA,OfficerB,...] - Simulate officer claim election")
            self:Print("/mdkp test loot [ItemLinkOrName] - Show loot popup & control panel")
            self:Print("/mdkp test auction [MinBid] [ItemLinkOrName] - Show auction popup")
            self:Print("/mdkp test lootcapture [on|off|status] - Auto-capture loot in test mode")
            return
        end

        if subCommand == "boss" then
            local npcId = testRemainder:match("^(%d+)")
            self:RunTestBossKill(npcId)
            return
        end

        if subCommand == "claim" then
            local npcId, claimRemainder = testRemainder:match("^(%d+)%s*(.-)$")
            local channelName, officerList = "RAID", ""
            if claimRemainder and claimRemainder ~= "" then
                local maybeChannel, remaining = claimRemainder:match("^(%S+)%s*(.-)$")
                local normalizedChannel = string.lower(trimText(maybeChannel))
                if normalizedChannel == "raid" or normalizedChannel == "party" or normalizedChannel == "guild" then
                    channelName = normalizedChannel
                    officerList = remaining or ""
                else
                    officerList = claimRemainder
                end
            end

            self:RunTestBossClaimElection(tostring(safeNumber(npcId, 0)), channelName, officerList)
            return
        end

        if subCommand == "loot" then
            self:InjectTestLoot(testRemainder)
            return
        end

        if subCommand == "auction" then
            local minBid, itemText = testRemainder:match("^([%-]?%d+)%s+(.+)$")
            if not minBid then
                minBid = 0
                itemText = testRemainder
            end
            itemText = trimText(itemText)
            if itemText == "" then
                itemText = "[Test Epic BoE]"
            end
            self:InjectTestLoot(itemText)
            self:StartAuction(minBid, itemText, 20)
            return
        end

        if subCommand == "lootcapture" or subCommand == "allloot" then
            local mode = string.lower(trimText(testRemainder))
            if mode == "" or mode == "status" then
                self:Print(self:IsTestAllLootEnabled() and "Test all-loot capture is ON." or "Test all-loot capture is OFF.", true)
                return
            end
            if mode == "on" then
                self:SetTestAllLootEnabled(true)
                return
            end
            if mode == "off" then
                self:SetTestAllLootEnabled(false)
                return
            end
            self:Print("Usage: /mdkp test lootcapture [on|off|status]", true)
            return
        end

        self:Print("Usage: /mdkp test [boss|claim|loot|auction|lootcapture] ...")
        return
    end

    self:ShowHelp()
end
