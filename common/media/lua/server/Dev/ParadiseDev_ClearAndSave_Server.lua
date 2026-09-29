ParadiseDev = ParadiseDev or {}
ParadiseDev.ClearAndSave = ParadiseDev.ClearAndSave or {}
ParadiseDev.ClearAndSave.module = "ClearAndSave"

function ParadiseDev.ClearAndSave.relay(module, command, sender, args)
    if module ~= ParadiseDev.ClearAndSave.module or command ~= ParadiseDev.ClearAndSave.module then return end
    args = args or {}
    sendServerCommand(
        ParadiseDev.ClearAndSave.module,
        ParadiseDev.ClearAndSave.module,
        {senderName = args.senderName or sender:getUsername(), delay = args.delay or 60}
    )
end

Events.OnClientCommand.Remove(ParadiseDev.ClearAndSave.relay)
Events.OnClientCommand.Add(ParadiseDev.ClearAndSave.relay)
