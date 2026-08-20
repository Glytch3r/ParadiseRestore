ParadiseDev = ParadiseDev or {}

require "Dev/ParadiseDev_TraitUtils"

function ParadiseDev.getTarg(targ)
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

function ParadiseDev.isAdm(targ)
    -- Most client-side callers omit the target and mean the local player.
    -- Treating nil as no target made all context-menu admin checks fail.
    targ = targ or (getPlayer and getPlayer() or nil)
    targ = ParadiseDev.getTarg(targ)
    return targ and targ.getAccessLevel and string.lower(tostring(targ:getAccessLevel())) == "admin" or false
end
