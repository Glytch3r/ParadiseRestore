ParadiseZ = ParadiseZ or {}

if isClient() then return end

function ParadiseZ.relayScareCrow(module, command, pl, args)
    if module ~= "ParadiseZ" or command ~= "isScareCrow" or not pl or not args then return end
    sendServerCommand(pl, "ParadiseZ", "isScareCrow", { id = pl:getOnlineID(), isScareCrow = args.isScareCrow == true })
end
Events.OnClientCommand.Remove(ParadiseZ.relayScareCrow)
Events.OnClientCommand.Add(ParadiseZ.relayScareCrow)
