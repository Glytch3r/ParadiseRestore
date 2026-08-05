
ParadiseDev = ParadiseDev or {}
function ParadiseDev.getSteamId(targ)
    if not targ then
        return 
    end
    if not instanceof(targ, "IsoPlayer") and type(targ) == 'string' then
        targ = getPlayerFromUsername(targ)    
    end

    local id = nil
    if getSteamModeActive and getSteamModeActive() then
        id = targ:getSteamID()
    end
    local pl = getPlayer() 
    if targ == pl then
        id = getCurrentUserSteamID()
    end
    return id
end
