local addon = MapleDKP
if not addon then
    return
end

local staticData = MapleDKPStaticData or {}
local DEFAULT_NEW_MEMBER_DKP = tonumber(staticData.defaultNewMemberDkp) or 180

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

function addon:Print(message, force)
    if self:IsQuietMode() and not force then
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800Maple DKP|r " .. trimText(message))
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
        return false
    end

    local resolvedValue = math.floor(parsed + 0.5)
    if resolvedValue < 0 then
        self:Print("Default DKP cannot be negative.")
        return false
    end

    local transaction = self:BuildConfigTransaction("newmemberdkp", "guild", resolvedValue, "", "", 0, "Updated new-member default DKP", self:MakeTransactionId("CFGNEWMEMBERDKP", "guild"), self:GetPlayerName(), time())
    if self:ApplyConfigTransactionRecord(transaction, true, false) then
        self:BroadcastConfigTransactionRecord(transaction)
        self:SendMessage(table.concat({ "CFG", "NEWMEMBERDKP", trimText(transaction.txId), tostring(resolvedValue) }, "\t"))
        self:Print(string.format("New-member default DKP set to %d.", resolvedValue))
        return true
    end

    return false
end

function addon:IsTrackingEnabled()
    if not self.guild then
        return true
    end

    return self.guild.trackingEnabled ~= false
end

function addon:SetTrackingEnabled(enabled)
    if not self:IsOfficer() then
        self:Print("Only guild leaders and officers can change raid DKP tracking.")
        return false
    end

    if not self.guild then
        return false
    end

    local resolved = enabled and true or false
    local current = self:IsTrackingEnabled()
    if current == resolved then
        self:Print(string.format("Raid DKP tracking is already %s.", resolved and "enabled" or "disabled"), true)
        return true
    end

    local value = resolved and 1 or 0
    local transaction = self:BuildConfigTransaction("tracking", "guild", value, "", "", 0, "Updated raid DKP tracking", self:MakeTransactionId("CFGTRACKING", "guild"), self:GetPlayerName(), time())
    if self:ApplyConfigTransactionRecord(transaction, true, false) then
        self:BroadcastConfigTransactionRecord(transaction)
        self:SendMessage(table.concat({ "CFG", "TRACKING", trimText(transaction.txId), tostring(value) }, "\t"))
        self:Print(string.format("Raid DKP tracking %s.", resolved and "enabled" or "disabled"), true)
        if not resolved and self.activeAuction then
            self.activeAuction = nil
            self.lastAuctionResult = "Auction cleared because raid DKP tracking is disabled."
            self:RefreshLeaderUI()
            self:RefreshAuctionPopup()
        end
        return true
    end

    return false
end

function addon:NormalizeName(name)
    name = trimText(name)

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
    self.guildName = guildName and trimText(guildName) or nil
    return self.guildName
end

function addon:IsGuildRosterMember(name)
    local normalizedName = self:NormalizeName(name)
    if not normalizedName then
        return false
    end

    return self.guildRosterMembers and self.guildRosterMembers[normalizedName] == true
end

function addon:IsOfficer()
    if self:IsTestMode() then
        return true
    end

    if not IsInGuild() then
        return false
    end

    if IsGuildLeader and IsGuildLeader("player") then
        return true
    end

    if CanEditOfficerNote then
        local canEdit = CanEditOfficerNote()
        if canEdit then
            return true
        end
    end

    if C_GuildInfo and C_GuildInfo.CanEditOfficerNote then
        local canEdit = C_GuildInfo.CanEditOfficerNote()
        if canEdit then
            return true
        end
    end

    local cachedRankIndex = safeNumber(self.playerGuildRankIndex, 99)
    if cachedRankIndex <= 1 then
        return true
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

    local playerName = self:GetPlayerName()
    for index = 1, memberCount do
        local rosterName
        local rankIndex
        if GetGuildRosterInfo then
            rosterName, _, rankIndex = GetGuildRosterInfo(index)
        elseif C_GuildInfo and C_GuildInfo.GetGuildRosterInfo then
            local info = C_GuildInfo.GetGuildRosterInfo(index)
            if type(info) == "table" then
                rosterName = info.name or info.fullName
                rankIndex = info.rankOrder or info.rankIndex
            else
                rosterName = nil
                rankIndex = nil
            end
        end

        local normalizedRosterName = self:NormalizeName(rosterName)
        if normalizedRosterName and normalizedRosterName == playerName then
            self.playerGuildRankIndex = safeNumber(rankIndex, 99)
            return self.playerGuildRankIndex <= 1
        end
    end

    return false
end
