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

local function formatSeconds(seconds)
    seconds = math.max(0, math.ceil(safeNumber(seconds, 0)))
    local minutes = math.floor(seconds / 60)
    local remainder = seconds % 60

    if minutes > 0 then
        return string.format("%d:%02d", minutes, remainder)
    end

    return string.format("%ds", remainder)
end

function addon:ToggleRaidDkpPopup()
    self:EnsureUI()

    local frame = self.ui.raidDkpFrame
    if frame:IsShown() then
        frame:Hide()
        return
    end

    frame:Show()
    self:RefreshRaidDkpPopup()
end

function addon:SetOptionsTab(tabName)
    if not self.ui.initialized or not self.ui.optionsFrame then
        return
    end

    if tabName == "auction" and not self:IsOfficer() then
        tabName = "members"
    end

    local optionsFrame = self.ui.optionsFrame
    optionsFrame.activeTab = tabName

    for name, page in pairs(optionsFrame.pages) do
        if name == tabName then
            page:Show()
        else
            page:Hide()
        end
    end

    for name, button in pairs(optionsFrame.tabButtons) do
        if name == tabName then
            button:Disable()
        else
            button:Enable()
        end
    end

    self:RefreshOptionsUI()
end

function addon:RefreshOptionsMembersPage()
    local optionsFrame = self.ui.optionsFrame
    if not optionsFrame or not optionsFrame.membersPage then
        return
    end

    local page = optionsFrame.membersPage
    local sortMode = page.sortMode or "name"
    local entries
    if sortMode == "dkp" then
        entries = self:GetSortedGuildDkpEntries()
    elseif sortMode == "earned" then
        entries = self:GetSortedGuildMemberEntriesByEarned()
    elseif sortMode == "spent" then
        entries = self:GetSortedGuildMemberEntriesBySpent()
    elseif sortMode == "class" then
        entries = self:GetSortedGuildMemberEntriesByClass(page.classSecondaryByDkp)
    else
        entries = self:GetSortedGuildMemberEntriesAlphabetical()
    end
    if page.sortByNameButton then
        if sortMode == "name" then page.sortByNameButton:Disable() else page.sortByNameButton:Enable() end
    end
    if page.sortByDkpButton then
        if sortMode == "dkp" then page.sortByDkpButton:Disable() else page.sortByDkpButton:Enable() end
    end
    if page.sortByEarnedButton then
        if sortMode == "earned" then page.sortByEarnedButton:Disable() else page.sortByEarnedButton:Enable() end
    end
    if page.sortBySpentButton then
        if sortMode == "spent" then page.sortBySpentButton:Disable() else page.sortBySpentButton:Enable() end
    end
    if page.sortByClassButton then
        if sortMode == "class" then page.sortByClassButton:Disable() else page.sortByClassButton:Enable() end
    end
    local selectedName = self.ui.optionsSelectedMember
    local columns = safeNumber(page.columns, 1)
    local rowsPerColumn = safeNumber(page.rowsPerColumn, 20)
    local maxOffset = math.max(0, #entries - columns * rowsPerColumn)
    local offset = math.min(page.scrollOffset or 0, maxOffset)
    page.scrollOffset = offset

    if page.scrollBar then
        page.scrollBar:SetMinMaxValues(0, maxOffset)
        page.scrollBar:SetValue(offset)
        if maxOffset > 0 then
            page.scrollBar:Show()
        else
            page.scrollBar:Hide()
        end
    end

    for _, button in ipairs(page.memberButtons) do
        local rowIndex = safeNumber(button.rowIndex, 1)
        local columnIndex = safeNumber(button.columnIndex, 1)
        local entryIndex = offset + (columnIndex - 1) * rowsPerColumn + rowIndex
        local entry = entries[entryIndex]
        if entry then
            local prefix = selectedName == entry.name and "> " or ""
            button.entryName = entry.name
            local colorHex = self:GetPlayerClassColorHex(entry.name)
            if colorHex then
                button.text:SetText(string.format("|c%s%s%s|r", colorHex, prefix, entry.name))
            else
                button.text:SetText(string.format("%s%s", prefix, entry.name))
            end
            if button.dkpText then
                button.dkpText:SetText(tostring(entry.dkp))
            end
            if button.earnedText then
                button.earnedText:SetText(tostring(safeNumber(entry.earned, 0)))
            end
            if button.spentText then
                button.spentText:SetText(tostring(safeNumber(entry.spent, 0)))
            end
            button:Show()
            button:Enable()
        else
            button.entryName = nil
            button.text:SetText("")
            if button.dkpText then
                button.dkpText:SetText("")
            end
            if button.earnedText then
                button.earnedText:SetText("")
            end
            if button.spentText then
                button.spentText:SetText("")
            end
            button:Hide()
        end
    end

    if selectedName and self.guild and self.guild.players and self.guild.players[selectedName] then
        local selectedInfo = self.guild.players[selectedName]
        page.selectedText:SetText(string.format("Selected: %s | DKP %d | Earned %d | Spent %d",
            selectedName,
            self:GetPlayerDKP(selectedName),
            safeNumber(selectedInfo and selectedInfo.earned, 0),
            safeNumber(selectedInfo and selectedInfo.spent, 0)
        ))
    else
        if selectedName then
            page.selectedText:SetText("Selected player is no longer in the list.")
        else
            page.selectedText:SetText("Select a member to edit their DKP.")
        end
    end

    if page.deleteButton then
        if selectedName and self.guild and self.guild.players and self.guild.players[selectedName] then
            page.deleteButton:Enable()
        else
            page.deleteButton:Disable()
        end
    end

    if page.removeRaiderButton then
        if selectedName and self.guild and self.guild.players and self.guild.players[selectedName] then
            page.removeRaiderButton:Enable()
        else
            page.removeRaiderButton:Disable()
        end
    end

    local startIndex = #entries == 0 and 0 or (offset * columns + 1)
    local endIndex = math.min(#entries, (offset + rowsPerColumn) * columns)
    local sortLabel = sortMode == "dkp" and "DKP desc"
        or sortMode == "earned" and "Earned desc"
        or sortMode == "spent" and "Spent desc"
        or sortMode == "class" and (page.classSecondaryByDkp and "Class+DKP" or "Class")
        or "A-Z"
    page.summaryText:SetText(string.format("Active raiders (earned in last 30 days): %d. Showing %d-%d (%s).", #entries, startIndex, endIndex, sortLabel))
    page.quietStatusText:SetText(self:IsQuietMode() and "Quiet mode: On" or "Quiet mode: Off")
    page.toggleQuietButton:SetText(self:IsQuietMode() and "Disable Quiet" or "Enable Quiet")
end

function addon:RefreshOptionsActionsPage()
    local optionsFrame = self.ui.optionsFrame
    if not optionsFrame or not optionsFrame.actionsPage then
        return
    end

    local page = optionsFrame.actionsPage
    local isOfficer = self:IsOfficer()

    local officerOnlyControls = {
        page.description,
        page.adjustTargetLabel,
        page.adjustTargetInput,
        page.adjustAmountLabel,
        page.adjustAmountInput,
        page.reasonLabel,
        page.adjustReasonInput,
        page.addButton,
        page.subtractButton,
        page.setButton,
        page.fullResetButton,
        page.fullResetWarningText,
        page.trackingToggleButton,
        page.testLootButton,
        page.testLootStatusText,
    }

    for _, control in ipairs(officerOnlyControls) do
        if control then
            if isOfficer then
                control:Show()
            else
                control:Hide()
            end
        end
    end

    if page.syncButton then
        page.syncButton:Show()
    end
    if page.trackingStatusText then
        page.trackingStatusText:Show()
        page.trackingStatusText:SetText(self:IsTrackingEnabled() and "Raid DKP tracking: ON" or "Raid DKP tracking: OFF")
    end
    if page.trackingToggleButton then
        page.trackingToggleButton:SetText(self:IsTrackingEnabled() and "Disable Tracking" or "Enable Tracking")
    end
    if page.historyHeader then
        page.historyHeader:Show()
    end
    if page.conflictSummaryText then
        page.conflictSummaryText:Show()
    end
    if page.reviewConflictsButton then
        page.reviewConflictsButton:Show()
    end
    if page.historyViewButton then
        page.historyViewButton:Show()
    end
    for _, row in ipairs(page.historyRows or {}) do
        row:Show()
    end

    if page.testLootButton then
        if self:IsTestMode() then
            page.testLootButton:Enable()
            page.testLootButton:SetText(self:IsTestAllLootEnabled() and "Loot Capture: On" or "Loot Capture: Off")
        else
            page.testLootButton:Disable()
            page.testLootButton:SetText("Loot Capture")
        end
    end

    if page.testLootStatusText then
        if self:IsTestMode() then
            page.testLootStatusText:SetText(self:IsTestAllLootEnabled() and "Test loot auto-capture is ON." or "Test loot auto-capture is OFF.")
        else
            page.testLootStatusText:SetText("Test loot auto-capture is only available in test mode.")
        end
    end

    local history = self.guild and self.guild.history or {}
    local offset = math.max(1, #history - #page.historyRows + 1)
    for index, row in ipairs(page.historyRows) do
        local line = history[offset + index - 1]
        row:SetText(line or (index == 1 and "No history recorded yet." or ""))
    end

    local conflictCount = self:GetConflictCount()
    if page.conflictSummaryText then
        if conflictCount > 0 then
            page.conflictSummaryText:SetText(string.format("Conflicts: %d unresolved. Review before using Set.", conflictCount))
        else
            page.conflictSummaryText:SetText("Conflicts: none.")
        end
    end
    if page.reviewConflictsButton then
        if conflictCount > 0 then
            page.reviewConflictsButton:Enable()
        else
            page.reviewConflictsButton:Disable()
        end
    end
end

function addon:RefreshOptionsConflictsPage()
    local optionsFrame = self.ui.optionsFrame
    if not optionsFrame or not optionsFrame.conflictsPage then
        return
    end

    local page = optionsFrame.conflictsPage
    local entries = self:GetConflictEntries()
    local maxOffset = math.max(0, #entries - #page.conflictRows)
    local offset = math.min(page.scrollOffset or 0, maxOffset)
    page.scrollOffset = offset

    if page.scrollBar then
        page.scrollBar:SetMinMaxValues(0, maxOffset)
        page.scrollBar:SetValue(offset)
        if maxOffset > 0 then
            page.scrollBar:Show()
        else
            page.scrollBar:Hide()
        end
    end

    if self.ui.optionsSelectedConflictId and not self.guild.conflicts[self.ui.optionsSelectedConflictId] then
        self.ui.optionsSelectedConflictId = nil
    end
    if not self.ui.optionsSelectedConflictId and entries[1] then
        self.ui.optionsSelectedConflictId = entries[1].id
    end

    for index, button in ipairs(page.conflictRows) do
        local entry = entries[offset + index]
        if entry then
            button.conflictId = entry.id
            local marker = entry.id == self.ui.optionsSelectedConflictId and "> " or ""
            local actor = trimText(entry.actor) ~= "" and trimText(entry.actor) or "unknown"
            button.text:SetText(string.format("%s%s | %s | %s -> %d", marker, entry.playerName, string.upper(trimText(entry.opType)), actor, safeNumber(entry.desiredValue, 0)))
            button:Show()
            button:Enable()
        else
            button.conflictId = nil
            button.text:SetText("")
            button:Hide()
        end
    end

    local selected = self.ui.optionsSelectedConflictId and self.guild.conflicts[self.ui.optionsSelectedConflictId] or nil
    if page.summaryText then
        page.summaryText:SetText(string.format("Open conflicts: %d", #entries))
    end
    if page.selectedText then
        if selected then
            page.selectedText:SetText(string.format("Selected: %s | %s by %s", selected.playerName, string.upper(trimText(selected.opType)), trimText(selected.actor) ~= "" and trimText(selected.actor) or "unknown"))
        else
            page.selectedText:SetText("Select a conflict to review.")
        end
    end
    if page.detailText then
        if selected then
            page.detailText:SetText(string.format(
                "Expected old DKP: %s\nCurrent DKP: %d\nRequested value: %d\nReason: %s",
                selected.expectedOldValue ~= nil and tostring(selected.expectedOldValue) or "n/a",
                safeNumber(selected.currentValue, 0),
                safeNumber(selected.desiredValue, 0),
                trimText(selected.reason)
            ))
        else
            page.detailText:SetText("No conflict selected.")
        end
    end

    local hasSelection = selected ~= nil
    if page.keepCurrentButton then
        if hasSelection then page.keepCurrentButton:Enable() else page.keepCurrentButton:Disable() end
    end
    if page.applyIncomingButton then
        if hasSelection then page.applyIncomingButton:Enable() else page.applyIncomingButton:Disable() end
    end
    if page.manualApplyButton then
        if hasSelection then page.manualApplyButton:Enable() else page.manualApplyButton:Disable() end
    end
    if page.manualValueInput and selected then
        page.manualValueInput:SetText(tostring(safeNumber(selected.currentValue, 0)))
    elseif page.manualValueInput and not hasSelection then
        page.manualValueInput:SetText("")
    end
end

function addon:RefreshOptionsBossesPage()
    local optionsFrame = self.ui.optionsFrame
    if not optionsFrame or not optionsFrame.bossesPage then
        return
    end

    local page = optionsFrame.bossesPage
    local isOfficer = self:IsOfficer()

    if page.description then
        if isOfficer then
            page.description:SetText("Select a boss from the list, then update only its DKP value.")
        else
            page.description:SetText("Boss DKP values (read-only).")
        end
    end

    local editControls = {
        page.selectedText,
        page.bossIdHeader,
        page.bossIdValue,
        page.bossNameHeader,
        page.bossNameValue,
        page.bossZoneHeader,
        page.bossZoneValue,
        page.bossAmountHeader,
        page.bossAmountInput,
        page.saveBossButton,
    }

    for _, control in ipairs(editControls) do
        if control then
            if isOfficer then
                control:Show()
            else
                control:Hide()
            end
        end
    end

    local rows = self:GetBossDisplayRows()
    local entries = self:GetSortedBossEntries()
    local selectedNpcId = self.ui.optionsSelectedBossNpcId
    local maxOffset = math.max(0, #rows - #page.bossRows)
    local offset = math.min(page.scrollOffset or 0, maxOffset)
    page.scrollOffset = offset

    local startIndex = #rows == 0 and 0 or (offset + 1)
    local endIndex = math.min(#rows, offset + #page.bossRows)
    if page.summaryText then
        page.summaryText:SetText(string.format("Rows %d-%d of %d | Bosses: %d | Scroll for more", startIndex, endIndex, #rows, #entries))
    end

    if page.scrollBar then
        page.scrollBar:SetMinMaxValues(0, maxOffset)
        page.scrollBar:SetValue(offset)
        if maxOffset > 0 then
            page.scrollBar:Show()
        else
            page.scrollBar:Hide()
        end
    end

    if (not selectedNpcId or selectedNpcId == "0") and entries[1] then
        selectedNpcId = entries[1].npcId
        self.ui.optionsSelectedBossNpcId = selectedNpcId
    end

    for index, button in ipairs(page.bossRows) do
        local row = rows[offset + index]
        if row then
            button.npcId = nil
            button.zoneName = nil

            if row.rowType == "zone" then
                button.zoneName = row.zone
                button.text:SetText(string.format("%s %s (%d)", row.collapsed and "+" or "-", row.zone, row.count))
            else
                local prefix = selectedNpcId == row.npcId and "> " or " "
                button.npcId = row.npcId
                button.text:SetText(string.format(" %s %d. %s - %d", prefix, row.encounterOrder, row.name, row.amount))
            end

            button:Show()
            button:Enable()
        else
            button.npcId = nil
            button.zoneName = nil
            button.text:SetText("")
            button:Hide()
        end
    end

    local selectedEntry
    for _, entry in ipairs(entries) do
        if entry.npcId == selectedNpcId then
            selectedEntry = entry
            break
        end
    end

    if selectedEntry then
        page.selectedText:SetText(string.format("Editing: %s", selectedEntry.zone))
        page.bossIdValue:SetText(selectedEntry.npcId)
        page.bossNameValue:SetText(selectedEntry.name)
        page.bossZoneValue:SetText(selectedEntry.zone)
        page.bossAmountInput:SetText(tostring(selectedEntry.amount))
    else
        page.selectedText:SetText("No boss selected.")
        page.bossIdValue:SetText("-")
        page.bossNameValue:SetText("-")
        page.bossZoneValue:SetText("-")
        page.bossAmountInput:SetText("0")
    end
end

function addon:RefreshOptionsAuctionPage()
    local optionsFrame = self.ui.optionsFrame
    if not optionsFrame or not optionsFrame.auctionPage then
        return
    end

    local page = optionsFrame.auctionPage
    if self.activeAuction then
        local remaining = math.max(0, (self.activeAuction.expiresAt or GetTime()) - GetTime())
        page.activeAuctionText:SetText(string.format("Active: %s (%d minimum, %s left)", self.activeAuction.item, self.activeAuction.minBid, formatSeconds(remaining)))
    else
        page.activeAuctionText:SetText("No active auction.")
    end

    local orderedBids = {}
    local canViewLiveBids = self.activeAuction and self.activeAuction.startedBy == self:GetPlayerName()
    if canViewLiveBids then
        for bidder, amount in pairs(self.activeAuction.bids or {}) do
            orderedBids[#orderedBids + 1] = {
                bidder = bidder,
                amount = amount,
            }
        end
    end

    table.sort(orderedBids, function(left, right)
        if left.amount == right.amount then
            return left.bidder < right.bidder
        end

        return left.amount > right.amount
    end)

    if page.currentBidsHeader then
        page.currentBidsHeader:SetText("Current Bids")
    end

    for index, row in ipairs(page.currentBidRows or {}) do
        local bid = orderedBids[index]
        if bid then
            row:SetText(string.format("%s - %d", bid.bidder, bid.amount))
        else
            if index == 1 and self.activeAuction and not canViewLiveBids then
                row:SetText("Silent bidding is active. Only the auction starter can view bids.")
            else
                row:SetText(index == 1 and (self.activeAuction and "No bids yet." or "No active auction.") or "")
            end
        end
    end
end
