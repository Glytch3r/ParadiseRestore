ParadisePanels = ParadisePanels or {}
ParadisePanels.table = ParadisePanels.table or {}
ParadisePanels.Demote = ParadisePanels.Demote or {}

ParadisePanels.Demote.ADM_MODULE = "ParadiseZ_access"
ParadisePanels.Demote.ADM_LOST_COMMAND = "accessLost"

function ParadisePanels.Demote.doDemote(pl)
    pl = pl or getPlayer()
    if not pl then return end
    ParadisePanels.CloseAdminPanels()
end

function ParadisePanels.Demote.onServerCommand(module, command, args)
    if module ~= ParadisePanels.Demote.ADM_MODULE or command ~= ParadisePanels.Demote.ADM_LOST_COMMAND then return end
    ParadisePanels.Demote.doDemote(getPlayer())
end
Events.OnServerCommand.Remove(ParadisePanels.Demote.onServerCommand)
Events.OnServerCommand.Add(ParadisePanels.Demote.onServerCommand)
