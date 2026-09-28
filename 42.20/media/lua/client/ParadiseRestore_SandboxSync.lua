require "ISUI/AdminPanel/ISServerSandboxOptionsUI"

ParadiseRestore = ParadiseRestore or {}

OnSandboxModified = LuaEventManager.AddEvent("OnSandboxModified")
if not OnSandboxModified then LuaEventManager.AddEvent("OnSandboxModified") end
function ParadiseRestore.onSandboxModified()
    local pl = getPlayer()
    if not pl then return end
    if string.lower(pl:getAccessLevel()) == "admin" then
        ParadiseZ.echo("SandboxOptions Updated")
    end
end
Events.OnSandboxModified.Remove(ParadiseRestore.onSandboxModified)
Events.OnSandboxModified.Add(ParadiseRestore.onSandboxModified)

function ParadiseRestore.onSandboxSyncCommand(module, command, args)
    if module ~= "ParadiseRestore" or command ~= "reParams" then return end
    triggerEvent("OnSandboxModified")
    local pl = getPlayer() 
    if pl and ParadiseRestore.isAdm(pl) and args.targUser then
        pl:setHaloNote('Admin '..tostring(args.targUser)..' SYNCED SANDBOX',150,250,150,900) 
    end
end
Events.OnServerCommand.Remove(ParadiseRestore.onSandboxSyncCommand)
Events.OnServerCommand.Add(ParadiseRestore.onSandboxSyncCommand)

function ParadiseRestore.onSandboxOptionsApply(self)
    ParadiseRestore.ISServerSandboxOptionsUIonButtonApply(self)
    if isClient() then
        sendClientCommand("ParadiseRestore", "reParams", {})
    end
end

function ParadiseRestore.installSandboxOptionsHook()
    if not ParadiseRestore.ISServerSandboxOptionsUIonButtonApply then
        ParadiseRestore.ISServerSandboxOptionsUIonButtonApply = ISServerSandboxOptionsUI.onButtonApply
    end
    ISServerSandboxOptionsUI.onButtonApply = ParadiseRestore.onSandboxOptionsApply
end
ParadiseRestore.installSandboxOptionsHook()
Events.OnGameStart.Remove(ParadiseRestore.installSandboxOptionsHook)
Events.OnGameStart.Add(ParadiseRestore.installSandboxOptionsHook)
