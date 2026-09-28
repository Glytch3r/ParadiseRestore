ParadiseDev = ParadiseDev or {}
ParadiseRestore = ParadiseRestore or {}


function ParadiseRestore.getTarg(targ)
    if not targ then return nil end
    if type(targ) ~= "string" then return targ end
    local pls = getOnlinePlayers and getOnlinePlayers() or nil
    if not pls then return nil end
    for index = 0, pls:size() - 1 do
        local pl = pls:get(index)
        if pl and pl:getUsername() == targ then return pl end
    end
    return nil
end

function ParadiseDev.getSteamIdOrUser(targ)
    if not getSteamModeActive() then
        return ParadiseDev.getResolvedTarg(targ)        
    end
    return tostring(targ:getSteamID()) or nil
end


function ParadiseDev.getResolvedTarg(targ)
    if type(targ) == "string" then 
        targ = getPlayerFromUsername(targ) or nil
        return targ 
    end    
    if instanceof(targ, "IsoPlayer") then
        return targ
    end
    return nil
end

function ParadiseRestore.isAdm(targ)
    targ = targ or (getPlayer and getPlayer() or nil)
    targ = ParadiseDev.getResolvedTarg(targ)
    if not targ then return false end
    return targ.getAccessLevel and string.lower(tostring(targ:getAccessLevel())) == "admin" or false
end

