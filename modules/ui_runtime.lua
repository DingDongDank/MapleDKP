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

local function getBagItemLink(bagIndex, slotIndex)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bagIndex, slotIndex)
    end
    if GetContainerItemLink then
        return GetContainerItemLink(bagIndex, slotIndex)
    end
    return nil
end

function addon:TryInsertAuctionItemLink(link)
    if type(link) ~= "string" or trimText(link) == "" then
        return false
    end

    if not self.ui or not self.ui.initialized or not self.ui.optionsFrame then
        return false
    end

    local auctionPage = self.ui.optionsFrame.auctionPage
    local input = auctionPage and auctionPage.auctionItemInput or nil
    if not input or not input.allowItemLinks then
        return false
    end

    if not self.ui.optionsFrame:IsShown() then
        return false
    end

    if self.ui.optionsFrame.activeTab ~= "auction" then
        return false
    end

    if not input:IsShown() then
        return false
    end

    input:SetText(link)
    input:HighlightText(0, 0)

    return true
end

function addon:EnsureItemLinkHook()
    if not self.chatLinkHookInstalled and type(ChatEdit_InsertLink) == "function" then
        local originalChatEditInsertLink = ChatEdit_InsertLink
        ChatEdit_InsertLink = function(link, ...)
            if addon and addon.TryInsertAuctionItemLink and addon:TryInsertAuctionItemLink(link) then
                return true
            end

            return originalChatEditInsertLink(link, ...)
        end
        self.chatLinkHookInstalled = true
    end

    if not self.modifiedItemClickHookInstalled and hooksecurefunc and type(HandleModifiedItemClick) == "function" then
        hooksecurefunc("HandleModifiedItemClick", function(link)
            if addon and addon.TryInsertAuctionItemLink then
                addon:TryInsertAuctionItemLink(link)
            end
        end)
        self.modifiedItemClickHookInstalled = true
    end

    if not self.containerItemClickHookInstalled and hooksecurefunc and type(ContainerFrameItemButton_OnModifiedClick) == "function" then
        hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(button)
            if not IsShiftKeyDown() then
                return
            end

            local bagIndex = button and (button.bag or (button.GetParent and button:GetParent() and button:GetParent():GetID()))
            local slotIndex = button and ((button.GetID and button:GetID()) or button.slot)
            if bagIndex == nil or slotIndex == nil then
                return
            end

            local itemLink = getBagItemLink(bagIndex, slotIndex)
            if itemLink and addon and addon.TryInsertAuctionItemLink then
                addon:TryInsertAuctionItemLink(itemLink)
            end
        end)
        self.containerItemClickHookInstalled = true
    end

    self.itemLinkHookInstalled = self.chatLinkHookInstalled
        and (self.modifiedItemClickHookInstalled or self.containerItemClickHookInstalled)
end

function addon:RefreshRaidDkpPopup()
    if not self.ui.initialized or not self.ui.raidDkpFrame then
        return
    end

    local frame = self.ui.raidDkpFrame
    if not frame:IsShown() then
        return
    end

    local entries = self:GetSortedTrackedDkpEntries()
    local count = math.min(#entries, #frame.rows)
    local localPlayer = self:GetPlayerName()
    local baseFont, baseSize, baseFlags = GameFontHighlightSmall:GetFont()

    for index, row in ipairs(frame.rows) do
        row:SetFont(baseFont, baseSize, baseFlags or "")
        if index <= count then
            local entry = entries[index]
            local colorHex = self:GetPlayerClassColorHex(entry.name)
            local displayName
            if colorHex then
                displayName = string.format("|c%s%s|r", colorHex, entry.name)
            else
                displayName = entry.name
            end
            if entry.name == localPlayer then
                row:SetText(string.format("|cFFFFD700%d.|r %s |cFFFFD700- %d (You)|r", index, displayName, entry.dkp))
            else
                row:SetText(string.format("%d. %s - %d", index, displayName, entry.dkp))
            end
        elseif index == 1 then
            row:SetText("No tracked raid members found.")
        else
            row:SetText("")
        end
    end

    frame.subtitle:SetText(string.format("Showing %d tracked members", #entries))
end

function addon:ToggleOptionsUI()
    self:EnsureItemLinkHook()
    self:EnsureUI()

    if self.ui.optionsFrame:IsShown() then
        self.ui.optionsFrame:Hide()
        return
    end

    self.ui.optionsFrame:Show()
    self:RefreshOptionsUI()
end

function addon:ShowOptionsUI()
    self:EnsureItemLinkHook()
    self:EnsureUI()
    self.ui.optionsFrame:Show()
    self:RefreshOptionsUI()
end

function addon:RefreshOptionsUI()
    if not self.ui.initialized or not self.ui.optionsFrame then
        return
    end

    local optionsFrame = self.ui.optionsFrame
    local isOfficer = self:IsOfficer()

    if optionsFrame.tabButtons and optionsFrame.tabButtons.auction then
        if isOfficer then
            optionsFrame.tabButtons.auction:Show()
        else
            optionsFrame.tabButtons.auction:Hide()
            if optionsFrame.activeTab == "auction" then
                self:SetOptionsTab("members")
                return
            end
        end
    end

    optionsFrame.officerLabel:SetText(isOfficer and "Officer controls enabled" or "Officer controls disabled")

    for _, control in ipairs(optionsFrame.officerControls) do
        if isOfficer then
            control:Enable()
        else
            control:Disable()
        end
    end

    self:RefreshOptionsMembersPage()
    self:RefreshOptionsActionsPage()
    self:RefreshOptionsBossesPage()
    self:RefreshOptionsAuctionPage()
    self:RefreshOptionsConflictsPage()
end

function addon:RefreshLootNotice()
    if not self.ui.initialized then
        return
    end

    local noticeFrame = self.ui.noticeFrame
    for index, row in ipairs(noticeFrame.rows) do
        local itemLink = self.recentLoot[index]
        row:SetText(itemLink or "")
    end

    if self.ui.noticeExpireAt and self.ui.noticeExpireAt > GetTime() and #self.recentLoot > 0 then
        noticeFrame:Show()
    else
        noticeFrame:Hide()
    end
end

function addon:RefreshHistoryFrame()
    if not self.ui.initialized or not self.ui.historyFrame then
        return
    end

    local historyFrame = self.ui.historyFrame
    local history = self.guild and self.guild.history or {}
    local totalRows = #history
    local rowsPerPage = #historyFrame.historyRows
    local maxOffset = math.max(0, totalRows - rowsPerPage)
    local offset = math.min(historyFrame.scrollOffset or 0, maxOffset)
    historyFrame.scrollOffset = offset

    if historyFrame.scrollBar then
        historyFrame.scrollBar:SetMinMaxValues(0, maxOffset)
        historyFrame.scrollBar:SetValue(offset)
        if maxOffset > 0 then
            historyFrame.scrollBar:Show()
        else
            historyFrame.scrollBar:Hide()
        end
    end

    for index, row in ipairs(historyFrame.historyRows) do
        local historyIndex = totalRows - offset - (index - 1)
        local entry = history[historyIndex]
        if entry then
            row:SetText(entry)
            row:Show()
        else
            row:SetText("")
            row:Hide()
        end
    end

    local startIndex = totalRows == 0 and 0 or math.max(1, totalRows - offset - (rowsPerPage - 1))
    local endIndex = totalRows == 0 and 0 or math.max(1, totalRows - offset)
    local atTop = (offset == 0)
    local atBottom = (offset >= maxOffset and totalRows > 0)
    if historyFrame.summaryText then
        local positionLabel
        if totalRows == 0 then
            positionLabel = "No entries"
        elseif atTop then
            positionLabel = "Top (Newest)"
        elseif atBottom then
            positionLabel = "Bottom (Oldest)"
        else
            positionLabel = "Middle"
        end
        historyFrame.summaryText:SetText(string.format("Showing %d-%d of %d total entries | Position: %s", startIndex, endIndex, totalRows, positionLabel))
    end

    if historyFrame.topHintText then
        if totalRows == 0 then
            historyFrame.topHintText:SetText("")
        elseif atTop then
            historyFrame.topHintText:SetText("[Top Reached]")
        else
            historyFrame.topHintText:SetText("Top: scroll up")
        end
    end

    if historyFrame.bottomHintText then
        if totalRows == 0 then
            historyFrame.bottomHintText:SetText("")
        elseif atBottom then
            historyFrame.bottomHintText:SetText("[Bottom Reached]")
        else
            historyFrame.bottomHintText:SetText("Bottom: scroll down")
        end
    end
end

function addon:RefreshLeaderUI()
    if not self.ui.initialized then
        return
    end

    local controlFrame = self.ui.controlFrame
    if not self:IsOfficer() then
        controlFrame:Hide()
        return
    end

    if controlFrame.trackingStatusText then
        controlFrame.trackingStatusText:SetText(self:IsTrackingEnabled() and "Tracking: ON" or "Tracking: OFF")
    end

    for index, row in ipairs(controlFrame.lootRows) do
        local itemLink = self.recentLoot[index]
        if itemLink then
            row.text:SetText(itemLink)
            row.button.itemLink = itemLink
            row.button:Enable()
        else
            row.text:SetText(index == 1 and "No recent loot detected." or "")
            row.button.itemLink = nil
            row.button:Disable()
        end
    end

    if self.activeAuction then
        local remaining = math.max(0, (self.activeAuction.expiresAt or GetTime()) - GetTime())
        controlFrame.auctionItemText:SetText(self.activeAuction.item)
        controlFrame.auctionMetaText:SetText(string.format("Minimum %d DKP, %s left.", self.activeAuction.minBid, formatSeconds(remaining)))
        controlFrame.auctionResultText:SetText(self.lastAuctionResult or "Winner will be shown here when bidding closes.")
        controlFrame.closeAuctionButton:Enable()
    else
        controlFrame.auctionItemText:SetText("No active auction.")
        controlFrame.auctionMetaText:SetText("")
        controlFrame.auctionResultText:SetText(self.lastAuctionResult or "Select a recent drop to start bidding.")
        controlFrame.closeAuctionButton:Disable()
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

    for index, row in ipairs(controlFrame.bidRows) do
        local bid = orderedBids[index]
        if bid then
            row:SetText(string.format("%s - %d", bid.bidder, bid.amount))
        else
            if index == 1 and self.activeAuction and not canViewLiveBids then
                row:SetText("Silent bidding is active. Only the auction starter can view bids.")
            else
                row:SetText(index == 1 and (self.activeAuction and "No bids yet." or "") or "")
            end
        end
    end
end

function addon:RefreshAuctionPopup()
    if not self.ui.initialized then
        return
    end

    local auctionFrame = self.ui.auctionFrame
    if not self.activeAuction then
        auctionFrame:Hide()
        auctionFrame.currentAuctionId = nil
        self.ui.auctionPopupDismissed = nil
        if self.ui.raidDkpFrame then
            self.ui.raidDkpFrame:Hide()
        end
        return
    end

    local remaining = math.max(0, (self.activeAuction.expiresAt or GetTime()) - GetTime())
    auctionFrame.itemText:SetText(self.activeAuction.item)
    auctionFrame.minBidText:SetText(string.format("Minimum bid: %d", self.activeAuction.minBid))
    auctionFrame.timerText:SetText(string.format("Time left: %s", formatSeconds(remaining)))
    auctionFrame.dkpText:SetText(string.format("Your DKP: %d", self:GetPlayerDKP(self:GetPlayerName())))

    if auctionFrame.currentAuctionId ~= self.activeAuction.id then
        auctionFrame.currentAuctionId = self.activeAuction.id
        auctionFrame.bidInput:SetText(tostring(self.activeAuction.minBid))
        auctionFrame.statusText:SetText("")
        self.ui.auctionPopupDismissed = false
    end

    if self.ui.auctionPopupDismissed then
        auctionFrame:Hide()
        if self.ui.raidDkpFrame then
            self.ui.raidDkpFrame:Hide()
        end
        return
    end

    auctionFrame:Show()
    auctionFrame:Raise()
    self:RefreshRaidDkpPopup()
end

function addon:OnUpdate(elapsed)
    self.ui.elapsed = (self.ui.elapsed or 0) + elapsed
    if self.ui.elapsed < 0.2 then
        return
    end

    self.ui.elapsed = 0

    if self.activeAuction and self.activeAuction.startedBy == self:GetPlayerName() and self:IsOfficer() then
        local remaining = (self.activeAuction.expiresAt or 0) - GetTime()
        if remaining > 0 and remaining <= 10 and not self.activeAuction.tenSecondWarningSent then
            self.activeAuction.tenSecondWarningSent = true
            self:AnnounceGroupChat(string.format("Bidding ends in 10 seconds for %s.", self.activeAuction.item))
        end
    end

    if self.activeAuction and (self.activeAuction.expiresAt or 0) <= GetTime() and not self.activeAuction.closing then
        if self.activeAuction.startedBy == self:GetPlayerName() and self:IsOfficer() then
            self.activeAuction.closing = true
            self:CloseAuction()
            return
        end
    end

    self:ResolvePendingBossAwards(false)

    if self.ui.initialized then
        self:RefreshLeaderUI()
        self:RefreshAuctionPopup()
        self:RefreshLootNotice()
        self:RefreshRaidDkpPopup()
    end
end
