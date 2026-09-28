ParadisePanels = ParadisePanels or {}
ParadisePanels.table = ParadisePanels.table or {}
ParadisePanels.Demote = ParadisePanels.Demote or {}


local ticks = 0
function ParadisePanels.Demote.PanelCloser(pl)
    ticks = ticks or 0
    ticks = ticks + 1
    if ticks % 3 ~= 0 then return end

    pl = pl or getPlayer()
    if not pl then return end
    pl:getModData()['isAdm'] = pl:getModData()['isAdm'] or ParadiseRestore.isAdm(pl)
    if pl:getModData()['isAdm'] and not ParadiseRestore.isAdm(pl)  then
        ParadisePanels.Demote.doDemote(pl)
    end
    pl:getModData()['isAdm'] = ParadiseRestore.isAdm(pl)
end

Events.OnPlayerUpdate.Add(ParadisePanels.Demote.PanelCloser)

    
function ParadisePanels.Demote.doDemote(pl) 
    pl = pl or getPlayer()
    if not pl then return end
    pl:getModData()['isAdm'] = false
    -- close each opened isAdmOnly panels
end