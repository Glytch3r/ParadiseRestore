if isClient() then return end

FactionManager = FactionManager or {}
if not FactionManager.isB41 then require "FactionManager/FactionManager_Shared" end
if FactionManager.isB41() then return end

FactionManager.data = FactionManager.data or nil
FactionManager.tick = FactionManager.tick or 0
FactionManager.pendingRenames = FactionManager.pendingRenames or {}
FactionManager.pendingDeletes = FactionManager.pendingDeletes or {}

function FactionManager.now()
    return os.time()
end

function FactionManager.date(int)
    if not int or tonumber(int) == nil then return "unknown" end
    return os.date("%Y-%m-%d %H:%M:%S", tonumber(int))
end

function FactionManager.getData()
    local data = ModData.getOrCreate(FactionManager.storeName)
    data.factions = data.factions or {}
    data.groups = data.groups or {}
    data.installedAt = data.installedAt or FactionManager.now()
    FactionManager.data = data
    return data
end

function FactionManager.isAdm(pl)
    return pl and pl.getAccessLevel and string.lower(tostring(pl:getAccessLevel())) == "admin"
end

function FactionManager.getStatePath(state, name)
    state = FactionManager.states[state] and state or "active"
    return FactionManager.statePaths[state] .. "/" .. FactionManager.safeName(name) .. ".log"
end

function FactionManager.readLog(path)
    local reader = getFileReader(path, false)
    if not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    return lines
end

function FactionManager.writeLines(path, lines)
    local writer = getFileWriter(path, true, false)
    if not writer then return false end
    for _, line in ipairs(lines or {}) do writer:write(line .. "\n") end
    writer:close()
    return true
end

function FactionManager.log(name, state, activity)
    if ParadiseRestore and ParadiseRestore.Sentinel and ParadiseRestore.Sentinel.writeFactionLog then
        return ParadiseRestore.Sentinel.writeFactionLog(FactionManager.getStatePath(state, name), tostring(activity))
    end
    local writer = getFileWriter(FactionManager.getStatePath(state, name), true, true)
    if not writer then return false end
    writer:write("[" .. FactionManager.date(FactionManager.now()) .. "] " .. tostring(activity) .. "\n")
    writer:close()
    return true
end

function FactionManager.logManager(activity)
    return FactionManager.log("_FactionManager", "active", activity)
end

function FactionManager.logGroupChange(records, activity)
    for _, record in ipairs(records or {}) do
        FactionManager.log(record.name, record.state, activity)
    end
end

function FactionManager.moveLog(name, oldState, newState)
    if oldState == newState then return end
    local oldPath = FactionManager.getStatePath(oldState, name)
    local newPath = FactionManager.getStatePath(newState, name)
    local lines = FactionManager.readLog(oldPath) or {}
    FactionManager.writeLines(newPath, lines)
    FactionManager.log(name, oldState, "log moved to " .. newPath)
end

function FactionManager.renameLog(oldName, newName, state)
    local oldPath = FactionManager.getStatePath(state, oldName)
    local newPath = FactionManager.getStatePath(state, newName)
    local lines = FactionManager.readLog(oldPath) or {}
    lines[#lines + 1] = "[" .. FactionManager.date(FactionManager.now()) .. "] " .. oldName .. " changed name to " .. newName
    FactionManager.writeLines(newPath, lines)
    FactionManager.log(oldName, state, "log renamed to " .. newPath)
end

function FactionManager.getMembers(faction)
    local result = {}
    if not faction then return result end
    local players = faction:getPlayers()
    if players then
        for int = 0, players:size() - 1 do result[#result + 1] = tostring(players:get(int)) end
    end
    table.sort(result, function(left, right) return string.lower(left) < string.lower(right) end)
    return result
end

function FactionManager.getColor(faction)
    local col = faction and faction:getTagColor() or nil
    return {
        r = col and col:getR() or 1,
        g = col and col:getG() or 1,
        b = col and col:getB() or 1,
    }
end

function FactionManager.updateRecord(record, faction)
    record.name = faction:getName()
    record.owner = faction:getOwner()
    record.members = FactionManager.getMembers(faction)
    record.tag = faction:getTag()
    record.color = FactionManager.getColor(faction)
    record.note = record.note or ""
    record.labels = record.labels or {}
    record.state = FactionManager.states[record.state] and record.state or "active"
    return record
end

function FactionManager.newRecord(faction, createdAt)
    local record = {
        createdAt = createdAt,
        lastActivity = createdAt,
        state = "active",
        note = "",
        labels = {},
    }
    return FactionManager.updateRecord(record, faction)
end

function FactionManager.setRecordState(record, state, reason)
    if not record or record.state == state then return false end
    local oldState = record.state
    record.state = state
    FactionManager.moveLog(record.name, oldState, state)
    FactionManager.log(record.name, state, reason)
    return true
end

function FactionManager.reconcile()
    local data = FactionManager.getData()
    local current = {}
    local factions = Faction.getFactions()
    local firstInstall = data.initialized ~= true
    for int = 0, factions:size() - 1 do
        local faction = factions:get(int)
        local name = faction:getName()
        current[name] = true
        local record = data.factions[name]
        if not record and not FactionManager.pendingRenames[name] and not FactionManager.pendingDeletes[name] then
            record = FactionManager.newRecord(faction, firstInstall and nil or FactionManager.now())
            data.factions[name] = record
            if not firstInstall then
                FactionManager.log(name, "active", tostring(faction:getOwner()) .. " created " .. name)
            end
        elseif record then
            FactionManager.updateRecord(record, faction)
        end
    end
    for oldName, newName in pairs(FactionManager.pendingRenames) do
        if current[newName] then FactionManager.pendingRenames[oldName] = nil end
    end
    for name in pairs(FactionManager.pendingDeletes) do
        if not current[name] then FactionManager.pendingDeletes[name] = nil end
    end
    for name, record in pairs(data.factions) do
        if record.state ~= "deleted" and not current[name] and not FactionManager.pendingRenames[name] then
            record.deletedAt = FactionManager.now()
            FactionManager.setRecordState(record, "deleted", name .. " disbanded")
        end
    end
    data.initialized = true
    ModData.transmit(FactionManager.storeName)
end

function FactionManager.getInactiveSeconds()
    local days = SandboxVars and SandboxVars.ParadiseZ and tonumber(SandboxVars.ParadiseZ.FactionInactiveDays) or 30
    return math.max(1, days) * 86400
end

function FactionManager.checkInactivity()
    local data = FactionManager.getData()
    local now = FactionManager.now()
    local changed = false
    for _, record in pairs(data.factions) do
        local activity = tonumber(record.lastActivity) or tonumber(data.installedAt)
        if record.state ~= "deleted" and activity and now - activity >= FactionManager.getInactiveSeconds() then
            changed = FactionManager.setRecordState(record, "inactive", record.name .. " inactivity label") or changed
        end
    end
    if changed then FactionManager.broadcastState() end
end
Events.EveryHours.Remove(FactionManager.checkInactivity)
Events.EveryHours.Add(FactionManager.checkInactivity)

function FactionManager.recordLogin(pl)
    if not pl then return end
    local faction = Faction.getPlayerFaction(pl:getUsername())
    if not faction then return end
    local tracksMembers = SandboxVars and SandboxVars.ParadiseZ and SandboxVars.ParadiseZ.FactionActivityTracksMembers == true
    if faction:getOwner() ~= pl:getUsername() and not tracksMembers then return end
    local data = FactionManager.getData()
    local record = data.factions[faction:getName()]
    if not record then return end
    if faction:getOwner() == pl:getUsername() then record.lastOwnerLogin = FactionManager.now() end
    record.lastActivity = FactionManager.now()
    local changed = FactionManager.setRecordState(record, "active", faction:getName() .. " activity restored by " .. pl:getUsername())
    ModData.transmit(FactionManager.storeName)
    if changed then FactionManager.broadcastState() end
end

function FactionManager.serializeRecord(record)
    return {
        name = record.name,
        owner = record.owner,
        members = FactionManager.copyTab(record.members),
        tag = record.tag,
        color = FactionManager.copyTab(record.color),
        createdAt = record.createdAt,
        lastActivity = record.lastActivity,
        lastOwnerLogin = record.lastOwnerLogin,
        deletedAt = record.deletedAt,
        state = record.state,
        note = record.note,
        labels = FactionManager.copyTab(record.labels),
    }
end

function FactionManager.buildState()
    FactionManager.reconcile()
    local data = FactionManager.getData()
    local result = { factions = {}, groups = FactionManager.copyTab(data.groups), serverTime = FactionManager.now() }
    for _, record in pairs(data.factions) do result.factions[#result.factions + 1] = FactionManager.serializeRecord(record) end
    table.sort(result.factions, function(left, right) return string.lower(left.name) < string.lower(right.name) end)
    table.sort(result.groups, function(left, right) return string.lower(left) < string.lower(right) end)
    return result
end

function FactionManager.sendState(pl)
    if not FactionManager.isAdm(pl) then return end
    sendServerCommand(pl, FactionManager.module, FactionManager.commands.state, FactionManager.buildState())
end

function FactionManager.broadcastState()
    local players = getOnlinePlayers()
    if not players then return end
    for int = 0, players:size() - 1 do FactionManager.sendState(players:get(int)) end
end

function FactionManager.sendVanillaState()
    local state = FactionManager.buildState()
    sendServerCommand(FactionManager.module, "vanillaState", state)
end

function FactionManager.findOnlinePlayer(user)
    local players = getOnlinePlayers()
    if not players then return nil end
    for int = 0, players:size() - 1 do
        local pl = players:get(int)
        if pl and pl:getUsername() == user then return pl end
    end
    return nil
end

function FactionManager.changeGroup(pl, act, args)
    local data = FactionManager.getData()
    local group = FactionManager.trim(args.group)
    if group == "" or #group > 40 then return false end
    if act == "createGroup" then
        if FactionManager.listHas(data.groups, group) then return false end
        data.groups[#data.groups + 1] = group
        FactionManager.logManager(pl:getUsername() .. " created faction filter group " .. group)
        return true
    end
    if act == "deleteGroup" then
        local affected = {}
        FactionManager.removeListValue(data.groups, group)
        for _, record in pairs(data.factions) do
            if FactionManager.listHas(record.labels, group) then affected[#affected + 1] = record end
            FactionManager.removeListValue(record.labels, group)
        end
        FactionManager.logGroupChange(affected, pl:getUsername() .. " deleted faction filter group " .. group)
        FactionManager.logManager(pl:getUsername() .. " deleted faction filter group " .. group)
        return true
    end
    if act == "renameGroup" then
        local newGroup = FactionManager.trim(args.value)
        if newGroup == "" or #newGroup > 40 or FactionManager.listHas(data.groups, newGroup) then return false end
        for int, value in ipairs(data.groups) do if value == group then data.groups[int] = newGroup end end
        local affected = {}
        for _, record in pairs(data.factions) do
            for int, value in ipairs(record.labels) do if value == group then record.labels[int] = newGroup end end
            if FactionManager.listHas(record.labels, newGroup) then affected[#affected + 1] = record end
        end
        FactionManager.logGroupChange(affected, pl:getUsername() .. " renamed faction filter group " .. group .. " to " .. newGroup)
        FactionManager.logManager(pl:getUsername() .. " renamed faction filter group " .. group .. " to " .. newGroup)
        return true
    end
    return false
end

function FactionManager.changeMetadata(pl, act, args, record)
    if act == "setNote" then
        record.note = tostring(args.value or ""):sub(1, 4000)
        FactionManager.log(record.name, record.state, pl:getUsername() .. " changed admin note")
        return true
    end
    local group = FactionManager.trim(args.group)
    if group == "" or not FactionManager.listHas(FactionManager.getData().groups, group) then return false end
    if act == "addLabel" and not FactionManager.listHas(record.labels, group) then
        record.labels[#record.labels + 1] = group
        FactionManager.log(record.name, record.state, pl:getUsername() .. " added label " .. group)
        return true
    end
    if act == "removeLabel" then
        FactionManager.removeListValue(record.labels, group)
        FactionManager.log(record.name, record.state, pl:getUsername() .. " removed label " .. group)
        return true
    end
    return false
end

function FactionManager.performVanilla(pl, act, args, record)
    local faction = FactionManager.getFactionByName(record.name)
    if not faction then return false end
    if act == "rename" then
        local newName = FactionManager.trim(args.value)
        if #newName < 3 or #newName > 15 or Faction.getFaction(newName) then return false end
        local data = FactionManager.getData()
        data.factions[record.name] = nil
        local oldName = record.name
        record.name = newName
        data.factions[newName] = record
        FactionManager.pendingRenames[oldName] = newName
        FactionManager.renameLog(oldName, newName, record.state)
        sendServerCommand(pl, FactionManager.module, FactionManager.commands.perform, { act = act, faction = oldName, value = newName })
        return true
    end
    if act == "delete" then
        FactionManager.pendingDeletes[record.name] = true
        record.deletedAt = FactionManager.now()
        FactionManager.setRecordState(record, "deleted", record.name .. " disbanded by " .. pl:getUsername())
        sendServerCommand(pl, FactionManager.module, FactionManager.commands.perform, { act = act, faction = record.name })
        return true
    end
    if act == "setOwner" then
        local user = FactionManager.trim(args.user)
        if user == "" then return false end
        if not faction:isMember(user) and not faction:isOwner(user) then
            local targPl = FactionManager.findOnlinePlayer(user)
            if not targPl or Faction.getPlayerFaction(user) then return false end
            faction:addPlayer(user)
        end
        FactionManager.log(record.name, record.state, record.name .. " " .. tostring(record.owner) .. " transfered the faction to " .. user)
        sendServerCommand(pl, FactionManager.module, FactionManager.commands.perform, { act = act, faction = record.name, user = user })
        return true
    end
    if act == "setTag" then
        local value = FactionManager.trim(args.value)
        if #value < 1 or #value > 4 or not faction:canCreateTag() then return false end
        FactionManager.log(record.name, record.state, pl:getUsername() .. " changed vanilla tag from " .. tostring(record.tag or "") .. " to " .. value)
        sendServerCommand(pl, FactionManager.module, FactionManager.commands.perform, { act = act, faction = record.name, value = value })
        return true
    end
    if act == "setColor" then
        if not faction:getTag() or not faction:canCreateTag() then return false end
        local r = math.max(0, math.min(1, tonumber(args.r) or 1))
        local g = math.max(0, math.min(1, tonumber(args.g) or 1))
        local b = math.max(0, math.min(1, tonumber(args.b) or 1))
        FactionManager.log(record.name, record.state, pl:getUsername() .. " changed faction color to " .. r .. "," .. g .. "," .. b)
        sendServerCommand(pl, FactionManager.module, FactionManager.commands.perform, { act = act, faction = record.name, r = r, g = g, b = b })
        return true
    end
    return false
end

function FactionManager.changeMember(pl, act, args, record)
    local faction = FactionManager.getFactionByName(record.name)
    local user = FactionManager.trim(args.user)
    if not faction or user == "" then return false end
    if act == "addPlayer" then
        if not FactionManager.findOnlinePlayer(user) or Faction.getPlayerFaction(user) then return false end
        faction:addPlayer(user)
        FactionManager.updateRecord(record, faction)
        FactionManager.log(record.name, record.state, record.name .. " recruited " .. user .. " " .. FactionManager.getMemberCount(faction) .. " members count")
        return true
    end
    if act == "removePlayer" and not faction:isOwner(user) and faction:isMember(user) then
        FactionManager.log(record.name, record.state, record.name .. " removed " .. user .. " " .. tostring(FactionManager.getMemberCount(faction) - 1) .. " members count")
        sendServerCommand(pl, FactionManager.module, FactionManager.commands.perform, { act = act, faction = record.name, user = user })
        return true
    end
    return false
end

function FactionManager.mutate(pl, args)
    if not FactionManager.isAdm(pl) or type(args) ~= "table" then return end
    local act = FactionManager.trim(args.act)
    local changed = false
    if act == "createGroup" or act == "deleteGroup" or act == "renameGroup" then
        changed = FactionManager.changeGroup(pl, act, args)
    else
        local record = FactionManager.getData().factions[FactionManager.trim(args.faction)]
        if not record then return end
        if act == "setNote" or act == "addLabel" or act == "removeLabel" then
            changed = FactionManager.changeMetadata(pl, act, args, record)
        elseif act == "addPlayer" or act == "removePlayer" then
            changed = FactionManager.changeMember(pl, act, args, record)
        elseif record.state ~= "deleted" then
            changed = FactionManager.performVanilla(pl, act, args, record)
        end
    end
    if not changed then return end
    ModData.transmit(FactionManager.storeName)
    FactionManager.sendVanillaState()
    FactionManager.broadcastState()
end

function FactionManager.onClientCommand(module, command, pl, args)
    if module ~= FactionManager.module then return end
    if command == FactionManager.commands.request then
        FactionManager.sendState(pl)
    elseif command == FactionManager.commands.mutate then
        FactionManager.mutate(pl, args)
    elseif command == FactionManager.commands.login then
        FactionManager.recordLogin(pl)
    end
end
Events.OnClientCommand.Remove(FactionManager.onClientCommand)
Events.OnClientCommand.Add(FactionManager.onClientCommand)

function FactionManager.onServerStarted()
    FactionManager.getData()
    FactionManager.reconcile()
end
Events.OnServerStarted.Remove(FactionManager.onServerStarted)
Events.OnServerStarted.Add(FactionManager.onServerStarted)

function FactionManager.onTick()
    FactionManager.tick = FactionManager.tick + 1
    if FactionManager.tick < 300 then return end
    FactionManager.tick = 0
    FactionManager.reconcile()
end
Events.OnTick.Remove(FactionManager.onTick)
Events.OnTick.Add(FactionManager.onTick)
