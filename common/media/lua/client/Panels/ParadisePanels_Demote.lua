ParadisePanels = ParadisePanels or {}
ParadisePanels.table = ParadisePanels.table or {}
ParadisePanels.Demote = ParadisePanels.Demote or {}


ParadisePanels.Demote.ticks = ParadisePanels.Demote.ticks or 0
function ParadisePanels.Demote.PanelCloser(pl)
    ParadisePanels.Demote.ticks = ParadisePanels.Demote.ticks + 1
    if ParadisePanels.Demote.ticks % 3 ~= 0 then return end

    pl = pl or getPlayer()
    if not pl then return end
    pl:getModData()['isAdm'] = pl:getModData()['isAdm'] or ParadiseRestore.isAdm(pl)
    if pl:getModData()['isAdm'] and not ParadiseRestore.isAdm(pl)  then
        ParadisePanels.Demote.doDemote(pl)
    end
    pl:getModData()['isAdm'] = ParadiseRestore.isAdm(pl)
end

Events.OnPlayerUpdate.Remove(ParadisePanels.Demote.PanelCloser)
Events.OnPlayerUpdate.Add(ParadisePanels.Demote.PanelCloser)

    
function ParadisePanels.Demote.doDemote(pl) 
    pl = pl or getPlayer()
    if not pl then return end
    pl:getModData()['isAdm'] = false
    ParadisePanels.CloseAdminPanels()
end
