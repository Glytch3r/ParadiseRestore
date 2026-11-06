if isClient() then return end

SquadManager = SquadManager or {}
if not SquadManager.isB41 then require "SquadManager/SquadManager_Shared" end
if SquadManager.isB41() then return end

SquadManager.data = SquadManager.data or nil
SquadManager.byMember = SquadManager.byMember or {}
SquadManager.onlineUser = SquadManager.onlineUser or {}
SquadManager.tagList = SquadManager.tagList or {}
SquadManager.tagSeq = SquadManager.tagSeq or 0
SquadManager.rate = SquadManager.rate or {}
SquadManager.clock = SquadManager.clock or 0
SquadManager.lastConfig = SquadManager.lastConfig or nil

SquadManager.events = {
    joined = "joined",
    left = "left",
    commenced = "commenced",
}

function SquadManager.serverNow()
    return os.time()
end

function SquadManager.getConfig()
    local values = {}
    local ok, opts = pcall(getSandboxOptions)
    for _, name in ipairs(SquadManager.optionKeys) do
        local value = SquadManager.defaults[name]
        if ok and opts and opts.getOptionByName then
            local found, result = pcall(function() return opts:getOptionByName("SquadManager." .. name) end)
            if found and result and result.getValue then
                local readOk, read = pcall(function() return result:getValue() end)
                if readOk and read ~= nil then value = read end
            end
        end
        values[name] = value
    end
    return SquadManager.sanitizeConfig(values)
end

function SquadManager.sameConfig(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for _, name in ipairs(SquadManager.optionKeys) do
        if tostring(a[name]) ~= tostring(b[name]) then return false end
    end
    return true
end

function SquadManager.getData()
    local data = ModData.getOrCreate(SquadManager.storeName)
    data.squads = data.squads or {}
    data.invites = data.invites or {}
    SquadManager.data = data
    return data
end

function SquadManager.flush()
    ModData.transmit(SquadManager.storeName)
end

function SquadManager.rebuildIndex()
    local data = SquadManager.getData()
    SquadManager.byMember = {}
    for key, squad in pairs(data.squads or {}) do
        if type(squad) == "table" then
            for _, user in ipairs(SquadManager.memberUsers(squad)) do
                SquadManager.byMember[user] = key
            end
        end
    end
end

function SquadManager.getSquad(user)
    local key = SquadManager.byMember[user]
    if not key then return nil, nil end
    local squad = SquadManager.getData().squads[key]
    if type(squad) ~= "table" then return nil, nil end
    return squad, key
end

function SquadManager.memberUsers(squad)
    local result = {}
    for _, item in ipairs(SquadManager.seatsOrdered(squad)) do
        result[#result + 1] = item.user
    end
    return result
end

function SquadManager.plOf(user)
    local pl = SquadManager.onlineUser[user]
    if pl and pl:getUsername() == user then return pl end
    return nil
end

function SquadManager.toMembers(squad, command, args, excludeUser)
    if type(squad) ~= "table" then return end
    for _, user in ipairs(SquadManager.memberUsers(squad)) do
        if user ~= excludeUser then
            local pl = SquadManager.plOf(user)
            if pl then sendServerCommand(pl, SquadManager.module, command, args or {}) end
        end
    end
end

function SquadManager.onlineList()
    local result = {}
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return result end
    for int = 0, players:size() - 1 do
        local pl = players:get(int)
        if pl and pl:getUsername() then result[#result + 1] = pl end
    end
    return result
end

function SquadManager.toUser(user, command, args)
    local pl = SquadManager.plOf(user)
    if pl then sendServerCommand(pl, SquadManager.module, command, args or {}) end
end

function SquadManager.toEveryone(command, args)
    for _, pl in ipairs(SquadManager.onlineList()) do
        sendServerCommand(pl, SquadManager.module, command, args or {})
    end
end

function SquadManager.sendConfig(pl)
    if not pl then return end
    sendServerCommand(pl, SquadManager.module, SquadManager.commands.config, SquadManager.getConfig())
end

function SquadManager.sendState(pl)
    if not pl then return end
    local user = pl:getUsername()
    local squad, key = SquadManager.getSquad(user)
    sendServerCommand(pl, SquadManager.module, SquadManager.commands.state, {
        key = key,
        user = user,
        squad = squad,
        config = SquadManager.getConfig(),
    })
end

function SquadManager.broadcastState(squad)
    for _, user in ipairs(SquadManager.memberUsers(squad)) do
        SquadManager.sendState(SquadManager.plOf(user))
    end
end

function SquadManager.notifyMembers(squad, event, user, excludeUser)
    SquadManager.toMembers(squad, SquadManager.commands.none, { event = event, user = user }, excludeUser)
end

function SquadManager.rateOk(user, bucket, limit, window)
    local stamp = SquadManager.serverNow()
    local entry = SquadManager.rate[user]
    if not entry then
        entry = {}
        SquadManager.rate[user] = entry
    end
    local last = entry[bucket] or 0
    if stamp - last < window then return false end
    entry[bucket] = stamp
    return true
end

function SquadManager.newSquad(user)
    local data = SquadManager.getData()
    local squad = {
        leader = user,
        active = false,
        created = SquadManager.serverNow(),
        seats = { [1] = user },
    }
    data.squads[user] = squad
    SquadManager.byMember[user] = user
    return squad
end

function SquadManager.freeSeat(squad, max)
    local seats = SquadManager.seatList(squad)
    for seat = 1, max do
        if not seats[seat] or seats[seat] == "" then return seat end
    end
    return nil
end

function SquadManager.removeSeat(squad, seat)
    if seat <= 1 then return end
    SquadManager.clearSeat(squad, seat)
    SquadManager.compact(squad)
end

function SquadManager.compact(squad)
    if type(squad) ~= "table" then return end
    local leader = SquadManager.sanitizeUser(squad.leader)
    if leader == "" then leader = nil end
    local others = {}
    for _, item in ipairs(SquadManager.seatsOrdered(squad)) do
        if item.user ~= leader then others[#others + 1] = item.user end
    end
    local seats = {}
    local int = 1
    if leader then
        seats[1] = leader
        int = 2
    end
    for _, user in ipairs(others) do
        seats[int] = user
        int = int + 1
    end
    squad.seats = seats
end

function SquadManager.destroy(squadKey, reason)
    local data = SquadManager.getData()
    local squad = data.squads[squadKey]
    if type(squad) ~= "table" then return end
    for _, user in ipairs(SquadManager.memberUsers(squad)) do
        SquadManager.byMember[user] = nil
        SquadManager.toUser(user, SquadManager.commands.departed, { reason = tostring(reason or "disbanded") })
        SquadManager.sendState(SquadManager.plOf(user))
    end
    SquadManager.dropTags(SquadManager.memberUsers(squad))
    data.squads[squadKey] = nil
    for user, entry in pairs(data.invites or {}) do
        local leader = type(entry) == "table" and entry.leader or entry
        if leader == squadKey then data.invites[user] = nil end
    end
    SquadManager.flush()
end

function SquadManager.detach(squad, user)
    local seat = SquadManager.seatOf(squad, user)
    if seat > 0 then SquadManager.clearSeat(squad, seat) end
    if SquadManager.sanitizeUser(squad.leader) == user then squad.leader = nil end
    SquadManager.compact(squad)
    SquadManager.byMember[user] = nil
    return SquadManager.seatCount(squad)
end

function SquadManager.rename(squad, oldKey, newLeader)
    local data = SquadManager.getData()
    newLeader = SquadManager.sanitizeUser(newLeader)
    if newLeader == "" then return oldKey end
    squad.leader = newLeader
    SquadManager.compact(squad)
    squad.active = false
    data.squads[oldKey] = nil
    data.squads[newLeader] = squad
    for _, user in ipairs(SquadManager.memberUsers(squad)) do
        SquadManager.byMember[user] = newLeader
    end
    for user, entry in pairs(data.invites or {}) do
        if type(entry) == "table" and entry.leader == oldKey then entry.leader = newLeader end
    end
    return newLeader
end

function SquadManager.promoteNext(squad, oldKey)
    local users = SquadManager.memberUsers(squad)
    if #users <= 0 then return nil end
    return SquadManager.rename(squad, oldKey, users[1])
end

function SquadManager.onLogin(pl)
    if not pl then return end
    SquadManager.onlineUser[pl:getUsername()] = pl
    SquadManager.rebuildIndex()
    SquadManager.sendConfig(pl)
    SquadManager.sendState(pl)
end

function SquadManager.removeOnlineMember(pl, reason)
    local user = pl:getUsername()
    local squad, key = SquadManager.getSquad(user)
    if not squad then return end
    local wasLeader = SquadManager.isLeader(squad, user)
    SquadManager.detach(squad, user)
    SquadManager.dropTags({ user })
    SquadManager.toUser(user, SquadManager.commands.departed, { reason = tostring(reason) })
    if SquadManager.seatCount(squad) <= 0 then
        SquadManager.destroy(key, reason)
        return
    end
    if wasLeader then SquadManager.promoteNext(squad, key) end
    SquadManager.flush()
    SquadManager.broadcastState(squad)
    SquadManager.notifyMembers(squad, SquadManager.events.left, user)
end

function SquadManager.onDeath(pl)
    if not pl then return end
    local config = SquadManager.getConfig()
    local user = pl:getUsername()
    local squad, key = SquadManager.getSquad(user)
    if not squad then return end
    if not config.SquadSystemEnabled then
        SquadManager.destroy(key, "disabled")
        return
    end
    if not SquadManager.isLeader(squad, user) then return end
    if config.DisbandWhenLeaderDies then
        SquadManager.destroy(key, "leaderDead")
        return
    end
    SquadManager.removeOnlineMember(pl, "leaderDead")
end

function SquadManager.tickPositions()
    for _, squad in pairs(SquadManager.getData().squads or {}) do
        if type(squad) == "table" and squad.active then
            local packed = {}
            for _, item in ipairs(SquadManager.seatsOrdered(squad)) do
                local pl = SquadManager.plOf(item.user)
                if pl then
                    packed[#packed + 1] = {
                        seat = item.seat,
                        user = item.user,
                        x = math.floor(pl:getX()),
                        y = math.floor(pl:getY()),
                        z = math.floor(pl:getZ()),
                        dir = math.floor((pl:getDirection() or 0) * 100) / 100,
                    }
                end
            end
            if #packed > 0 then
                SquadManager.toMembers(squad, SquadManager.commands.positions, { members = packed })
            end
        end
    end
end

function SquadManager.tickAutoLeave()
    local config = SquadManager.getConfig()
    for key, squad in pairs(SquadManager.getData().squads or {}) do
        if type(squad) == "table" then
            local leader = SquadManager.plOf(squad.leader)
            if leader then
                for _, user in ipairs(SquadManager.memberUsers(squad)) do
                    if user ~= squad.leader then
                        local pl = SquadManager.plOf(user)
                        if pl and pl:DistTo(leader:getX(), leader:getY()) > config.AutoLeaveDistance then
                            SquadManager.removeOnlineMember(pl, "distance")
                        end
                    end
                end
            elseif SquadManager.seatCount(squad) > 0 then
                SquadManager.destroy(key, "leaderGone")
            end
        end
    end
end

function SquadManager.dropTags(users)
    if #SquadManager.tagList <= 0 then return end
    local doomed = {}
    for _, user in ipairs(users or {}) do doomed[user] = true end
    for int = #SquadManager.tagList, 1, -1 do
        local tag = SquadManager.tagList[int]
        if doomed[tag.owner] then
            SquadManager.toEveryone(SquadManager.commands.tagExpire, { id = tag.id })
            table.remove(SquadManager.tagList, int)
        end
    end
end

function SquadManager.tickTags()
    if #SquadManager.tagList <= 0 then return end
    local stamp = SquadManager.serverNow()
    for int = #SquadManager.tagList, 1, -1 do
        local tag = SquadManager.tagList[int]
        if stamp >= tag.expires then
            SquadManager.toEveryone(SquadManager.commands.tagExpire, { id = tag.id })
            table.remove(SquadManager.tagList, int)
        else
            local pl = tag.user and SquadManager.plOf(tag.user) or nil
            if pl and not pl:isDead() then
                tag.x = math.floor(pl:getX())
                tag.y = math.floor(pl:getY())
                tag.z = math.floor(pl:getZ())
            elseif tag.user then
                SquadManager.toEveryone(SquadManager.commands.tagExpire, { id = tag.id })
                table.remove(SquadManager.tagList, int)
            end
        end
    end
end

function SquadManager.tickInvites()
    local data = SquadManager.getData()
    local stamp = SquadManager.serverNow()
    local changed = false
    for user, entry in pairs(data.invites or {}) do
        if type(entry) ~= "table" or stamp >= (entry.expires or 0) then
            local leader = type(entry) == "table" and entry.leader or ""
            data.invites[user] = nil
            SquadManager.toUser(user, SquadManager.commands.inviteResolved, { fromUser = leader })
            changed = true
        end
    end
    if changed then SquadManager.flush() end
end

function SquadManager.tickEnabled()
    local config = SquadManager.getConfig()
    local previous = SquadManager.lastConfig
    SquadManager.lastConfig = config
    if previous and previous.SquadSystemEnabled and not config.SquadSystemEnabled then
        SquadManager.disableAll()
    end
    if previous and not SquadManager.sameConfig(previous, config) then
        for _, pl in ipairs(SquadManager.onlineList()) do SquadManager.sendConfig(pl) end
    end
end

function SquadManager.tickOnline()
    local present = {}
    local dropped = {}
    for _, pl in ipairs(SquadManager.onlineList()) do
        local user = pl:getUsername()
        if user then
            present[user] = pl
            if not SquadManager.onlineUser[user] then SquadManager.onlineUser[user] = pl end
        end
    end
    for user, pl in pairs(SquadManager.onlineUser) do
        if not present[user] then dropped[#dropped + 1] = pl end
    end
    for _, pl in ipairs(dropped) do
        SquadManager.onlineUser[pl:getUsername()] = nil
        SquadManager.rate[pl:getUsername()] = nil
        SquadManager.removeOnlineMember(pl, "offline")
    end
end

function SquadManager.disableAll()
    local data = SquadManager.getData()
    for key in pairs(data.squads or {}) do SquadManager.destroy(key, "disabled") end
    for user in pairs(data.invites or {}) do data.invites[user] = nil end
    SquadManager.tagList = {}
    SquadManager.flush()
end

function SquadManager.onTick()
    local stamp = SquadManager.serverNow()
    if SquadManager.clock == stamp then return end
    SquadManager.clock = stamp
    SquadManager.tickOnline()
    SquadManager.tickEnabled()
    SquadManager.tickAutoLeave()
    SquadManager.tickPositions()
    SquadManager.tickTags()
    SquadManager.tickInvites()
end

function SquadManager.actCreate(pl, args)
    local config = SquadManager.getConfig()
    if not config.SquadSystemEnabled then return end
    local user = pl:getUsername()
    if SquadManager.getSquad(user) then
        SquadManager.sendState(pl)
        return
    end
    SquadManager.newSquad(user)
    SquadManager.flush()
    SquadManager.sendState(pl)
end

function SquadManager.actInvite(pl, args)
    local config = SquadManager.getConfig()
    if not config.SquadSystemEnabled then return end
    local user = pl:getUsername()
    local squad, key = SquadManager.getSquad(user)
    if not SquadManager.isLeader(squad, user) then return end
    local target = SquadManager.sanitizeUser(args.user)
    if target == "" or target == user then return end
    if not SquadManager.plOf(target) then return end
    if SquadManager.getSquad(target) then return end
    if SquadManager.seatCount(squad) >= config.SquadMaxMembers then return end
    local data = SquadManager.getData()
    data.invites[target] = { leader = key, expires = SquadManager.serverNow() + 30 }
    SquadManager.flush()
    SquadManager.toUser(target, SquadManager.commands.invitePrompt, { fromUser = user, squad = key })
end

function SquadManager.actRespond(pl, args)
    local config = SquadManager.getConfig()
    local user = pl:getUsername()
    local data = SquadManager.getData()
    local entry = data.invites[user]
    data.invites[user] = nil
    if type(entry) ~= "table" then return end
    local squad = data.squads[entry.leader]
    SquadManager.toUser(user, SquadManager.commands.inviteResolved, { fromUser = entry.leader, accepted = args.accept and true or false })
    if not config.SquadSystemEnabled or type(squad) ~= "table" or not args.accept then
        SquadManager.flush()
        return
    end
    if SquadManager.getSquad(user) then
        SquadManager.flush()
        return
    end
    if SquadManager.seatCount(squad) >= config.SquadMaxMembers then
        SquadManager.flush()
        return
    end
    local seat = SquadManager.freeSeat(squad, config.SquadMaxMembers)
    if not seat then
        SquadManager.flush()
        return
    end
    SquadManager.setSeat(squad, seat, user)
    SquadManager.byMember[user] = entry.leader
    SquadManager.onlineUser[user] = pl
    SquadManager.flush()
    SquadManager.sendState(pl)
    SquadManager.broadcastState(squad)
    SquadManager.notifyMembers(squad, SquadManager.events.joined, user, user)
end

function SquadManager.actTransfer(pl, args)
    local config = SquadManager.getConfig()
    if not config.SquadSystemEnabled then return end
    local user = pl:getUsername()
    local squad, key = SquadManager.getSquad(user)
    if not squad then return end
    local from = math.floor(tonumber(args.from) or 0)
    local to = math.floor(tonumber(args.to) or 0)
    if from <= 0 or to <= 0 or from == to then return end
    if from > config.SquadMaxMembers or to > config.SquadMaxMembers then return end
    local src = SquadManager.seatUser(squad, from)
    if not src then return end
    local dst = SquadManager.seatUser(squad, to)
    if not SquadManager.isLeader(squad, user) and src ~= user then return end
    if to == 1 and not SquadManager.isLeader(squad, user) then return end
    SquadManager.setSeat(squad, from, dst)
    SquadManager.setSeat(squad, to, src)
    local top = SquadManager.seatUser(squad, 1)
    if top ~= SquadManager.sanitizeUser(squad.leader) then
        key = SquadManager.rename(squad, key, top)
    end
    SquadManager.flush()
    SquadManager.broadcastState(squad)
end

function SquadManager.actKick(pl, args)
    local config = SquadManager.getConfig()
    if not config.SquadSystemEnabled then return end
    local user = pl:getUsername()
    local squad, key = SquadManager.getSquad(user)
    if not SquadManager.isLeader(squad, user) then return end
    local seat = math.floor(tonumber(args.seat) or 0)
    if seat <= 1 or seat > config.SquadMaxMembers then return end
    local target = SquadManager.seatUser(squad, seat)
    if not target then return end
    SquadManager.detach(squad, target)
    SquadManager.toUser(target, SquadManager.commands.departed, { reason = "kicked" })
    if SquadManager.seatCount(squad) <= 0 then
        SquadManager.destroy(key, "empty")
        return
    end
    SquadManager.flush()
    SquadManager.broadcastState(squad)
    SquadManager.notifyMembers(squad, SquadManager.events.left, target)
end

function SquadManager.actLeave(pl, args)
    SquadManager.removeOnlineMember(pl, "left")
end

function SquadManager.actCommence(pl, args)
    local config = SquadManager.getConfig()
    if not config.SquadSystemEnabled then return end
    local user = pl:getUsername()
    local squad = SquadManager.getSquad(user)
    if not SquadManager.isLeader(squad, user) then return end
    if squad.active then
        SquadManager.sendState(pl)
        return
    end
    squad.active = true
    SquadManager.flush()
    SquadManager.broadcastState(squad)
    SquadManager.notifyMembers(squad, SquadManager.events.commenced)
end

function SquadManager.actDisband(pl, args)
    local user = pl:getUsername()
    local squad, key = SquadManager.getSquad(user)
    if not SquadManager.isLeader(squad, user) then return end
    SquadManager.destroy(key, "disbanded")
end

function SquadManager.actChat(pl, args)
    local config = SquadManager.getConfig()
    if not config.SquadSystemEnabled then return end
    local user = pl:getUsername()
    local squad = SquadManager.getSquad(user)
    if not squad or not squad.active then return end
    local text = tostring(args.text or ""):gsub("%c", " ")
    text = text:match("^%s*(.-)%s*$") or ""
    if #text <= 0 or #text > 140 then return end
    if not SquadManager.rateOk(user, "chat", 5, 10) then return end
    SquadManager.toMembers(squad, SquadManager.commands.chatLine, { user = user, text = text })
end

function SquadManager.actActionCall(pl, args)
    local config = SquadManager.getConfig()
    if not config.SquadSystemEnabled then return end
    local user = pl:getUsername()
    local squad = SquadManager.getSquad(user)
    if not squad or not squad.active then return end
    local entry = SquadManager.actionCallByIndex(args.index)
    if not entry then return end
    if entry.leader and not SquadManager.isLeader(squad, user) then return end
    if not SquadManager.rateOk(user, "call", 1, 1) then return end
    local tx = tonumber(args.tx)
    local ty = tonumber(args.ty)
    local tz = tonumber(args.tz)
    local payload = {
        user = user,
        index = entry.index,
        seat = SquadManager.seatOf(squad, user),
        x = math.floor(pl:getX()),
        y = math.floor(pl:getY()),
        z = math.floor(pl:getZ()),
        leader = SquadManager.isLeader(squad, user) and true or false,
    }
    if tx and ty and tz and pl:DistTo(tx, ty) <= 60 then
        payload.tx = math.floor(tx)
        payload.ty = math.floor(ty)
        payload.tz = math.floor(tz)
    end
    SquadManager.toMembers(squad, SquadManager.commands.actionCall, payload)
end

function SquadManager.actTag(pl, args)
    local config = SquadManager.getConfig()
    if not config.SquadSystemEnabled then return end
    local user = pl:getUsername()
    local squad = SquadManager.getSquad(user)
    if not squad or not squad.active then return end
    if not SquadManager.rateOk(user, "tag", 1, 1) then return end
    local kind = args.kind == "player" and "player" or "zombie"
    local x = math.floor(tonumber(args.x) or 0)
    local y = math.floor(tonumber(args.y) or 0)
    local z = math.floor(tonumber(args.z) or 0)
    local targetUser = nil
    if kind == "player" then
        targetUser = SquadManager.sanitizeUser(args.user)
        if targetUser == "" or targetUser == user then return end
        local targPl = SquadManager.plOf(targetUser)
        if not targPl then return end
        x = math.floor(targPl:getX())
        y = math.floor(targPl:getY())
        z = math.floor(targPl:getZ())
        if not SquadManager.rateOk(user, "tagPlayer", 4, 10) then return end
    elseif not SquadManager.rateOk(user, "tagZombie", 6, 10) then
        return
    end
    if x == 0 and y == 0 then return end
    if pl:DistTo(x, y) > 60 then return end
    SquadManager.tagSeq = SquadManager.tagSeq + 1
    local id = tostring(SquadManager.tagSeq)
    local tag = {
        id = id,
        kind = kind,
        user = targetUser,
        owner = user,
        x = x,
        y = y,
        z = z,
        expires = SquadManager.serverNow() + config.TargetTagDuration,
    }
    SquadManager.tagList[#SquadManager.tagList + 1] = tag
    SquadManager.toEveryone(SquadManager.commands.tagAdd, {
        id = id,
        kind = kind,
        owner = user,
        user = targetUser,
        x = tag.x,
        y = tag.y,
        z = tag.z,
        ttl = config.TargetTagDuration,
    })
end

function SquadManager.onClientCommand(module, command, pl, args)
    if module ~= SquadManager.module then return end
    if not pl then return end
    args = type(args) == "table" and args or {}
    SquadManager.onlineUser[pl:getUsername()] = pl

    if command == SquadManager.commands.requestState then
        SquadManager.sendState(pl)
    elseif command == SquadManager.commands.login then
        SquadManager.onLogin(pl)
    elseif command == SquadManager.commands.create then
        SquadManager.actCreate(pl, args)
    elseif command == SquadManager.commands.invite then
        SquadManager.actInvite(pl, args)
    elseif command == SquadManager.commands.respond then
        SquadManager.actRespond(pl, args)
    elseif command == SquadManager.commands.transferSeat then
        SquadManager.actTransfer(pl, args)
    elseif command == SquadManager.commands.kick then
        SquadManager.actKick(pl, args)
    elseif command == SquadManager.commands.leave then
        SquadManager.actLeave(pl, args)
    elseif command == SquadManager.commands.commence then
        SquadManager.actCommence(pl, args)
    elseif command == SquadManager.commands.disband then
        SquadManager.actDisband(pl, args)
    elseif command == SquadManager.commands.chat then
        SquadManager.actChat(pl, args)
    elseif command == SquadManager.commands.actionCall then
        SquadManager.actActionCall(pl, args)
    elseif command == SquadManager.commands.tag then
        SquadManager.actTag(pl, args)
    elseif command == SquadManager.commands.config then
        SquadManager.sendConfig(pl)
    end
end
Events.OnClientCommand.Remove(SquadManager.onClientCommand)
Events.OnClientCommand.Add(SquadManager.onClientCommand)

function SquadManager.onCharacterDeath(char)
    if not char or not instanceof(char, "IsoPlayer") then return end
    SquadManager.onDeath(char)
end
Events.OnCharacterDeath.Remove(SquadManager.onCharacterDeath)
Events.OnCharacterDeath.Add(SquadManager.onCharacterDeath)

function SquadManager.onGameStart()
    SquadManager.onlineUser = {}
    SquadManager.rate = {}
    SquadManager.tagList = {}
    SquadManager.clock = 0
    SquadManager.lastConfig = nil
    SquadManager.rebuildIndex()
    local config = SquadManager.getConfig()
    SquadManager.lastConfig = config
    if not config.SquadSystemEnabled then SquadManager.disableAll() end
end
Events.OnGameStart.Remove(SquadManager.onGameStart)
Events.OnGameStart.Add(SquadManager.onGameStart)

function SquadManager.onServerReset()
    SquadManager.data = nil
    SquadManager.byMember = {}
    SquadManager.onGameStart()
end
Events.OnReset.Remove(SquadManager.onServerReset)
Events.OnReset.Add(SquadManager.onServerReset)

function SquadManager.onTickWrapper()
    SquadManager.onTick()
end
Events.OnTick.Remove(SquadManager.onTickWrapper)
Events.OnTick.Add(SquadManager.onTickWrapper)
