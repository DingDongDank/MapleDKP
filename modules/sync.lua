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

function addon:SendMessage(message, channel, targetName)
    if not message or message == "" then
        return
    end

    channel = trimText(channel)
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

function addon:BroadcastTransactionRecord(transaction, channel, targetName)
    if type(transaction) ~= "table" then
        return
    end

    self:SendMessage(table.concat({
        "TX",
        "PLAYER",
        trimText(transaction.txId),
        trimText(transaction.actor),
        trimText(transaction.target),
        trimText(transaction.opType),
        tostring(safeNumber(transaction.delta, 0)),
        tostring(safeNumber(transaction.desiredValue, 0)),
        trimText(transaction.expectedOldValue ~= nil and tostring(transaction.expectedOldValue) or ""),
        trimText(transaction.reason),
        tostring(safeNumber(transaction.createdAt, time())),
        tostring(safeNumber(transaction.actorSeq, 0)),
        trimText(transaction.resolvedTxId or ""),
        trimText(transaction.resolutionAction or ""),
    }, "\t"), channel, targetName)
end

function addon:BroadcastConfigTransactionRecord(transaction, channel, targetName)
    if type(transaction) ~= "table" then
        return
    end

    self:SendMessage(table.concat({
        "TX",
        "CFG",
        trimText(transaction.txId),
        trimText(transaction.actor),
        trimText(transaction.target),
        trimText(transaction.opType),
        tostring(safeNumber(transaction.value, 0)),
        trimText(transaction.label or ""),
        trimText(transaction.zone or ""),
        tostring(safeNumber(transaction.encounterOrder, 999)),
        trimText(transaction.reason or ""),
        tostring(safeNumber(transaction.createdAt, time())),
        tostring(safeNumber(transaction.actorSeq, 0)),
    }, "\t"), channel, targetName)
end

function addon:SendTransactionsForActor(targetName, actor, afterSequence)
    if not self.guild then
        return 0
    end

    targetName = self:NormalizeName(targetName)
    actor = self:NormalizeName(actor)
    if not targetName or not actor then
        return 0
    end

    local sent = 0
    for _, transaction in ipairs(self:GetSortedTransactions()) do
        if self:NormalizeName(transaction.actor) == actor and safeNumber(transaction.actorSeq, 0) > safeNumber(afterSequence, 0) then
            if trimText(transaction.recordType) == "config" then
                self:BroadcastConfigTransactionRecord(transaction, "WHISPER", targetName)
            else
                self:BroadcastTransactionRecord(transaction, "WHISPER", targetName)
            end
            sent = sent + 1
        end
    end

    return sent
end

function addon:SyncActorSequencesWithPeer(peerName, remoteActorSequences)
    if not self.guild then
        return 0, 0
    end

    peerName = self:NormalizeName(peerName)
    if not peerName then
        return 0, 0
    end

    local requested = 0
    local pushed = 0
    local localSequences = self:GetActorSequenceSummary()
    local replayableSequences = self:GetReplayableActorSequenceSummary()
    local actors = {}

    for actorName in pairs(localSequences) do
        actors[actorName] = true
    end
    for actorName in pairs(remoteActorSequences or {}) do
        actors[self:NormalizeName(actorName) or actorName] = true
    end

    for actorName in pairs(actors) do
        local localSequence = safeNumber(localSequences[actorName], 0)
        local remoteSequence = safeNumber(remoteActorSequences and remoteActorSequences[actorName], 0)
        if remoteSequence > localSequence then
            self:SendMessage(table.concat({ "TXREQ", actorName, tostring(localSequence) }, "\t"), "WHISPER", peerName)
            requested = requested + 1
        elseif safeNumber(replayableSequences[actorName], 0) > remoteSequence then
            pushed = pushed + self:SendTransactionsForActor(peerName, actorName, remoteSequence)
        end
    end

    return requested, pushed
end

function addon:SendSnapshot(targetName, requestId)
    if not self.guild then
        return
    end

    local snapshotId = trimText(requestId)
    if snapshotId == "" then
        snapshotId = self:MakeTransactionId("SNP", targetName or "guild")
    end

    local senderName = self:GetPlayerName() or "unknown"
    local normalizedTarget = self:NormalizeName(targetName)
    local target = normalizedTarget or ""
    self:SendMessage(table.concat({ "SNP", "BEGIN", snapshotId, tostring(self.guild.revision), senderName, target, tostring(self:GetNewMemberDefaultDkp()) }, "\t"))

    for playerName, info in pairs(self.guild.players) do
        self:SendMessage(table.concat({
            "SNP",
            "PLAYER",
            snapshotId,
            playerName,
            tostring(safeNumber(info.dkp, 0)),
            tostring(safeNumber(info.updatedAt, 0)),
            tostring(safeNumber(info.earned, 0)),
            tostring(safeNumber(info.spent, 0)),
        }, "\t"))
    end

    for npcId, boss in pairs(self.guild.bosses) do
        self:SendMessage(table.concat({
            "SNP",
            "BOSS",
            snapshotId,
            npcId,
            tostring(safeNumber(boss.amount, 0)),
            trimText(boss.name),
            trimText(boss.zone ~= nil and boss.zone or "Custom"),
            tostring(safeNumber(boss.encounterOrder, 999)),
        }, "\t"))
    end

    for playerName, enabled in pairs(self.guild.manualRaiders or {}) do
        if enabled == true then
            self:SendMessage(table.concat({
                "SNP",
                "RAIDER",
                snapshotId,
                playerName,
            }, "\t"))
        end
    end

    for playerName, enabled in pairs(self.guild.manualInactiveRaiders or {}) do
        if enabled == true then
            self:SendMessage(table.concat({
                "SNP",
                "NORAIDER",
                snapshotId,
                playerName,
            }, "\t"))
        end
    end

    for actorName, sequence in pairs(self:GetActorSequenceSummary()) do
        self:SendMessage(table.concat({
            "SNP",
            "ACTOR",
            snapshotId,
            actorName,
            tostring(sequence),
        }, "\t"))
    end

    self:SendMessage(table.concat({ "SNP", "END", snapshotId, tostring(self.guild.revision), senderName }, "\t"))

    local syncTarget = normalizedTarget and (" to " .. normalizedTarget) or " to guild"
    self:Print(string.format("Snapshot sent%s (rev %d).", syncTarget, safeNumber(self.guild.revision, 0)))
end

function addon:RequestSync(force)
    if not self.guild then
        return
    end

    local now = GetTime and GetTime() or time()
    if not force and now and self.lastSyncRequestAt and (now - self.lastSyncRequestAt) < 15 then
        return
    end
    self.lastSyncRequestAt = now

    local requestId = self:MakeTransactionId("REQSYNC", self:GetPlayerName() or "unknown")
    self:SendMessage(table.concat({ "REQSYNC", tostring(self.guild.revision), self:GetPlayerName() or "unknown", requestId }, "\t"))
end
