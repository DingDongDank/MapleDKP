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
addon.recentLoot = {}
addon.auctionDuration = 30
addon.lastAuctionResult = nil
addon.ui = {
    initialized = false,
}

local DEFAULT_NEW_MEMBER_DKP = 180

local DEFAULT_BOSSES = {
    ["15550"] = { name = "Attumen the Huntsman", amount = 10, zone = "Karazhan", encounterOrder = 1 },
    ["15687"] = { name = "Moroes", amount = 10, zone = "Karazhan", encounterOrder = 2 },
    ["16457"] = { name = "Maiden of Virtue", amount = 10, zone = "Karazhan", encounterOrder = 3 },
    -- Opera events are represented as separate encounter entries.
    ["17521"] = { name = "Opera Event: Big Bad Wolf", amount = 10, zone = "Karazhan", encounterOrder = 4 },
    ["18168"] = { name = "Opera Event: The Crone", amount = 10, zone = "Karazhan", encounterOrder = 5 },
    ["17534"] = { name = "Opera Event: Romulo and Julianne", amount = 10, zone = "Karazhan", encounterOrder = 6 },
    ["15691"] = { name = "The Curator", amount = 10, zone = "Karazhan", encounterOrder = 7 },
    ["15688"] = { name = "Terestian Illhoof", amount = 10, zone = "Karazhan", encounterOrder = 8 },
    ["16524"] = { name = "Shade of Aran", amount = 10, zone = "Karazhan", encounterOrder = 9 },
    ["15689"] = { name = "Netherspite", amount = 10, zone = "Karazhan", encounterOrder = 10 },
    ["16816"] = { name = "Chess Event", amount = 10, zone = "Karazhan", encounterOrder = 11 },
    ["15690"] = { name = "Prince Malchezaar", amount = 20, zone = "Karazhan", encounterOrder = 12 },
    ["17225"] = { name = "Nightbane", amount = 10, zone = "Karazhan", encounterOrder = 13 },
    ["16179"] = { name = "Hyakiss the Lurker", amount = 10, zone = "Karazhan", encounterOrder = 14 },
    ["16180"] = { name = "Shadikith the Glider", amount = 10, zone = "Karazhan", encounterOrder = 15 },
    ["16181"] = { name = "Rokad the Ravager", amount = 10, zone = "Karazhan", encounterOrder = 16 },
    ["18831"] = { name = "High King Maulgar", amount = 10, zone = "Gruul's Lair", encounterOrder = 1 },
    ["19044"] = { name = "Gruul the Dragonkiller", amount = 20, zone = "Gruul's Lair", encounterOrder = 2 },
    ["17257"] = { name = "Magtheridon", amount = 20, zone = "Magtheridon's Lair", encounterOrder = 1 },
    ["21216"] = { name = "Hydross the Unstable", amount = 10, zone = "Serpentshrine Cavern", encounterOrder = 1 },
    ["21215"] = { name = "Leotheras the Blind", amount = 10, zone = "Serpentshrine Cavern", encounterOrder = 2 },
    ["21213"] = { name = "Morogrim Tidewalker", amount = 10, zone = "Serpentshrine Cavern", encounterOrder = 3 },
    ["21212"] = { name = "Lady Vashj", amount = 20, zone = "Serpentshrine Cavern", encounterOrder = 4 },
    ["19514"] = { name = "Al'ar", amount = 10, zone = "Tempest Keep", encounterOrder = 1 },
    ["19516"] = { name = "Void Reaver", amount = 10, zone = "Tempest Keep", encounterOrder = 2 },
    ["18805"] = { name = "High Astromancer Solarian", amount = 10, zone = "Tempest Keep", encounterOrder = 3 },
    ["19622"] = { name = "Kael'thas Sunstrider", amount = 20, zone = "Tempest Keep", encounterOrder = 4 },
    ["23576"] = { name = "Nalorakk", amount = 10, zone = "Zul'Aman", encounterOrder = 1 },
    ["23574"] = { name = "Akil'zon", amount = 10, zone = "Zul'Aman", encounterOrder = 2 },
    ["23578"] = { name = "Jan'alai the Dragonhawk Lord", amount = 10, zone = "Zul'Aman", encounterOrder = 3 },
    ["23577"] = { name = "Halazzi the Lynx Lord", amount = 10, zone = "Zul'Aman", encounterOrder = 4 },
    ["24239"] = { name = "Hex Lord Malacrass", amount = 10, zone = "Zul'Aman", encounterOrder = 5 },
    ["23863"] = { name = "Zul'jin", amount = 20, zone = "Zul'Aman", encounterOrder = 6 },
    ["22887"] = { name = "High Warlord Naj'entus", amount = 10, zone = "Black Temple", encounterOrder = 1 },
    ["22898"] = { name = "Supremus", amount = 10, zone = "Black Temple", encounterOrder = 2 },
    ["22841"] = { name = "Shade of Akama", amount = 10, zone = "Black Temple", encounterOrder = 3 },
    ["22871"] = { name = "Teron Gorefiend", amount = 10, zone = "Black Temple", encounterOrder = 4 },
    ["22948"] = { name = "Gurtogg Bloodboil", amount = 10, zone = "Black Temple", encounterOrder = 5 },
    ["23418"] = { name = "Reliquary of Souls", amount = 10, zone = "Black Temple", encounterOrder = 6 },
    ["22947"] = { name = "Mother Shahraz", amount = 10, zone = "Black Temple", encounterOrder = 7 },
    ["22949"] = { name = "Illidari Council", amount = 10, zone = "Black Temple", encounterOrder = 8 },
    ["22917"] = { name = "Illidan Stormrage", amount = 20, zone = "Black Temple", encounterOrder = 9 },
    ["24850"] = { name = "Kalecgos", amount = 10, zone = "Sunwell Plateau", encounterOrder = 1 },
    ["24882"] = { name = "Brutallus", amount = 10, zone = "Sunwell Plateau", encounterOrder = 2 },
    ["25038"] = { name = "Felmyst", amount = 10, zone = "Sunwell Plateau", encounterOrder = 3 },
    ["25165"] = { name = "Eredar Twins", amount = 10, zone = "Sunwell Plateau", encounterOrder = 4 },
    ["25741"] = { name = "M'uru", amount = 10, zone = "Sunwell Plateau", encounterOrder = 5 },
    ["25315"] = { name = "Kil'jaeden", amount = 20, zone = "Sunwell Plateau", encounterOrder = 6 },
}

-- Bump this number any time DEFAULT_BOSSES amounts, encounterOrder, or names change.
-- On load, if the stored guild.bossSchemaVersion is older, amount is also reset to defaults.
local BOSS_SCHEMA_VERSION = 3

local ZONE_SORT_ORDER = {
    ["Karazhan"] = 1,
    ["Gruul's Lair"] = 2,
    ["Magtheridon's Lair"] = 3,
    ["Serpentshrine Cavern"] = 4,
    ["Tempest Keep"] = 5,
    ["Zul'Aman"] = 6,
    ["Black Temple"] = 7,
    ["Sunwell Plateau"] = 8,
    ["Custom"] = 100,
}

local CLASS_NAME_TO_TOKEN = {
    ["PALADIN"] = "PALADIN",
    ["WARRIOR"] = "WARRIOR",
    ["HUNTER"] = "HUNTER",
    ["MAGE"] = "MAGE",
    ["SHAMAN"] = "SHAMAN",
    ["PRIEST"] = "PRIEST",
    ["WARLOCK"] = "WARLOCK",
    ["ROGUE"] = "ROGUE",
    ["DRUID"] = "DRUID",
}

local CLASS_COLOR_HEX = {
    ["PALADIN"] = "FFF58CBA", -- pink
    ["WARRIOR"] = "FF8B5A2B", -- brown
    ["HUNTER"] = "FF2E8B57", -- green
    ["MAGE"] = "FF87CEFA", -- light blue
    ["SHAMAN"] = "FF1E90FF", -- blue
    ["PRIEST"] = "FFFFFFFF", -- white
    ["WARLOCK"] = "FF9370DB", -- purple
    ["ROGUE"] = "FFFFFF66", -- yellow
    ["DRUID"] = "FFFF8C00", -- orange
}

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

function addon:CreatePanel(name, width, height, title)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

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

    return frame
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

function addon:GetSortedTrackedDkpEntries()
    local entries = {}
    local members = self:GetTrackedGroupMembers()

    for _, memberName in ipairs(members) do
        local info = self.guild and self.guild.players and self.guild.players[memberName]
        entries[#entries + 1] = {
            name = memberName,
            dkp = self:GetPlayerDKP(memberName),
            class = info and info.class or nil,
        }
    end

    table.sort(entries, function(left, right)
        if left.dkp == right.dkp then
            return left.name < right.name
        end
        return left.dkp > right.dkp
    end)

    return entries
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

function addon:GetSortedGuildDkpEntries()
    local entries = {}

    if not self.guild then
        return entries
    end

    for name, info in pairs(self.guild.players or {}) do
        entries[#entries + 1] = {
            name = name,
            dkp = safeNumber(info.dkp, 0),
        }
    end

    table.sort(entries, function(left, right)
        if left.dkp == right.dkp then
            return left.name < right.name
        end

        return left.dkp > right.dkp
    end)

    return entries
end

function addon:GetSortedGuildMemberEntriesAlphabetical()
    local entries = {}

    if not self.guild then
        return entries
    end

    for name, info in pairs(self.guild.players or {}) do
        entries[#entries + 1] = {
            name = name,
            dkp = safeNumber(info.dkp, 0),
        }
    end

    table.sort(entries, function(left, right)
        return left.name < right.name
    end)

    return entries
end

function addon:GetSortedGuildMemberEntriesByClass(secondaryByDkp)
    local entries = {}
    if not self.guild then return entries end
    for name, info in pairs(self.guild.players or {}) do
        entries[#entries + 1] = {
            name = name,
            dkp = safeNumber(info.dkp, 0),
            class = (info.class and info.class ~= "") and info.class or nil,
        }
    end
    table.sort(entries, function(left, right)
        local lc = left.class or ""
        local rc = right.class or ""
        if lc ~= rc then
            if lc == "" then return false end
            if rc == "" then return true end
            return lc < rc
        end
        if secondaryByDkp then
            if left.dkp ~= right.dkp then
                return left.dkp > right.dkp
            end
        end
        return left.name < right.name
    end)
    return entries
end

function addon:GetSortedBossEntries()
    local entries = {}

    if not self.guild then
        return entries
    end

    for npcId, boss in pairs(self.guild.bosses or {}) do
        entries[#entries + 1] = {
            npcId = npcId,
            name = trim(boss.name),
            amount = safeNumber(boss.amount, 0),
            zone = trim(boss.zone ~= nil and boss.zone or "Custom"),
            encounterOrder = safeNumber(boss.encounterOrder, 999),
        }
    end

    table.sort(entries, function(left, right)
        local leftZoneOrder = safeNumber(ZONE_SORT_ORDER[left.zone], 999)
        local rightZoneOrder = safeNumber(ZONE_SORT_ORDER[right.zone], 999)

        if leftZoneOrder == rightZoneOrder and left.zone == right.zone and left.encounterOrder == right.encounterOrder and left.name == right.name then
            return left.npcId < right.npcId
        end

        if leftZoneOrder == rightZoneOrder and left.zone == right.zone and left.encounterOrder == right.encounterOrder then
            return left.name < right.name
        end

        if leftZoneOrder == rightZoneOrder and left.zone == right.zone then
            return left.encounterOrder < right.encounterOrder
        end

        if leftZoneOrder == rightZoneOrder then
            return left.zone < right.zone
        end

        return leftZoneOrder < rightZoneOrder
    end)

    return entries
end

function addon:GetBossDisplayRows()
    local rows = {}
    local byZone = {}
    local zoneOrder = {}
    local collapsed = self.ui.optionsCollapsedZones or {}

    for _, entry in ipairs(self:GetSortedBossEntries()) do
        byZone[entry.zone] = byZone[entry.zone] or {}
        zoneOrder[entry.zone] = zoneOrder[entry.zone] or safeNumber(ZONE_SORT_ORDER[entry.zone], 999)
        byZone[entry.zone][#byZone[entry.zone] + 1] = entry
    end

    local zones = {}
    for zoneName in pairs(byZone) do
        zones[#zones + 1] = zoneName
    end

    table.sort(zones, function(left, right)
        local leftOrder = safeNumber(zoneOrder[left], 999)
        local rightOrder = safeNumber(zoneOrder[right], 999)
        if leftOrder == rightOrder then
            return left < right
        end
        return leftOrder < rightOrder
    end)

    for _, zoneName in ipairs(zones) do
        rows[#rows + 1] = {
            rowType = "zone",
            zone = zoneName,
            collapsed = collapsed[zoneName] ~= false,
            count = #byZone[zoneName],
        }

        if collapsed[zoneName] == false then
            for _, entry in ipairs(byZone[zoneName]) do
                rows[#rows + 1] = {
                    rowType = "boss",
                    zone = zoneName,
                    npcId = entry.npcId,
                    name = entry.name,
                    amount = entry.amount,
                    encounterOrder = entry.encounterOrder,
                }
            end
        end
    end

    return rows
end

function addon:ToggleBossZoneCollapsed(zoneName)
    zoneName = trim(zoneName)
    if zoneName == "" then
        return
    end

    self.ui.optionsCollapsedZones = self.ui.optionsCollapsedZones or {}
    self.ui.optionsCollapsedZones[zoneName] = (self.ui.optionsCollapsedZones[zoneName] == false)
    self:RefreshOptionsBossesPage()
end

function addon:SetOptionsStatus(message)
    if self.ui and self.ui.optionsFrame and self.ui.optionsFrame.statusText then
        self.ui.optionsFrame.statusText:SetText(trim(message))
    end
end

function addon:SelectOptionsMember(name)
    self.ui.optionsSelectedMember = self:NormalizeName(name)

    if self.ui and self.ui.optionsFrame and self.ui.optionsFrame.actionsPage and self.ui.optionsFrame.actionsPage.adjustTargetInput then
        self.ui.optionsFrame.actionsPage.adjustTargetInput:SetText(self.ui.optionsSelectedMember or "")
    end

    if self.ui and self.ui.optionsFrame and self:IsOfficer() then
        self:SetOptionsTab("actions")
        local actionsPage = self.ui.optionsFrame.actionsPage
        if actionsPage and actionsPage.adjustAmountInput then
            actionsPage.adjustAmountInput:SetFocus()
            actionsPage.adjustAmountInput:HighlightText()
        end
        return
    end

    self:RefreshOptionsUI()
end

function addon:SelectOptionsBoss(npcId)
    self.ui.optionsSelectedBossNpcId = tostring(safeNumber(npcId, 0))
    self:RefreshOptionsUI()
end

function addon:SetOptionsTab(tabName)
    if not self.ui.initialized or not self.ui.optionsFrame then
        return
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
    if page.sortByClassButton then
        if sortMode == "class" then page.sortByClassButton:Disable() else page.sortByClassButton:Enable() end
    end
    local selectedName = self.ui.optionsSelectedMember
    local columns = safeNumber(page.columns, 1)
    local rowsPerColumn = safeNumber(page.rowsPerColumn, 20)
    local totalRows = math.ceil(#entries / columns)
    local maxOffset = math.max(0, totalRows - rowsPerColumn)
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
        local entryIndex = ((offset + rowIndex - 1) * columns) + columnIndex
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
                button.dkpText:Show()
            end
            button:Show()
            button:Enable()
        else
            button.entryName = nil
            button.text:SetText("")
            if button.dkpText then
                button.dkpText:SetText("")
                button.dkpText:Hide()
            end
            button:Hide()
        end
    end

    if selectedName then
        page.selectedText:SetText(string.format("Selected: %s (%d DKP)", selectedName, self:GetPlayerDKP(selectedName)))
    else
        page.selectedText:SetText("Select a member to edit their DKP.")
    end

    local startIndex = #entries == 0 and 0 or (offset * columns + 1)
    local endIndex = math.min(#entries, (offset + rowsPerColumn) * columns)
    local sortLabel = sortMode == "dkp" and "DKP desc" or sortMode == "class" and (page.classSecondaryByDkp and "Class+DKP" or "Class") or "A-Z"
    page.summaryText:SetText(string.format("Tracking %d players. Showing %d-%d (%s).", #entries, startIndex, endIndex, sortLabel))
    page.quietStatusText:SetText(self:IsQuietMode() and "Quiet mode: On" or "Quiet mode: Off")
    page.toggleQuietButton:SetText(self:IsQuietMode() and "Disable Quiet" or "Enable Quiet")
end

function addon:RefreshOptionsActionsPage()
    local optionsFrame = self.ui.optionsFrame
    if not optionsFrame or not optionsFrame.actionsPage then
        return
    end

    local page = optionsFrame.actionsPage
    if page.defaultMemberDkpInput and not page.defaultMemberDkpInput:HasFocus() then
        page.defaultMemberDkpInput:SetText(tostring(self:GetNewMemberDefaultDkp()))
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
end

function addon:RefreshOptionsBossesPage()
    local optionsFrame = self.ui.optionsFrame
    if not optionsFrame or not optionsFrame.bossesPage then
        return
    end

    local page = optionsFrame.bossesPage
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
end

function addon:ToggleOptionsUI()
    self:EnsureUI()

    if self.ui.optionsFrame:IsShown() then
        self.ui.optionsFrame:Hide()
        return
    end

    self.ui.optionsFrame:Show()
    self:RefreshOptionsUI()
end

function addon:ShowOptionsUI()
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
end

function addon:EnsureUI()
    if self.ui.initialized then
        return
    end

    local controlFrame = self:CreatePanel("MapleDKPControlFrame", 430, 460, "Maple DKP Loot Control")
    controlFrame:SetPoint("CENTER", UIParent, "CENTER", -250, 30)
    controlFrame:SetFrameStrata("DIALOG")
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
    auctionFrame:SetFrameStrata("DIALOG")
    auctionFrame:SetToplevel(true)
    auctionFrame.closeButton:Hide()
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
    raidDkpFrame.subtitle = self:CreateRowText(raidDkpFrame, "GameFontHighlightSmall", 280, "TOPLEFT", 16, -40)
    raidDkpFrame.subtitle:SetText("")
    raidDkpFrame.rows = {}
    for index = 1, 25 do
        raidDkpFrame.rows[index] = self:CreateRowText(raidDkpFrame, "GameFontHighlightSmall", 280, "TOPLEFT", 16, -40 - (index * 20))
    end

    local noticeFrame = self:CreatePanel("MapleDKPLootNoticeFrame", 300, 170, "Boss Loot")
    noticeFrame:SetPoint("TOP", UIParent, "TOP", 0, -160)
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
    historyFrame:SetFrameStrata("DIALOG")
    historyFrame:SetToplevel(true)
    historyFrame.closeButton:SetScript("OnClick", function()
        historyFrame:Hide()
    end)

    historyFrame.scrollOffset = 0
    historyFrame.scrollBar = self:CreateVerticalSlider(historyFrame, 750, "TOPRIGHT", historyFrame, "TOPRIGHT", 0, -42, function(value)
        historyFrame.scrollOffset = value
        addon:RefreshHistoryFrame()
    end)

    historyFrame.summaryText = self:CreateRowText(historyFrame, "GameFontHighlightSmall", 750, "TOPLEFT", 16, -40)
    historyFrame.summaryText:SetText("")

    historyFrame.historyRows = {}
    for index = 1, 24 do
        historyFrame.historyRows[index] = self:CreateRowText(historyFrame, "GameFontHighlightSmall", 750, "TOPLEFT", 16, -60 - ((index - 1) * 20))
    end

    local optionsFrame = self:CreatePanel("MapleDKPOptionsFrame", 700, 650, "Maple DKP Options")
    optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 40, 20)

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
    membersPage.quietStatusText = self:CreateRowText(membersPage, "GameFontHighlightSmall", 180, "TOPLEFT", 0, -4)
    membersPage.toggleQuietButton = self:CreateButton(membersPage, "Enable Quiet", 100, 22, "TOPRIGHT", membersPage, "TOPRIGHT", 0, -4, function()
        addon:SetQuietMode(not addon:IsQuietMode())
        addon:SetOptionsStatus(addon:IsQuietMode() and "Quiet mode enabled." or "Quiet mode disabled.")
        addon:RefreshOptionsUI()
    end)
    membersPage.summaryText = self:CreateRowText(membersPage, "GameFontHighlightSmall", 400, "TOPLEFT", 0, -34)
    membersPage.selectedText = self:CreateRowText(membersPage, "GameFontHighlightSmall", 420, "TOPLEFT", 0, -54)
    membersPage.sortMode = "name"
    membersPage.classSecondaryByDkp = false
    membersPage.sortByDkpButton = self:CreateButton(membersPage, "DKP", 68, 20, "TOPRIGHT", membersPage, "TOPRIGHT", -20, -32, function()
        membersPage.sortMode = "dkp"
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
    membersPage.scrollOffset = 0
    membersPage.columns = 3
    membersPage.rowsPerColumn = 20
    membersPage.scrollBar = self:CreateVerticalSlider(membersPage, 458, "TOPRIGHT", membersPage, "TOPRIGHT", 0, -82, function(value)
        membersPage.scrollOffset = value
        addon:RefreshOptionsMembersPage()
    end)
    membersPage.memberButtons = {}
    local memberColumnWidth = 202
    local memberColumnGap = 8
    local memberDkpWidth = 48
    for rowIndex = 1, membersPage.rowsPerColumn do
        for columnIndex = 1, membersPage.columns do
            local offsetX = (columnIndex - 1) * (memberColumnWidth + memberColumnGap)
            local button = self:CreateListButton(membersPage, memberColumnWidth, 18, "TOPLEFT", membersPage, "TOPLEFT", offsetX, -82 - ((rowIndex - 1) * 22), function(clickedButton)
                if clickedButton.entryName then
                    addon:SelectOptionsMember(clickedButton.entryName)
                    addon:RefreshOptionsMembersPage()
                end
            end)
            -- Shrink the name text so it doesn't overlap the DKP number on the right.
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", button, "LEFT", 4, 0)
            button.text:SetPoint("RIGHT", button, "RIGHT", -(memberDkpWidth + 6), 0)
            -- Right-aligned DKP value label.
            button.dkpText = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.dkpText:SetWidth(memberDkpWidth)
            button.dkpText:SetPoint("RIGHT", button, "RIGHT", -4, 0)
            button.dkpText:SetJustifyH("RIGHT")
            button.rowIndex = rowIndex
            button.columnIndex = columnIndex
            membersPage.memberButtons[#membersPage.memberButtons + 1] = button
        end
    end
    self:EnableMouseWheelScroll(membersPage, membersPage.scrollBar)

    -- Inline DKP editing controls
    membersPage.editDivider = membersPage:CreateTexture(nil, "BACKGROUND")
    membersPage.editDivider:SetColorTexture(0.5, 0.5, 0.5, 0.3)
    membersPage.editDivider:SetPoint("TOPLEFT", 0, -550)
    membersPage.editDivider:SetSize(685, 1)

    membersPage.editLabel = membersPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    membersPage.editLabel:SetPoint("TOPLEFT", 0, -563)
    membersPage.editLabel:SetText("Quick Edit")

    local editAmountLabel = membersPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editAmountLabel:SetPoint("TOPLEFT", 0, -585)
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

    local actionsPage = createPage()
    actionsPage.description = self:CreateRowText(actionsPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -4)
    actionsPage.description:SetText("Use the selected member from the Members tab, or type a name manually.")
    local adjustTargetLabel = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    adjustTargetLabel:SetPoint("TOPLEFT", 0, -34)
    adjustTargetLabel:SetText("Player")
    actionsPage.adjustTargetInput = self:CreateInput(actionsPage, 140, 24, "LEFT", adjustTargetLabel, "RIGHT", 8, 0, false)
    actionsPage.adjustTargetInput:SetMaxLetters(24)
    local adjustAmountLabel = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    adjustAmountLabel:SetPoint("LEFT", actionsPage.adjustTargetInput, "RIGHT", 14, 0)
    adjustAmountLabel:SetText("Amount")
    actionsPage.adjustAmountInput = self:CreateInput(actionsPage, 70, 24, "LEFT", adjustAmountLabel, "RIGHT", 8, 0, true)
    actionsPage.adjustAmountInput:SetMaxLetters(6)
    actionsPage.adjustAmountInput:SetText("0")
    local reasonLabel = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    reasonLabel:SetPoint("TOPLEFT", 0, -64)
    reasonLabel:SetText("Reason")
    actionsPage.adjustReasonInput = self:CreateInput(actionsPage, 300, 24, "LEFT", reasonLabel, "RIGHT", 8, 0, false)
    actionsPage.adjustReasonInput:SetMaxLetters(60)
    actionsPage.adjustReasonInput:SetText("Manual adjustment")
    actionsPage.addButton = self:CreateButton(actionsPage, "Add", 70, 22, "LEFT", actionsPage.adjustReasonInput, "RIGHT", 8, 0, function()
        addon:AdjustPlayer(actionsPage.adjustTargetInput:GetText(), actionsPage.adjustAmountInput:GetText(), trim(actionsPage.adjustReasonInput:GetText()))
        addon:SetOptionsStatus("Applied DKP add adjustment.")
        addon:RefreshOptionsUI()
    end)
    actionsPage.subtractButton = self:CreateButton(actionsPage, "Subtract", 70, 22, "LEFT", actionsPage.addButton, "RIGHT", 8, 0, function()
        local amount = math.abs(math.floor(safeNumber(actionsPage.adjustAmountInput:GetText(), 0) + 0.5))
        addon:AdjustPlayer(actionsPage.adjustTargetInput:GetText(), -amount, trim(actionsPage.adjustReasonInput:GetText()))
        addon:SetOptionsStatus("Applied DKP subtraction.")
        addon:RefreshOptionsUI()
    end)
    actionsPage.setButton = self:CreateButton(actionsPage, "Set", 70, 22, "LEFT", actionsPage.subtractButton, "RIGHT", 8, 0, function()
        addon:SetPlayerDKP(actionsPage.adjustTargetInput:GetText(), actionsPage.adjustAmountInput:GetText(), trim(actionsPage.adjustReasonInput:GetText()))
        addon:SetOptionsStatus("Applied DKP set adjustment.")
        addon:RefreshOptionsUI()
    end)
    local awardLabel = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    awardLabel:SetPoint("TOPLEFT", 0, -104)
    awardLabel:SetText("Raid Award")
    actionsPage.awardAmountInput = self:CreateInput(actionsPage, 70, 24, "LEFT", awardLabel, "RIGHT", 8, 0, true)
    actionsPage.awardAmountInput:SetMaxLetters(5)
    actionsPage.awardAmountInput:SetText("10")
    local awardReasonLabel = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    awardReasonLabel:SetPoint("LEFT", actionsPage.awardAmountInput, "RIGHT", 14, 0)
    awardReasonLabel:SetText("Reason")
    actionsPage.awardReasonInput = self:CreateInput(actionsPage, 250, 24, "LEFT", awardReasonLabel, "RIGHT", 8, 0, false)
    actionsPage.awardReasonInput:SetMaxLetters(60)
    actionsPage.awardReasonInput:SetText("Raid award")
    actionsPage.awardButton = self:CreateButton(actionsPage, "Award", 70, 22, "LEFT", actionsPage.awardReasonInput, "RIGHT", 8, 0, function()
        addon:AwardRaid(actionsPage.awardAmountInput:GetText(), trim(actionsPage.awardReasonInput:GetText()))
        addon:SetOptionsStatus("Awarded raid DKP.")
        addon:RefreshOptionsUI()
    end)
    local defaultMemberDkpLabel = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    defaultMemberDkpLabel:SetPoint("TOPLEFT", 0, -130)
    defaultMemberDkpLabel:SetText("New Member DKP")
    actionsPage.defaultMemberDkpInput = self:CreateInput(actionsPage, 60, 24, "LEFT", defaultMemberDkpLabel, "RIGHT", 8, 0, true)
    actionsPage.defaultMemberDkpInput:SetMaxLetters(6)
    actionsPage.defaultMemberDkpInput:SetText(tostring(self:GetNewMemberDefaultDkp()))
    actionsPage.defaultMemberDkpButton = self:CreateButton(actionsPage, "Save", 64, 22, "LEFT", actionsPage.defaultMemberDkpInput, "RIGHT", 8, 0, function()
        if addon:SetNewMemberDefaultDkp(actionsPage.defaultMemberDkpInput:GetText()) then
            addon:SetOptionsStatus("Updated new-member default DKP.")
        else
            addon:SetOptionsStatus("Could not update new-member default DKP.")
        end
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
    actionsPage.testLootStatusText = self:CreateRowText(actionsPage, "GameFontHighlightSmall", 300, "LEFT", actionsPage.testLootButton, "RIGHT", 10, 0)
    actionsPage.testLootStatusText:SetText("")
    actionsPage.historyHeader = actionsPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionsPage.historyHeader:SetPoint("TOPLEFT", 0, -184)
    actionsPage.historyHeader:SetText("Recent History")
    actionsPage.historyViewButton = self:CreateButton(actionsPage, "View All", 80, 22, "TOPRIGHT", actionsPage, "TOPRIGHT", -2, -178, function()
        addon.ui.historyFrame:Show()
        addon.ui.historyFrame:Raise()
        addon:RefreshHistoryFrame()
    end)
    actionsPage.historyRows = {}
    for index = 1, 12 do
        actionsPage.historyRows[index] = self:CreateRowText(actionsPage, "GameFontHighlightSmall", 620, "TOPLEFT", 0, -190 - (index * 20))
    end

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
    local bossIdHeader = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossIdHeader:SetPoint("TOPLEFT", 350, -64)
    bossIdHeader:SetText("NPC ID")
    bossesPage.bossIdValue = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossIdValue:SetPoint("LEFT", bossIdHeader, "RIGHT", 8, 0)
    bossesPage.bossIdValue:SetJustifyH("LEFT")
    local bossNameHeader = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossNameHeader:SetPoint("TOPLEFT", 350, -92)
    bossNameHeader:SetText("Boss")
    bossesPage.bossNameValue = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossNameValue:SetPoint("LEFT", bossNameHeader, "RIGHT", 8, 0)
    bossesPage.bossNameValue:SetJustifyH("LEFT")
    local bossZoneHeader = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossZoneHeader:SetPoint("TOPLEFT", 350, -120)
    bossZoneHeader:SetText("Dungeon")
    bossesPage.bossZoneValue = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossesPage.bossZoneValue:SetPoint("LEFT", bossZoneHeader, "RIGHT", 8, 0)
    bossesPage.bossZoneValue:SetJustifyH("LEFT")
    local bossAmountHeader = bossesPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bossAmountHeader:SetPoint("TOPLEFT", 350, -152)
    bossAmountHeader:SetText("Award")
    bossesPage.bossAmountInput = self:CreateInput(bossesPage, 80, 24, "LEFT", bossAmountHeader, "RIGHT", 8, 0, true)
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

    optionsFrame.membersPage = membersPage
    optionsFrame.actionsPage = actionsPage
    optionsFrame.bossesPage = bossesPage
    optionsFrame.auctionPage = auctionPage
    optionsFrame.pages.members = membersPage
    optionsFrame.pages.actions = actionsPage
    optionsFrame.pages.bosses = bossesPage
    optionsFrame.pages.auction = auctionPage
    optionsFrame.activeTab = "members"

    optionsFrame.officerControls = {
        actionsPage.addButton,
        actionsPage.subtractButton,
        actionsPage.setButton,
        actionsPage.awardButton,
        actionsPage.defaultMemberDkpInput,
        actionsPage.defaultMemberDkpButton,
        auctionPage.startAuctionButton,
        auctionPage.closeAuctionButton,
        auctionPage.openLootButton,
        actionsPage.adjustTargetInput,
        actionsPage.adjustAmountInput,
        actionsPage.adjustReasonInput,
        actionsPage.awardAmountInput,
        actionsPage.awardReasonInput,
        bossesPage.bossAmountInput,
        bossesPage.saveBossButton,
        auctionPage.auctionItemInput,
        auctionPage.auctionMinInput,
        auctionPage.auctionDurationInput,
    }

    optionsFrame:SetScript("OnShow", function()
        addon:SetOptionsTab(optionsFrame.activeTab or "members")
    end)

    self.ui.controlFrame = controlFrame
    self.ui.auctionFrame = auctionFrame
    self.ui.raidDkpFrame = raidDkpFrame
    self.ui.noticeFrame = noticeFrame
    self.ui.historyFrame = historyFrame
    self.ui.optionsFrame = optionsFrame
    self.ui.initialized = true
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

function addon:RemoveRecentLoot(itemLink)
    for index, value in ipairs(self.recentLoot) do
        if value == itemLink then
            table.remove(self.recentLoot, index)
            return
        end
    end
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
    if historyFrame.summaryText then
        historyFrame.summaryText:SetText(string.format("Showing %d-%d of %d total entries", startIndex, endIndex, totalRows))
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
    end

    auctionFrame:Show()
    auctionFrame:Raise()
    self:RefreshRaidDkpPopup()
end

function addon:ReopenAuctionBidWindow(showNoAuctionMessage)
    if not self.activeAuction then
        if showNoAuctionMessage then
            self:Print("There is no active auction.")
        end
        return false
    end

    self:EnsureUI()
    self:RefreshAuctionPopup()
    return true
end

function addon:ShowLootNotice()
    self:EnsureUI()
    self.ui.noticeExpireAt = GetTime() + 20
    self:RefreshLootNotice()
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

function addon:OnUpdate(elapsed)
    self.ui.elapsed = (self.ui.elapsed or 0) + elapsed
    if self.ui.elapsed < 0.2 then
        return
    end

    self.ui.elapsed = 0

    if self.activeAuction and (self.activeAuction.expiresAt or 0) <= GetTime() and not self.activeAuction.closing then
        if self.activeAuction.startedBy == self:GetPlayerName() and self:IsOfficer() then
            self.activeAuction.closing = true
            self:CloseAuction()
            return
        end
    end

    if self.ui.initialized then
        self:RefreshLeaderUI()
        self:RefreshAuctionPopup()
        self:RefreshLootNotice()
        self:RefreshRaidDkpPopup()
    end
end

function addon:Print(message, force)
    if self:IsQuietMode() and not force then
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800Maple DKP|r " .. trim(message))
end

function addon:IsQuietMode()
    return self.db and self.db.settings and self.db.settings.quiet == true
end

function addon:SetQuietMode(enabled)
    if not self.db then
        return
    end

    self.db.settings = self.db.settings or {}
    self.db.settings.quiet = enabled and true or false
    self:Print(self.db.settings.quiet and "Quiet mode enabled." or "Quiet mode disabled.", true)
end

function addon:IsTestAllLootEnabled()
    return self.db and self.db.settings and self.db.settings.testAllLoot == true
end

function addon:SetTestAllLootEnabled(enabled)
    if not self.db then
        return
    end

    self.db.settings = self.db.settings or {}
    self.db.settings.testAllLoot = enabled and true or false
    self:Print(self.db.settings.testAllLoot and "Test all-loot capture enabled." or "Test all-loot capture disabled.", true)
end

function addon:GetNewMemberDefaultDkp()
    if not self.guild then
        return DEFAULT_NEW_MEMBER_DKP
    end

    return math.floor(safeNumber(self.guild.newMemberDefaultDkp, DEFAULT_NEW_MEMBER_DKP) + 0.5)
end

function addon:SetNewMemberDefaultDkp(value)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can change the new-member default DKP.")
        return false
    end

    local parsed = safeNumber(value, nil)
    if parsed == nil then
        self:Print("Usage: /mdkp defaultdkp Value")
    auctionPage.reopenBidButton = self:CreateButton(auctionPage, "Bid Window", 100, 22, "LEFT", auctionPage.openLootButton, "RIGHT", 10, 0, function()
        if addon:ReopenAuctionBidWindow(false) then
            addon:SetOptionsStatus("Reopened the bid window.")
        else
            addon:SetOptionsStatus("There is no active auction to reopen.")
        end
    end)
        return false
    end

    local resolvedValue = math.floor(parsed + 0.5)
    if resolvedValue < 0 then
        self:Print("Default DKP cannot be negative.")
    self:Print("/mdkp auction reopen")
        return false
    end

    self.guild.newMemberDefaultDkp = resolvedValue
    self:NextRevision()
    self:SendMessage(table.concat({ "CFG", "NEWMEMBERDKP", tostring(resolvedValue) }, "\t"))
    self:Print(string.format("New-member default DKP set to %d.", resolvedValue))
    return true
end

function addon:NormalizeName(name)
    name = trim(name)

    if name == "" then
        return nil
    end

    local shortName = string.match(name, "^[^-]+")
    if not shortName or shortName == "" then
        return nil
    end

    return shortName
end

function addon:GetPlayerName()
    if not self.playerName then
        self.playerName = self:NormalizeName(UnitName("player"))
    end

    return self.playerName
end

function addon:GetGuildName()
    local guildName = GetGuildInfo("player")
    self.guildName = guildName and trim(guildName) or nil
    return self.guildName
end

function addon:IsGuildRosterMember(name)
    local normalizedName = self:NormalizeName(name)
    if not normalizedName then
        return false
    end

    return self.guildRosterMembers and self.guildRosterMembers[normalizedName] == true
end

function addon:IsTestMode()
    return TEST_MODE == true
end

function addon:IsOfficer()
    if self:IsTestMode() then
        return true
    end

    if not IsInGuild() then
        return false
    end

    if CanEditOfficerNote then
        return CanEditOfficerNote()
    end

    return false
end

function addon:EnsureDatabase()
    MapleDKPDB = MapleDKPDB or {}
    MapleDKPDB.version = 1
    MapleDKPDB.guilds = MapleDKPDB.guilds or {}
    MapleDKPDB.settings = MapleDKPDB.settings or { quiet = false, testAllLoot = false }

    self.db = MapleDKPDB
    self.db.settings = self.db.settings or {}
    if self.db.settings.quiet == nil then
        self.db.settings.quiet = false
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
    }

    self.guild = self.db.guilds[guildName]
    self.guild.players = self.guild.players or {}
    self.guild.history = self.guild.history or {}
    self.guild.activityLog = self.guild.activityLog or {}
    self.guild.bosses = self.guild.bosses or {}
    self.guild.knownTransactions = self.guild.knownTransactions or {}
    self.guild.revision = safeNumber(self.guild.revision, 0)
    self.guild.newMemberDefaultDkp = math.floor(safeNumber(self.guild.newMemberDefaultDkp, DEFAULT_NEW_MEMBER_DKP) + 0.5)

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
                playerData.updatedAt = time()
            end
        end
        self.guild.startingDkpSeeded = true
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
            updatedAt = time(),
            class = nil,
        }
        self.guild.players[name] = playerData
    elseif playerData.dkp == nil then
        playerData.dkp = self:IsGuildRosterMember(name) and self:GetNewMemberDefaultDkp() or 0
        playerData.updatedAt = time()
    end

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

    return string.format("%s %s", stamp, trim(entry.reason))
end

function addon:NextRevision()
    self.guild.revision = safeNumber(self.guild.revision, 0) + 1
    return self.guild.revision
end

function addon:MakeTransactionId(kind, target)
    return table.concat({
        kind,
        self:GetPlayerName() or "unknown",
        target or "guild",
        tostring(time()),
        tostring(math.random(1000, 9999)),
    }, ":")
end

function addon:RegisterTransaction(txId)
    self.guild.knownTransactions[txId] = true
    local ordered = self.guild.knownTransactionsOrder or {}
    ordered[#ordered + 1] = txId
    self.guild.knownTransactionsOrder = ordered

    while #ordered > 400 do
        local oldest = table.remove(ordered, 1)
        self.guild.knownTransactions[oldest] = nil
    end
end

function addon:HasSeenTransaction(txId)
    return self.guild and self.guild.knownTransactions and self.guild.knownTransactions[txId]
end

function addon:SendMessage(message, channel, targetName)
    if not message or message == "" then
        return
    end

    channel = trim(channel)
    if channel == "" then
        channel = "GUILD"
    end

    if channel == "GUILD" and not IsInGuild() then
        return
    end

    targetName = self:NormalizeName(targetName)
    if channel == "WHISPER" and not targetName then
        return
    end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(self.prefix, message, channel, targetName)
        return
    end

    if SendAddonMessage then
        SendAddonMessage(self.prefix, message, channel, targetName)
    end
end

function addon:BroadcastPlayerUpdate(targetName, delta, newValue, reason, txId, actor)
    self:SendMessage(table.concat({
        "TX",
        "PLAYER",
        txId,
        trim(actor),
        trim(targetName),
        tostring(delta),
        tostring(newValue),
        trim(reason),
    }, "\t"))
end

function addon:ApplyPlayerTransaction(targetName, delta, newValue, reason, txId, actor, silent)
    if not self.guild then
        return false
    end

    targetName = self:NormalizeName(targetName)
    if not targetName or not txId or txId == "" then
        return false
    end

    if self:HasSeenTransaction(txId) then
        return false
    end

    local oldValue = self:GetPlayerDKP(targetName)
    local resolvedValue = safeNumber(newValue, oldValue + safeNumber(delta, 0))
    local appliedDelta = resolvedValue - oldValue
    self:SetPlayerValue(targetName, resolvedValue)
    self:RegisterTransaction(txId)
    self:NextRevision()
    self:AppendHistory(string.format("%s -> %s (%+d) by %s [%s]", targetName, resolvedValue, appliedDelta, actor or "unknown", trim(reason)))
    self:AppendActivity({
        type = "PLAYER_TX",
        actor = actor,
        target = targetName,
        delta = appliedDelta,
        oldValue = oldValue,
        newValue = resolvedValue,
        reason = reason,
        txId = txId,
    })

    if not silent then
        self:Print(string.format("%s now has %d DKP (%+d).", targetName, resolvedValue, appliedDelta))
    end

    return true
end

function addon:AdjustPlayer(targetName, delta, reason)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can change DKP.")
        return
    end

    local name = self:NormalizeName(targetName)
    local amount = math.floor(safeNumber(delta, 0) + 0.5)
    if not name then
        self:Print("Usage: /mdkp add PlayerName Amount Reason")
        return
    end

    local newValue = self:GetPlayerDKP(name) + amount
    local txId = self:MakeTransactionId("ADD", name)
    if self:ApplyPlayerTransaction(name, amount, newValue, reason or "Manual adjustment", txId, self:GetPlayerName(), true) then
        self:BroadcastPlayerUpdate(name, amount, newValue, reason or "Manual adjustment", txId, self:GetPlayerName())
        self:Print(string.format("Adjusted %s by %+d DKP. New total: %d.", name, amount, newValue))
    end
end

function addon:SetPlayerDKP(targetName, value, reason)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can set DKP.")
        return
    end

    local name = self:NormalizeName(targetName)
    local resolvedValue = math.floor(safeNumber(value, 0) + 0.5)
    if not name then
        self:Print("Usage: /mdkp set PlayerName Value Reason")
        return
    end

    local currentValue = self:GetPlayerDKP(name)
    local delta = resolvedValue - currentValue
    local txId = self:MakeTransactionId("SET", name)
    if self:ApplyPlayerTransaction(name, delta, resolvedValue, reason or "Manual set", txId, self:GetPlayerName(), true) then
        self:BroadcastPlayerUpdate(name, delta, resolvedValue, reason or "Manual set", txId, self:GetPlayerName())
        self:Print(string.format("Set %s to %d DKP.", name, resolvedValue))
    end
end

function addon:ListStandings()
    if not self.guild then
        self:Print("No guild data loaded yet.")
        return
    end

    local standings = {}
    for name, info in pairs(self.guild.players) do
        standings[#standings + 1] = { name = name, dkp = safeNumber(info.dkp, 0) }
    end

    table.sort(standings, function(left, right)
        if left.dkp == right.dkp then
            return left.name < right.name
        end

        return left.dkp > right.dkp
    end)

    self:Print("Top DKP standings:")
    for index = 1, math.min(#standings, 10) do
        local entry = standings[index]
        self:Print(string.format("%d. %s - %d", index, entry.name, entry.dkp))
    end
end

function addon:SyncGuildRoster()
    if not self.guild or not IsInGuild() then
        self.guildRosterMembers = {}
        return
    end

    local refreshGuildRoster = GuildRoster or (C_GuildInfo and C_GuildInfo.GuildRoster)
    if refreshGuildRoster then
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

    for index = 1, memberCount do
        local name
        local classToken
        if GetGuildRosterInfo then
            local rosterName, _, _, _, className, _, _, _, _, _, classFileName = GetGuildRosterInfo(index)
            name = rosterName
            classToken = classFileName or className
        elseif C_GuildInfo and C_GuildInfo.GetGuildRosterInfo then
            local info = C_GuildInfo.GetGuildRosterInfo(index)
            if type(info) == "table" then
                name = info.name or info.fullName
                classToken = info.classFilename or info.classFileName or info.className
            else
                name = info
            end
        end

        name = self:NormalizeName(name)
        if name then
            rosterMembers[name] = true
            self:EnsurePlayer(name)
            self:UpdatePlayerClass(name, classToken)
        end
    end

    self.guildRosterMembers = rosterMembers
end

function addon:GetRaidGuildMembers()
    local members = {}
    local seen = {}

    if IsInRaid() then
        for index = 1, GetNumRaidMembers() do
            local unit = "raid" .. index
            local name = self:NormalizeName(UnitName(unit))
            if name and self.guild.players[name] and not seen[name] then
                members[#members + 1] = name
                seen[name] = true
            end
        end
    elseif GetNumPartyMembers() and GetNumPartyMembers() > 0 then
        local playerName = self:GetPlayerName()
        if playerName and self.guild.players[playerName] then
            members[#members + 1] = playerName
            seen[playerName] = true
        end

        for index = 1, GetNumPartyMembers() do
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

    if IsInRaid() then
        for index = 1, GetNumRaidMembers() do
            local unit = "raid" .. index
            addMember(UnitName(unit), select(2, UnitClass(unit)))
        end
    elseif GetNumPartyMembers() and GetNumPartyMembers() > 0 then
        for index = 1, GetNumPartyMembers() do
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
    if IsInRaid() then
        for index = 1, GetNumRaidMembers() do
            local raidName, _, _, _, _, _, _, _, _, isRaidLeader = GetRaidRosterInfo(index)
            if isRaidLeader then
                return self:NormalizeName(raidName)
            end
        end
    end

    if GetNumPartyMembers() and GetNumPartyMembers() > 0 then
        if UnitIsPartyLeader and UnitIsPartyLeader("player") then
            return self:GetPlayerName()
        end

        for index = 1, GetNumPartyMembers() do
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

    if IsInRaid() then
        self:SendMessage(message, "RAID")
    elseif GetNumPartyMembers() and GetNumPartyMembers() > 0 then
        self:SendMessage(message, "PARTY")
    end
end

function addon:GetGroupChatChannel()
    if IsInRaid() then
        return "RAID"
    end

    if GetNumPartyMembers and GetNumPartyMembers() and GetNumPartyMembers() > 0 then
        return "PARTY"
    end

    return nil
end

function addon:AnnounceAuctionStartToGroup(itemLink, minBid, duration, lootMasterName)
    local channel = self:GetGroupChatChannel()
    if not channel or not SendChatMessage then
        return
    end

    local itemText = trim(itemLink)
    local lootMaster = self:NormalizeName(lootMasterName) or self:GetPlayerName() or "LootMaster"
    local minimum = math.floor(safeNumber(minBid, 0) + 0.5)
    local seconds = math.floor(safeNumber(duration, 0) + 0.5)
    local sampleBid = minimum > 0 and minimum or 1

    SendChatMessage(string.format("[MapleDKP] Auction started: %s | Min %d DKP | %ds", itemText, minimum, seconds), channel)
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

    local input = string.lower(trim(message))
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

function addon:AwardRaid(amount, reason, sharedTxRoot)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can award DKP.")
        return
    end

    local raidMembers = self:GetTrackedGroupMembers()
    if #raidMembers == 0 then
        self:Print("No guild raid members found to award.")
        return
    end

    local amountValue = math.floor(safeNumber(amount, 0) + 0.5)
    for _, memberName in ipairs(raidMembers) do
        if sharedTxRoot and sharedTxRoot ~= "" then
            local txId = table.concat({ sharedTxRoot, memberName }, ":")
            local newValue = self:GetPlayerDKP(memberName) + amountValue
            if self:ApplyPlayerTransaction(memberName, amountValue, newValue, reason, txId, self:GetPlayerName(), true) then
                self:BroadcastPlayerUpdate(memberName, amountValue, newValue, reason, txId, self:GetPlayerName())
            end
        else
            self:AdjustPlayer(memberName, amountValue, reason)
        end
    end

    self:Print(string.format("Awarded %d DKP to %d raid members.", amountValue, #raidMembers))
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
    self.guild.bosses[npcId] = {
        name = bossName,
        amount = amount,
        zone = zone,
        encounterOrder = encounterOrder,
    }
    self:NextRevision()
    self:SendMessage(table.concat({ "CFG", "BOSS", npcId, tostring(amount), bossName, zone, tostring(encounterOrder) }, "\t"))
    self:Print(string.format("Boss %s (%s) now awards %d DKP.", bossName, npcId, amount))
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
    itemLink = trim(itemLink)
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
    }

    self.lastAuctionResult = nil
    self:RemoveRecentLoot(itemLink)
    self:EnsureUI()
    self:RefreshLeaderUI()
    self:RefreshAuctionPopup()
    self:RefreshLootNotice()
    local startMessage = table.concat({ "AUC", "START", auctionId, self:GetPlayerName(), tostring(minBid), itemLink, tostring(duration) }, "\t")
    self:SendMessage(startMessage)
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
        if self.activeAuction.startedBy == self:GetPlayerName() then
            self:SendMessage(bidMessage)
        else
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
    local closedBy = self:GetPlayerName()
    self.activeAuction = nil
    self:EnsureUI()

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
        self:SendMessage(closeMessage)
        self:BroadcastGroupMessage(closeMessage)
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
        self:SendMessage(closeMessage)
        self:BroadcastGroupMessage(closeMessage)
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
    self:SendMessage(closeMessage)
    self:BroadcastGroupMessage(closeMessage)
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

function addon:SendSnapshot(targetName, requestId)
    if not self.guild then
        return
    end

    local snapshotId = trim(requestId)
    if snapshotId == "" then
        snapshotId = self:MakeTransactionId("SNP", targetName or "guild")
    end

    local senderName = self:GetPlayerName() or "unknown"
    local target = trim(targetName or "guild")
    self:SendMessage(table.concat({ "SNP", "BEGIN", snapshotId, tostring(self.guild.revision), senderName, target, tostring(self:GetNewMemberDefaultDkp()) }, "\t"))

    for playerName, info in pairs(self.guild.players) do
        -- Include updatedAt so receivers can merge two raid datasets by timestamp.
        self:SendMessage(table.concat({ "SNP", "PLAYER", snapshotId, playerName, tostring(safeNumber(info.dkp, 0)), tostring(safeNumber(info.updatedAt, 0)) }, "\t"))
    end

    for npcId, boss in pairs(self.guild.bosses) do
        self:SendMessage(table.concat({
            "SNP",
            "BOSS",
            snapshotId,
            npcId,
            tostring(safeNumber(boss.amount, 0)),
            trim(boss.name),
            trim(boss.zone ~= nil and boss.zone or "Custom"),
            tostring(safeNumber(boss.encounterOrder, 999)),
        }, "\t"))
    end

    self:SendMessage(table.concat({ "SNP", "END", snapshotId, tostring(self.guild.revision), senderName }, "\t"))
end

function addon:RequestSync()
    if not self.guild then
        return
    end

    local requestId = self:MakeTransactionId("REQSYNC", self:GetPlayerName() or "unknown")
    self:SendMessage(table.concat({ "REQSYNC", tostring(self.guild.revision), self:GetPlayerName() or "unknown", requestId }, "\t"))
end

function addon:HandleBossKill(destGUID)
    if not self.guild or not self:IsOfficer() or not destGUID then
        return
    end

    local npcId = string.match(destGUID, "Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if not npcId then
        return
    end

    local boss = self.guild.bosses[npcId]
    if not boss then
        return
    end

    local now = time()
    if self.recentBossKills[npcId] and (now - self.recentBossKills[npcId]) < 15 then
        return
    end

    self.recentBossKills[npcId] = now

    -- Use a deterministic cross-client transaction root so the same boss kill
    -- cannot stack if multiple officers process it at once.
    local awardTxRoot = table.concat({ "BOSSKILL", npcId, trim(destGUID or "") }, ":")
    self:AwardRaid(safeNumber(boss.amount, 0), "Boss kill: " .. trim(boss.name), awardTxRoot)
end

function addon:RunTestBossKill(npcId)
    if not self.guild then
        self:Print("No guild data loaded yet.")
        return
    end

    npcId = tostring(safeNumber(npcId, 0))
    if npcId == "0" then
        local entries = self:GetSortedBossEntries()
        if entries[1] then
            npcId = entries[1].npcId
        end
    end

    local boss = self.guild.bosses[npcId]
    if not boss then
        self:Print("Usage: /mdkp test boss [NpcID]")
        return
    end

    local txRoot = self:MakeTransactionId("TESTBOSS", npcId)
    self:AwardRaid(safeNumber(boss.amount, 0), "Test boss kill: " .. trim(boss.name), txRoot)
    self:Print(string.format("Test boss kill simulated: %s (%s).", trim(boss.name), npcId))
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

function addon:HandleChatMessage(prefix, message, _, sender)
    if prefix ~= self.prefix or not self.guild then
        return
    end

    local senderName = self:NormalizeName(sender)
    if senderName == self:GetPlayerName() then
        return
    end

    local parts = splitMessage(message)
    local command = parts[1]

    if command == "REQSYNC" then
        local theirRevision = safeNumber(parts[2], 0)
        local requestId = trim(parts[4])
        if requestId == "" then
            requestId = nil
        end

        -- Any member with a higher revision can respond, not just officers.
        -- The revision number is the trust anchor: whoever has seen more
        -- transactions wins and can propagate data to others who missed them.
        if self.guild.revision > theirRevision then
            self:SendSnapshot(senderName, requestId)
        end
        return
    end

    if command == "CFG" and parts[2] == "BOSS" then
        local npcId = tostring(safeNumber(parts[3], 0))
        if npcId ~= "0" then
            local existing = self.guild.bosses[npcId] or DEFAULT_BOSSES[npcId] or {}
            local zone = trim(parts[6])
            if zone == "" then
                zone = trim(existing.zone ~= nil and existing.zone or "Custom")
            end

            local encounterOrder = safeNumber(parts[7], safeNumber(existing.encounterOrder, 999))
            self.guild.bosses[npcId] = {
                amount = math.floor(safeNumber(parts[4], 0) + 0.5),
                name = trim(parts[5]),
                zone = zone,
                encounterOrder = encounterOrder,
            }
            self:NextRevision()
        end
        return
    end

    if command == "CFG" and parts[2] == "NEWMEMBERDKP" then
        local value = math.floor(safeNumber(parts[3], 0) + 0.5)
        if value < 0 then
            value = 0
        end
        self.guild.newMemberDefaultDkp = value
        self:NextRevision()
        return
    end

    if command == "TX" and parts[2] == "PLAYER" then
        self:ApplyPlayerTransaction(parts[5], safeNumber(parts[6], 0), safeNumber(parts[7], 0), parts[8], parts[3], parts[4], true)
        self:RefreshAuctionPopup()
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

            if safeNumber(parts[3], nil) then
                snapshotId = string.format("legacy:%s:%s", senderName or "unknown", tostring(time()))
                revision = safeNumber(parts[3], 0)
                declaredSender = senderName
                targetName = self:NormalizeName(parts[4])
            else
                snapshotId = trim(parts[3])
                revision = safeNumber(parts[4], 0)
                declaredSender = self:NormalizeName(parts[5]) or senderName
                targetName = self:NormalizeName(parts[6])
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
                bosses = {},
                newMemberDefaultDkp = safeNumber(parts[7], nil),
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

            if dkpAmount == nil then
                -- Legacy format without snapshotId prefix.
                snapshotId = self.pendingSnapshot.id
                playerName = self:NormalizeName(parts[3])
                dkpAmount = safeNumber(parts[4], 0)
                updatedAt = 0
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
            }
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

            -- Always attempt a per-player merge so data from parallel raids
            -- (e.g. two 10-man groups running on different nights) is combined
            -- rather than overwritten. For each player, keep whichever record
            -- has the more recent updatedAt timestamp.
            local mergedAny = false
            for playerName, incoming in pairs(self.pendingSnapshot.players) do
                local existing = self.guild.players[playerName]
                if not existing or safeNumber(incoming.updatedAt, 0) > safeNumber(existing.updatedAt, 0) then
                    self.guild.players[playerName] = incoming
                    mergedAny = true
                end
            end

            -- Boss config is officer-managed; use last-writer-wins by revision.
            if finishedRevision >= safeNumber(self.guild.revision, 0) then
                self.guild.bosses = self.pendingSnapshot.bosses
                if self.pendingSnapshot.newMemberDefaultDkp ~= nil then
                    self.guild.newMemberDefaultDkp = math.floor(safeNumber(self.pendingSnapshot.newMemberDefaultDkp, 0) + 0.5)
                end
                self.guild.revision = self.pendingSnapshot.revision
            end

            self.guild.knownTransactions = self.guild.knownTransactions or {}
            self.guild.knownTransactionsOrder = self.guild.knownTransactionsOrder or {}

            if mergedAny then
                self:Print("DKP snapshot merged.")
            end
            self.pendingSnapshot = nil
            return
        end
    end
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
    self:Print("/mdkp bid Amount")
    self:Print("/mdkp auction close [PlayerName] (use PlayerName to assign for free if no bids)")
    self:Print("/mdkp auction status")
    self:Print("/mdkp sync")
    self:Print("/mdkp defaultdkp [Value|status]")
    self:Print("/mdkp quiet [on|off|toggle|status]")
    self:Print("/mdkp help")
    self:Print("/mdkp ui")
    if self:IsTestMode() then
        self:Print("/mdkp test (or /mdkp test help) - Show test commands")
    end
end

function addon:HandleSlashCommand(message)
    local input = trim(message)
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
        local mode = string.lower(trim(remainder))
        if mode == "" or mode == "status" then
            self:Print(string.format("New-member default DKP is %d.", self:GetNewMemberDefaultDkp()), true)
            return
        end

        self:SetNewMemberDefaultDkp(remainder)
        return
    end

    if command == "quiet" then
        local mode = string.lower(trim(remainder))
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
            itemText = trim(itemText)
            if itemText == "" then
                itemText = "[Test Epic BoE]"
            end
            self:InjectTestLoot(itemText)
            self:StartAuction(minBid, itemText, 20)
            return
        end

        if subCommand == "lootcapture" or subCommand == "allloot" then
            local mode = string.lower(trim(testRemainder))
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

        self:Print("Usage: /mdkp test [boss|loot|auction|lootcapture] ...")
        return
    end

    self:ShowHelp()
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
        self:SyncGuildRoster()
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
        self:SyncGuildRoster()
        self:SyncTrackedGroupMembers()
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

    if event == "COMBAT_LOG_EVENT_UNFILTERED" and CombatLogGetCurrentEventInfo then
        local _, subEvent, _, _, _, _, _, destGUID = CombatLogGetCurrentEventInfo()
        if subEvent == "PARTY_KILL" then
            self:HandleBossKill(destGUID)
        end
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
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
addon:SetScript("OnEvent", function(_, event, ...)
    addon:OnEvent(event, ...)
end)
addon:SetScript("OnUpdate", function(_, elapsed)
    addon:OnUpdate(elapsed)
end)