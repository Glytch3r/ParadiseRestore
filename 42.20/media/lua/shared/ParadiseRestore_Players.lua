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

function ParadiseRestore.isSteamMode()
    return getSteamModeActive and getSteamModeActive() or false
end

function ParadiseRestore.getSteamIdOrUser(targ)
    if not ParadiseRestore.isSteamMode() then
        return       
    end
    targ = ParadiseRestore.getResolvedTarg(targ)
    if not targ then return nil end
    local id = targ.getSteamID and targ:getSteamID() or nil
    if id and tostring(id) ~= "" and tostring(id) ~= "0" then
        return tostring(id)
    end
    return targ:getUsername() or nil
end

function ParadiseRestore.getResolvedTargUser(targ)
    if type(targ) == "string" then 
        local check = getPlayerFromUsername(targ) 
        if check then 
            return targ
        end        
    elseif instanceof(targ, "IsoPlayer") then
        return targ:getUsername() 
    end
    return nil
end

function ParadiseRestore.getResolvedTarg(targ)
    if type(targ) == "string" then 
        targ = getPlayerFromUsername(targ) 
        return targ or nil
    end    
    if instanceof(targ, "IsoPlayer") then
        return targ
    end
    return nil
end

function ParadiseRestore.isAdm(targ)
    targ = ParadiseRestore.getResolvedTarg(targ)
    targ = targ or (getPlayer and getPlayer() or false)
    if not targ then return false end
    return targ.getAccessLevel and string.lower(tostring(targ:getAccessLevel())) == "admin" or false
end

function ParadiseRestore.getTargPlFromSq(sq, targUser, rad)
    rad = rad or 0
    local targ = nil
    if sq and instanceof(sq, "IsoGridSquare") then
        local players = ParadiseRestore.getPlayersFromSq(sq, rad)
        if players then
            for i = 1, #players do
                local check = players[i]
                if check and check:getUsername() == targUser then 
                    targ = check
                    break
                end
            end
        end
    end
    return targ
end

function ParadiseRestore.getPlayersFromSq(sq, rad)
    local players = {}
    local cell = getCell and getCell() or nil
    if not sq or not cell then return players end
    
    rad = rad or 2
    local radSq = rad * rad
    
    for dx = -rad, rad do
        for dy = -rad, rad do
            if (dx * dx + dy * dy) <= radSq then
                local nearby = cell:getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
                local moving = nearby and nearby:getMovingObjects() or nil
                
                if moving then
                    for index = 0, moving:size() - 1 do
                        local check = moving:get(index)
                        if check and instanceof(check, "IsoPlayer") and check:getUsername() then
                            players[#players + 1] = check
                        end
                    end
                end
            end
        end
    end
    
    table.sort(players, function(left, right)
        return string.lower(tostring(left:getUsername())) < string.lower(tostring(right:getUsername()))
    end)
    
    return players
end
