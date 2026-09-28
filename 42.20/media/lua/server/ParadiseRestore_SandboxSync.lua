ParadiseRestore = ParadiseRestore or {}

function ParadiseRestore.onSandboxSyncCommand(module, command, pl, args)
    if module ~= "ParadiseRestore" or command ~= "reParams" then return end
    sendServerCommand("ParadiseRestore", "reParams", {})
end
Events.OnClientCommand.Remove(ParadiseRestore.onSandboxSyncCommand)
Events.OnClientCommand.Add(ParadiseRestore.onSandboxSyncCommand)
