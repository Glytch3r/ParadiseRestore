
ParadiseDev = ParadiseDev or {}

function ParadiseDev.getTarg(targ)
    if not targ then
        return nil
    end
    if instanceof(targ, "IsoPlayer") then
        return targ
    end

    if type(targ) == 'string' then
        targ = getPlayerFromUsername(targ)
    end

    return targ
end

function ParadiseDev.getSteamId(targ)
    targ = ParadiseDev.getTarg(targ)
    if not targ then return end

    local id = nil
    if getSteamModeActive and getSteamModeActive() and targ.getSteamID then
        id = targ:getSteamID()
    end
    local pl = getPlayer()
    if targ == pl and getCurrentUserSteamID then
        id = getCurrentUserSteamID()
    end
    return id
end
function ParadiseDev.isAdm(targ)
    targ = ParadiseDev.getTarg(targ) or getPlayer()
    return ((targ and string.lower(targ:getAccessLevel()) == "admin") or (isClient() and isAdmin()))
end
