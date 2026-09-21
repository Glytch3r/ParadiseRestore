ParadiseDev = ParadiseDev or {}
ParadiseRestore = ParadiseRestore or {}

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
    targ = targ or (getPlayer and getPlayer() or nil)
    targ = ParadiseDev.getTarg(targ)
    if not targ then return false end
    if targ.getAccessLevel and string.lower(tostring(targ:getAccessLevel())) == "admin" then return true end
    local role = targ.getRole and targ:getRole() or nil
    if not role then return false end
    local roleName = role.getName and role:getName() or role
    roleName = string.lower(tostring(roleName))
    return roleName == "officer" or roleName == "officers"
end

ParadiseRestore.isAdm = ParadiseDev.isAdm
