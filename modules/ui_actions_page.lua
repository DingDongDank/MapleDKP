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

function addon:CreateOptionsActionsPage(createPage)
    local actionsPage = createPage()
    actionsPage.description = self:CreateRowText(actionsPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -4)
    actionsPage.description:SetText("Use the selected member from the Members tab, or type a name manually.")
    actionsPage.adjustTargetLabel = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    actionsPage.adjustTargetLabel:SetPoint("TOPLEFT", 0, -34)
    actionsPage.adjustTargetLabel:SetText("Player")
    actionsPage.adjustTargetInput = self:CreateInput(actionsPage, 140, 24, "LEFT", actionsPage.adjustTargetLabel, "RIGHT", 8, 0, false)
    actionsPage.adjustTargetInput:SetMaxLetters(24)
    actionsPage.adjustAmountLabel = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    actionsPage.adjustAmountLabel:SetPoint("LEFT", actionsPage.adjustTargetInput, "RIGHT", 14, 0)
    actionsPage.adjustAmountLabel:SetText("Amount")
    actionsPage.adjustAmountInput = self:CreateInput(actionsPage, 70, 24, "LEFT", actionsPage.adjustAmountLabel, "RIGHT", 8, 0, true)
    actionsPage.adjustAmountInput:SetMaxLetters(6)
    actionsPage.adjustAmountInput:SetText("0")
    actionsPage.reasonLabel = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    actionsPage.reasonLabel:SetPoint("TOPLEFT", 0, -64)
    actionsPage.reasonLabel:SetText("Reason")
    actionsPage.adjustReasonInput = self:CreateInput(actionsPage, 300, 24, "LEFT", actionsPage.reasonLabel, "RIGHT", 8, 0, false)
    actionsPage.adjustReasonInput:SetMaxLetters(60)
    actionsPage.adjustReasonInput:SetText("Manual adjustment")
    actionsPage.addButton = self:CreateButton(actionsPage, "Add", 70, 22, "LEFT", actionsPage.adjustReasonInput, "RIGHT", 8, 0, function()
        addon:AdjustPlayer(actionsPage.adjustTargetInput:GetText(), actionsPage.adjustAmountInput:GetText(), trimText(actionsPage.adjustReasonInput:GetText()))
        addon:SetOptionsStatus("Applied DKP add adjustment.")
        addon:RefreshOptionsUI()
    end)
    actionsPage.subtractButton = self:CreateButton(actionsPage, "Subtract", 70, 22, "LEFT", actionsPage.addButton, "RIGHT", 8, 0, function()
        local amount = math.abs(math.floor(safeNumber(actionsPage.adjustAmountInput:GetText(), 0) + 0.5))
        addon:AdjustPlayer(actionsPage.adjustTargetInput:GetText(), -amount, trimText(actionsPage.adjustReasonInput:GetText()))
        addon:SetOptionsStatus("Applied DKP subtraction.")
        addon:RefreshOptionsUI()
    end)
    actionsPage.setButton = self:CreateButton(actionsPage, "Set", 70, 22, "LEFT", actionsPage.subtractButton, "RIGHT", 8, 0, function()
        addon:SetPlayerDKP(actionsPage.adjustTargetInput:GetText(), actionsPage.adjustAmountInput:GetText(), trimText(actionsPage.adjustReasonInput:GetText()))
        addon:SetOptionsStatus("Applied DKP set adjustment.")
        addon:RefreshOptionsUI()
    end)
    actionsPage.syncButton = self:CreateButton(actionsPage, "Sync", 80, 22, "TOPLEFT", actionsPage, "TOPLEFT", 0, -160, function()
        if addon:IsOfficer() then
            addon:SendSnapshot(nil)
            addon:SetOptionsStatus("Broadcasted a DKP snapshot to the guild.")
        else
            addon:RequestSync()
            addon:SetOptionsStatus("Requested the latest DKP snapshot from an officer.")
        end
    end)
    actionsPage.trackingStatusText = self:CreateRowText(actionsPage, "GameFontHighlightSmall", 260, "TOPLEFT", 0, -188)
    actionsPage.trackingStatusText:SetText("")
    actionsPage.trackingToggleButton = self:CreateButton(actionsPage, "Enable Tracking", 120, 22, "LEFT", actionsPage.trackingStatusText, "RIGHT", 10, 0, function()
        if not addon:IsOfficer() then
            addon:SetOptionsStatus("Only guild leaders and officers can change raid tracking.")
            addon:RefreshOptionsUI()
            return
        end

        addon:SetTrackingEnabled(not addon:IsTrackingEnabled())
        addon:SetOptionsStatus(addon:IsTrackingEnabled() and "Raid DKP tracking enabled." or "Raid DKP tracking disabled.")
        addon:RefreshOptionsUI()
    end)
    self:CreateActionsFullResetControls(actionsPage)
    actionsPage.testLootButton = self:CreateButton(actionsPage, "Loot Capture", 110, 22, "LEFT", actionsPage.syncButton, "RIGHT", 8, 0, function()
        if not addon:IsTestMode() then
            addon:SetOptionsStatus("Test loot capture is only available in test mode.")
            addon:RefreshOptionsUI()
            return
        end

        addon:SetTestAllLootEnabled(not addon:IsTestAllLootEnabled())
        addon:SetOptionsStatus(addon:IsTestAllLootEnabled() and "Enabled test loot auto-capture." or "Disabled test loot auto-capture.")
        addon:RefreshOptionsUI()
    end)
    actionsPage.testLootStatusText = self:CreateRowText(actionsPage, "GameFontHighlightSmall", 260, "LEFT", actionsPage.testLootButton, "RIGHT", 10, 0)
    actionsPage.testLootStatusText:SetText("")
    actionsPage.conflictSummaryText = self:CreateRowText(actionsPage, "GameFontHighlightSmall", 360, "TOPLEFT", 0, -246)
    actionsPage.reviewConflictsButton = self:CreateButton(actionsPage, "Review Conflicts", 120, 22, "LEFT", actionsPage.conflictSummaryText, "RIGHT", 10, 0, function()
        addon:SetOptionsTab("conflicts")
    end)
    actionsPage.historyHeader = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionsPage.historyHeader:SetPoint("TOPLEFT", 0, -272)
    actionsPage.historyHeader:SetText("Recent History")
    actionsPage.historyViewButton = self:CreateButton(actionsPage, "View All", 80, 22, "TOPRIGHT", actionsPage, "TOPRIGHT", -2, -266, function()
        addon.ui.historyFrame:Show()
        addon.ui.historyFrame:Raise()
        addon:RefreshHistoryFrame()
    end)
    actionsPage.historyRows = {}
    for index = 1, 12 do
        actionsPage.historyRows[index] = self:CreateRowText(actionsPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -278 - (index * 20))
    end

    return actionsPage
end
