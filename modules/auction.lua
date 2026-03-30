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

local function shallowCopy(source)
    local target = {}
    for key, value in pairs(source or {}) do
        target[key] = value
    end
    return target
end

local function getBagSlotCount(bagIndex)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagIndex) or 0
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bagIndex) or 0
    end
    return 0
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

function addon:GetConfiguredMinBid()
    self:EnsureUI()

    local amount = math.floor(safeNumber(self.ui.controlFrame.minBidInput:GetText(), 0) + 0.5)
    if amount < 0 then
        amount = 0
    end

    self.ui.controlFrame.minBidInput:SetText(tostring(amount))
    return amount
end

function addon:GetConfiguredDuration()
    self:EnsureUI()

    local duration = math.floor(safeNumber(self.ui.controlFrame.durationInput:GetText(), self.auctionDuration) + 0.5)
    if duration < 5 then
        duration = 5
    end

    self.ui.controlFrame.durationInput:SetText(tostring(duration))
    return duration
end

function addon:FindInventoryItemLink(searchText)
    local rawQuery = trimText(searchText)
    local query = string.lower(rawQuery)
    if query == "" then
        return nil
    end

    local exactLink = rawQuery:match("(\124c%x+\124Hitem:[^\124]+\124h%[[^%]]+%]\124h\124r)")
    if exactLink and exactLink ~= "" then
        return exactLink
    end

    for bagIndex = 0, 4 do
        local slotCount = getBagSlotCount(bagIndex)
        for slotIndex = 1, slotCount do
            local itemLink = getBagItemLink(bagIndex, slotIndex)
            if itemLink and itemLink ~= "" then
                local itemName = GetItemInfo(itemLink)
                local searchHaystack = string.lower(trimText(itemName or itemLink))
                if string.find(searchHaystack, query, 1, true) then
                    return itemLink
                end
            end
        end
    end

    return nil
end

function addon:StartAuctionFromInventory(minBid, searchText, duration)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can start auctions.")
        return false
    end

    local itemLink = self:FindInventoryItemLink(searchText)
    if not itemLink then
        self:Print("No matching inventory item found. Use part of the item name or paste an item link.")
        return false
    end

    local hadAuction = self.activeAuction ~= nil
    self:StartAuction(minBid, itemLink, duration)
    return (not hadAuction) and self.activeAuction ~= nil
end

function addon:SubmitAuctionBid()
    if not self.ui.initialized or not self.activeAuction then
        return
    end

    local bidAmount = safeNumber(self.ui.auctionFrame.bidInput:GetText(), nil)
    if not bidAmount then
        self.ui.auctionFrame.statusText:SetText("Enter a valid number.")
        return
    end

    if self:RegisterBid(self:GetPlayerName(), bidAmount, false) then
        self.ui.auctionFrame.statusText:SetText(string.format("Submitted %d DKP.", bidAmount))
    else
        self.ui.auctionFrame.statusText:SetText("Bid rejected. Check your DKP and the minimum bid.")
    end
end

function addon:AnnounceAuctionStartToGroup(itemLink, minBid, duration, lootMasterName)
    local channel = self:GetGroupChatChannel()
    if not channel or not SendChatMessage then
        return
    end

    local itemText = trimText(itemLink)
    local lootMaster = self:NormalizeName(lootMasterName) or self:GetPlayerName() or "LootMaster"
    local minimum = math.floor(safeNumber(minBid, 0) + 0.5)
    local seconds = math.floor(safeNumber(duration, 0) + 0.5)
    local sampleBid = minimum > 0 and minimum or 1

    SendChatMessage(string.format("[MapleDKP] Up for bid: %s | Min %d DKP | Time limit: %ds", itemText, minimum, seconds), channel)
    SendChatMessage("[MapleDKP] Bidding starts now.", channel)
    SendChatMessage(string.format("[MapleDKP] No addon? Whisper %s: bid <amount>", lootMaster), channel)
    SendChatMessage(string.format("[MapleDKP] Example: /w %s bid %d", lootMaster, sampleBid), channel)
end

function addon:HandleWhisperBid(message, sender)
    if not self.activeAuction or self.activeAuction.startedBy ~= self:GetPlayerName() then
        return
    end

    local bidder = self:NormalizeName(sender)
    if not bidder then
        return
    end

    local input = string.lower(trimText(message))
    local amountText = input:match("^!?bid%s+([%-]?%d+)$")
    if not amountText then
        return
    end

    local amount = math.floor(safeNumber(amountText, 0) + 0.5)
    local accepted = self:RegisterBid(bidder, amount, true, self.activeAuction.id)
    if not SendChatMessage then
        return
    end

    if accepted then
        SendChatMessage(string.format("[MapleDKP] Bid accepted: %d on %s.", amount, self.activeAuction.item), "WHISPER", nil, bidder)
    else
        SendChatMessage(string.format("[MapleDKP] Bid not accepted. Minimum is %d.", self.activeAuction.minBid), "WHISPER", nil, bidder)
    end
end

function addon:StartAuction(minBid, itemLink, duration)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can start auctions.")
        return
    end

    if self.activeAuction then
        self:Print("Finish the current auction before starting a new one.")
        return
    end

    minBid = math.floor(safeNumber(minBid, 0) + 0.5)
    itemLink = trimText(itemLink)

    if itemLink ~= "" and not string.find(itemLink, "|Hitem:", 1, true) then
        local resolvedItemLink = self:FindInventoryItemLink(itemLink)
        if resolvedItemLink and resolvedItemLink ~= "" then
            itemLink = resolvedItemLink
        end
    end

    duration = math.floor(safeNumber(duration, self.auctionDuration) + 0.5)
    if duration < 5 then
        duration = 5
    end

    if minBid < 0 or itemLink == "" then
        self:Print("Usage: /mdkp auction start MinimumBid ItemLinkOrName")
        return
    end

    local auctionId = self:MakeTransactionId("AUC", itemLink)
    self.activeAuction = {
        id = auctionId,
        item = itemLink,
        minBid = minBid,
        bids = {},
        startedBy = self:GetPlayerName(),
        startedAt = time(),
        duration = duration,
        expiresAt = GetTime() + duration,
        tenSecondWarningSent = false,
    }

    self.lastAuctionResult = nil
    self.ui.auctionPopupDismissed = false
    self:RemoveRecentLoot(itemLink)
    self:EnsureUI()
    self:RefreshLeaderUI()
    self:RefreshAuctionPopup()
    self:RefreshLootNotice()
    local startMessage = table.concat({ "AUC", "START", auctionId, self:GetPlayerName(), tostring(minBid), itemLink, tostring(duration) }, "\t")
    self:BroadcastGroupMessage(startMessage)
    self:AnnounceAuctionStartToGroup(itemLink, minBid, duration, self:GetPlayerName())
    self:Print(string.format("Auction started for %s. Minimum bid: %d. %d seconds remaining.", itemLink, minBid, duration))
end

function addon:RegisterBid(bidder, amount, remote, auctionId)
    bidder = self:NormalizeName(bidder)
    amount = math.floor(safeNumber(amount, 0) + 0.5)

    if not self.activeAuction then
        if not remote then
            self:Print("There is no active auction.")
        end
        return false
    end

    if auctionId and self.activeAuction.id ~= auctionId then
        return false
    end

    if remote and self.activeAuction.startedBy ~= self:GetPlayerName() then
        return false
    end

    if not bidder or amount < self.activeAuction.minBid then
        if not remote then
            self:Print("Bid is below the current minimum.")
        end
        return false
    end

    self:TryAutoSeedDefaultDkp(bidder)

    if self:GetPlayerDKP(bidder) < amount then
        if not remote then
            self:Print("You cannot bid more DKP than you currently have.")
        end
        return false
    end

    local currentBid = self.activeAuction.bids[bidder]
    if currentBid and currentBid >= amount then
        if not remote then
            self:Print("Your new bid must be higher than your current bid.")
        end
        return false
    end

    self.activeAuction.bids[bidder] = amount

    self:EnsureUI()
    self:RefreshLeaderUI()
    self:RefreshAuctionPopup()

    if not remote then
        local bidMessage = table.concat({ "AUC", "BID", self.activeAuction.id, bidder, tostring(amount) }, "\t")
        if self.activeAuction.startedBy ~= self:GetPlayerName() then
            self:SendMessage(bidMessage, "WHISPER", self.activeAuction.startedBy)
        end
        self:Print(string.format("Bid submitted: %d on %s.", amount, self.activeAuction.item))
    end

    return true
end

function addon:GetWinningBid(preferredWinner)
    if not self.activeAuction then
        return nil, nil
    end

    if preferredWinner then
        local preferredAmount = self.activeAuction.bids[preferredWinner]
        if preferredAmount then
            return preferredWinner, preferredAmount
        end
    end

    local winningName
    local winningBid = -1

    for bidder, amount in pairs(self.activeAuction.bids) do
        if amount > winningBid or (amount == winningBid and bidder < winningName) then
            winningName = bidder
            winningBid = amount
        end
    end

    if not winningName then
        return nil, nil
    end

    return winningName, winningBid
end

function addon:GetAuctionBidAnnouncementLines(bids)
    local orderedBids = {}
    for bidder, amount in pairs(bids or {}) do
        orderedBids[#orderedBids + 1] = {
            bidder = bidder,
            amount = math.floor(safeNumber(amount, 0) + 0.5),
        }
    end

    if #orderedBids == 0 then
        return {}
    end

    table.sort(orderedBids, function(left, right)
        if left.amount == right.amount then
            return left.bidder < right.bidder
        end
        return left.amount > right.amount
    end)

    local lines = {}
    local currentLine = "Bids:"

    for _, bid in ipairs(orderedBids) do
        local entry = string.format("%s %d", bid.bidder, bid.amount)
        local separator = (currentLine == "Bids:") and " " or ", "
        local nextLine = currentLine .. separator .. entry

        if string.len(nextLine) > 230 then
            lines[#lines + 1] = currentLine
            currentLine = "Bids cont: " .. entry
        else
            currentLine = nextLine
        end
    end

    lines[#lines + 1] = currentLine
    return lines
end

function addon:CloseAuction(preferredWinner)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can close auctions.")
        return
    end

    if not self.activeAuction then
        self:Print("There is no active auction.")
        return
    end

    preferredWinner = preferredWinner and self:NormalizeName(preferredWinner) or nil
    local winner, amount = self:GetWinningBid(preferredWinner)
    local isFreeAssignment = false

    if preferredWinner and not winner then
        winner = preferredWinner
        amount = 0
        isFreeAssignment = true
    end

    local auctionId = self.activeAuction.id
    local item = self.activeAuction.item
    local closingBids = shallowCopy(self.activeAuction.bids or {})
    local closedBy = self:GetPlayerName()
    self.activeAuction = nil
    self:EnsureUI()
    self:AnnounceGroupChat(string.format("Bidding has stopped for %s.", item))

    if not winner then
        self.lastAuctionResult = string.format("No bids were submitted for %s.", item)
        self:AppendHistory(string.format("Auction closed by %s: no winner for %s", closedBy or "unknown", item))
        self:AppendActivity({
            type = "AUCTION_CLOSE",
            actor = closedBy,
            auctionId = auctionId,
            item = item,
            outcome = "no_winner",
        })
        local closeMessage = table.concat({ "AUC", "CLOSE", auctionId, self:GetPlayerName(), "", "0", item }, "\t")
        self:BroadcastGroupMessage(closeMessage)
        self:AnnounceGroupChat(string.format("No valid bids received for %s.", item))
        self:RefreshLeaderUI()
        self:RefreshAuctionPopup()
        self:Print("Auction closed with no bids.")
        return
    end

    if amount <= 0 then
        self.lastAuctionResult = string.format("%s was assigned %s for free.", winner, item)
        self:AppendHistory(string.format("Auction closed by %s: %s assigned %s for free", closedBy or "unknown", winner, item))
        self:AppendActivity({
            type = "AUCTION_CLOSE",
            actor = closedBy,
            auctionId = auctionId,
            winner = winner,
            winningBid = 0,
            item = item,
            outcome = "free",
        })
        self:Print(string.format("%s was assigned %s for free.", winner, item))
        if isFreeAssignment then
            self:Print(string.format("No bids received. Assign %s to %s for disenchant/free roll.", item, winner))
        else
            self:Print(string.format("Assign %s to %s in the loot window.", item, winner))
        end

        local closeMessage = table.concat({ "AUC", "CLOSE", auctionId, self:GetPlayerName(), winner, "0", item }, "\t")
        self:BroadcastGroupMessage(closeMessage)
        self:AnnounceGroupChat(string.format("Winner: %s won %s for free.", winner, item))
        for _, line in ipairs(self:GetAuctionBidAnnouncementLines(closingBids)) do
            self:AnnounceGroupChat(line)
        end
        self:RefreshLeaderUI()
        self:RefreshAuctionPopup()
        return
    end

    local settlementTxId = table.concat({ "AUCSETTLE", auctionId }, ":")
    local newValue = self:GetPlayerDKP(winner) - amount
    local applied = self:ApplyPlayerTransaction(winner, -amount, newValue, "Won " .. item, settlementTxId, self:GetPlayerName(), true)

    if applied then
        self:BroadcastPlayerUpdate(winner, -amount, newValue, "Won " .. item, settlementTxId, self:GetPlayerName())
        self.lastAuctionResult = string.format("%s won %s for %d DKP.", winner, item, amount)
        self:AppendHistory(string.format("Auction closed by %s: %s won %s for %d DKP", closedBy or "unknown", winner, item, amount))
        self:AppendActivity({
            type = "AUCTION_CLOSE",
            actor = closedBy,
            auctionId = auctionId,
            winner = winner,
            winningBid = amount,
            item = item,
            outcome = "paid",
        })
        self:Print(string.format("%s won %s for %d DKP.", winner, item, amount))
        self:Print(string.format("Assign %s to %s in the loot window.", item, winner))
    else
        self.lastAuctionResult = string.format("Auction already settled for %s.", item)
        self:Print(string.format("Auction settlement for %s was already applied.", item))
    end

    local closeMessage = table.concat({ "AUC", "CLOSE", auctionId, self:GetPlayerName(), winner, tostring(amount), item }, "\t")
    self:BroadcastGroupMessage(closeMessage)
    if applied then
        self:AnnounceGroupChat(string.format("Winner: %s won %s for %d DKP.", winner, item, amount))
        for _, line in ipairs(self:GetAuctionBidAnnouncementLines(closingBids)) do
            self:AnnounceGroupChat(line)
        end
    end
    self:RefreshLeaderUI()
    self:RefreshAuctionPopup()
end

function addon:ShowAuctionStatus()
    if not self.activeAuction then
        self:Print("There is no active auction.")
        return
    end

    self:Print(string.format("Auction: %s (minimum %d)", self.activeAuction.item, self.activeAuction.minBid))
    local winner, amount = self:GetWinningBid()
    if winner and amount then
        self:Print(string.format("Current high bid: %s with %d", winner, amount))
    else
        self:Print("No bids yet.")
    end
end
