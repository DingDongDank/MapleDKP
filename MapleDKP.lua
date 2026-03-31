local addonName = ...

local addon = CreateFrame("Frame")
MapleDKP = addon

-- Temporary test harness toggle. Keep ON while validating workflows without real raids.
-- Set to false when moving to in-depth live validation.
local TEST_MODE = false

addon.prefix = "MapleDKP"
addon.playerName = nil
addon.guildName = nil
addon.db = nil
addon.guild = nil
addon.activeAuction = nil
addon.pendingSnapshot = nil
addon.recentBossKills = {}
addon.pendingBossAwards = {}
addon.recentLoot = {}
addon.auctionDuration = 30
addon.lastAuctionResult = nil
addon.lastSyncRequestAt = 0
addon.ui = {
    initialized = false,
}

local staticData = MapleDKPStaticData or {}

local DEFAULT_NEW_MEMBER_DKP = tonumber(staticData.defaultNewMemberDkp) or 180
local ACTIVE_RAIDER_WINDOW_SECONDS = tonumber(staticData.activeRaiderWindowSeconds) or (30 * 24 * 60 * 60)
local DEFAULT_BOSSES = staticData.defaultBosses or {}

addon.DEFAULT_BOSSES = DEFAULT_BOSSES

local BOSS_SCHEMA_VERSION = tonumber(staticData.bossSchemaVersion) or 3
local ZONE_SORT_ORDER = staticData.zoneSortOrder or {}
local CLASS_NAME_TO_TOKEN = staticData.classNameToToken or {}
local CLASS_COLOR_HEX = staticData.classColorHex or {}

local function trim(value)
    if not value then
        return ""
    end

    value = tostring(value)
    value = value:gsub("[\r\n\t]", " ")
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function splitMessage(message)
    local parts = {}

    if message == nil then
        return parts
    end

    local startIndex = 1
    while true do
        local separatorIndex = string.find(message, "\t", startIndex, true)
        if not separatorIndex then
            parts[#parts + 1] = string.sub(message, startIndex)
            break
        end

        parts[#parts + 1] = string.sub(message, startIndex, separatorIndex - 1)
        startIndex = separatorIndex + 1

        if startIndex > (#message + 1) then
            parts[#parts + 1] = ""
            break
        end
    end

    return parts
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

local function formatSeconds(seconds)
    seconds = math.max(0, math.ceil(safeNumber(seconds, 0)))
    local minutes = math.floor(seconds / 60)
    local remainder = seconds % 60

    if minutes > 0 then
        return string.format("%d:%02d", minutes, remainder)
    end

    return string.format("%ds", remainder)
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

local function getRaidMemberCount()
    if not IsInRaid or not IsInRaid() then
        return 0
    end

    if GetNumGroupMembers then
        return GetNumGroupMembers() or 0
    end

    if GetNumRaidMembers then
        return GetNumRaidMembers() or 0
    end

    return 0
end

local function getPartyMemberCount()
    if GetNumSubgroupMembers then
        return GetNumSubgroupMembers() or 0
    end

    if GetNumPartyMembers then
        return GetNumPartyMembers() or 0
    end

    return 0
end

local function isPlayerInCurrentGroup(addonRef, playerName)
    local normalized = addonRef and addonRef.NormalizeName and addonRef:NormalizeName(playerName)
    if not normalized then
        return false
    end

    local raidMemberCount = getRaidMemberCount()
    if raidMemberCount > 0 then
        for index = 1, raidMemberCount do
            if addonRef:NormalizeName(UnitName("raid" .. index)) == normalized then
                return true
            end
        end
        return false
    end

    local partyMemberCount = getPartyMemberCount()
    if partyMemberCount > 0 then
        if addonRef:NormalizeName(UnitName("player")) == normalized then
            return true
        end
        for index = 1, partyMemberCount do
            if addonRef:NormalizeName(UnitName("party" .. index)) == normalized then
                return true
            end
        end
        return false
    end

    return false
end


function addon:AddRaider(targetName)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can add raiders.")
        return false
    end

    if not self.guild then
        return false
    end

    local name = self:NormalizeName(targetName)
    if not name then
        return false
    end

    if not self:IsGuildRosterMember(name) then
        self:Print(string.format("%s is not currently in guild roster.", name))
        return false
    end

    self:EnsurePlayer(name)
    local currentDkp = self:GetPlayerDKP(name)
    if currentDkp == 0 then
        local averageDkp, sourceCount = self:GetAverageActiveRaiderDkp(name)
        if averageDkp > 0 and sourceCount > 0 then
            local txId = self:MakeTransactionId("RAIDERSEED", name)
            if self:ApplyPlayerTransaction(name, averageDkp, averageDkp, "Active raider baseline", txId, self:GetPlayerName(), true) then
                self:BroadcastPlayerUpdate(name, averageDkp, averageDkp, "Active raider baseline", txId, self:GetPlayerName())
            end
        end
    end

    local transaction = self:BuildConfigTransaction("addraider", name, 1, "", "", 0, "Added to active raiders", self:MakeTransactionId("CFGADDRAIDER", name), self:GetPlayerName(), time())
    if self:ApplyConfigTransactionRecord(transaction, true, false) then
        self:BroadcastConfigTransactionRecord(transaction)
        self:SendMessage(table.concat({ "CFG", "ADDRAIDER", trim(transaction.txId), name }, "\t"))
        self:Print(string.format("Added %s to the raider list.", name))
        return true
    end

    return false
end

function addon:RemoveRaider(targetName)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can remove raiders.")
        return false
    end

    if not self.guild then
        return false
    end

    local name = self:NormalizeName(targetName)
    if not name then
        self:Print("Select a player to remove from active raiders.")
        return false
    end

    if not self.guild.players or not self.guild.players[name] then
        self:Print(string.format("%s is not in the DKP roster.", name))
        return false
    end

    local transaction = self:BuildConfigTransaction("remraider", name, 0, "", "", 0, "Removed from active raiders", self:MakeTransactionId("CFGREMRAIDER", name), self:GetPlayerName(), time())
    if self:ApplyConfigTransactionRecord(transaction, true, false) then
        self:BroadcastConfigTransactionRecord(transaction)
        self:SendMessage(table.concat({ "CFG", "REMRAIDER", trim(transaction.txId), name }, "\t"))
        self:Print(string.format("Removed %s from the active raider list.", name))
        return true
    end

    return false
end

function addon:RefreshAddRaiderPopup()
    if not self.ui or not self.ui.initialized or not self.ui.addRaiderFrame then
        return
    end

    local frame = self.ui.addRaiderFrame
    if not frame:IsShown() then
        return
    end

    local allEntries = self:GetSortedGuildRosterEntries()
    local query = string.lower(trim(frame.searchQuery or ""))
    local entries = {}
    if query == "" then
        entries = allEntries
    else
        for _, entry in ipairs(allEntries) do
            if string.find(string.lower(entry.name), query, 1, true) then
                entries[#entries + 1] = entry
            end
        end
    end
    local maxOffset = math.max(0, #entries - #frame.rows)
    local offset = math.min(frame.scrollOffset or 0, maxOffset)
    frame.scrollOffset = offset

    if frame.scrollBar then
        frame.scrollBar:SetMinMaxValues(0, maxOffset)
        frame.scrollBar:SetValue(offset)
        if maxOffset > 0 then
            frame.scrollBar:Show()
        else
            frame.scrollBar:Hide()
        end
    end

    for index, button in ipairs(frame.rows) do
        local entry = entries[offset + index]
        if entry then
            button.entryName = entry.name
            if entry.active then
                button.text:SetText(string.format("%s |cFF88FF88(Active)|r", entry.name))
            else
                button.text:SetText(entry.name)
            end
            button:Show()
            button:Enable()
        else
            button.entryName = nil
            button.text:SetText("")
            button:Hide()
        end
    end

    local activeCount = 0
    for _, entry in ipairs(allEntries) do
        if entry.active then
            activeCount = activeCount + 1
        end
    end

    if frame.summaryText then
        if query == "" then
            frame.summaryText:SetText(string.format("Guild members: %d | Active raiders: %d", #allEntries, activeCount))
        else
            frame.summaryText:SetText(string.format("Guild members: %d | Active raiders: %d | Matches: %d", #allEntries, activeCount, #entries))
        end
    end
end

function addon:ShowAddRaiderPopup()
    self:EnsureUI()
    self:SyncGuildRoster()
    if self.ui.addRaiderFrame and self.ui.addRaiderFrame.searchInput then
        self.ui.addRaiderFrame.searchQuery = ""
        self.ui.addRaiderFrame.searchInput:SetText("")
    end
    self.ui.addRaiderFrame:Show()
    self.ui.addRaiderFrame:Raise()
    self:RefreshAddRaiderPopup()
end

function addon:DeletePlayerRecord(targetName)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can delete players.")
        return false
    end

    if not self.guild then
        return false
    end

    local name = self:NormalizeName(targetName)
    if not name then
        self:Print("Select a player to delete.")
        return false
    end

    if not self.guild.players or not self.guild.players[name] then
        self:Print(string.format("%s is not in the DKP roster.", name))
        return false
    end

    local currentValue = self:GetPlayerDKP(name)
    local transaction = self:BuildPlayerTransaction("delete", name, 0, 0, "Manual delete", self:MakeTransactionId("DELETE", name), self:GetPlayerName(), currentValue, time())
    if self:ApplyTransactionRecord(transaction, true, false) then
        self:BroadcastTransactionRecord(transaction)
        self:Print(string.format("Deleted player record for %s.", name))
        return true
    end

    return false
end

function addon:EnsureUI()
    if self.ui.initialized then
        return
    end

    local controlFrame = self:CreatePanel("MapleDKPControlFrame", 430, 460, "Maple DKP Loot Control")
    controlFrame:SetPoint("CENTER", UIParent, "CENTER", -250, 30)
    controlFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    controlFrame.closeButton:SetScript("OnClick", function()
        controlFrame:Hide()
    end)

    local minBidLabel = controlFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minBidLabel:SetPoint("TOPLEFT", 14, -38)
    minBidLabel:SetText("Min Bid")

    controlFrame.minBidInput = self:CreateInput(controlFrame, 50, 24, "LEFT", minBidLabel, "RIGHT", 8, 0, true)
    controlFrame.minBidInput:SetMaxLetters(5)
    controlFrame.minBidInput:SetText("10")

    local durationLabel = controlFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    durationLabel:SetPoint("LEFT", controlFrame.minBidInput, "RIGHT", 18, 0)
    durationLabel:SetText("Seconds")

    controlFrame.durationInput = self:CreateInput(controlFrame, 50, 24, "LEFT", durationLabel, "RIGHT", 8, 0, true)
    controlFrame.durationInput:SetMaxLetters(3)
    controlFrame.durationInput:SetText(tostring(self.auctionDuration))

    controlFrame.trackingStatusText = self:CreateRowText(controlFrame, "GameFontHighlightSmall", 170, "TOPRIGHT", -18, -40)
    controlFrame.trackingStatusText:SetJustifyH("RIGHT")
    controlFrame.trackingStatusText:SetText("")

    controlFrame.lootHeader = controlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controlFrame.lootHeader:SetPoint("TOPLEFT", 14, -70)
    controlFrame.lootHeader:SetText("Recent Loot")

    controlFrame.lootRows = {}
    for index = 1, 6 do
        local rowText = self:CreateRowText(controlFrame, "GameFontHighlightSmall", 250, "TOPLEFT", 14, -76 - (index * 26))
        local rowButton = CreateFrame("Button", nil, controlFrame, "UIPanelButtonTemplate")
        rowButton:SetSize(85, 22)
        rowButton:SetPoint("LEFT", rowText, "RIGHT", 8, 0)
        rowButton:SetText("Auction")
        rowButton:Disable()
        rowButton:SetScript("OnClick", function(button)
            addon:StartAuction(addon:GetConfiguredMinBid(), button.itemLink, addon:GetConfiguredDuration())
        end)
        controlFrame.lootRows[index] = {
            text = rowText,
            button = rowButton,
        }
    end

    controlFrame.auctionHeader = controlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controlFrame.auctionHeader:SetPoint("TOPLEFT", 14, -244)
    controlFrame.auctionHeader:SetText("Active Auction")

    controlFrame.auctionItemText = self:CreateRowText(controlFrame, "GameFontHighlight", 395, "TOPLEFT", 14, -266)
    controlFrame.auctionMetaText = self:CreateRowText(controlFrame, "GameFontHighlightSmall", 280, "TOPLEFT", 14, -286)
    controlFrame.auctionResultText = self:CreateRowText(controlFrame, "GameFontHighlightSmall", 395, "TOPLEFT", 14, -306)

    controlFrame.closeAuctionButton = CreateFrame("Button", nil, controlFrame, "UIPanelButtonTemplate")
    controlFrame.closeAuctionButton:SetSize(95, 22)
    controlFrame.closeAuctionButton:SetPoint("TOPRIGHT", -18, -262)
    controlFrame.closeAuctionButton:SetText("Close Now")
    controlFrame.closeAuctionButton:Disable()
    controlFrame.closeAuctionButton:SetScript("OnClick", function()
        addon:CloseAuction()
    end)

    controlFrame.bidHeader = controlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controlFrame.bidHeader:SetPoint("TOPLEFT", 14, -326)
    controlFrame.bidHeader:SetText("Bids")

    controlFrame.bidRows = {}
    for index = 1, 6 do
        local bidText = self:CreateRowText(controlFrame, "GameFontHighlightSmall", 395, "TOPLEFT", 14, -330 - (index * 16))
        controlFrame.bidRows[index] = bidText
    end

    local auctionFrame = self:CreatePanel("MapleDKPAuctionFrame", 320, 205, "Maple DKP Auction")
    auctionFrame:SetPoint("CENTER", UIParent, "CENTER", 180, 120)
    auctionFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    auctionFrame.closeButton:SetScript("OnClick", function()
        addon.ui.auctionPopupDismissed = true
        auctionFrame:Hide()
        if addon.ui.raidDkpFrame then
            addon.ui.raidDkpFrame:Hide()
        end
    end)
    auctionFrame.itemText = self:CreateRowText(auctionFrame, "GameFontHighlight", 280, "TOPLEFT", 16, -42)
    auctionFrame.minBidText = self:CreateRowText(auctionFrame, "GameFontHighlightSmall", 280, "TOPLEFT", 16, -72)
    auctionFrame.timerText = self:CreateRowText(auctionFrame, "GameFontHighlightSmall", 280, "TOPLEFT", 16, -92)
    auctionFrame.dkpText = self:CreateRowText(auctionFrame, "GameFontHighlightSmall", 280, "TOPLEFT", 16, -112)

    local bidLabel = auctionFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bidLabel:SetPoint("TOPLEFT", 16, -140)
    bidLabel:SetText("Your Bid")

    auctionFrame.bidInput = self:CreateInput(auctionFrame, 70, 24, "LEFT", bidLabel, "RIGHT", 8, 0, true)
    auctionFrame.bidInput:SetMaxLetters(6)
    auctionFrame.bidInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addon:SubmitAuctionBid()
    end)

    auctionFrame.submitButton = CreateFrame("Button", nil, auctionFrame, "UIPanelButtonTemplate")
    auctionFrame.submitButton:SetSize(90, 22)
    auctionFrame.submitButton:SetPoint("LEFT", auctionFrame.bidInput, "RIGHT", 10, 0)
    auctionFrame.submitButton:SetText("Submit")
    auctionFrame.submitButton:SetScript("OnClick", function()
        addon:SubmitAuctionBid()
    end)

    auctionFrame.statusText = self:CreateRowText(auctionFrame, "GameFontHighlightSmall", 280, "TOPLEFT", 16, -172)

    auctionFrame.raidListButton = self:CreateButton(auctionFrame, "Raid DKP", 90, 22, "TOPRIGHT", auctionFrame, "TOPRIGHT", -16, -170, function()
        addon:ToggleRaidDkpPopup()
    end)

    local raidDkpFrame = self:CreatePanel("MapleDKPRaidDkpFrame", 320, 560, "Raid DKP")
    raidDkpFrame:SetPoint("LEFT", auctionFrame, "RIGHT", 12, 0)
    raidDkpFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    raidDkpFrame.subtitle = self:CreateRowText(raidDkpFrame, "GameFontHighlightSmall", 280, "TOPLEFT", 16, -40)
    raidDkpFrame.subtitle:SetText("")
    raidDkpFrame.rows = {}
    for index = 1, 25 do
        raidDkpFrame.rows[index] = self:CreateRowText(raidDkpFrame, "GameFontHighlightSmall", 280, "TOPLEFT", 16, -40 - (index * 20))
    end

    local noticeFrame = self:CreatePanel("MapleDKPLootNoticeFrame", 300, 170, "Boss Loot")
    noticeFrame:SetPoint("TOP", UIParent, "TOP", 0, -160)
    noticeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    noticeFrame.closeButton:SetScript("OnClick", function()
        addon.ui.noticeExpireAt = nil
        noticeFrame:Hide()
    end)
    noticeFrame.rows = {}
    for index = 1, 5 do
        noticeFrame.rows[index] = self:CreateRowText(noticeFrame, "GameFontHighlightSmall", 260, "TOPLEFT", 16, -40 - ((index - 1) * 24))
    end

    local historyFrame = self:CreatePanel("MapleDKPHistoryFrame", 800, 700, "DKP History")
    historyFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    historyFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    historyFrame.closeButton:SetScript("OnClick", function()
        historyFrame:Hide()
    end)

    historyFrame.scrollOffset = 0
    historyFrame.scrollBar = self:CreateVerticalSlider(historyFrame, 750, "TOPRIGHT", historyFrame, "TOPRIGHT", 0, -42, function(value)
        historyFrame.scrollOffset = value
        addon:RefreshHistoryFrame()
    end)
    self:EnableMouseWheelScroll(historyFrame, historyFrame.scrollBar)

    historyFrame.summaryText = self:CreateRowText(historyFrame, "GameFontHighlightSmall", 750, "TOPLEFT", 16, -40)
    historyFrame.summaryText:SetText("")
    historyFrame.topHintText = self:CreateRowText(historyFrame, "GameFontHighlightSmall", 220, "TOPRIGHT", -28, -40)
    historyFrame.topHintText:SetJustifyH("RIGHT")
    historyFrame.bottomHintText = self:CreateRowText(historyFrame, "GameFontHighlightSmall", 220, "BOTTOMRIGHT", -28, 16)
    historyFrame.bottomHintText:SetJustifyH("RIGHT")

    historyFrame.historyRows = {}
    for index = 1, 24 do
        historyFrame.historyRows[index] = self:CreateRowText(historyFrame, "GameFontHighlightSmall", 750, "TOPLEFT", 16, -60 - ((index - 1) * 20))
    end

    local optionsFrame = self:CreatePanel("MapleDKPOptionsFrame", 700, 650, "Maple DKP Options")
    optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 40, 20)
    optionsFrame:SetFrameStrata("DIALOG")

    optionsFrame.officerLabel = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    optionsFrame.officerLabel:SetPoint("TOPRIGHT", -36, -11)
    optionsFrame.officerLabel:SetText("")

    optionsFrame.statusText = self:CreateRowText(optionsFrame, "GameFontHighlightSmall", 630, "BOTTOMLEFT", 16, 20)
    optionsFrame.statusText:SetText("Select a tab to manage DKP, bosses, and auctions.")

    optionsFrame.tabButtons = {}
    optionsFrame.pages = {}

    local tabNames = {
        { key = "members", label = "Members", x = 16 },
        { key = "actions", label = "Actions", x = 118 },
        { key = "bosses", label = "Bosses", x = 220 },
        { key = "auction", label = "Auction", x = 322 },
        { key = "conflicts", label = "Conflicts", x = 424 },
    }

    for _, tab in ipairs(tabNames) do
        optionsFrame.tabButtons[tab.key] = self:CreateButton(optionsFrame, tab.label, 92, 22, "TOPLEFT", optionsFrame, "TOPLEFT", tab.x, -36, function()
            addon:SetOptionsTab(tab.key)
        end)
    end

    local function createPage()
        local page = CreateFrame("Frame", nil, optionsFrame)
        page:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 16, -68)
        page:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 42)
        page:Hide()
        return page
    end

    local membersPage = createPage()
    membersPage.quietStatusText = self:CreateRowText(membersPage, "GameFontHighlightSmall", 180, "TOPLEFT", 0, -2)
    membersPage.toggleQuietButton = self:CreateButton(membersPage, "Enable Quiet", 100, 22, "TOPRIGHT", membersPage, "TOPRIGHT", 0, -2, function()
        addon:SetQuietMode(not addon:IsQuietMode())
        addon:SetOptionsStatus(addon:IsQuietMode() and "Quiet mode enabled." or "Quiet mode disabled.")
        addon:RefreshOptionsUI()
    end)
    membersPage.summaryText = self:CreateRowText(membersPage, "GameFontHighlightSmall", 400, "TOPLEFT", 0, -26)
    membersPage.selectedText = self:CreateRowText(membersPage, "GameFontHighlightSmall", 420, "TOPLEFT", 0, -44)
    membersPage.addRaiderButton = self:CreateButton(membersPage, "Add Raider", 100, 22, "RIGHT", membersPage.toggleQuietButton, "LEFT", -8, 0, function()
        addon:ShowAddRaiderPopup()
    end)
    membersPage.removeRaiderButton = self:CreateButton(membersPage, "Remove Raider", 112, 22, "RIGHT", membersPage.addRaiderButton, "LEFT", -6, 0, function()
        local targetName = addon.ui.optionsSelectedMember
        if addon:RemoveRaider(targetName) then
            addon:SetOptionsStatus("Removed player from active raiders.")
        else
            addon:SetOptionsStatus("Could not remove player from active raiders.")
        end
        addon:RefreshOptionsUI()
    end)
    membersPage.removeRaiderButton:Disable()
    membersPage.sortMode = "name"
    membersPage.classSecondaryByDkp = false
    membersPage.sortByDkpButton = self:CreateButton(membersPage, "DKP", 68, 20, "TOPRIGHT", membersPage, "TOPRIGHT", -20, -24, function()
        membersPage.sortMode = "dkp"
        membersPage.scrollOffset = 0
        addon:RefreshOptionsMembersPage()
    end)
    membersPage.sortBySpentButton = self:CreateButton(membersPage, "Spent", 68, 20, "RIGHT", membersPage.sortByDkpButton, "LEFT", -4, 0, function()
        membersPage.sortMode = "spent"
        membersPage.scrollOffset = 0
        addon:RefreshOptionsMembersPage()
    end)
    membersPage.sortByEarnedButton = self:CreateButton(membersPage, "Earned", 68, 20, "RIGHT", membersPage.sortBySpentButton, "LEFT", -4, 0, function()
        membersPage.sortMode = "earned"
        membersPage.scrollOffset = 0
        addon:RefreshOptionsMembersPage()
    end)
    membersPage.sortByNameButton = self:CreateButton(membersPage, "Name", 68, 20, "RIGHT", membersPage.sortByDkpButton, "LEFT", -4, 0, function()
        membersPage.sortMode = "name"
        membersPage.scrollOffset = 0
        addon:RefreshOptionsMembersPage()
    end)
    membersPage.sortByClassButton = self:CreateButton(membersPage, "Class", 68, 20, "RIGHT", membersPage.sortByNameButton, "LEFT", -4, 0, function()
        membersPage.classSecondaryByDkp = (membersPage.sortMode == "dkp")
        membersPage.sortMode = "class"
        membersPage.scrollOffset = 0
        addon:RefreshOptionsMembersPage()
    end)
    membersPage.sortByNameButton:ClearAllPoints()
    membersPage.sortByNameButton:SetPoint("RIGHT", membersPage.sortByEarnedButton, "LEFT", -4, 0)
    membersPage.summaryText:ClearAllPoints()
    membersPage.summaryText:SetPoint("TOPLEFT", membersPage, "TOPLEFT", 0, -26)
    membersPage.summaryText:SetPoint("RIGHT", membersPage.sortByClassButton, "LEFT", -8, 0)
    membersPage.summaryText:SetJustifyH("LEFT")
    membersPage.scrollOffset = 0
    membersPage.columns = 3
    membersPage.rowsPerColumn = 16
    membersPage.scrollBar = self:CreateVerticalSlider(membersPage, 370, "TOPRIGHT", membersPage, "TOPRIGHT", -2, -70, function(value)
        membersPage.scrollOffset = value
        addon:RefreshOptionsMembersPage()
    end)

    membersPage.columnHeaders = {}
    membersPage.memberButtons = {}
    local memberColumnWidth = 208
    local memberColumnGap = 6
    local memberDkpWidth = 44
    local memberEarnedWidth = 44
    local memberSpentWidth = 44
    local memberValueGap = 4
    for columnIndex = 1, membersPage.columns do
        local offsetX = (columnIndex - 1) * (memberColumnWidth + memberColumnGap)
        local headerSpentX = offsetX + memberColumnWidth - 4 - memberSpentWidth
        local headerEarnedX = headerSpentX - memberValueGap - memberEarnedWidth
        local headerDkpX = headerEarnedX - memberValueGap - memberDkpWidth
        local headerNameWidth = math.max(48, headerDkpX - (offsetX + 8) - 6)
        local headerName = self:CreateRowText(membersPage, "GameFontNormalSmall", headerNameWidth, "TOPLEFT", offsetX + 8, -70)
        headerName:SetText("Name")
        local headerDkp = self:CreateRowText(membersPage, "GameFontNormalSmall", memberDkpWidth, "TOPLEFT", headerDkpX, -70)
        headerDkp:SetJustifyH("RIGHT")
        headerDkp:SetText("DKP")
        local headerEarned = self:CreateRowText(membersPage, "GameFontNormalSmall", memberEarnedWidth, "TOPLEFT", headerEarnedX, -70)
        headerEarned:SetJustifyH("RIGHT")
        headerEarned:SetText("Earn")
        local headerSpent = self:CreateRowText(membersPage, "GameFontNormalSmall", memberSpentWidth, "TOPLEFT", headerSpentX, -70)
        headerSpent:SetJustifyH("RIGHT")
        headerSpent:SetText("Spent")
        membersPage.columnHeaders[#membersPage.columnHeaders + 1] = headerName
        membersPage.columnHeaders[#membersPage.columnHeaders + 1] = headerDkp
        membersPage.columnHeaders[#membersPage.columnHeaders + 1] = headerEarned
        membersPage.columnHeaders[#membersPage.columnHeaders + 1] = headerSpent
    end

    for rowIndex = 1, membersPage.rowsPerColumn do
        for columnIndex = 1, membersPage.columns do
            local offsetX = (columnIndex - 1) * (memberColumnWidth + memberColumnGap)
            local button = self:CreateListButton(membersPage, memberColumnWidth, 18, "TOPLEFT", membersPage, "TOPLEFT", offsetX, -88 - ((rowIndex - 1) * 22), function(clickedButton)
                if clickedButton.entryName then
                    addon:SelectOptionsMember(clickedButton.entryName)
                    addon:RefreshOptionsMembersPage()
                end
            end)
            -- Shrink the name text so it doesn't overlap the DKP number on the right.
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", button, "LEFT", 4, 0)
            button.text:SetPoint("RIGHT", button, "RIGHT", -(memberDkpWidth + memberEarnedWidth + memberSpentWidth + (memberValueGap * 2) + 8), 0)
            -- Right-aligned DKP value label.
            button.dkpText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.dkpText:SetWidth(memberDkpWidth)
            button.dkpText:SetPoint("RIGHT", button, "RIGHT", -(memberEarnedWidth + memberSpentWidth + (memberValueGap * 2) + 4), 0)
            button.dkpText:SetJustifyH("RIGHT")
            button.earnedText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.earnedText:SetWidth(memberEarnedWidth)
            button.earnedText:SetPoint("RIGHT", button, "RIGHT", -(memberSpentWidth + memberValueGap + 4), 0)
            button.earnedText:SetJustifyH("RIGHT")
            button.spentText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.spentText:SetWidth(memberSpentWidth)
            button.spentText:SetPoint("RIGHT", button, "RIGHT", -4, 0)
            button.spentText:SetJustifyH("RIGHT")
            button.rowIndex = rowIndex
            button.columnIndex = columnIndex
            membersPage.memberButtons[#membersPage.memberButtons + 1] = button
        end
    end
    self:EnableMouseWheelScroll(membersPage, membersPage.scrollBar)

    -- Inline DKP editing controls
    membersPage.editDivider = membersPage:CreateTexture(nil, "BACKGROUND")
    membersPage.editDivider:SetColorTexture(0.5, 0.5, 0.5, 0.3)
    membersPage.editDivider:SetPoint("TOPLEFT", 0, -448)
    membersPage.editDivider:SetSize(660, 1)

    membersPage.editLabel = membersPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    membersPage.editLabel:SetPoint("TOPLEFT", 0, -461)
    membersPage.editLabel:SetText("Quick Edit")

    local editAmountLabel = membersPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editAmountLabel:SetPoint("TOPLEFT", 0, -483)
    editAmountLabel:SetText("Amount")
    membersPage.editAmountInput = self:CreateInput(membersPage, 70, 24, "LEFT", editAmountLabel, "RIGHT", 8, 0, true)
    membersPage.editAmountInput:SetMaxLetters(6)
    membersPage.editAmountInput:SetText("0")

    local editReasonLabel = membersPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editReasonLabel:SetPoint("LEFT", membersPage.editAmountInput, "RIGHT", 14, 0)
    editReasonLabel:SetText("Reason")
    membersPage.editReasonInput = self:CreateInput(membersPage, 250, 24, "LEFT", editReasonLabel, "RIGHT", 8, 0, false)
    membersPage.editReasonInput:SetMaxLetters(60)
    membersPage.editReasonInput:SetText("Quick adjustment")

    membersPage.editAddButton = self:CreateButton(membersPage, "Add", 70, 22, "LEFT", membersPage.editReasonInput, "RIGHT", 8, 0, function()
        if addon.ui.optionsSelectedMember then
            addon:AdjustPlayer(addon.ui.optionsSelectedMember, membersPage.editAmountInput:GetText(), trim(membersPage.editReasonInput:GetText()))
            addon:SetOptionsStatus("Applied DKP add adjustment.")
            addon:RefreshOptionsUI()
        end
    end)

    membersPage.editSubtractButton = self:CreateButton(membersPage, "Subtract", 70, 22, "LEFT", membersPage.editAddButton, "RIGHT", 8, 0, function()
        if addon.ui.optionsSelectedMember then
            local amount = math.abs(math.floor(safeNumber(membersPage.editAmountInput:GetText(), 0) + 0.5))
            addon:AdjustPlayer(addon.ui.optionsSelectedMember, -amount, trim(membersPage.editReasonInput:GetText()))
            addon:SetOptionsStatus("Applied DKP subtraction.")
            addon:RefreshOptionsUI()
        end
    end)

    membersPage.editSetButton = self:CreateButton(membersPage, "Set", 70, 22, "LEFT", membersPage.editSubtractButton, "RIGHT", 8, 0, function()
        if addon.ui.optionsSelectedMember then
            addon:SetPlayerDKP(addon.ui.optionsSelectedMember, membersPage.editAmountInput:GetText(), trim(membersPage.editReasonInput:GetText()))
            addon:SetOptionsStatus("Applied DKP set adjustment.")
            addon:RefreshOptionsUI()
        end
    end)

    membersPage.deleteButton = self:CreateButton(membersPage, "Delete", 80, 22, "TOPLEFT", membersPage, "TOPLEFT", 0, -510, function()
        local targetName = addon.ui.optionsSelectedMember
        if addon:DeletePlayerRecord(targetName) then
            addon:SetOptionsStatus("Deleted player record.")
        else
            addon:SetOptionsStatus("Could not delete player record.")
        end
        addon:RefreshOptionsUI()
    end)
    membersPage.deleteButton:Disable()

    local addRaiderFrame = self:CreatePanel("MapleDKPAddRaiderFrame", 360, 560, "Add Raider")
    addRaiderFrame:SetPoint("CENTER", optionsFrame, "CENTER", 0, 0)
    addRaiderFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    addRaiderFrame.searchLabel = addRaiderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    addRaiderFrame.searchLabel:SetPoint("TOPLEFT", 16, -40)
    addRaiderFrame.searchLabel:SetText("Search")
    addRaiderFrame.searchQuery = ""
    addRaiderFrame.searchInput = self:CreateInput(addRaiderFrame, 220, 24, "LEFT", addRaiderFrame.searchLabel, "RIGHT", 8, 0, false)
    addRaiderFrame.searchInput:SetMaxLetters(24)
    addRaiderFrame.searchInput:SetScript("OnTextChanged", function(self)
        addRaiderFrame.searchQuery = self:GetText() or ""
        addRaiderFrame.scrollOffset = 0
        addon:RefreshAddRaiderPopup()
    end)
    addRaiderFrame.summaryText = self:CreateRowText(addRaiderFrame, "GameFontHighlightSmall", 316, "TOPLEFT", 16, -70)
    addRaiderFrame.summaryText:SetText("")
    addRaiderFrame.scrollOffset = 0
    addRaiderFrame.scrollBar = self:CreateVerticalSlider(addRaiderFrame, 438, "TOPRIGHT", addRaiderFrame, "TOPRIGHT", -2, -96, function(value)
        addRaiderFrame.scrollOffset = value
        addon:RefreshAddRaiderPopup()
    end)
    addRaiderFrame.rows = {}
    for index = 1, 22 do
        addRaiderFrame.rows[index] = self:CreateListButton(addRaiderFrame, 316, 18, "TOPLEFT", addRaiderFrame, "TOPLEFT", 16, -94 - ((index - 1) * 20), function(button)
            if not button.entryName then
                return
            end

            if addon:AddRaider(button.entryName) then
                addon:SetOptionsStatus(string.format("Added %s to active raiders.", button.entryName))
                addon:RefreshOptionsMembersPage()
                addon:RefreshAddRaiderPopup()
            end
        end)
    end
    self:EnableMouseWheelScroll(addRaiderFrame, addRaiderFrame.scrollBar)
    addRaiderFrame:SetScript("OnShow", function()
        addon:RefreshAddRaiderPopup()
    end)
    local resetConfirmFrame = self:CreateResetConfirmFrame(optionsFrame)

    local actionsPage = self:CreateOptionsActionsPage(createPage)

    local bossesPage = createPage()
    bossesPage.description = self:CreateRowText(bossesPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -4)
    bossesPage.description:SetText("Select a boss from the list, then update only its DKP value.")
    bossesPage.summaryText = self:CreateRowText(bossesPage, "GameFontHighlightSmall", 294, "TOPLEFT", 0, -20)
    bossesPage.summaryText:SetText("Rows 0-0 of 0 | Bosses: 0")
    bossesPage.scrollOffset = 0
    bossesPage.scrollBar = self:CreateVerticalSlider(bossesPage, 458, "TOPLEFT", bossesPage, "TOPLEFT", 304, -34, function(value)
        bossesPage.scrollOffset = value
        addon:RefreshOptionsBossesPage()
    end)
    bossesPage.bossRows = {}
    for index = 1, 20 do
        bossesPage.bossRows[index] = self:CreateListButton(bossesPage, 294, 18, "TOPLEFT", bossesPage, "TOPLEFT", 0, -34 - ((index - 1) * 22), function(button)
            if button.zoneName then
                addon:ToggleBossZoneCollapsed(button.zoneName)
            elseif button.npcId then
                addon:SelectOptionsBoss(button.npcId)
            end
        end)
    end
    self:EnableMouseWheelScroll(bossesPage, bossesPage.scrollBar)
    bossesPage.selectedText = self:CreateRowText(bossesPage, "GameFontHighlightSmall", 290, "TOPLEFT", 350, -34)
    bossesPage.bossIdHeader = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossIdHeader:SetPoint("TOPLEFT", 350, -64)
    bossesPage.bossIdHeader:SetText("NPC ID")
    bossesPage.bossIdValue = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossIdValue:SetPoint("LEFT", bossesPage.bossIdHeader, "RIGHT", 8, 0)
    bossesPage.bossIdValue:SetJustifyH("LEFT")
    bossesPage.bossNameHeader = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossNameHeader:SetPoint("TOPLEFT", 350, -92)
    bossesPage.bossNameHeader:SetText("Boss")
    bossesPage.bossNameValue = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossNameValue:SetPoint("LEFT", bossesPage.bossNameHeader, "RIGHT", 8, 0)
    bossesPage.bossNameValue:SetJustifyH("LEFT")
    bossesPage.bossZoneHeader = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossZoneHeader:SetPoint("TOPLEFT", 350, -120)
    bossesPage.bossZoneHeader:SetText("Dungeon")
    bossesPage.bossZoneValue = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossZoneValue:SetPoint("LEFT", bossesPage.bossZoneHeader, "RIGHT", 8, 0)
    bossesPage.bossZoneValue:SetJustifyH("LEFT")
    bossesPage.bossAmountHeader = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossAmountHeader:SetPoint("TOPLEFT", 350, -152)
    bossesPage.bossAmountHeader:SetText("Award")
    bossesPage.bossAmountInput = self:CreateInput(bossesPage, 80, 24, "LEFT", bossesPage.bossAmountHeader, "RIGHT", 8, 0, true)
    bossesPage.bossAmountInput:SetMaxLetters(5)
    bossesPage.saveBossButton = self:CreateButton(bossesPage, "Save Value", 90, 22, "LEFT", bossesPage.bossAmountInput, "RIGHT", 10, 0, function()
        if addon.ui.optionsSelectedBossNpcId and addon.ui.optionsSelectedBossNpcId ~= "0" then
            addon:ConfigureBoss(addon.ui.optionsSelectedBossNpcId, bossesPage.bossAmountInput:GetText(), bossesPage.bossNameValue:GetText())
            addon:SetOptionsStatus("Updated boss reward value.")
            addon:RefreshOptionsUI()
        end
    end)

    local auctionPage = createPage()
    auctionPage.description = self:CreateRowText(auctionPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -4)
    auctionPage.description:SetText("Use this page to launch or close auctions and open the loot-control window.")
    auctionPage.activeAuctionText = self:CreateRowText(auctionPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -34)
    local auctionItemLabel = auctionPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    auctionItemLabel:SetPoint("TOPLEFT", 0, -68)
    auctionItemLabel:SetText("Item")
    auctionPage.auctionItemInput = self:CreateInput(auctionPage, 320, 24, "LEFT", auctionItemLabel, "RIGHT", 8, 0, false)
    auctionPage.auctionItemInput:SetMaxLetters(120)
    auctionPage.auctionItemInput.allowItemLinks = true
    auctionPage.auctionItemInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addon:StartAuction(auctionPage.auctionMinInput:GetText(), self:GetText(), auctionPage.auctionDurationInput:GetText())
        addon:SetOptionsStatus("Started auction from the Auction tab.")
        addon:RefreshOptionsUI()
    end)
    local auctionMinLabel = auctionPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    auctionMinLabel:SetPoint("TOPLEFT", 0, -100)
    auctionMinLabel:SetText("Min Bid")
    auctionPage.auctionMinInput = self:CreateInput(auctionPage, 70, 24, "LEFT", auctionMinLabel, "RIGHT", 8, 0, true)
    auctionPage.auctionMinInput:SetMaxLetters(5)
    auctionPage.auctionMinInput:SetText("10")
    local auctionDurationLabel = auctionPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    auctionDurationLabel:SetPoint("LEFT", auctionPage.auctionMinInput, "RIGHT", 14, 0)
    auctionDurationLabel:SetText("Seconds")
    auctionPage.auctionDurationInput = self:CreateInput(auctionPage, 70, 24, "LEFT", auctionDurationLabel, "RIGHT", 8, 0, true)
    auctionPage.auctionDurationInput:SetMaxLetters(3)
    auctionPage.auctionDurationInput:SetText(tostring(self.auctionDuration))
    auctionPage.startAuctionButton = self:CreateButton(auctionPage, "Start", 80, 22, "LEFT", auctionPage.auctionDurationInput, "RIGHT", 10, 0, function()
        addon:StartAuction(auctionPage.auctionMinInput:GetText(), auctionPage.auctionItemInput:GetText(), auctionPage.auctionDurationInput:GetText())
        addon:SetOptionsStatus("Started auction from the Auction tab.")
        addon:RefreshOptionsUI()
    end)
    auctionPage.statusAuctionButton = self:CreateButton(auctionPage, "Refresh", 80, 22, "LEFT", auctionPage.startAuctionButton, "RIGHT", 8, 0, function()
        addon:RefreshOptionsUI()
    end)
    auctionPage.closeAuctionButton = self:CreateButton(auctionPage, "Close", 80, 22, "LEFT", auctionPage.statusAuctionButton, "RIGHT", 8, 0, function()
        addon:CloseAuction()
        addon:SetOptionsStatus("Closed the current auction.")
        addon:RefreshOptionsUI()
    end)
    auctionPage.openLootButton = self:CreateButton(auctionPage, "Loot Window", 100, 22, "TOPLEFT", auctionPage, "TOPLEFT", 0, -140, function()
        if not addon:IsOfficer() then
            addon:SetOptionsStatus("Only officers can open the loot control panel.")
            return
        end
        addon.ui.controlFrame:Show()
        addon:RefreshLeaderUI()
        addon:SetOptionsStatus("Opened the loot control panel.")
    end)
    auctionPage.currentBidsHeader = auctionPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    auctionPage.currentBidsHeader:SetPoint("TOPLEFT", auctionPage.openLootButton, "BOTTOMLEFT", 0, -14)
    auctionPage.currentBidsHeader:SetText("Current Bids")
    auctionPage.currentBidRows = {}
    for index = 1, 10 do
        auctionPage.currentBidRows[index] = self:CreateRowText(auctionPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -196 - ((index - 1) * 18))
    end

    local conflictsPage = createPage()
    conflictsPage.summaryText = self:CreateRowText(conflictsPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -4)
    conflictsPage.selectedText = self:CreateRowText(conflictsPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -24)
    conflictsPage.scrollOffset = 0
    conflictsPage.scrollBar = self:CreateVerticalSlider(conflictsPage, 360, "TOPLEFT", conflictsPage, "TOPLEFT", 304, -48, function(value)
        conflictsPage.scrollOffset = value
        addon:RefreshOptionsConflictsPage()
    end)
    conflictsPage.conflictRows = {}
    for index = 1, 15 do
        conflictsPage.conflictRows[index] = self:CreateListButton(conflictsPage, 294, 18, "TOPLEFT", conflictsPage, "TOPLEFT", 0, -48 - ((index - 1) * 22), function(button)
            if button.conflictId then
                addon:SelectOptionsConflict(button.conflictId)
            end
        end)
    end
    self:EnableMouseWheelScroll(conflictsPage, conflictsPage.scrollBar)
    conflictsPage.detailText = self:CreateRowText(conflictsPage, "GameFontHighlightSmall", 300, "TOPLEFT", 350, -48)
    conflictsPage.detailText:SetJustifyH("LEFT")
    conflictsPage.keepCurrentButton = self:CreateButton(conflictsPage, "Keep Current", 100, 22, "TOPLEFT", conflictsPage, "TOPLEFT", 350, -170, function()
        if addon.ui.optionsSelectedConflictId then
            addon:ResolveConflict(addon.ui.optionsSelectedConflictId, "keep")
            addon:SetOptionsStatus("Kept the current DKP value.")
        end
    end)
    conflictsPage.applyIncomingButton = self:CreateButton(conflictsPage, "Apply Incoming", 110, 22, "LEFT", conflictsPage.keepCurrentButton, "RIGHT", 8, 0, function()
        if addon.ui.optionsSelectedConflictId then
            addon:ResolveConflict(addon.ui.optionsSelectedConflictId, "apply")
            addon:SetOptionsStatus("Applied the incoming conflict value.")
        end
    end)
    conflictsPage.manualValueInput = self:CreateInput(conflictsPage, 80, 24, "TOPLEFT", conflictsPage, "TOPLEFT", 350, -206, true)
    conflictsPage.manualApplyButton = self:CreateButton(conflictsPage, "Manual Set", 90, 22, "LEFT", conflictsPage.manualValueInput, "RIGHT", 8, 0, function()
        if addon.ui.optionsSelectedConflictId then
            addon:ResolveConflict(addon.ui.optionsSelectedConflictId, "manual", conflictsPage.manualValueInput:GetText())
            addon:SetOptionsStatus("Applied a manual conflict resolution.")
        end
    end)

    optionsFrame.membersPage = membersPage
    optionsFrame.actionsPage = actionsPage
    optionsFrame.bossesPage = bossesPage
    optionsFrame.auctionPage = auctionPage
    optionsFrame.conflictsPage = conflictsPage
    optionsFrame.pages.members = membersPage
    optionsFrame.pages.actions = actionsPage
    optionsFrame.pages.bosses = bossesPage
    optionsFrame.pages.auction = auctionPage
    optionsFrame.pages.conflicts = conflictsPage
    optionsFrame.activeTab = "members"

    optionsFrame.officerControls = {
        actionsPage.addButton,
        actionsPage.subtractButton,
        actionsPage.setButton,
        actionsPage.fullResetButton,
        auctionPage.startAuctionButton,
        auctionPage.closeAuctionButton,
        auctionPage.openLootButton,
        conflictsPage.keepCurrentButton,
        conflictsPage.applyIncomingButton,
        conflictsPage.manualValueInput,
        conflictsPage.manualApplyButton,
        actionsPage.adjustTargetInput,
        actionsPage.adjustAmountInput,
        actionsPage.adjustReasonInput,
        bossesPage.bossAmountInput,
        bossesPage.saveBossButton,
        auctionPage.auctionItemInput,
        auctionPage.auctionMinInput,
        auctionPage.auctionDurationInput,
        membersPage.addRaiderButton,
        membersPage.removeRaiderButton,
        membersPage.deleteButton,
    }

    optionsFrame:SetScript("OnShow", function()
        addon:SetOptionsTab(optionsFrame.activeTab or "members")
    end)

    self.ui.controlFrame = controlFrame
    self.ui.auctionFrame = auctionFrame
    self.ui.raidDkpFrame = raidDkpFrame
    self.ui.noticeFrame = noticeFrame
    self.ui.historyFrame = historyFrame
    self.ui.addRaiderFrame = addRaiderFrame
    self.ui.resetConfirmFrame = resetConfirmFrame
    self.ui.optionsFrame = optionsFrame
    self.ui.initialized = true
end

function addon:RemoveRecentLoot(itemLink)
    for index, value in ipairs(self.recentLoot) do
        if value == itemLink then
            table.remove(self.recentLoot, index)
            return
        end
    end
end

function addon:ReopenAuctionBidWindow(showNoAuctionMessage)
    if not self.activeAuction then
        if showNoAuctionMessage then
            self:Print("There is no active auction.")
        end
        return false
    end

    self:EnsureUI()
    self.ui.auctionPopupDismissed = false
    self:RefreshAuctionPopup()
    return true
end

function addon:ShowLootNotice()
    self:EnsureUI()
    self.ui.noticeExpireAt = GetTime() + 20
    self:RefreshLootNotice()
end

function addon:BroadcastLoot()
    self:SendMessage(table.concat({ "LOOT", "BEGIN" }, "\t"))
    for _, itemLink in ipairs(self.recentLoot) do
        self:SendMessage(table.concat({ "LOOT", "ITEM", trim(itemLink) }, "\t"))
    end
    self:SendMessage(table.concat({ "LOOT", "END" }, "\t"))
end

function addon:IsRaidLootMasterMode()
    if not IsInRaid() or not GetLootMethod then
        return false
    end

    local lootMethod = string.lower(trim(GetLootMethod() or ""))
    return lootMethod == "master"
end

function addon:ShouldCaptureOpenedLoot()
    if self:IsTestMode() then
        return self:IsTestAllLootEnabled()
    end

    return self:IsRaidLootMasterMode()
end

function addon:HandleLootOpened()
    if not self:IsOfficer() or not GetNumLootItems or not LootSlotHasItem then
        return
    end

    if not self:ShouldCaptureOpenedLoot() then
        return
    end

    local lootItems = {}
    local lootCount = GetNumLootItems() or 0
    local requireEpic = not self:IsTestMode()
    for slotIndex = 1, lootCount do
        if LootSlotHasItem(slotIndex) then
            local itemLink = GetLootSlotLink and GetLootSlotLink(slotIndex) or nil
            local _, itemName, _, quality = GetLootSlotInfo(slotIndex)
            if requireEpic and (not quality or quality < 4) then
                -- skip non-epic items in live mode
            elseif itemLink or itemName then
                lootItems[#lootItems + 1] = itemLink or itemName
            end
        end
    end

    if #lootItems == 0 then
        return
    end

    self.recentLoot = lootItems
    self:EnsureUI()
    self:RefreshLeaderUI()
    self:BroadcastLoot()
end

function addon:IsTestMode()
    return TEST_MODE == true
end

function addon:EnsureDatabase()
    MapleDKPDB = MapleDKPDB or {}
    MapleDKPDB.version = 1
    MapleDKPDB.guilds = MapleDKPDB.guilds or {}
    MapleDKPDB.settings = MapleDKPDB.settings or { quiet = true, testAllLoot = false }

    self.db = MapleDKPDB
    self.db.settings = self.db.settings or {}
    if self.db.settings.quiet == nil then
        self.db.settings.quiet = true
    end
    if self.db.settings.testAllLoot == nil then
        self.db.settings.testAllLoot = false
    end

    local guildName = self:GetGuildName()
    if not guildName then
        return false
    end

    self.db.guilds[guildName] = self.db.guilds[guildName] or {
        players = {},
        history = {},
        activityLog = {},
        revision = 0,
        bosses = {},
        knownTransactions = {},
        transactionLogById = {},
        transactionOrder = {},
        actorSequences = {},
        replayBaselineAt = 0,
        conflicts = {},
        conflictOrder = {},
        conflictCounter = 0,
        resolvedTransactions = {},
        manualRaiders = {},
        manualInactiveRaiders = {},
    }

    self.guild = self.db.guilds[guildName]
    self.guild.players = self.guild.players or {}
    self.guild.history = self.guild.history or {}
    self.guild.activityLog = self.guild.activityLog or {}
    self.guild.bosses = self.guild.bosses or {}
    self.guild.knownTransactions = self.guild.knownTransactions or {}
    self.guild.transactionLogById = self.guild.transactionLogById or {}
    self.guild.transactionOrder = self.guild.transactionOrder or {}
    self.guild.actorSequences = self.guild.actorSequences or {}
    self.guild.replayBaselineAt = safeNumber(self.guild.replayBaselineAt, 0)
    self.guild.conflicts = self.guild.conflicts or {}
    self.guild.conflictOrder = self.guild.conflictOrder or {}
    self.guild.conflictCounter = safeNumber(self.guild.conflictCounter, 0)
    self.guild.resolvedTransactions = self.guild.resolvedTransactions or {}
    self.guild.manualRaiders = self.guild.manualRaiders or {}
    self.guild.manualInactiveRaiders = self.guild.manualInactiveRaiders or {}
    self.guild.revision = safeNumber(self.guild.revision, 0)
    self.guild.newMemberDefaultDkp = math.floor(safeNumber(self.guild.newMemberDefaultDkp, DEFAULT_NEW_MEMBER_DKP) + 0.5)
    if self.guild.trackingEnabled == nil then
        self.guild.trackingEnabled = true
    end

    local storedSchema = safeNumber(self.guild.bossSchemaVersion, 0)
    local schemaStale = storedSchema < BOSS_SCHEMA_VERSION

    for npcId, boss in pairs(DEFAULT_BOSSES) do
        if not self.guild.bosses[npcId] then
            -- New entry: copy everything from defaults.
            self.guild.bosses[npcId] = shallowCopy(boss)
        else
            local saved = self.guild.bosses[npcId]
            -- Always keep structural metadata current so ordering/grouping is correct.
            saved.zone = boss.zone
            saved.encounterOrder = boss.encounterOrder
            saved.name = boss.name
            -- Reset amount to the new default only when the schema has been bumped,
            -- so stale values (5, 8, 12 …) are corrected without wiping officer edits
            -- made after the last schema update.
            if schemaStale or saved.amount == nil then
                saved.amount = boss.amount
            end
        end
    end

    if schemaStale then
        self.guild.bossSchemaVersion = BOSS_SCHEMA_VERSION
    end

    -- One-time initialization: set all existing players to 180 DKP on first load
    if not self.guild.dkpInitialized then
        for playerName, playerData in pairs(self.guild.players) do
            if playerData then
                playerData.dkp = DEFAULT_NEW_MEMBER_DKP
                playerData.earned = safeNumber(playerData.earned, 0)
                playerData.spent = safeNumber(playerData.spent, 0)
                playerData.updatedAt = time()
            end
        end
        self.guild.dkpInitialized = true
    end

    -- Migration for older builds that seeded roster members at 0 during login.
    -- Only run when there is no recorded transaction history to avoid changing live data.
    if not self.guild.startingDkpSeeded and #self.guild.history == 0 then
        for _, playerData in pairs(self.guild.players) do
            if playerData and safeNumber(playerData.dkp, 0) == 0 then
                playerData.dkp = self:GetNewMemberDefaultDkp()
                playerData.earned = safeNumber(playerData.earned, 0)
                playerData.spent = safeNumber(playerData.spent, 0)
                playerData.updatedAt = time()
            end
        end
        self.guild.startingDkpSeeded = true
    end

    for _, playerData in pairs(self.guild.players) do
        if playerData then
            playerData.earned = safeNumber(playerData.earned, 0)
            playerData.spent = safeNumber(playerData.spent, 0)
        end
    end

    if self.guild.replayBaselineAt <= 0 then
        self.guild.replayBaselineAt = time()
    end

    return true
end

function addon:EnsurePlayer(name)
    if not self.guild then
        return nil
    end

    name = self:NormalizeName(name)
    if not name then
        return nil
    end

    local playerData = self.guild.players[name]
    if not playerData then
        local startingDkp = self:IsGuildRosterMember(name) and self:GetNewMemberDefaultDkp() or 0
        playerData = {
            dkp = startingDkp,
            earned = 0,
            spent = 0,
            updatedAt = time(),
            class = nil,
        }
        self.guild.players[name] = playerData
    elseif playerData.dkp == nil then
        playerData.dkp = self:IsGuildRosterMember(name) and self:GetNewMemberDefaultDkp() or 0
        playerData.updatedAt = time()
    end

    playerData.earned = safeNumber(playerData.earned, 0)
    playerData.spent = safeNumber(playerData.spent, 0)

    return playerData, name
end

function addon:NormalizeClassToken(classValue)
    local token = trim(classValue)
    if token == "" then
        return nil
    end

    token = string.upper(token)
    token = token:gsub("%s+", "")

    if CLASS_COLOR_HEX[token] then
        return token
    end

    return CLASS_NAME_TO_TOKEN[token]
end

function addon:UpdatePlayerClass(name, classValue)
    local playerData, normalizedName = self:EnsurePlayer(name)
    if not playerData or not normalizedName then
        return
    end

    local classToken = self:NormalizeClassToken(classValue)
    if classToken then
        playerData.class = classToken
    end
end

function addon:GetPlayerClassColorHex(name)
    if not self.guild then
        return nil
    end

    local normalizedName = self:NormalizeName(name)
    if not normalizedName then
        return nil
    end

    local playerData = self.guild.players and self.guild.players[normalizedName]
    local classToken = playerData and self:NormalizeClassToken(playerData.class)
    if classToken and CLASS_COLOR_HEX[classToken] then
        return CLASS_COLOR_HEX[classToken]
    end

    return nil
end

function addon:GetPlayerDKP(name)
    local playerData = self:EnsurePlayer(name)
    if not playerData then
        return 0
    end

    return safeNumber(playerData.dkp, 0)
end

function addon:TryAutoSeedDefaultDkp(name)
    if not self.guild then
        return false
    end

    local playerData, normalizedName = self:EnsurePlayer(name)
    if not playerData or not normalizedName then
        return false
    end

    if not self:IsGuildRosterMember(normalizedName) then
        return false
    end

    local currentDkp = safeNumber(playerData.dkp, 0)
    local earned = safeNumber(playerData.earned, 0)
    local spent = safeNumber(playerData.spent, 0)
    if currentDkp ~= 0 or earned ~= 0 or spent ~= 0 then
        return false
    end

    local seededValue = self:GetNewMemberDefaultDkp()
    if seededValue <= 0 then
        return false
    end

    local txId = self:MakeTransactionId("SEED", normalizedName)
    if self:ApplyPlayerTransaction(normalizedName, seededValue, seededValue, "Auto-seed default DKP", txId, self:GetPlayerName(), true) then
        self:BroadcastPlayerUpdate(normalizedName, seededValue, seededValue, "Auto-seed default DKP", txId, self:GetPlayerName())
        return true
    end

    return false
end

function addon:EnsureAwardEligibility(name)
    if not self.guild then
        return nil, 0, false, false
    end

    local playerData, normalizedName = self:EnsurePlayer(name)
    if not playerData or not normalizedName then
        return nil, 0, false, false
    end

    local autoAdded = false
    self.guild.manualRaiders = self.guild.manualRaiders or {}
    self.guild.manualInactiveRaiders = self.guild.manualInactiveRaiders or {}

    if self.guild.manualRaiders[normalizedName] ~= true then
        local configTx = self:BuildConfigTransaction(
            "addraider",
            normalizedName,
            1,
            "",
            "",
            0,
            "Auto-added during boss award",
            self:MakeTransactionId("CFGAUTOADD", normalizedName),
            self:GetPlayerName(),
            time()
        )
        if self:ApplyConfigTransactionRecord(configTx, true, false) then
            self:BroadcastConfigTransactionRecord(configTx)
            self:SendMessage(table.concat({ "CFG", "ADDRAIDER", trim(configTx.txId), normalizedName }, "\t"))
            autoAdded = true
        end
    end

    local hasHistory = safeNumber(playerData.dkp, 0) ~= 0 or safeNumber(playerData.earned, 0) ~= 0 or safeNumber(playerData.spent, 0) ~= 0
    local seeded = false
    local seededValue = 0
    if not hasHistory then
        local averageDkp, sourceCount = self:GetAverageActiveRaiderDkp(normalizedName)
        if sourceCount <= 0 then
            averageDkp = self:GetNewMemberDefaultDkp()
        end

        if averageDkp > 0 then
            local seedTxId = self:MakeTransactionId("RAIDSEED", normalizedName)
            if self:ApplyPlayerTransaction(normalizedName, averageDkp, averageDkp, "Auto baseline from active raiders", seedTxId, self:GetPlayerName(), true) then
                self:BroadcastPlayerUpdate(normalizedName, averageDkp, averageDkp, "Auto baseline from active raiders", seedTxId, self:GetPlayerName())
                seeded = true
                seededValue = averageDkp
            end
        end
    end

    return normalizedName, seededValue, autoAdded, seeded
end

function addon:SetPlayerValue(name, newValue)
    local playerData = self:EnsurePlayer(name)
    if not playerData then
        return nil
    end

    playerData.dkp = math.floor(safeNumber(newValue, 0) + 0.5)
    playerData.updatedAt = time()
    return playerData.dkp
end

function addon:AppendHistory(line)
    local history = self.guild and self.guild.history
    if not history then
        return
    end

    history[#history + 1] = string.format("%s %s", date("%m/%d %H:%M"), trim(line))
    while #history > 200 do
        table.remove(history, 1)
    end
end

function addon:AppendActivity(entry)
    local activityLog = self.guild and self.guild.activityLog
    if not activityLog or type(entry) ~= "table" then
        return
    end

    activityLog[#activityLog + 1] = {
        at = safeNumber(entry.at, time()),
        type = trim(entry.type),
        actor = trim(entry.actor),
        target = trim(entry.target),
        delta = safeNumber(entry.delta, 0),
        oldValue = safeNumber(entry.oldValue, 0),
        newValue = safeNumber(entry.newValue, 0),
        reason = trim(entry.reason),
        txId = trim(entry.txId),
        auctionId = trim(entry.auctionId),
        winner = trim(entry.winner),
        winningBid = safeNumber(entry.winningBid, 0),
        item = trim(entry.item),
        outcome = trim(entry.outcome),
    }

    while #activityLog > 2000 do
        table.remove(activityLog, 1)
    end
end

function addon:FormatActivityEntry(entry)
    if not entry then
        return ""
    end

    local stamp = date("%m/%d %H:%M", safeNumber(entry.at, time()))
    local entryType = trim(entry.type)

    if entryType == "PLAYER_TX" then
        return string.format(
            "%s TX %s %+d (%d -> %d) by %s [%s]",
            stamp,
            trim(entry.target),
            safeNumber(entry.delta, 0),
            safeNumber(entry.oldValue, 0),
            safeNumber(entry.newValue, 0),
            trim(entry.actor) ~= "" and trim(entry.actor) or "unknown",
            trim(entry.reason)
        )
    end

    if entryType == "AUCTION_CLOSE" then
        local outcome = trim(entry.outcome)
        if outcome == "paid" then
            return string.format(
                "%s AUC %s won %s for %d DKP (closed by %s)",
                stamp,
                trim(entry.winner),
                trim(entry.item),
                safeNumber(entry.winningBid, 0),
                trim(entry.actor) ~= "" and trim(entry.actor) or "unknown"
            )
        end

        if outcome == "free" then
            return string.format(
                "%s AUC %s assigned %s for free (closed by %s)",
                stamp,
                trim(entry.winner),
                trim(entry.item),
                trim(entry.actor) ~= "" and trim(entry.actor) or "unknown"
            )
        end

        return string.format(
            "%s AUC no winner for %s (closed by %s)",
            stamp,
            trim(entry.item),
            trim(entry.actor) ~= "" and trim(entry.actor) or "unknown"
        )
    end

    if entryType == "CONFLICT" then
        return string.format(
            "%s CONFLICT %s by %s [%s]",
            stamp,
            trim(entry.target),
            trim(entry.actor) ~= "" and trim(entry.actor) or "unknown",
            trim(entry.reason)
        )
    end

    if entryType == "PLAYER_DELETE" then
        return string.format(
            "%s DEL %s by %s [%s]",
            stamp,
            trim(entry.target),
            trim(entry.actor) ~= "" and trim(entry.actor) or "unknown",
            trim(entry.reason)
        )
    end

    if entryType == "CONFLICT_RESOLVED" then
        return string.format(
            "%s CONFLICT RESOLVED %s by %s [%s]",
            stamp,
            trim(entry.target),
            trim(entry.actor) ~= "" and trim(entry.actor) or "unknown",
            trim(entry.reason)
        )
    end

    return string.format("%s %s", stamp, trim(entry.reason))
end

function addon:SyncGuildRoster(skipRefresh)
    if not self.guild or not IsInGuild() then
        self.guildRosterMembers = {}
        self.playerGuildRankIndex = nil
        return
    end

    local refreshGuildRoster = GuildRoster or (C_GuildInfo and C_GuildInfo.GuildRoster)
    if not skipRefresh and refreshGuildRoster then
        pcall(refreshGuildRoster)
    end

    local memberCount = 0
    if GetNumGuildMembers then
        memberCount = GetNumGuildMembers() or 0
    elseif C_GuildInfo and C_GuildInfo.GetNumGuildMembers then
        memberCount = C_GuildInfo.GetNumGuildMembers() or 0
    end

    local rosterMembers = {}
    self.guildRosterMembers = rosterMembers
    self.playerGuildRankIndex = nil
    local localPlayerName = self:GetPlayerName()

    for index = 1, memberCount do
        local name
        local classToken
        local rankIndex
        if GetGuildRosterInfo then
            local rosterName, _, rosterRankIndex, _, className, _, _, _, _, _, classFileName = GetGuildRosterInfo(index)
            name = rosterName
            rankIndex = rosterRankIndex
            classToken = classFileName or className
        elseif C_GuildInfo and C_GuildInfo.GetGuildRosterInfo then
            local info = C_GuildInfo.GetGuildRosterInfo(index)
            if type(info) == "table" then
                name = info.name or info.fullName
                rankIndex = info.rankOrder or info.rankIndex
                classToken = info.classFilename or info.classFileName or info.className
            else
                name = info
            end
        end

        name = self:NormalizeName(name)
        if name then
            rosterMembers[name] = true
            if name == localPlayerName then
                self.playerGuildRankIndex = safeNumber(rankIndex, 99)
            end
            self:EnsurePlayer(name)
            self:UpdatePlayerClass(name, classToken)
        end
    end

    self.guildRosterMembers = rosterMembers
end

function addon:GetRaidGuildMembers()
    local members = {}
    local seen = {}
    local raidMemberCount = getRaidMemberCount()
    local partyMemberCount = getPartyMemberCount()

    if raidMemberCount > 0 then
        for index = 1, raidMemberCount do
            local unit = "raid" .. index
            local name = self:NormalizeName(UnitName(unit))
            if name and self.guild.players[name] and not seen[name] then
                members[#members + 1] = name
                seen[name] = true
            end
        end
    elseif partyMemberCount > 0 then
        local playerName = self:GetPlayerName()
        if playerName and self.guild.players[playerName] then
            members[#members + 1] = playerName
            seen[playerName] = true
        end

        for index = 1, partyMemberCount do
            local unit = "party" .. index
            local name = self:NormalizeName(UnitName(unit))
            if name and self.guild.players[name] and not seen[name] then
                members[#members + 1] = name
                seen[name] = true
            end
        end
    else
        local playerName = self:GetPlayerName()
        if playerName and self.guild.players[playerName] then
            members[#members + 1] = playerName
        end
    end

    table.sort(members)
    return members
end

function addon:GetTrackedGroupMembers()
    local members = {}
    local seen = {}
    local raidMemberCount = getRaidMemberCount()
    local partyMemberCount = getPartyMemberCount()

    local function addMember(rawName, classToken)
        local name = self:NormalizeName(rawName)
        if not name or seen[name] then
            return
        end

        self:EnsurePlayer(name)
        self:UpdatePlayerClass(name, classToken)
        members[#members + 1] = name
        seen[name] = true
    end

    addMember(UnitName("player"), select(2, UnitClass("player")))

    if raidMemberCount > 0 then
        for index = 1, raidMemberCount do
            local unit = "raid" .. index
            addMember(UnitName(unit), select(2, UnitClass(unit)))
        end
    elseif partyMemberCount > 0 then
        for index = 1, partyMemberCount do
            local unit = "party" .. index
            addMember(UnitName(unit), select(2, UnitClass(unit)))
        end
    end

    table.sort(members)
    return members
end

function addon:SyncTrackedGroupMembers()
    if not self.guild then
        return
    end

    self:GetTrackedGroupMembers()
end

function addon:GetGroupLeaderName()
    local raidMemberCount = getRaidMemberCount()
    local partyMemberCount = getPartyMemberCount()

    if raidMemberCount > 0 then
        for index = 1, raidMemberCount do
            local raidName, _, _, _, _, _, _, _, _, isRaidLeader = GetRaidRosterInfo(index)
            if isRaidLeader then
                return self:NormalizeName(raidName)
            end
        end
    end

    if partyMemberCount > 0 then
        if UnitIsPartyLeader and UnitIsPartyLeader("player") then
            return self:GetPlayerName()
        end

        for index = 1, partyMemberCount do
            if UnitIsPartyLeader and UnitIsPartyLeader("party" .. index) then
                return self:NormalizeName(UnitName("party" .. index))
            end
        end
    end

    return self:GetPlayerName()
end

function addon:BroadcastGroupMessage(message)
    if not message or message == "" then
        return
    end

    if getRaidMemberCount() > 0 then
        self:SendMessage(message, "RAID")
    elseif getPartyMemberCount() > 0 then
        self:SendMessage(message, "PARTY")
    end
end

function addon:GetGroupChatChannel()
    if getRaidMemberCount() > 0 then
        return "RAID"
    end

    return nil
end

function addon:AnnounceGroupChat(message)
    local channel = self:GetGroupChatChannel()
    local text = trim(message)
    if not channel or not SendChatMessage or text == "" then
        return
    end

    SendChatMessage("[MapleDKP] " .. text, channel)
end

function addon:AwardRaid(amount, reason, sharedTxRoot)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can award DKP.")
        return
    end

    if not self:IsTrackingEnabled() then
        self:Print("Raid DKP tracking is disabled.")
        return
    end

    local raidMembers = self:GetTrackedGroupMembers()
    if #raidMembers == 0 then
        self:Print("No guild raid members found to award.")
        return
    end

    local amountValue = math.floor(safeNumber(amount, 0) + 0.5)
    local seededCount = 0
    local autoAddedCount = 0
    for _, memberName in ipairs(raidMembers) do
        local eligibleName, seededValue, autoAdded, seeded = self:EnsureAwardEligibility(memberName)
        if eligibleName then
            memberName = eligibleName
            if autoAdded then
                autoAddedCount = autoAddedCount + 1
            end
            if seeded then
                seededCount = seededCount + 1
            end
        end

        local awardAmountForMember = seeded and 10 or amountValue
        if sharedTxRoot and sharedTxRoot ~= "" then
            local txId = table.concat({ sharedTxRoot, memberName }, ":")
            local newValue = self:GetPlayerDKP(memberName) + awardAmountForMember
            if self:ApplyPlayerTransaction(memberName, awardAmountForMember, newValue, reason, txId, self:GetPlayerName(), true) then
                self:BroadcastPlayerUpdate(memberName, awardAmountForMember, newValue, reason, txId, self:GetPlayerName())
            end
        else
            self:AdjustPlayer(memberName, awardAmountForMember, reason)
        end

        if seeded and seededValue > 0 then
            self:Print(string.format("%s auto-seeded to %d DKP and awarded 10 DKP for the kill.", memberName, seededValue))
        end
    end

    self:Print(string.format("Awarded %d DKP to %d raid members.", amountValue, #raidMembers))
    if autoAddedCount > 0 then
        self:Print(string.format("Auto-added %d raid members to active raiders during award.", autoAddedCount))
    end
    if seededCount > 0 then
        self:Print(string.format("Auto-seeded %d raid members with no prior DKP history.", seededCount))
    end
end

function addon:ConfigureBoss(npcId, amount, bossName)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can configure boss values.")
        return
    end

    npcId = tostring(safeNumber(npcId, 0))
    amount = math.floor(safeNumber(amount, 0) + 0.5)
    bossName = trim(bossName)

    if npcId == "0" or bossName == "" then
        self:Print("Usage: /mdkp boss add NpcID Amount Boss Name")
        return
    end

    local existing = self.guild.bosses[npcId] or DEFAULT_BOSSES[npcId] or {}
    local zone = trim(existing.zone ~= nil and existing.zone or "Custom")
    local encounterOrder = safeNumber(existing.encounterOrder, 999)
    local transaction = self:BuildConfigTransaction("boss", npcId, amount, bossName, zone, encounterOrder, "Configured boss award", self:MakeTransactionId("CFGBOSS", npcId), self:GetPlayerName(), time())
    if self:ApplyConfigTransactionRecord(transaction, true, false) then
        self:BroadcastConfigTransactionRecord(transaction)
        self:SendMessage(table.concat({ "CFG", "BOSS", trim(transaction.txId), npcId, tostring(amount), bossName, zone, tostring(encounterOrder) }, "\t"))
        self:Print(string.format("Boss %s (%s) now awards %d DKP.", bossName, npcId, amount))
    end
end

function addon:ListBosses()
    if not self.guild then
        return
    end

    self:Print("Configured boss awards:")
    for npcId, boss in pairs(self.guild.bosses) do
        self:Print(string.format("%s - %s: %d", npcId, boss.name, safeNumber(boss.amount, 0)))
    end
end

function addon:InjectTestLoot(itemLink)
    itemLink = trim(itemLink)
    if itemLink == "" then
        itemLink = "[Test Epic BoE]"
    end

    self.recentLoot = { itemLink }
    self:EnsureUI()
    self.ui.controlFrame:Show()
    self:ShowLootNotice()
    self:RefreshLeaderUI()
    self:BroadcastLoot()
    self:Print("Injected test loot: " .. itemLink)
end

function addon:HandleChatMessage(prefix, message, distribution, sender)
    if prefix ~= self.prefix or not self.guild then
        return
    end

    local senderName = self:NormalizeName(sender)
    if senderName == self:GetPlayerName() then
        return
    end

    local parts = splitMessage(message)
    local command = parts[1]

    if command == "BCLAIM" then
        self:HandleBossAwardClaim(parts[2], parts[3], parts[4], senderName, distribution)
        return
    end

    if command == "REQSYNC" then
        local theirRevision = safeNumber(parts[2], 0)
        local requestId = trim(parts[4])
        if requestId == "" then
            requestId = nil
        end

        -- Replay-based sync needs exchange even when revisions tie, otherwise
        -- two isolated officers can both be "current" but still miss each
        -- other's transactions.
        if self.guild.revision >= theirRevision then
            self:SendSnapshot(senderName, requestId)
        end
        return
    end

    if command == "TXREQ" then
        local actorName = self:NormalizeName(parts[2])
        local afterSequence = safeNumber(parts[3], 0)
        if actorName then
            self:SendTransactionsForActor(senderName, actorName, afterSequence)
        end
        return
    end

    if command == "CFG" and parts[2] == "BOSS" then
        local txId
        local baseIndex = 3
        if string.find(trim(parts[3]), ":", 1, true) then
            txId = trim(parts[3])
            baseIndex = 4
        end
        if txId ~= nil and self:HasSeenTransaction(txId) then
            return
        end

        local npcId = tostring(safeNumber(parts[baseIndex], 0))
        if npcId ~= "0" then
            local existing = self.guild.bosses[npcId] or DEFAULT_BOSSES[npcId] or {}
            local zone = trim(parts[baseIndex + 3])
            if zone == "" then
                zone = trim(existing.zone ~= nil and existing.zone or "Custom")
            end

            local encounterOrder = safeNumber(parts[baseIndex + 4], safeNumber(existing.encounterOrder, 999))
            self.guild.bosses[npcId] = {
                amount = math.floor(safeNumber(parts[baseIndex + 1], 0) + 0.5),
                name = trim(parts[baseIndex + 2]),
                zone = zone,
                encounterOrder = encounterOrder,
            }
            if txId ~= nil then
                self:RegisterTransaction(txId)
            end
            self:NextRevision()
        end
        return
    end

    if command == "CFG" and parts[2] == "DELPLAYER" then
        local playerName = self:NormalizeName(parts[3])
        if playerName and self.guild.players and self.guild.players[playerName] then
            self.guild.players[playerName] = nil
            if self.guild.manualRaiders then
                self.guild.manualRaiders[playerName] = nil
            end
            if self.guild.manualInactiveRaiders then
                self.guild.manualInactiveRaiders[playerName] = nil
            end
            if self.ui and self.ui.optionsSelectedMember == playerName then
                self.ui.optionsSelectedMember = nil
            end
            self:NextRevision()
        end
        return
    end

    if command == "CFG" and parts[2] == "ADDRAIDER" then
        local txId
        local nameIndex = 3
        if string.find(trim(parts[3]), ":", 1, true) then
            txId = trim(parts[3])
            nameIndex = 4
        end
        if txId ~= nil and self:HasSeenTransaction(txId) then
            return
        end

        local playerName = self:NormalizeName(parts[nameIndex])
        if playerName then
            self:EnsurePlayer(playerName)
            self.guild.manualRaiders = self.guild.manualRaiders or {}
            self.guild.manualInactiveRaiders = self.guild.manualInactiveRaiders or {}
            self.guild.manualInactiveRaiders[playerName] = nil
            self.guild.manualRaiders[playerName] = true
            if txId ~= nil then
                self:RegisterTransaction(txId)
            end
            self:NextRevision()
        end
        return
    end

    if command == "CFG" and parts[2] == "REMRAIDER" then
        local txId
        local nameIndex = 3
        if string.find(trim(parts[3]), ":", 1, true) then
            txId = trim(parts[3])
            nameIndex = 4
        end
        if txId ~= nil and self:HasSeenTransaction(txId) then
            return
        end

        local playerName = self:NormalizeName(parts[nameIndex])
        if playerName then
            self.guild.manualRaiders = self.guild.manualRaiders or {}
            self.guild.manualInactiveRaiders = self.guild.manualInactiveRaiders or {}
            self.guild.manualRaiders[playerName] = nil
            self.guild.manualInactiveRaiders[playerName] = true
            if txId ~= nil then
                self:RegisterTransaction(txId)
            end
            self:NextRevision()
        end
        return
    end

    if command == "CFG" and parts[2] == "NEWMEMBERDKP" then
        local txId
        local valueIndex = 3
        if string.find(trim(parts[3]), ":", 1, true) then
            txId = trim(parts[3])
            valueIndex = 4
        end
        if txId ~= nil and self:HasSeenTransaction(txId) then
            return
        end

        local value = math.floor(safeNumber(parts[valueIndex], 0) + 0.5)
        if value < 0 then
            value = 0
        end
        self.guild.newMemberDefaultDkp = value
        if txId ~= nil then
            self:RegisterTransaction(txId)
        end
        self:NextRevision()
        return
    end

    if command == "CFG" and parts[2] == "TRACKING" then
        local txId
        local valueIndex = 3
        if string.find(trim(parts[3]), ":", 1, true) then
            txId = trim(parts[3])
            valueIndex = 4
        end
        if txId ~= nil and self:HasSeenTransaction(txId) then
            return
        end

        local enabled = safeNumber(parts[valueIndex], 1) ~= 0
        self.guild.trackingEnabled = enabled
        if txId ~= nil then
            self:RegisterTransaction(txId)
        end
        self:NextRevision()
        return
    end

    if command == "TX" and parts[2] == "CFG" then
        local transaction = self:BuildConfigTransaction(
            parts[6],
            parts[5],
            safeNumber(parts[7], 0),
            parts[8],
            parts[9],
            safeNumber(parts[10], 999),
            parts[11],
            parts[3],
            parts[4],
            safeNumber(parts[12], time())
        )
        transaction.actorSeq = safeNumber(parts[13], safeNumber(transaction.actorSeq, 0))

        if self:ApplyConfigTransactionRecord(transaction, true, true) then
            self:RefreshHistoryFrame()
            self:RefreshOptionsUI()
        end
        return
    end

    if command == "TX" and parts[2] == "PLAYER" then
        local transaction
        local opType = trim(parts[6])
        if opType == "set" or opType == "add" or opType == "sub" or opType == "delete" or opType == "resolve" then
            local expectedOldValue = trim(parts[9])
            if expectedOldValue == "" then
                expectedOldValue = nil
            else
                expectedOldValue = safeNumber(expectedOldValue, nil)
            end

            transaction = self:BuildPlayerTransaction(
                opType,
                parts[5],
                safeNumber(parts[7], 0),
                safeNumber(parts[8], 0),
                parts[10],
                parts[3],
                parts[4],
                expectedOldValue,
                safeNumber(parts[11], time())
            )
            transaction.actorSeq = safeNumber(parts[12], safeNumber(transaction.actorSeq, 0))
            transaction.resolvedTxId = trim(parts[13])
            transaction.resolutionAction = trim(parts[14])
        else
            transaction = self:BuildPlayerTransaction(
                "add",
                parts[5],
                safeNumber(parts[6], 0),
                safeNumber(parts[7], 0),
                parts[8],
                parts[3],
                parts[4],
                nil,
                time()
            )
        end

        local applied = self:ApplyTransactionRecord(transaction, true, true)
        if applied then
            self:RefreshLeaderUI()
            self:RefreshAuctionPopup()
            self:RefreshHistoryFrame()
            self:RefreshOptionsUI()
        elseif self:GetConflictCount() > 0 then
            self:RefreshHistoryFrame()
            self:RefreshOptionsUI()
        end
        return
    end

    if command == "LOOT" then
        local lootCommand = parts[2]
        if lootCommand == "BEGIN" then
            self.recentLoot = {}
            return
        end

        if lootCommand == "ITEM" then
            local itemLink = trim(parts[3])
            if itemLink ~= "" then
                self.recentLoot[#self.recentLoot + 1] = itemLink
            end
            return
        end

        if lootCommand == "END" then
            if #self.recentLoot > 0 then
                for _, itemLink in ipairs(self.recentLoot) do
                    self:Print("Loot dropped: " .. itemLink)
                end
                self:ShowLootNotice()
            else
                self:RefreshLootNotice()
            end
            return
        end
    end

    if command == "AUC" then
        if not isPlayerInCurrentGroup(self, senderName) then
            return
        end

        if not self:IsTrackingEnabled() then
            return
        end

        local auctionCommand = parts[2]
        if auctionCommand == "START" then
            self.activeAuction = {
                id = trim(parts[3]),
                item = trim(parts[6]),
                minBid = math.floor(safeNumber(parts[5], 0) + 0.5),
                bids = {},
                startedBy = trim(parts[4]),
                startedAt = time(),
                duration = math.floor(safeNumber(parts[7], self.auctionDuration) + 0.5),
                expiresAt = GetTime() + math.floor(safeNumber(parts[7], self.auctionDuration) + 0.5),
            }
            if self.activeAuction.duration < 5 then
                self.activeAuction.duration = self.auctionDuration
                self.activeAuction.expiresAt = GetTime() + self.auctionDuration
            end
            self.lastAuctionResult = nil
            self:EnsureUI()
            self:RefreshLeaderUI()
            self:RefreshAuctionPopup()
            self:Print(string.format("Auction started for %s. Minimum bid: %d.", self.activeAuction.item, self.activeAuction.minBid))
            return
        end

        if auctionCommand == "BID" then
            if self.activeAuction and self.activeAuction.startedBy == self:GetPlayerName() then
                self:RegisterBid(parts[4], parts[5], true, parts[3])
            end
            return
        end

        if auctionCommand == "BIDREQ" then
            if self.activeAuction and self.activeAuction.startedBy == self:GetPlayerName() then
                self:RegisterBid(senderName, parts[3], true, self.activeAuction.id)
            end
            return
        end

        if auctionCommand == "CLOSE" then
            local winner = self:NormalizeName(parts[5])
            local amount = math.floor(safeNumber(parts[6], 0) + 0.5)
            local item = trim(parts[7])
            local closedBy = self:NormalizeName(parts[4]) or senderName or "unknown"
            self.activeAuction = nil
            self:EnsureUI()

            if winner and amount > 0 then
                self.lastAuctionResult = string.format("%s won %s for %d DKP.", winner, item, amount)
                self:AppendHistory(string.format("Auction closed by %s: %s won %s for %d DKP", closedBy, winner, item, amount))
                self:AppendActivity({
                    type = "AUCTION_CLOSE",
                    actor = closedBy,
                    auctionId = parts[3],
                    winner = winner,
                    winningBid = amount,
                    item = item,
                    outcome = "paid",
                })
                self:RefreshLeaderUI()
                self:RefreshAuctionPopup()
                self:Print(string.format("Auction closed: %s won %s for %d DKP.", winner, item, amount))
            elseif winner then
                self.lastAuctionResult = string.format("%s was assigned %s for free.", winner, item)
                self:AppendHistory(string.format("Auction closed by %s: %s assigned %s for free", closedBy, winner, item))
                self:AppendActivity({
                    type = "AUCTION_CLOSE",
                    actor = closedBy,
                    auctionId = parts[3],
                    winner = winner,
                    winningBid = 0,
                    item = item,
                    outcome = "free",
                })
                self:RefreshLeaderUI()
                self:RefreshAuctionPopup()
                self:Print(string.format("Auction closed: %s was assigned %s for free.", winner, item))
            else
                self.lastAuctionResult = string.format("No bids were submitted for %s.", item)
                self:AppendHistory(string.format("Auction closed by %s: no winner for %s", closedBy, item))
                self:AppendActivity({
                    type = "AUCTION_CLOSE",
                    actor = closedBy,
                    auctionId = parts[3],
                    item = item,
                    outcome = "no_winner",
                })
                self:RefreshLeaderUI()
                self:RefreshAuctionPopup()
                self:Print(string.format("Auction closed for %s with no winner.", item))
            end
            return
        end
    end

    if command == "SNP" then
        local snapshotCommand = parts[2]
        if snapshotCommand == "BEGIN" then
            local snapshotId
            local revision
            local declaredSender
            local targetName
            local targetRaw

            if safeNumber(parts[3], nil) then
                snapshotId = string.format("legacy:%s:%s", senderName or "unknown", tostring(time()))
                revision = safeNumber(parts[3], 0)
                declaredSender = senderName
                targetName = self:NormalizeName(parts[4])
            else
                snapshotId = trim(parts[3])
                revision = safeNumber(parts[4], 0)
                declaredSender = self:NormalizeName(parts[5]) or senderName
                targetRaw = string.lower(trim(parts[6]))
                if targetRaw == "" or targetRaw == "guild" or targetRaw == "all" then
                    targetName = nil
                else
                    targetName = self:NormalizeName(parts[6])
                end
            end

            if targetName and targetName ~= self:GetPlayerName() then
                self.pendingSnapshot = nil
                return
            end

            if declaredSender and senderName and declaredSender ~= senderName then
                return
            end

            if not snapshotId or snapshotId == "" then
                return
            end

            self.pendingSnapshot = {
                id = snapshotId,
                sender = senderName,
                revision = revision,
                players = {},
                transactions = {},
                actorSequences = {},
                bosses = {},
                manualRaiders = {},
                manualInactiveRaiders = {},
                newMemberDefaultDkp = safeNumber(parts[7], nil),
                trackingEnabled = parts[8] ~= nil and safeNumber(parts[8], 1) ~= 0 or nil,
                startedAt = GetTime(),
            }
            return
        end

        if not self.pendingSnapshot then
            return
        end

        if self.pendingSnapshot.sender and senderName ~= self.pendingSnapshot.sender then
            return
        end

        if self.pendingSnapshot.startedAt and (GetTime() - self.pendingSnapshot.startedAt) > 15 then
            self.pendingSnapshot = nil
            return
        end

        if snapshotCommand == "PLAYER" then
            local snapshotId = trim(parts[3])
            local playerName = self:NormalizeName(parts[4])
            local dkpAmount = safeNumber(parts[5], nil)
            local updatedAt = safeNumber(parts[6], 0)
            local earnedAmount = safeNumber(parts[7], 0)
            local spentAmount = safeNumber(parts[8], 0)

            if dkpAmount == nil then
                -- Legacy format without snapshotId prefix.
                snapshotId = self.pendingSnapshot.id
                playerName = self:NormalizeName(parts[3])
                dkpAmount = safeNumber(parts[4], 0)
                updatedAt = 0
                earnedAmount = 0
                spentAmount = 0
            end

            if snapshotId ~= self.pendingSnapshot.id then
                return
            end

            if not playerName then
                return
            end

            self.pendingSnapshot.players[playerName] = {
                dkp = math.floor(safeNumber(dkpAmount, 0) + 0.5),
                updatedAt = safeNumber(updatedAt, 0),
                earned = math.floor(safeNumber(earnedAmount, 0) + 0.5),
                spent = math.floor(safeNumber(spentAmount, 0) + 0.5),
            }
            return
        end

        if snapshotCommand == "TX" then
            local snapshotId = trim(parts[3])
            if snapshotId ~= self.pendingSnapshot.id then
                return
            end

            local expectedOldValue = trim(parts[10])
            if expectedOldValue == "" then
                expectedOldValue = nil
            else
                expectedOldValue = safeNumber(expectedOldValue, nil)
            end

            local transaction = self:BuildPlayerTransaction(
                parts[7],
                parts[6],
                safeNumber(parts[8], 0),
                safeNumber(parts[9], 0),
                parts[11],
                parts[4],
                parts[5],
                expectedOldValue,
                safeNumber(parts[12], time())
            )
            transaction.actorSeq = safeNumber(parts[13], safeNumber(transaction.actorSeq, 0))
            transaction.resolvedTxId = trim(parts[14])
            transaction.resolutionAction = trim(parts[15])
            self.pendingSnapshot.transactions[#self.pendingSnapshot.transactions + 1] = transaction
            return
        end

        if snapshotCommand == "ACTOR" then
            local snapshotId = trim(parts[3])
            local actorName = self:NormalizeName(parts[4])
            if snapshotId ~= self.pendingSnapshot.id then
                return
            end
            if actorName then
                self.pendingSnapshot.actorSequences[actorName] = safeNumber(parts[5], 0)
            end
            return
        end

        if snapshotCommand == "BOSS" then
            local snapshotId = trim(parts[3])
            local npcId = tostring(safeNumber(parts[4], 0))
            local amount = safeNumber(parts[5], nil)
            local bossName = trim(parts[6])
            local zone = trim(parts[7])
            local encounterOrder = safeNumber(parts[8], 999)

            if amount == nil then
                snapshotId = self.pendingSnapshot.id
                npcId = tostring(safeNumber(parts[3], 0))
                amount = safeNumber(parts[4], 0)
                bossName = trim(parts[5])
                zone = ""
                encounterOrder = 999
            end

            if snapshotId ~= self.pendingSnapshot.id then
                return
            end

            local defaultBoss = DEFAULT_BOSSES[npcId]
            if zone == "" then
                zone = trim(defaultBoss and defaultBoss.zone or "Custom")
            end

            if encounterOrder == 999 and defaultBoss and defaultBoss.encounterOrder then
                encounterOrder = defaultBoss.encounterOrder
            end

            self.pendingSnapshot.bosses[npcId] = {
                amount = math.floor(safeNumber(amount, 0) + 0.5),
                name = bossName,
                zone = zone,
                encounterOrder = encounterOrder,
            }
            return
        end

        if snapshotCommand == "RAIDER" then
            local snapshotId = trim(parts[3])
            local playerName = self:NormalizeName(parts[4])
            if snapshotId ~= self.pendingSnapshot.id then
                return
            end
            if playerName then
                self.pendingSnapshot.manualRaiders[playerName] = true
            end
            return
        end

        if snapshotCommand == "NORAIDER" then
            local snapshotId = trim(parts[3])
            local playerName = self:NormalizeName(parts[4])
            if snapshotId ~= self.pendingSnapshot.id then
                return
            end
            if playerName then
                self.pendingSnapshot.manualInactiveRaiders[playerName] = true
            end
            return
        end

        if snapshotCommand == "END" then
            local snapshotId = trim(parts[3])
            local finishedRevision = safeNumber(parts[4], nil)

            if finishedRevision == nil then
                snapshotId = self.pendingSnapshot.id
                finishedRevision = safeNumber(parts[3], 0)
            end

            if snapshotId ~= self.pendingSnapshot.id then
                return
            end

            local mergedAny = false
            local replayedPlayers = {}
            for _, transaction in ipairs(self.pendingSnapshot.transactions or {}) do
                replayedPlayers[trim(transaction.target)] = true
                local applied = self:ApplyTransactionRecord(transaction, true, true)
                if applied then
                    mergedAny = true
                end
            end

            -- Keep snapshot state as a bootstrap fallback for players that have
            -- not yet been covered by replayed transactions.
            for playerName, incoming in pairs(self.pendingSnapshot.players) do
                local existing = self.guild.players[playerName]
                if not replayedPlayers[playerName] and (not existing or safeNumber(incoming.updatedAt, 0) > safeNumber(existing.updatedAt, 0)) then
                    self.guild.players[playerName] = incoming
                    mergedAny = true
                end
            end

            -- Boss config is officer-managed; use last-writer-wins by revision.
            if finishedRevision >= safeNumber(self.guild.revision, 0) then
                self.guild.bosses = self.pendingSnapshot.bosses
                self.guild.manualRaiders = self.pendingSnapshot.manualRaiders or {}
                self.guild.manualInactiveRaiders = self.pendingSnapshot.manualInactiveRaiders or {}
                if self.pendingSnapshot.newMemberDefaultDkp ~= nil then
                    self.guild.newMemberDefaultDkp = math.floor(safeNumber(self.pendingSnapshot.newMemberDefaultDkp, 0) + 0.5)
                end
                if self.pendingSnapshot.trackingEnabled ~= nil then
                    self.guild.trackingEnabled = self.pendingSnapshot.trackingEnabled == true
                end
                self.guild.revision = self.pendingSnapshot.revision
            end

            self.guild.knownTransactions = self.guild.knownTransactions or {}
            self.guild.knownTransactionsOrder = self.guild.knownTransactionsOrder or {}
            for actorName, sequence in pairs(self.pendingSnapshot.actorSequences or {}) do
                local normalizedActor = self:NormalizeName(actorName)
                if normalizedActor and sequence > self:GetActorSequence(normalizedActor) then
                    self.guild.actorSequences[normalizedActor] = safeNumber(sequence, 0)
                end
            end

            local snapshotSender = self.pendingSnapshot.sender or "unknown"
            if mergedAny then
                self:Print(string.format("Snapshot received from %s (rev %d). DKP changes merged.", snapshotSender, finishedRevision))
            else
                self:Print(string.format("Snapshot received from %s (rev %d). No newer DKP data.", snapshotSender, finishedRevision))
            end
            self:RefreshLeaderUI()
            self:RefreshAuctionPopup()
            self:RefreshHistoryFrame()
            self:RefreshOptionsUI()
            self:SyncActorSequencesWithPeer(snapshotSender, self.pendingSnapshot.actorSequences or {})
            self.pendingSnapshot = nil
            return
        end
    end
end

function addon:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(self.prefix)
        elseif RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(self.prefix)
        end

        SLASH_MDKP1 = "/mdkp"
        SlashCmdList.MDKP = function(message)
            addon:HandleSlashCommand(message)
        end

        self:EnsureDatabase()
        self:SyncGuildRoster()
        self:SyncTrackedGroupMembers()

        local uiReady, uiError = pcall(function()
            self:EnsureUI()
        end)
        if not uiReady then
            self:Print("UI failed to initialize: " .. trim(uiError), true)
        end

        self:EnsureItemLinkHook()

        if hooksecurefunc and not self.escapeHookInstalled then
            hooksecurefunc("CloseSpecialWindows", function()
                addon:CloseAllAddonWindows()
            end)
            self.escapeHookInstalled = true
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(5, function()
                addon:RequestSync()
            end)
        end

        if self:IsTestMode() then
            self:Print("TEST MODE is ON. Officer restrictions are bypassed and /mdkp test commands are enabled.", true)
            self:Print(self:IsTestAllLootEnabled() and "Test all-loot capture is ON." or "Test all-loot capture is OFF.", true)
        end

        self:Print("Loaded. Use /mdkp for commands.")
        return
    end

    if event == "PLAYER_GUILD_UPDATE" then
        self:EnsureDatabase()
        self:SyncGuildRoster(true)
        self:SyncTrackedGroupMembers()

        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                addon:RequestSync()
            end)
        end
        return
    end

    if event == "GUILD_ROSTER_UPDATE" then
        if not self.guild then
            self:EnsureDatabase()
        end
        self:SyncGuildRoster(true)
        self:SyncTrackedGroupMembers()

        -- Guild online/offline changes are a good signal that a newer client may have
        -- just logged in. Request a snapshot (throttled) so stale clients catch up.
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function()
                addon:RequestSync(false)
            end)
        else
            self:RequestSync(false)
        end
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
        if not self.guild then
            self:EnsureDatabase()
        end
        self:SyncTrackedGroupMembers()
        return
    end

    if event == "CHAT_MSG_ADDON" then
        self:HandleChatMessage(...)
        return
    end

    if event == "CHAT_MSG_WHISPER" then
        local message, sender = ...
        self:HandleWhisperBid(message, sender)
        return
    end

    if event == "LOOT_OPENED" then
        self:HandleLootOpened()
        return
    end

    if event == "ENCOUNTER_END" then
        self:HandleEncounterEnd(...)
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" and CombatLogGetCurrentEventInfo then
        local _, subEvent, _, _, _, _, _, destGUID, destName = CombatLogGetCurrentEventInfo()
        if subEvent == "PARTY_KILL" or subEvent == "UNIT_DIED" or subEvent == "UNIT_DESTROYED" then
            self:HandleBossKill(destGUID, destName)
        end
        return
    end
end

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_GUILD_UPDATE")
addon:RegisterEvent("GUILD_ROSTER_UPDATE")
addon:RegisterEvent("GROUP_ROSTER_UPDATE")
addon:RegisterEvent("RAID_ROSTER_UPDATE")
addon:RegisterEvent("CHAT_MSG_ADDON")
addon:RegisterEvent("CHAT_MSG_WHISPER")
addon:RegisterEvent("LOOT_OPENED")
addon:RegisterEvent("ENCOUNTER_END")
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
addon:SetScript("OnEvent", function(_, event, ...)
    addon:OnEvent(event, ...)
end)
addon:SetScript("OnUpdate", function(_, elapsed)
    addon:OnUpdate(elapsed)
end)