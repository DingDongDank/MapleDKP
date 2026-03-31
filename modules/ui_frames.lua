local addon = MapleDKP
if not addon then
    return
end

function addon:CreatePanel(name, width, height, title)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    if frame.HookScript then
        frame:HookScript("OnShow", function(self)
            self:Raise()
        end)
        frame:HookScript("OnMouseDown", function(self)
            self:Raise()
        end)
    end

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(true)
    background:SetColorTexture(0.05, 0.05, 0.05, 0.92)

    local header = frame:CreateTexture(nil, "ARTWORK")
    header:SetPoint("TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", -4, -4)
    header:SetHeight(24)
    header:SetColorTexture(0.14, 0.14, 0.14, 0.98)

    local dragHandle = CreateFrame("Frame", nil, frame)
    dragHandle:SetPoint("TOPLEFT", 6, -5)
    dragHandle:SetPoint("TOPRIGHT", -30, -5)
    dragHandle:SetHeight(22)
    dragHandle:EnableMouse(true)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    dragHandle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    frame.dragHandle = dragHandle

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOPLEFT", 12, -11)
    titleText:SetJustifyH("LEFT")
    titleText:SetText(title)
    frame.titleText = titleText

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", 2, 2)
    frame.closeButton = closeButton

    self:RegisterEscapeFrame(name)

    return frame
end

function addon:RegisterEscapeFrame(frameName)
    if not frameName or frameName == "" or not UISpecialFrames then
        return
    end

    for _, existingName in ipairs(UISpecialFrames) do
        if existingName == frameName then
            return
        end
    end

    table.insert(UISpecialFrames, frameName)
end

function addon:CreateRowText(parent, template, width, anchor, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint(anchor, x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    return text
end

function addon:CreateInput(parent, width, height, point, relativeTo, relativePoint, offsetX, offsetY, numeric)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(width, height)
    input:SetAutoFocus(false)
    input:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    input:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    input:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    if numeric then
        input:SetNumeric(true)
    end

    return input
end

function addon:CreateButton(parent, label, width, height, point, relativeTo, relativePoint, offsetX, offsetY, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    button:SetText(label)
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

function addon:CreateListButton(parent, width, height, point, relativeTo, relativePoint, offsetX, offsetY, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(true)
    highlight:SetColorTexture(1, 1, 1, 0.08)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 4, 0)
    text:SetPoint("RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    button.text = text

    if onClick then
        button:SetScript("OnClick", onClick)
    end

    return button
end

function addon:CreateVerticalSlider(parent, height, point, relativeTo, relativePoint, offsetX, offsetY, onChanged)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetOrientation("VERTICAL")
    slider:SetSize(18, height)
    slider:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
    slider:SetMinMaxValues(0, 0)
    slider:SetValue(0)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:SetScript("OnValueChanged", function(self, value)
        if onChanged then
            onChanged(math.floor(value + 0.5))
        end
    end)

    if slider.Text then
        slider.Text:Hide()
    end
    if slider.Low then
        slider.Low:Hide()
    end
    if slider.High then
        slider.High:Hide()
    end

    return slider
end

function addon:EnableMouseWheelScroll(frame, slider)
    if not frame or not slider or not frame.EnableMouseWheel then
        return
    end

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local minValue, maxValue = slider:GetMinMaxValues()
        if not minValue or not maxValue or maxValue <= minValue then
            return
        end

        local current = slider:GetValue() or 0
        local nextValue = current - delta
        if nextValue < minValue then
            nextValue = minValue
        elseif nextValue > maxValue then
            nextValue = maxValue
        end

        slider:SetValue(nextValue)
    end)
end
