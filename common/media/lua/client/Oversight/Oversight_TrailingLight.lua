-- Restore controls delegate to the owner's ParadiseZ_42 renderer.
ParadiseZ = ParadiseZ or {}
function ParadiseZ.isTrailingLightMode(pl)
    pl = pl or getPlayer()
    local tl = ParadiseZTrailingLights
    return pl and tl and tl.getState(pl:getPlayerNum()).enabled == true or false
end
function ParadiseZ.setTrailingLightMode(activate, pl)
    pl = pl or getPlayer()
    if not pl or not pl:isAlive() or not ParadiseRestore.isAdm(pl) then return end
    local tl = ParadiseZTrailingLights
    if not tl or activate == nil then return end
    tl.getState(pl:getPlayerNum()).enabled = activate == true
    tl.onLocalStateChanged(pl:getPlayerNum())
end
function ParadiseZ.toggleTrailingLightMode(pl)
    pl = pl or getPlayer()
    ParadiseZ.setTrailingLightMode(not ParadiseZ.isTrailingLightMode(pl), pl)
end
