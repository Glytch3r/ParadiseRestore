ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.Immortality = ParadiseRestore.Immortality or {}

local Immortality = ParadiseRestore.Immortality

Immortality.entries = Immortality.entries or {}
Immortality.selfState = Immortality.selfState or false

function Immortality.getSelfState()
    if isClient and isClient() then return Immortality.selfState == true end
    local pl = getPlayer and getPlayer() or nil
    if not pl or not Immortality.isImmortal then return false end
    return Immortality.isImmortal(pl) == true
end

function Immortality.requestState()
    if isClient and isClient() then
        if sendClientCommand then
            sendClientCommand(Immortality.MODULE, "list", {})
            sendClientCommand(Immortality.MODULE, "query", {})
        end
        return
    end
    Immortality.entries = Immortality.getEntries and Immortality.getEntries() or {}
    Immortality.refreshPanel()
end

function Immortality.onServerCommand(module, command, args)
    if module ~= Immortality.MODULE then return end
    if command == "state" then
        Immortality.entries = args and args.entries or {}
        Immortality.refreshPanel()
        return
    end
    if command == "self" then
        Immortality.selfState = args and args.isImmortal == true or false
        Immortality.refreshPanel()
    end
end

function Immortality.applyLocal(username, key, isImmortal)
    if key and Immortality.setByKey then
        return Immortality.setByKey(key, username, isImmortal == true)
    end
    local targ = username and Immortality.findPlayer and Immortality.findPlayer(username) or nil
    if targ and Immortality.set then
        return Immortality.set(targ, isImmortal == true)
    end
    if username and Immortality.setPending then
        return Immortality.setPending(username, isImmortal == true)
    end
    return false
end

function Immortality.requestSet(username, isImmortal)
    if not username or tostring(username) == "" then return false end
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand(Immortality.MODULE, "set", {
            username = tostring(username),
            isImmortal = isImmortal == true,
        })
        return true
    end
    local ok = Immortality.applyLocal(username, nil, isImmortal == true)
    Immortality.requestState()
    return ok
end

function Immortality.requestKeySet(key, username, isImmortal)
    if not key or tostring(key) == "" then return false end
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand(Immortality.MODULE, "set", {
            key = tostring(key),
            username = username,
            isImmortal = isImmortal == true,
        })
        return true
    end
    local ok = Immortality.applyLocal(username, key, isImmortal == true)
    Immortality.requestState()
    return ok
end

function Immortality.requestSelfToggle()
    local pl = getPlayer and getPlayer() or nil
    if not pl then return false end
    local next = not Immortality.getSelfState()
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand(Immortality.MODULE, "self", { isImmortal = next })
        return true
    end
    if Immortality.set then Immortality.set(pl, next) end
    Immortality.selfState = next
    Immortality.requestState()
    return true
end

function Immortality.refreshPanel()
    if ParadiseDev and ParadiseDev.PlayerDataSyncer and ParadiseDev.PlayerDataSyncer.refreshPanel then
        ParadiseDev.PlayerDataSyncer.refreshPanel()
    end
end

Events.OnServerCommand.Remove(Immortality.onServerCommand)
Events.OnServerCommand.Add(Immortality.onServerCommand)
Events.OnConnected.Remove(Immortality.requestState)
Events.OnConnected.Add(Immortality.requestState)