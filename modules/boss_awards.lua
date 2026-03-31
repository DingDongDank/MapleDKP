local addon = MapleDKP
if not addon then
    return
end

local BOSS_KILL_ALIASES = {
    ["16151"] = "15550", -- Midnight -> Attumen encounter
    ["17533"] = "17534", -- Romulo -> Romulo and Julianne encounter
    ["21684"] = "16816", -- King Llane -> Chess Event
    ["21752"] = "16816", -- Warchief Blackhand -> Chess Event
}

local BOSS_KILL_NAME_ALIASES = {
    ["attumen the huntsman"] = "15550",
    ["midnight"] = "15550",
    ["moroes"] = "15687",
    ["maiden of virtue"] = "16457",
    ["big bad wolf"] = "17521",
    ["the crone"] = "18168",
    ["romulo"] = "17534",
    ["julianne"] = "17534",
    ["romulo and julianne"] = "17534",
    ["opera event"] = "17521",
    ["opera"] = "17521",
    ["the curator"] = "15691",
    ["terestian illhoof"] = "15688",
    ["shade of aran"] = "16524",
    ["netherspite"] = "15689",
    ["echo of medivh"] = "16816",
    ["the chess event"] = "16816",
    ["chess event"] = "16816",
    ["king llane"] = "16816",
    ["warchief blackhand"] = "16816",
    ["prince malchezaar"] = "15690",
    ["nightbane"] = "17225",
    ["high king maulgar"] = "18831",
    ["gruul the dragonkiller"] = "19044",
    ["magtheridon"] = "17257",
}

local BOSS_KILL_COOLDOWN_SECONDS = 60
local BOSS_AWARD_CLAIM_SETTLE_SECONDS = 0.8

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

local function extractNpcIdFromGuid(rawGuid)
    local guid = trimText(rawGuid)
    if guid == "" then
        return nil
    end

    return string.match(guid, "^[^-]+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
end

local function normalizeBossName(name)
    local normalized = string.lower(trimText(name))
    normalized = normalized:gsub("^opera event:%s*", "")
    normalized = normalized:gsub("^chess event:%s*", "")
    return normalized
end

function addon:ResolvePendingBossAwards(forceResolve)
    if not self:IsOfficer() or not self.pendingBossAwards then
        return
    end

    local nowTime = time()
    local nowFrame = GetTime()
    local localPlayer = self:GetPlayerName()
    for claimId, claim in pairs(self.pendingBossAwards) do
        local shouldResolve = forceResolve == true or nowFrame >= safeNumber(claim.resolveAt, 0)
        if shouldResolve then
            local encounterNpcId = trimText(claim.encounterNpcId)
            if claim.winner == localPlayer and encounterNpcId ~= "" then
                if not self.recentBossKills[encounterNpcId] or (nowTime - self.recentBossKills[encounterNpcId]) >= BOSS_KILL_COOLDOWN_SECONDS then
                    self.recentBossKills[encounterNpcId] = nowTime
                    self:AwardRaid(safeNumber(claim.amount, 0), trimText(claim.reason), trimText(claim.claimId))
                end
            elseif encounterNpcId ~= "" then
                self.recentBossKills[encounterNpcId] = nowTime
            end

            self.pendingBossAwards[claimId] = nil
        end
    end
end

function addon:ResolveBossEncounterNpcId(rawNpcId, rawBossName)
    local encounterNpcId = rawNpcId and (BOSS_KILL_ALIASES[rawNpcId] or rawNpcId) or nil
    if encounterNpcId and self.guild and self.guild.bosses and self.guild.bosses[encounterNpcId] then
        return encounterNpcId
    end

    local normalizedName = normalizeBossName(rawBossName)
    if normalizedName == "" then
        return encounterNpcId
    end

    if self.guild and self.guild.bosses then
        for npcId, boss in pairs(self.guild.bosses) do
            if normalizeBossName(boss.name) == normalizedName then
                return npcId
            end
        end
    end

    return BOSS_KILL_NAME_ALIASES[normalizedName] or encounterNpcId
end

function addon:ProcessBossAward(encounterNpcId, awardSource)
    if not self.guild or not self:IsOfficer() or not encounterNpcId then
        return false
    end

    if not self:IsTrackingEnabled() then
        return false
    end

    local boss = self.guild.bosses[encounterNpcId]
    if not boss then
        if self:IsTestMode() then
            self:Print(string.format("Boss kill ignored: npcId %s is not configured in MapleDKP.", encounterNpcId))
        end
        return false
    end

    local now = time()
    if self.recentBossKills[encounterNpcId] and (now - self.recentBossKills[encounterNpcId]) < BOSS_KILL_COOLDOWN_SECONDS then
        return false
    end

    local killWindow = math.floor((now + math.floor(BOSS_KILL_COOLDOWN_SECONDS / 2)) / BOSS_KILL_COOLDOWN_SECONDS)
    local awardTxRoot = table.concat({ "BOSSKILL", encounterNpcId, tostring(killWindow) }, ":")
    local localPlayer = self:GetPlayerName()
    local pending = self.pendingBossAwards[awardTxRoot]
    if not pending then
        pending = {
            claimId = awardTxRoot,
            encounterNpcId = encounterNpcId,
            amount = safeNumber(boss.amount, 0),
            reason = "Boss kill: " .. trimText(boss.name),
            winner = localPlayer,
            resolveAt = GetTime() + BOSS_AWARD_CLAIM_SETTLE_SECONDS,
            claimants = {},
            source = trimText(awardSource),
            createdAt = now,
        }
        self.pendingBossAwards[awardTxRoot] = pending
    end

    if localPlayer then
        pending.claimants[localPlayer] = true
        if not pending.winner or string.lower(localPlayer) < string.lower(pending.winner) then
            pending.winner = localPlayer
        end
    end

    self:BroadcastGroupMessage(table.concat({ "BCLAIM", awardTxRoot, encounterNpcId, tostring(now) }, "\t"))
    return true
end

function addon:HandleBossAwardClaim(claimId, encounterNpcId, claimAt, senderName, distribution)
    local channel = trimText(distribution)
    if channel ~= "RAID" and channel ~= "PARTY" then
        return
    end

    if not self.guild or not self:IsOfficer() then
        return
    end

    claimId = trimText(claimId)
    encounterNpcId = trimText(encounterNpcId)
    senderName = self:NormalizeName(senderName)
    if claimId == "" or encounterNpcId == "" or not senderName then
        return
    end

    local boss = self.guild.bosses and self.guild.bosses[encounterNpcId]
    if not boss then
        return
    end

    local now = time()
    if self.recentBossKills[encounterNpcId] and (now - self.recentBossKills[encounterNpcId]) < BOSS_KILL_COOLDOWN_SECONDS then
        return
    end

    local pending = self.pendingBossAwards[claimId]
    if not pending then
        pending = {
            claimId = claimId,
            encounterNpcId = encounterNpcId,
            amount = safeNumber(boss.amount, 0),
            reason = "Boss kill: " .. trimText(boss.name),
            winner = senderName,
            resolveAt = GetTime() + BOSS_AWARD_CLAIM_SETTLE_SECONDS,
            claimants = {},
            source = "claim-message",
            createdAt = safeNumber(claimAt, now),
        }
        self.pendingBossAwards[claimId] = pending
    end

    pending.claimants[senderName] = true
    if not pending.winner or string.lower(senderName) < string.lower(pending.winner) then
        pending.winner = senderName
    end
end

function addon:HandleBossKill(destGUID, destName)
    if not self.guild or not self:IsOfficer() or (not destGUID and trimText(destName) == "") then
        return
    end

    local npcId = extractNpcIdFromGuid(destGUID)
    local encounterNpcId = self:ResolveBossEncounterNpcId(npcId, destName)
    if not encounterNpcId then
        return
    end

    self:ProcessBossAward(encounterNpcId, "combat-log")
end

function addon:HandleEncounterEnd(encounterId, encounterName, difficultyId, groupSize, success)
    if success ~= 1 or not self.guild or not self:IsOfficer() then
        return
    end

    local encounterNpcId = self:ResolveBossEncounterNpcId(nil, encounterName)
    if not encounterNpcId then
        if self:IsTestMode() then
            self:Print(string.format("Encounter end ignored: %s is not configured in MapleDKP.", trimText(encounterName)))
        end
        return
    end

    self:ProcessBossAward(encounterNpcId, "encounter-end")
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
    self:AwardRaid(safeNumber(boss.amount, 0), "Test boss kill: " .. trimText(boss.name), txRoot)
    self:Print(string.format("Test boss kill simulated: %s (%s).", trimText(boss.name), npcId))
end

function addon:RunTestBossClaimElection(npcId, channelName, officerListCsv)
    if not self:IsTestMode() then
        self:Print("Test mode is disabled.")
        return
    end

    if not self.guild then
        self:Print("No guild data loaded yet.")
        return
    end

    local distribution = string.upper(trimText(channelName))
    if distribution == "" then
        distribution = "RAID"
    end

    local boss = self.guild.bosses and self.guild.bosses[npcId]
    if not boss then
        self:Print("Usage: /mdkp test claim NpcID [raid|party|guild] [OfficerA,OfficerB,...]")
        return
    end

    local now = time()
    local killWindow = math.floor((now + math.floor(BOSS_KILL_COOLDOWN_SECONDS / 2)) / BOSS_KILL_COOLDOWN_SECONDS)
    local claimId = table.concat({ "BOSSKILL", npcId, tostring(killWindow) }, ":")
    local localPlayer = self:GetPlayerName() or "unknown"
    local pending = {
        claimId = claimId,
        encounterNpcId = npcId,
        amount = safeNumber(boss.amount, 0),
        reason = "Boss kill: " .. trimText(boss.name),
        winner = localPlayer,
        resolveAt = GetTime() + BOSS_AWARD_CLAIM_SETTLE_SECONDS,
        claimants = { [localPlayer] = true },
        source = "test-claim",
        createdAt = now,
    }
    self.pendingBossAwards[claimId] = pending

    for rawName in string.gmatch(trimText(officerListCsv) .. ",", "([^,]*),") do
        local candidate = self:NormalizeName(rawName)
        if candidate and candidate ~= "" then
            self:HandleBossAwardClaim(claimId, npcId, now, candidate, distribution)
        end
    end

    local claim = self.pendingBossAwards[claimId]
    if not claim then
        self:Print("Claim simulation failed to initialize.")
        return
    end

    local claimants = {}
    for name in pairs(claim.claimants or {}) do
        claimants[#claimants + 1] = name
    end
    table.sort(claimants)

    self:Print(string.format("Claim simulation for %s (%s) on %s.", trimText(boss.name), npcId, distribution), true)
    self:Print(string.format("Claimants considered: %s", #claimants > 0 and table.concat(claimants, ", ") or "(none)"), true)
    self:Print(string.format("Winner elected: %s", trimText(claim.winner)), true)
    if claim.winner == localPlayer then
        self:Print("This client would perform the award for this kill window.", true)
    else
        self:Print("This client would skip awarding; another officer would perform it.", true)
    end

    self.pendingBossAwards[claimId] = nil
end
