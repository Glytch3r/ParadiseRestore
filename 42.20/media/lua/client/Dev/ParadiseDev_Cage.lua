ParadiseDev = ParadiseDev or {}
ParadiseDev.Cage = ParadiseDev.Cage or {}

--require "ISUI/AdminPanel/ISUsersList"

ParadiseDev.Cage.scoreboardContext = nil
ParadiseDev.Cage.usersListContext = nil
ParadiseDev.Cage.populateScoreboard = nil
ParadiseDev.Cage.hookScoreboard = nil

ParadiseDev.Cage.entries = ParadiseDev.Cage.entries or {}
ParadiseDev.Cage.window = ParadiseDev.Cage.window or nil

function ParadiseDev.Cage.isSteamMode()
    return getSteamModeActive and getSteamModeActive() or false
end

function ParadiseDev.Cage.requestState()
    if sendClientCommand then sendClientCommand("ParadiseDevCage", "list", {}) end
end

function ParadiseDev.Cage.setLocal(username, key, isCaged)
    local pl = getPlayer and getPlayer() or nil
    if not key and pl and pl.getUsername and pl:getUsername() == username then
        if ParadiseDev.Cage.isSteamMode() then
            key = pl.getSteamID and tostring(pl:getSteamID()) or nil
        else
            key = username
        end
    end
    if not key or tostring(key) == "" or tostring(key) == "0" then return false end
    if ParadiseDev.Cage.set and pl and pl.getUsername and pl:getUsername() == username then
        return ParadiseDev.Cage.set(pl, isCaged == true)
    end
    local store = ModData and ModData.getOrCreate and ModData.getOrCreate("ParadiseDev_IsCaged") or nil
    if not store then return false end
    store.players = store.players or {}
    store.names = store.names or {}
    key = tostring(key)
    if isCaged then
        store.players[key] = true
        store.names[key] = tostring(username or "")
    else
        store.players[key] = nil
        store.names[key] = nil
    end
    if ModData.transmit then ModData.transmit("ParadiseDev_IsCaged") end
    return true
end

function ParadiseDev.Cage.requestSet(username, isCaged)
    if not username or username == "" then return false end
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand("ParadiseDevCage", "set", {
            username = tostring(username),
            isCaged = isCaged == true,
        })
        return true
    end
    return ParadiseDev.Cage.setLocal(username, nil, isCaged == true)
end

function ParadiseDev.Cage.requestLogData(username)
    if not username or username == "" or not sendClientCommand then return false end
    sendClientCommand("ParadiseDevCage", "logData", { username = username })
    return true
end

function ParadiseDev.Cage.requestSteamIdSet(steamId, isCaged)
    ParadiseDev.Cage.requestKeySet(steamId, nil, isCaged)
end

function ParadiseDev.Cage.requestKeySet(key, username, isCaged)
    if not key or key == "" then return false end
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand("ParadiseDevCage", "set", { key = key, username = username, isCaged = isCaged == true })
        return true
    end
    return ParadiseDev.Cage.setLocal(username, key, isCaged == true)
end

function ParadiseDev.Cage.isTargetCaged(targ)
    if not targ then return false end
    local player = targ
    if not player.getCharacterTraits then
        local username = targ.username or (targ.getUsername and targ:getUsername())
        player = username and getPlayerFromUsername(username) or nil
    end
    local trait = ParadiseDev.getTrait and ParadiseDev.getTrait("ParadiseDev:Caged") or nil
    return player and trait and ParadiseDev.hasTrait and ParadiseDev.hasTrait(player, trait) or false
end

--[[ 
function ParadiseDev.Cage.addTargetOptions(context, targ)
    if not ParadiseDev.isAdm() or not context or not targ then return end
    local user = targ.username or (targ.getUsername and targ:getUsername())
    if not user or user == "" then return end
    if ParadiseDev.Cage.isTargetCaged(targ) then
        context:addOption("Remove Caged Trait: " .. tostring(user), nil, ParadiseDev.Cage.requestSet, user, false)
    else
        context:addOption("Add Caged Trait: " .. tostring(user), nil, ParadiseDev.Cage.requestSet, user, true)
    end
    context:addOption("Log Data: " .. tostring(user), nil, ParadiseDev.Cage.requestLogData, user)
end

function ParadiseDev.Cage.getWorldTarget(context)
    if not context or not context.options then return nil end
    for _, option in ipairs(context.options) do
        local target = option.param4
        if target and instanceof(target, "IsoPlayer") then return target end
    end
    return nil
end

function ParadiseDev.Cage.addWorldContext(plNum, context, worldobjects, test)
    if test or not ParadiseDev.isAdm() then return end
    ParadiseDev.Cage.addTargetOptions(context, ParadiseDev.Cage.getWorldTarget(context))
end
Events.OnFillWorldObjectContex tMenu.Add(ParadiseDev.Cage.addWorldContext)
]]

