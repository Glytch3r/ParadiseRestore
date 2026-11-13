if isClient and isClient() then return end

ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.Immortality = ParadiseRestore.Immortality or {}

local Immortality = ParadiseRestore.Immortality

Immortality.refreshMs = 1000
Immortality.nextRefresh = 0
Immortality.keys = {}
Immortality.syncTimes = Immortality.syncTimes or {}

function Immortality.refreshKeys()
    local keys = {}
    ParadiseRestore.forEachActivePlayer(function(pl)
        if not Immortality.isActive(pl) then return end
        local key = Immortality.getKey(pl)
        if key then keys[key] = true end
        local userKey = Immortality.getUsernameKey(Immortality.getUsername(pl))
        if userKey then keys[userKey] = true end
    end)
    Immortality.keys = keys
end

function Immortality.clearZed(zed)
    zed:clearAggroList()
    zed:setTarget(nil)
    local path = zed:getPathFindBehavior2()
    if path then
        path:reset()
        path:cancel()
    end
    zed:setPath2(nil)
end

function Immortality.onZedUpdate(zed)
    local targ = zed:getTarget()
    if not targ then return end
    if not instanceof(targ, "IsoPlayer") then return end

    local now = getTimestampMs()
    if now >= Immortality.nextRefresh then
        Immortality.nextRefresh = now + Immortality.refreshMs
        Immortality.refreshKeys()
    end

    local key = Immortality.getKey(targ)
    local userKey = Immortality.getUsernameKey(Immortality.getUsername(targ))
    if not ((key and Immortality.keys[key]) or (userKey and Immortality.keys[userKey])) then return end

    Immortality.clearZed(zed)
end
Events.OnZombieUpdate.Remove(Immortality.onZedUpdate)
Events.OnZombieUpdate.Add(Immortality.onZedUpdate)

function Immortality.setPending(user, isImmortal)
    local userKey = Immortality.getUsernameKey(user)
    if not userKey then return false end
    local store = Immortality.getStore()
    if not store then return false end
    if isImmortal then
        store.pending[userKey] = true
        store.pendingNames[userKey] = tostring(user)
    else
        store.pending[userKey] = nil
        store.pendingNames[userKey] = nil
    end
    ModData.transmit(Immortality.StoreName)
    Immortality.nextRefresh = 0
    return true
end

function Immortality.setStored(key, user, isImmortal)
    if not key or tostring(key) == "" then return false end
    key = tostring(key)
    local store = Immortality.getStore()
    if not store then return false end
    user = user or store.names[key]
    if isImmortal then
        store.players[key] = true
        if user then store.names[key] = tostring(user) end
    else
        store.players[key] = nil
        store.names[key] = nil
    end
    ModData.transmit(Immortality.StoreName)
    Immortality.nextRefresh = 0
    return true
end

function Immortality.set(pl, isImmortal)
    local key = Immortality.getKey(pl)
    if not key then return false end
    local user = Immortality.getUsername(pl)
    local userKey = Immortality.getUsernameKey(user)
    local store = Immortality.getStore()
    if not store then return false end
    if isImmortal then
        store.players[key] = true
        if user then store.names[key] = user end
    else
        store.players[key] = nil
        store.names[key] = nil
        if userKey then
            store.players[userKey] = nil
            store.names[userKey] = nil
        end
        local id = Immortality.getSteamId(pl)
        if id then
            store.players[id] = nil
            store.names[id] = nil
        end
    end
    if userKey then
        store.pending[userKey] = nil
        store.pendingNames[userKey] = nil
    end
    ModData.transmit(Immortality.StoreName)
    Immortality.nextRefresh = 0
    return true
end

function Immortality.findPlayerByKey(key)
    if not key or tostring(key) == "" then return nil end
    key = tostring(key)
    local userKey = Immortality.getUsernameKey(key)
    local function matches(pl)
        if not pl then return false end
        if Immortality.getKey(pl) == key then return true end
        return userKey and Immortality.getUsernameKey(Immortality.getUsername(pl)) == userKey or false
    end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            local pl = players:get(index)
            if matches(pl) then return pl end
        end
    end
    local host = getPlayer and getPlayer() or nil
    return matches(host) and host or nil
end

function Immortality.findPlayer(user)
    if not user or tostring(user) == "" then return nil end
    return Immortality.findPlayerByKey(user)
end

function Immortality.setByKey(key, user, isImmortal)
    if not key or tostring(key) == "" then return false end
    key = tostring(key)
    local targ = Immortality.findPlayerByKey(key)
    if targ then return Immortality.set(targ, isImmortal == true) end
    local userKey = key:match("^username:(.+)$")
    if userKey then
        local store = Immortality.getStore()
        return Immortality.setPending(store and store.pendingNames[userKey] or userKey, isImmortal == true)
    end
    return Immortality.setStored(key, user, isImmortal == true)
end

function Immortality.syncPlayer(pl)
    if not pl then return false end
    local user = Immortality.getUsername(pl)
    local userKey = Immortality.getUsernameKey(user)
    local key = Immortality.getKey(pl)
    local store = Immortality.getStore()
    if not store then return false end
    if userKey and key and store.pending[userKey] == true then
        store.pending[userKey] = nil
        store.pendingNames[userKey] = nil
        store.players[key] = true
        if user then store.names[key] = user end
        ModData.transmit(Immortality.StoreName)
        Immortality.nextRefresh = 0
    end
    return Immortality.isImmortal(pl)
end

function Immortality.getEntries(extraPl)
    local entries = {}
    local included = {}
    local includedUsers = {}
    local store = Immortality.getStore()
    local function addPlayer(pl)
        if not pl then return end
        local key = Immortality.getKey(pl)
        if not key or included[key] then return end
        local isImmortal = Immortality.syncPlayer(pl)
        local user = Immortality.getUsername(pl) or ""
        included[key] = true
        local userKey = Immortality.getUsernameKey(user)
        if userKey then includedUsers[userKey] = true end
        entries[#entries + 1] = {
            key = key,
            steamId = Immortality.getSteamId(pl) or "",
            username = user,
            displayName = pl.getDisplayName and pl:getDisplayName() or user,
            isImmortal = isImmortal,
            isActive = isImmortal and Immortality.isAllowed(pl) or false,
            online = true,
        }
    end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            addPlayer(players:get(index))
        end
    end
    addPlayer(extraPl)
    if store then
        for key, val in pairs(store.players) do
            if val == true and not included[key] then
                entries[#entries + 1] = {
                    key = key,
                    steamId = Immortality.isSteamMode() and "" or key,
                    username = store.names[key] or (Immortality.isSteamMode() and key or ""),
                    displayName = "",
                    isImmortal = true,
                    online = false,
                }
            end
        end
        for userKey, val in pairs(store.pending) do
            if val == true and not includedUsers[userKey] then
                entries[#entries + 1] = {
                    key = "username:" .. userKey,
                    steamId = "",
                    username = store.pendingNames[userKey] or userKey,
                    displayName = "",
                    isImmortal = true,
                    online = false,
                }
            end
        end
    end
    table.sort(entries, function(a, b)
        return tostring(a.username or a.key) < tostring(b.username or b.key)
    end)
    return entries
end

function Immortality.sendState(pl)
    if not pl then return end
    sendServerCommand(pl, Immortality.MODULE, "state", { entries = Immortality.getEntries(pl) })
end

function Immortality.sendSelfState(pl)
    if not pl then return end
    sendServerCommand(pl, Immortality.MODULE, "self", { isImmortal = Immortality.isImmortal(pl) })
end

function Immortality.broadcastState()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return end
    local entries = Immortality.getEntries()
    for index = 0, players:size() - 1 do
        local pl = players:get(index)
        if pl and ParadiseRestore.isAdm(pl) then
            sendServerCommand(pl, Immortality.MODULE, "state", { entries = entries })
        end
    end
end

function Immortality.onClientCommand(module, command, pl, args)
    if module ~= Immortality.MODULE or not pl or type(args) ~= "table" then return end
    local isAdm = ParadiseRestore.isAdm(pl)

    if command == "list" then
        if not isAdm then return end
        Immortality.sendState(pl)
        return
    end

    if command == "query" then
        Immortality.sendSelfState(pl)
        return
    end

    if command == "self" then
        if not isAdm then return end
        Immortality.set(pl, args.isImmortal == true)
        Immortality.sendSelfState(pl)
        Immortality.broadcastState()
        return
    end

    if command ~= "set" then return end
    if not isAdm then return end

    local key = args.key
    local user = args.username

    if key then
        Immortality.setByKey(key, user, args.isImmortal == true)
    elseif user and tostring(user) ~= "" then
        local targ = Immortality.findPlayer(user)
        if not targ and Immortality.getUsername(pl) == user then targ = pl end
        if targ then
            Immortality.set(targ, args.isImmortal == true)
        else
            Immortality.setPending(user, args.isImmortal == true)
        end
    else
        return
    end

    Immortality.broadcastState()
    Immortality.sendSelfState(pl)
end

function Immortality.onInitGlobalModData()
    Immortality.getStore()
    Immortality.nextRefresh = 0
end

function Immortality.enforceZone(pl)
    if not pl then return end
    if not Immortality.isImmortal(pl) then return end
    if Immortality.isAllowed(pl) then return end
    Immortality.set(pl, false)
    Immortality.sendSelfState(pl)
    Immortality.broadcastState()
end

function Immortality.onPlayerUpdate(pl)
    if not pl then return end
    local key = Immortality.getKey(pl) or Immortality.getUsername(pl)
    if not key then return end
    local now = getTimestampMs()
    local last = Immortality.syncTimes[key]
    if last and now - last < 1000 then return end
    Immortality.syncTimes[key] = now
    Immortality.syncPlayer(pl)
    Immortality.enforceZone(pl)
end

function Immortality.onTick()
    ParadiseRestore.forEachActivePlayer(Immortality.onPlayerUpdate)
end

Events.OnInitGlobalModData.Remove(Immortality.onInitGlobalModData)
Events.OnInitGlobalModData.Add(Immortality.onInitGlobalModData)
Events.OnClientCommand.Remove(Immortality.onClientCommand)
Events.OnClientCommand.Add(Immortality.onClientCommand)
Events.OnTick.Remove(Immortality.onTick)
Events.OnTick.Add(Immortality.onTick)