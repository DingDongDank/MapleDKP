local addon = MapleDKP
if not addon then
    return
end

local staticData = MapleDKPStaticData or {}
local ACTIVE_RAIDER_WINDOW_SECONDS = tonumber(staticData.activeRaiderWindowSeconds) or (30 * 24 * 60 * 60)
local ZONE_SORT_ORDER = staticData.zoneSortOrder or {}

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

function addon:GetSortedGuildDkpEntries()
    local entries = self:GetActiveGuildMemberEntries(false)

    table.sort(entries, function(left, right)
        if left.dkp == right.dkp then
            return left.name < right.name
        end

        return left.dkp > right.dkp
    end)

    return entries
end

function addon:GetSortedGuildMemberEntriesAlphabetical()
    local entries = self:GetActiveGuildMemberEntries(false)

    table.sort(entries, function(left, right)
        return left.name < right.name
    end)

    return entries
end

function addon:GetSortedGuildMemberEntriesByClass(secondaryByDkp)
    local entries = self:GetActiveGuildMemberEntries(true)
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

function addon:GetSortedGuildMemberEntriesByEarned()
    local entries = self:GetActiveGuildMemberEntries(false)

    table.sort(entries, function(left, right)
        if left.earned == right.earned then
            return left.name < right.name
        end

        return left.earned > right.earned
    end)

    return entries
end

function addon:GetSortedGuildMemberEntriesBySpent()
    local entries = self:GetActiveGuildMemberEntries(false)

    table.sort(entries, function(left, right)
        if left.spent == right.spent then
            return left.name < right.name
        end

        return left.spent > right.spent
    end)

    return entries
end

function addon:GetActiveRaiderLookup()
    local active = {}
    if not self.guild then
        return active
    end

    local cutoff = time() - ACTIVE_RAIDER_WINDOW_SECONDS

    for _, entry in ipairs(self.guild.activityLog or {}) do
        if trimText(entry.type) == "PLAYER_TX" then
            local target = self:NormalizeName(entry.target)
            local delta = safeNumber(entry.delta, 0)
            local at = safeNumber(entry.at, 0)
            if target and delta > 0 and at >= cutoff then
                active[target] = true
            end
        end
    end

    for name, info in pairs(self.guild.players or {}) do
        if not active[name] then
            local updatedAt = safeNumber(info.updatedAt, 0)
            local earned = safeNumber(info.earned, 0)
            if earned > 0 and updatedAt >= cutoff then
                active[name] = true
            end
        end
    end

    for name, enabled in pairs(self.guild.manualRaiders or {}) do
        if enabled == true then
            active[name] = true
        end
    end

    for name, enabled in pairs(self.guild.manualInactiveRaiders or {}) do
        if enabled == true then
            active[name] = nil
        end
    end

    return active
end

function addon:GetActiveGuildMemberEntries(includeClass)
    local entries = {}
    if not self.guild then
        return entries
    end

    local active = self:GetActiveRaiderLookup()
    for name, info in pairs(self.guild.players or {}) do
        if active[name] then
            entries[#entries + 1] = {
                name = name,
                dkp = safeNumber(info.dkp, 0),
                earned = safeNumber(info.earned, 0),
                spent = safeNumber(info.spent, 0),
                class = includeClass and ((info.class and info.class ~= "") and info.class or nil) or nil,
            }
        end
    end

    return entries
end

function addon:GetSortedGuildRosterEntries()
    local entries = {}
    if not self.guild then
        return entries
    end

    local activeLookup = self:GetActiveRaiderLookup()
    local rosterMap = self.guildRosterMembers or {}

    for name in pairs(rosterMap) do
        local info = self.guild.players and self.guild.players[name] or nil
        entries[#entries + 1] = {
            name = name,
            dkp = safeNumber(info and info.dkp, 0),
            active = activeLookup[name] == true,
        }
    end

    table.sort(entries, function(left, right)
        if left.active ~= right.active then
            return left.active
        end
        return left.name < right.name
    end)

    return entries
end

function addon:GetAverageActiveRaiderDkp(excludedName)
    if not self.guild then
        return 0, 0
    end

    local excluded = self:NormalizeName(excludedName)
    local activeLookup = self:GetActiveRaiderLookup()
    local totalDkp = 0
    local count = 0

    for name, isActive in pairs(activeLookup) do
        if isActive and name ~= excluded then
            totalDkp = totalDkp + self:GetPlayerDKP(name)
            count = count + 1
        end
    end

    if count <= 0 then
        return 0, 0
    end

    return math.floor((totalDkp / count) + 0.5), count
end

function addon:GetSortedBossEntries()
    local entries = {}

    if not self.guild then
        return entries
    end

    for npcId, boss in pairs(self.guild.bosses or {}) do
        entries[#entries + 1] = {
            npcId = npcId,
            name = trimText(boss.name),
            amount = safeNumber(boss.amount, 0),
            zone = trimText(boss.zone ~= nil and boss.zone or "Custom"),
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
    zoneName = trimText(zoneName)
    if zoneName == "" then
        return
    end

    self.ui.optionsCollapsedZones = self.ui.optionsCollapsedZones or {}
    self.ui.optionsCollapsedZones[zoneName] = (self.ui.optionsCollapsedZones[zoneName] == false)
    self:RefreshOptionsBossesPage()
end

function addon:SetOptionsStatus(message)
    if self.ui and self.ui.optionsFrame and self.ui.optionsFrame.statusText then
        self.ui.optionsFrame.statusText:SetText(trimText(message))
    end
end

function addon:SelectOptionsMember(name)
    self.ui.optionsSelectedMember = self:NormalizeName(name)

    if self.ui and self.ui.optionsFrame and self.ui.optionsFrame.actionsPage and self.ui.optionsFrame.actionsPage.adjustTargetInput then
        self.ui.optionsFrame.actionsPage.adjustTargetInput:SetText(self.ui.optionsSelectedMember or "")
    end

    self:RefreshOptionsUI()
end

function addon:SelectOptionsBoss(npcId)
    self.ui.optionsSelectedBossNpcId = tostring(safeNumber(npcId, 0))
    self:RefreshOptionsUI()
end

function addon:SelectOptionsConflict(conflictId)
    self.ui.optionsSelectedConflictId = trimText(conflictId)
    self:RefreshOptionsUI()
end
