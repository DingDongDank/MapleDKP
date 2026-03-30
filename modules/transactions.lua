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

function addon:NextRevision()
    self.guild.revision = safeNumber(self.guild.revision, 0) + 1
    return self.guild.revision
end

function addon:MakeTransactionId(kind, target)
    local actor = self:GetPlayerName() or "unknown"
    local sequence = self:NextActorSequence(actor)
    return table.concat({
        kind,
        actor,
        target or "guild",
        tostring(sequence),
        tostring(time()),
    }, ":")
end

function addon:MakeConfigTransactionId(kind, target)
    return table.concat({
        kind,
        self:GetPlayerName() or "unknown",
        target or "guild",
        tostring(time()),
        tostring(math.random(1000, 9999)),
    }, ":")
end

function addon:NextActorSequence(actor)
    if not self.guild then
        return 0
    end

    actor = self:NormalizeName(actor) or "unknown"
    self.guild.actorSequences = self.guild.actorSequences or {}
    local nextValue = safeNumber(self.guild.actorSequences[actor], 0) + 1
    self.guild.actorSequences[actor] = nextValue
    return nextValue
end

function addon:GetActorSequence(actor)
    if not self.guild then
        return 0
    end

    actor = self:NormalizeName(actor) or "unknown"
    return safeNumber(self.guild.actorSequences and self.guild.actorSequences[actor], 0)
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

function addon:BuildPlayerTransaction(opType, targetName, delta, newValue, reason, txId, actor, expectedOldValue, createdAt)
    local normalizedTarget = self:NormalizeName(targetName)
    local normalizedActor = self:NormalizeName(actor) or self:GetPlayerName() or "unknown"
    local parsedTxId = trimText(txId)
    local storedAt = safeNumber(createdAt, time())

    if parsedTxId == "" then
        parsedTxId = self:MakeTransactionId(string.upper(trimText(opType) ~= "" and opType or "TX"), normalizedTarget or "guild")
    end

    local sequence = 0
    local embeddedActor = string.match(parsedTxId, "^[^:]+:([^:]+):")
    local embeddedSequence = string.match(parsedTxId, "^[^:]+:[^:]+:[^:]+:(%d+):")
    if embeddedActor and embeddedActor ~= "" then
        normalizedActor = self:NormalizeName(embeddedActor) or normalizedActor
    end
    if embeddedSequence then
        sequence = safeNumber(embeddedSequence, 0)
    end

    return {
        recordType = "player",
        txId = parsedTxId,
        opType = string.lower(trimText(opType) ~= "" and opType or "add"),
        actor = normalizedActor,
        actorSeq = sequence,
        target = normalizedTarget,
        delta = math.floor(safeNumber(delta, 0) + 0.5),
        desiredValue = math.floor(safeNumber(newValue, 0) + 0.5),
        expectedOldValue = expectedOldValue ~= nil and math.floor(safeNumber(expectedOldValue, 0) + 0.5) or nil,
        reason = trimText(reason),
        createdAt = storedAt,
    }
end

function addon:BuildConfigTransaction(opType, targetName, value, label, zone, encounterOrder, reason, txId, actor, createdAt)
    local normalizedActor = self:NormalizeName(actor) or self:GetPlayerName() or "unknown"
    local normalizedTarget = trimText(targetName)
    local parsedTxId = trimText(txId)
    local storedAt = safeNumber(createdAt, time())

    if parsedTxId == "" then
        parsedTxId = self:MakeTransactionId(string.upper(trimText(opType) ~= "" and opType or "CFG"), normalizedTarget ~= "" and normalizedTarget or "guild")
    end

    local sequence = 0
    local embeddedActor = string.match(parsedTxId, "^[^:]+:([^:]+):")
    local embeddedSequence = string.match(parsedTxId, "^[^:]+:[^:]+:[^:]+:(%d+):")
    if embeddedActor and embeddedActor ~= "" then
        normalizedActor = self:NormalizeName(embeddedActor) or normalizedActor
    end
    if embeddedSequence then
        sequence = safeNumber(embeddedSequence, 0)
    end

    if string.lower(trimText(opType)) == "addraider" or string.lower(trimText(opType)) == "remraider" then
        normalizedTarget = self:NormalizeName(targetName)
    elseif normalizedTarget == "" then
        normalizedTarget = "guild"
    end

    return {
        recordType = "config",
        txId = parsedTxId,
        opType = string.lower(trimText(opType)),
        actor = normalizedActor,
        actorSeq = sequence,
        target = normalizedTarget,
        value = math.floor(safeNumber(value, 0) + 0.5),
        label = trimText(label),
        zone = trimText(zone),
        encounterOrder = safeNumber(encounterOrder, 999),
        reason = trimText(reason),
        createdAt = storedAt,
    }
end

function addon:RecordTransaction(transaction)
    if not self.guild or type(transaction) ~= "table" then
        return false
    end

    local txId = trimText(transaction.txId)
    if txId == "" or self.guild.transactionLogById[txId] then
        return false
    end

    self.guild.transactionLogById[txId] = transaction
    self.guild.transactionOrder[#self.guild.transactionOrder + 1] = txId
    self:RegisterTransaction(txId)

    local actor = self:NormalizeName(transaction.actor) or "unknown"
    local actorSeq = safeNumber(transaction.actorSeq, 0)
    if actorSeq > self:GetActorSequence(actor) then
        self.guild.actorSequences[actor] = actorSeq
    end

    while #self.guild.transactionOrder > 1200 do
        local oldest = table.remove(self.guild.transactionOrder, 1)
        self.guild.transactionLogById[oldest] = nil
    end

    return true
end

function addon:GetSortedTransactions()
    local entries = {}
    if not self.guild then
        return entries
    end

    for _, txId in ipairs(self.guild.transactionOrder or {}) do
        local transaction = self.guild.transactionLogById and self.guild.transactionLogById[txId]
        if transaction then
            entries[#entries + 1] = transaction
        end
    end

    table.sort(entries, function(left, right)
        local leftAt = safeNumber(left.createdAt, 0)
        local rightAt = safeNumber(right.createdAt, 0)
        if leftAt == rightAt then
            local leftActor = trimText(left.actor)
            local rightActor = trimText(right.actor)
            if leftActor == rightActor then
                local leftSeq = safeNumber(left.actorSeq, 0)
                local rightSeq = safeNumber(right.actorSeq, 0)
                if leftSeq == rightSeq then
                    return trimText(left.txId) < trimText(right.txId)
                end

                return leftSeq < rightSeq
            end

            return leftActor < rightActor
        end

        return leftAt < rightAt
    end)

    return entries
end

function addon:GetConflictEntries()
    local entries = {}
    if not self.guild then
        return entries
    end

    for _, conflictId in ipairs(self.guild.conflictOrder or {}) do
        local conflict = self.guild.conflicts and self.guild.conflicts[conflictId]
        if conflict and trimText(conflict.status) ~= "resolved" then
            entries[#entries + 1] = conflict
        end
    end

    table.sort(entries, function(left, right)
        return safeNumber(left.detectedAt, 0) > safeNumber(right.detectedAt, 0)
    end)

    return entries
end

function addon:GetConflictCount()
    return #self:GetConflictEntries()
end

function addon:CreateConflict(transaction, currentValue, reason)
    if not self.guild or type(transaction) ~= "table" then
        return nil
    end

    if self.guild.resolvedTransactions and self.guild.resolvedTransactions[trimText(transaction.txId)] then
        return nil
    end

    local existingId = trimText(transaction.txId)
    for _, conflictId in ipairs(self.guild.conflictOrder or {}) do
        local existing = self.guild.conflicts and self.guild.conflicts[conflictId]
        if existing and trimText(existing.txId) == existingId and trimText(existing.status) ~= "resolved" then
            return existing
        end
    end

    self.guild.conflictCounter = safeNumber(self.guild.conflictCounter, 0) + 1
    local conflictId = string.format("CF:%s:%d", self:GetPlayerName() or "unknown", self.guild.conflictCounter)
    local conflict = {
        id = conflictId,
        txId = trimText(transaction.txId),
        actor = trimText(transaction.actor),
        playerName = trimText(transaction.target),
        opType = trimText(transaction.opType),
        delta = safeNumber(transaction.delta, 0),
        desiredValue = safeNumber(transaction.desiredValue, 0),
        expectedOldValue = transaction.expectedOldValue,
        currentValue = safeNumber(currentValue, 0),
        reason = trimText(reason),
        detectedAt = time(),
        status = "open",
        createdAt = safeNumber(transaction.createdAt, time()),
    }

    self.guild.conflicts[conflictId] = conflict
    self.guild.conflictOrder[#self.guild.conflictOrder + 1] = conflictId
    self:AppendHistory(string.format("Conflict for %s from %s [%s]", conflict.playerName, conflict.actor ~= "" and conflict.actor or "unknown", conflict.reason))
    self:AppendActivity({
        type = "CONFLICT",
        actor = conflict.actor,
        target = conflict.playerName,
        oldValue = conflict.currentValue,
        newValue = conflict.desiredValue,
        reason = conflict.reason,
        txId = conflict.txId,
    })

    return conflict
end

function addon:MarkTransactionResolved(resolvedTxId, action, actor)
    if not self.guild or not resolvedTxId or resolvedTxId == "" then
        return
    end

    self.guild.resolvedTransactions = self.guild.resolvedTransactions or {}
    self.guild.resolvedTransactions[resolvedTxId] = {
        action = trimText(action),
        actor = trimText(actor),
        at = time(),
    }

    for _, conflictId in ipairs(self.guild.conflictOrder or {}) do
        local conflict = self.guild.conflicts and self.guild.conflicts[conflictId]
        if conflict and trimText(conflict.txId) == trimText(resolvedTxId) and trimText(conflict.status) ~= "resolved" then
            conflict.status = "resolved"
            conflict.resolvedAt = time()
            conflict.resolution = trimText(action)
            conflict.resolvedBy = trimText(actor)
        end
    end
end

function addon:BuildConflictResolutionTransaction(conflict, action, resolvedValue)
    if type(conflict) ~= "table" then
        return nil
    end

    local playerName = self:NormalizeName(conflict.playerName)
    if not playerName then
        return nil
    end

    local transaction = self:BuildPlayerTransaction(
        "resolve",
        playerName,
        0,
        safeNumber(resolvedValue, self:GetPlayerDKP(playerName)),
        "Conflict resolution",
        self:MakeTransactionId("RESOLVE", playerName),
        self:GetPlayerName(),
        nil,
        time()
    )
    transaction.resolvedTxId = trimText(conflict.txId)
    transaction.resolutionAction = trimText(action)
    return transaction
end

function addon:GetActorSequenceSummary()
    local summary = {}
    if not self.guild then
        return summary
    end

    for actor, sequence in pairs(self.guild.actorSequences or {}) do
        summary[self:NormalizeName(actor) or actor] = safeNumber(sequence, 0)
    end

    return summary
end

function addon:GetReplayableActorSequenceSummary()
    local summary = {}
    if not self.guild then
        return summary
    end

    for _, transaction in ipairs(self:GetSortedTransactions()) do
        local actorName = self:NormalizeName(transaction.actor)
        local actorSeq = safeNumber(transaction.actorSeq, 0)
        if actorName and actorSeq > safeNumber(summary[actorName], 0) then
            summary[actorName] = actorSeq
        end
    end

    return summary
end

function addon:ResolveConflict(conflictId, action, manualValue)
    if not self.guild or not self.guild.conflicts then
        return false
    end

    local conflict = self.guild.conflicts[conflictId]
    if not conflict or trimText(conflict.status) == "resolved" then
        return false
    end

    local playerName = self:NormalizeName(conflict.playerName)
    if not playerName then
        return false
    end

    local currentValue = self:GetPlayerDKP(playerName)
    local resolutionTx
    if action == "apply" then
        local tx = self:BuildPlayerTransaction(conflict.opType, playerName, conflict.delta, conflict.desiredValue, conflict.reason, self:MakeTransactionId("RESOLVE", playerName), self:GetPlayerName(), currentValue, time())
        tx.opType = "set"
        tx.desiredValue = safeNumber(conflict.desiredValue, currentValue)
        tx.expectedOldValue = currentValue
        self:ApplyTransactionRecord(tx, true, true)
        self:BroadcastTransactionRecord(tx)
        resolutionTx = self:BuildConflictResolutionTransaction(conflict, action, tx.desiredValue)
    elseif action == "manual" then
        local resolvedValue = math.floor(safeNumber(manualValue, currentValue) + 0.5)
        local tx = self:BuildPlayerTransaction("set", playerName, resolvedValue - currentValue, resolvedValue, "Conflict resolution", self:MakeTransactionId("RESOLVE", playerName), self:GetPlayerName(), currentValue, time())
        self:ApplyTransactionRecord(tx, true, true)
        self:BroadcastTransactionRecord(tx)
        resolutionTx = self:BuildConflictResolutionTransaction(conflict, action, resolvedValue)
    elseif action == "keep" then
        resolutionTx = self:BuildConflictResolutionTransaction(conflict, action, currentValue)
    else
        return false
    end

    if resolutionTx then
        self:ApplyTransactionRecord(resolutionTx, true, false)
        self:BroadcastTransactionRecord(resolutionTx)
    end

    conflict.status = "resolved"
    conflict.resolvedAt = time()
    conflict.resolution = trimText(action)
    conflict.resolvedBy = self:GetPlayerName() or "unknown"
    self:AppendHistory(string.format("Conflict resolved for %s by %s (%s)", playerName, conflict.resolvedBy, trimText(action)))
    self:RefreshHistoryFrame()
    self:RefreshOptionsUI()
    return true
end

function addon:ApplyConfigTransactionRecord(transaction, silent, fromSync)
    if not self.guild or type(transaction) ~= "table" then
        return false
    end

    local txId = trimText(transaction.txId)
    local opType = string.lower(trimText(transaction.opType))
    local targetName = trimText(transaction.target)
    if txId == "" or targetName == "" then
        return false
    end

    if self.guild.transactionLogById and self.guild.transactionLogById[txId] then
        return false
    end

    self:RecordTransaction(transaction)
    self.guild.manualRaiders = self.guild.manualRaiders or {}
    self.guild.manualInactiveRaiders = self.guild.manualInactiveRaiders or {}

    if opType == "boss" then
        local npcId = tostring(safeNumber(targetName, 0))
        if npcId == "0" then
            return false
        end

        local defaultBosses = addon.DEFAULT_BOSSES or {}
        local existing = self.guild.bosses[npcId] or defaultBosses[npcId] or {}
        local zone = trimText(transaction.zone)
        if zone == "" then
            zone = trimText(existing.zone ~= nil and existing.zone or "Custom")
        end

        self.guild.bosses[npcId] = {
            amount = math.floor(safeNumber(transaction.value, 0) + 0.5),
            name = trimText(transaction.label),
            zone = zone,
            encounterOrder = safeNumber(transaction.encounterOrder, safeNumber(existing.encounterOrder, 999)),
        }
        self:NextRevision()
        self:AppendHistory(string.format("Boss %s (%s) -> %d by %s [%s]", trimText(transaction.label), npcId, safeNumber(transaction.value, 0), transaction.actor or "unknown", trimText(transaction.reason)))
        return true
    end

    if opType == "addraider" then
        local playerName = self:NormalizeName(targetName)
        if not playerName then
            return false
        end

        self:EnsurePlayer(playerName)
        self.guild.manualInactiveRaiders[playerName] = nil
        self.guild.manualRaiders[playerName] = true
        self:NextRevision()
        self:AppendHistory(string.format("Raider added: %s by %s [%s]", playerName, transaction.actor or "unknown", trimText(transaction.reason)))
        return true
    end

    if opType == "remraider" then
        local playerName = self:NormalizeName(targetName)
        if not playerName then
            return false
        end

        self.guild.manualRaiders[playerName] = nil
        self.guild.manualInactiveRaiders[playerName] = true
        self:NextRevision()
        self:AppendHistory(string.format("Raider removed: %s by %s [%s]", playerName, transaction.actor or "unknown", trimText(transaction.reason)))
        return true
    end

    if opType == "newmemberdkp" then
        self.guild.newMemberDefaultDkp = math.max(0, math.floor(safeNumber(transaction.value, 0) + 0.5))
        self:NextRevision()
        self:AppendHistory(string.format("New-member default DKP -> %d by %s [%s]", self.guild.newMemberDefaultDkp, transaction.actor or "unknown", trimText(transaction.reason)))
        return true
    end

    return false
end

function addon:ApplyTransactionRecord(transaction, silent, fromSync)
    if not self.guild or type(transaction) ~= "table" then
        return false
    end

    if trimText(transaction.recordType) == "config" then
        return self:ApplyConfigTransactionRecord(transaction, silent, fromSync)
    end

    local targetName = self:NormalizeName(transaction.target)
    local txId = trimText(transaction.txId)
    local opType = string.lower(trimText(transaction.opType))
    if not targetName or txId == "" then
        return false
    end

    if self.guild.transactionLogById and self.guild.transactionLogById[txId] then
        return false
    end

    if opType == "resolve" then
        self:RecordTransaction(transaction)
        self:MarkTransactionResolved(trimText(transaction.resolvedTxId), trimText(transaction.resolutionAction), transaction.actor or self:GetPlayerName() or "unknown")
        self:NextRevision()
        self:AppendHistory(string.format("Conflict %s resolved by %s (%s)", trimText(transaction.resolvedTxId), transaction.actor or "unknown", trimText(transaction.resolutionAction)))
        self:AppendActivity({
            type = "CONFLICT_RESOLVED",
            actor = transaction.actor,
            target = targetName,
            reason = trimText(transaction.resolutionAction),
            txId = txId,
        })
        return true
    end

    local existingPlayerData = self.guild.players and self.guild.players[targetName] or nil
    local oldValue = safeNumber(existingPlayerData and existingPlayerData.dkp, 0)
    local desiredValue
    local appliedDelta

    if opType == "delete" then
        local expectedOldValue = transaction.expectedOldValue
        if expectedOldValue ~= nil and safeNumber(expectedOldValue, oldValue) ~= oldValue then
            self:RecordTransaction(transaction)
            self:CreateConflict(transaction, oldValue, string.format("Expected %d before delete, found %d.", safeNumber(expectedOldValue, oldValue), oldValue))
            if not silent then
                self:Print(string.format("Conflict detected for %s delete. Review it in the Conflicts tab.", targetName))
            end
            return false
        end

        self:RecordTransaction(transaction)
        if self.guild.players then
            self.guild.players[targetName] = nil
        end
        if self.guild.manualRaiders then
            self.guild.manualRaiders[targetName] = nil
        end
        if self.guild.manualInactiveRaiders then
            self.guild.manualInactiveRaiders[targetName] = nil
        end
        if self.ui and self.ui.optionsSelectedMember == targetName then
            self.ui.optionsSelectedMember = nil
        end
        self:NextRevision()
        self:AppendHistory(string.format("Deleted player record for %s by %s [%s]", targetName, transaction.actor or "unknown", trimText(transaction.reason)))
        self:AppendActivity({
            type = "PLAYER_DELETE",
            actor = transaction.actor,
            target = targetName,
            oldValue = oldValue,
            newValue = 0,
            reason = transaction.reason,
            txId = txId,
        })
        return true
    end

    local playerData = self:EnsurePlayer(targetName)
    if not playerData then
        return false
    end

    if opType == "set" then
        local expectedOldValue = transaction.expectedOldValue
        if expectedOldValue ~= nil and safeNumber(expectedOldValue, oldValue) ~= oldValue then
            self:RecordTransaction(transaction)
            self:CreateConflict(transaction, oldValue, string.format("Expected %d before set, found %d.", safeNumber(expectedOldValue, oldValue), oldValue))
            if not silent then
                self:Print(string.format("Conflict detected for %s. Review it in the Conflicts tab.", targetName))
            end
            return false
        end

        desiredValue = math.floor(safeNumber(transaction.desiredValue, oldValue) + 0.5)
    else
        desiredValue = oldValue + math.floor(safeNumber(transaction.delta, 0) + 0.5)
    end

    appliedDelta = desiredValue - oldValue
    playerData.dkp = desiredValue
    if appliedDelta > 0 then
        playerData.earned = safeNumber(playerData.earned, 0) + appliedDelta
    elseif appliedDelta < 0 then
        playerData.spent = safeNumber(playerData.spent, 0) + math.abs(appliedDelta)
    end
    playerData.updatedAt = safeNumber(transaction.createdAt, time())

    self:RecordTransaction(transaction)
    self:NextRevision()
    self:AppendHistory(string.format("%s -> %s (%+d) by %s [%s]", targetName, desiredValue, appliedDelta, transaction.actor or "unknown", trimText(transaction.reason)))
    self:AppendActivity({
        type = fromSync and "PLAYER_TX_SYNC" or "PLAYER_TX",
        actor = transaction.actor,
        target = targetName,
        delta = appliedDelta,
        oldValue = oldValue,
        newValue = desiredValue,
        reason = transaction.reason,
        txId = txId,
    })

    if not silent then
        self:Print(string.format("%s now has %d DKP (%+d).", targetName, desiredValue, appliedDelta))
    end

    return true
end

function addon:BroadcastPlayerUpdate(targetName, delta, newValue, reason, txId, actor)
    local transaction = self:BuildPlayerTransaction("add", targetName, delta, newValue, reason, txId, actor, nil, time())
    self:BroadcastTransactionRecord(transaction)
end

function addon:ApplyPlayerTransaction(targetName, delta, newValue, reason, txId, actor, silent)
    local transaction = self:BuildPlayerTransaction("add", targetName, delta, newValue, reason, txId, actor, nil, time())
    return self:ApplyTransactionRecord(transaction, silent, false)
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
    local transaction = self:BuildPlayerTransaction("add", name, amount, newValue, reason or "Manual adjustment", self:MakeTransactionId("ADD", name), self:GetPlayerName(), nil, time())
    if self:ApplyTransactionRecord(transaction, true, false) then
        self:BroadcastTransactionRecord(transaction)
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
    local transaction = self:BuildPlayerTransaction("set", name, delta, resolvedValue, reason or "Manual set", self:MakeTransactionId("SET", name), self:GetPlayerName(), currentValue, time())
    if self:ApplyTransactionRecord(transaction, true, false) then
        self:BroadcastTransactionRecord(transaction)
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
