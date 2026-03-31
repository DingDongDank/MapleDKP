local addon = MapleDKP
if not addon then
    return
end

function addon:CreateResetConfirmFrame(optionsFrame)
    local resetConfirmFrame = self:CreatePanel("MapleDKPResetConfirmFrame", 430, 220, "Confirm Full Reset")
    resetConfirmFrame:SetPoint("CENTER", optionsFrame, "CENTER", 0, 0)
    resetConfirmFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    resetConfirmFrame.infoText = self:CreateRowText(resetConfirmFrame, "GameFontHighlightSmall", 390, "TOPLEFT", 16, -40)
    resetConfirmFrame.infoText:SetText("This will wipe all DKP history and set every player's DKP to 0.\nType Confirm exactly to enable reset.")
    resetConfirmFrame.inputLabel = resetConfirmFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resetConfirmFrame.inputLabel:SetPoint("TOPLEFT", 16, -104)
    resetConfirmFrame.inputLabel:SetText("Type here")
    resetConfirmFrame.input = self:CreateInput(resetConfirmFrame, 140, 24, "LEFT", resetConfirmFrame.inputLabel, "RIGHT", 8, 0, false)
    resetConfirmFrame.input:SetMaxLetters(16)
    resetConfirmFrame.statusText = self:CreateRowText(resetConfirmFrame, "GameFontHighlightSmall", 390, "TOPLEFT", 16, -136)
    resetConfirmFrame.statusText:SetText("")
    resetConfirmFrame.confirmButton = self:CreateButton(resetConfirmFrame, "Confirm Reset", 120, 24, "BOTTOMLEFT", resetConfirmFrame, "BOTTOMLEFT", 16, 16, function()
        local typedText = resetConfirmFrame.input:GetText() or ""
        if typedText ~= "Confirm" then
            resetConfirmFrame.statusText:SetText("Type Confirm exactly to continue.")
            return
        end

        if addon:ExecuteFullDkpReset() then
            addon:SetOptionsStatus("Full reset complete: history wiped and all player DKP set to 0.")
            addon:RefreshOptionsUI()
            addon:RefreshHistoryFrame()
            resetConfirmFrame:Hide()
        else
            resetConfirmFrame.statusText:SetText("Full reset failed. Officer permissions are required.")
        end
    end)
    resetConfirmFrame.confirmButton:Disable()
    resetConfirmFrame.cancelButton = self:CreateButton(resetConfirmFrame, "Cancel", 90, 24, "LEFT", resetConfirmFrame.confirmButton, "RIGHT", 8, 0, function()
        resetConfirmFrame:Hide()
    end)
    resetConfirmFrame.input:SetScript("OnTextChanged", function(self)
        local typedText = self:GetText() or ""
        if typedText == "Confirm" then
            resetConfirmFrame.confirmButton:Enable()
            resetConfirmFrame.statusText:SetText("")
        else
            resetConfirmFrame.confirmButton:Disable()
        end
    end)
    resetConfirmFrame:SetScript("OnShow", function()
        resetConfirmFrame.input:SetText("")
        resetConfirmFrame.statusText:SetText("")
        resetConfirmFrame.confirmButton:Disable()
        resetConfirmFrame.input:SetFocus()
    end)

    return resetConfirmFrame
end

function addon:CreateActionsFullResetControls(actionsPage)
    actionsPage.fullResetButton = self:CreateButton(actionsPage, "Full Reset...", 120, 22, "TOPLEFT", actionsPage, "TOPLEFT", 0, -216, function()
        if not addon:IsOfficer() then
            addon:SetOptionsStatus("Only guild leaders and officers can run a full reset.")
            addon:RefreshOptionsUI()
            return
        end

        addon:EnsureUI()
        addon.ui.resetConfirmFrame:Show()
        addon.ui.resetConfirmFrame:Raise()
    end)
    actionsPage.fullResetWarningText = self:CreateRowText(actionsPage, "GameFontHighlightSmall", 420, "LEFT", actionsPage.fullResetButton, "RIGHT", 10, 0)
    actionsPage.fullResetWarningText:SetText("Wipes history and resets all player DKP to 0.")
end
