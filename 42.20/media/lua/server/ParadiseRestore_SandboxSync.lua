ParadiseRestore = ParadiseRestore or {}

function ParadiseRestore.onSandboxSyncCommand(module, command, sender, args)
    if module ~= "ParadiseRestore" or command ~= "reParams" then return end
    local targUser = sender:getUsername();
    sendServerCommand("ParadiseRestore", "reParams", {targUser = targUser})
end
Events.OnClientCommand.Remove(ParadiseRestore.onSandboxSyncCommand)
Events.OnClientCommand.Add(ParadiseRestore.onSandboxSyncCommand)
