if not isClient() then return end

FactionManager = FactionManager or {}
if not FactionManager.isB41 then require "FactionManager/FactionManager_Shared" end
if FactionManager.isB41() then return end

FactionManager.clientState = FactionManager.clientState or { factions = {}, groups = {} }

function FactionManager.send(command, args)
    sendClientCommand(FactionManager.module, command, args or {})
end

function FactionManager.requestState()
    FactionManager.send(FactionManager.commands.request)
end

function FactionManager.sendMutation(act, args)
    args = args or {}
    args.act = act
    FactionManager.send(FactionManager.commands.mutate, args)
end

function FactionManager.applyVanillaRecord(record)
    if not record or record.state == "deleted" then return end
    local faction = Faction.getFaction(record.name)
    if not faction then return end
    faction:setOwner(record.owner)
    local players = faction:getPlayers()
    players:clear()
    for _, user in ipairs(record.members or {}) do players:add(user) end
    faction:setTag(record.tag)
    if record.color then
        local col = ColorInfo.new()
        col:set(record.color.r or 1, record.color.g or 1, record.color.b or 1, 1)
        faction:setTagColor(col)
    end
end

function FactionManager.applyVanillaState(args)
    if type(args) ~= "table" or type(args.factions) ~= "table" then return end
    for _, record in ipairs(args.factions) do FactionManager.applyVanillaRecord(record) end
end

function FactionManager.perform(args)
    if type(args) ~= "table" then return end
    local faction = Faction.getFaction(args.faction)
    if not faction then return end
    if args.act == "rename" then
        sendFactionChangeTitle(faction, args.value)
    elseif args.act == "delete" then
        sendFactionDisband(faction)
    elseif args.act == "setOwner" then
        sendFactionChangeOwner(faction, args.user)
    elseif args.act == "removePlayer" then
        sendFactionRemoveMember(faction, args.user)
    elseif args.act == "setTag" then
        faction:setTag(args.value)
        sendFactionChangeTag(faction)
    elseif args.act == "setColor" then
        local col = ColorInfo.new()
        col:set(args.r, args.g, args.b, 1)
        faction:setTagColor(col)
        sendFactionChangeTag(faction)
    end
end

function FactionManager.onServerCommand(module, command, args)
    if module ~= FactionManager.module then return end
    if command == FactionManager.commands.state then
        FactionManager.clientState = args or { factions = {}, groups = {} }
        if FactionManager.instance and FactionManager.instance.refresh then FactionManager.instance:refresh() end
    elseif command == FactionManager.commands.perform then
        FactionManager.perform(args)
    elseif command == "vanillaState" then
        FactionManager.applyVanillaState(args)
    end
end
Events.OnServerCommand.Remove(FactionManager.onServerCommand)
Events.OnServerCommand.Add(FactionManager.onServerCommand)

function FactionManager.onConnected()
    FactionManager.send(FactionManager.commands.login)
    FactionManager.requestState()
end
Events.OnConnected.Remove(FactionManager.onConnected)
Events.OnConnected.Add(FactionManager.onConnected)

function FactionManager.onCreatePlayer(plNum, pl)
    if not pl or not pl:isLocalPlayer() then return end
    FactionManager.send(FactionManager.commands.login)
end
Events.OnCreatePlayer.Remove(FactionManager.onCreatePlayer)
Events.OnCreatePlayer.Add(FactionManager.onCreatePlayer)

function FactionManager.onSyncFaction()
    FactionManager.requestState()
end
Events.SyncFaction.Remove(FactionManager.onSyncFaction)
Events.SyncFaction.Add(FactionManager.onSyncFaction)
