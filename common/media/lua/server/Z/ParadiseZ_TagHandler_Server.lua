ParadiseZ = ParadiseZ or {}
ParadiseZ.TagHandler = ParadiseZ.TagHandler or {}

ParadiseZ.TagHandler.storeName = "ParadiseZ_AdminTagStates"

function ParadiseZ.TagHandler.getStore()
    local store = ModData.getOrCreate(ParadiseZ.TagHandler.storeName)
    store.states = store.states or {}
    return store
end

function ParadiseZ.TagHandler.sendStates(pl)
    sendServerCommand(pl, "ParadiseZTagHandler", "adminTagStates", { states = ParadiseZ.TagHandler.getStore().states })
end

function ParadiseZ.TagHandler.onClientCommand(module, command, pl, args)
    if module ~= "ParadiseZTagHandler" or not pl then return end
    if command == "requestAdminTagState" then
        ParadiseZ.TagHandler.sendStates(pl)
        return
    end
    if command ~= "setAdminTagState" or not ParadiseRestore.isAdm(pl) or not args then return end
    local user = pl:getUsername()
    if not user then return end
    local shown = args.shown == true
    local store = ParadiseZ.TagHandler.getStore()
    store.states[string.lower(tostring(user))] = shown
    ModData.transmit(ParadiseZ.TagHandler.storeName)
    sendServerCommand("ParadiseZTagHandler", "adminTagState", { user = user, shown = shown })
end
Events.OnClientCommand.Remove(ParadiseZ.TagHandler.onClientCommand)
Events.OnClientCommand.Add(ParadiseZ.TagHandler.onClientCommand)

function ParadiseZ.TagHandler.onInitGlobalModData()
    ParadiseZ.TagHandler.getStore()
end
Events.OnInitGlobalModData.Remove(ParadiseZ.TagHandler.onInitGlobalModData)
Events.OnInitGlobalModData.Add(ParadiseZ.TagHandler.onInitGlobalModData)
