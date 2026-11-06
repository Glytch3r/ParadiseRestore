if not isClient() then return end

SquadManager = SquadManager or {}
if not SquadManager.isB41 then require "SquadManager/SquadManager_Shared" end
if SquadManager.isB41() then return end

require "ISUI/ISModalDialog"

SquadManager.state = SquadManager.state or { key = nil, user = nil, squad = nil }
SquadManager.config = SquadManager.config or nil
SquadManager.members = SquadManager.members or {}
SquadManager.tags = SquadManager.tags or {}
SquadManager.pendingInvite = SquadManager.pendingInvite or nil
SquadManager.loaded = false

function SquadManager.send(command, args)
    if not isClient() then return end
    sendClientCommand(SquadManager.module, command, args or {})
end

function SquadManager.username()
    local pl = getPlayer and getPlayer() or nil
    if not pl then return nil end
    return pl:getUsername()
end

function SquadManager.configValue(name, fallback)
    local value = SquadManager.config and SquadManager.config[name] or nil
    if value == nil then value = fallback end
    if value == nil then value = SquadManager.defaults[name] end
    if type(value) == "boolean" then return value end
    if name == "SquadSystemEnabled" or name == "DisbandWhenLeaderDies" then return value == true or value == 1 end
    return value
end

function SquadManager.isEnabled()
    return SquadManager.configValue("SquadSystemEnabled") == true
end

function SquadManager.getSquad()
    return type(SquadManager.state.squad) == "table" and SquadManager.state.squad or nil
end

function SquadManager.inSquad()
    return SquadManager.getSquad() ~= nil
end

function SquadManager.isActive()
    local squad = SquadManager.getSquad()
    return SquadManager.isEnabled() and squad ~= nil and squad.active == true
end

function SquadManager.isLeader(squad, user)
    squad = type(squad) == "table" and squad or SquadManager.getSquad()
    user = user or SquadManager.username()
    if not user or user == "" then return false end
    return SquadManager.leaderUser(squad) == user
end

function SquadManager.seat()
    local squad = SquadManager.getSquad()
    if not squad then return 0 end
    return SquadManager.seatOf(squad, SquadManager.username())
end

function SquadManager.maxSeats()
    return math.floor(tonumber(SquadManager.configValue("SquadMaxMembers")) or SquadManager.defaults.SquadMaxMembers)
end

function SquadManager.updateMembers(members)
    SquadManager.members = type(members) == "table" and members or {}
end

function SquadManager.memberBySeat(seat)
    for _, entry in ipairs(SquadManager.members) do
        if entry.seat == seat then return entry end
    end
    return nil
end

function SquadManager.memberByUser(user)
    for _, entry in ipairs(SquadManager.members) do
        if entry.user == user then return entry end
    end
    return nil
end

function SquadManager.refreshVisuals()
    if SquadManager.Visuals then SquadManager.Visuals.refresh() end
    if SquadManager.Map then SquadManager.Map.refresh() end
end

function SquadManager.clearAll(keepTags)
    SquadManager.members = {}
    if SquadManager.Visuals then SquadManager.Visuals.clearAll() end
    if SquadManager.Map then SquadManager.Map.clearAll(keepTags) end
    if SquadManager.ActionCalls then SquadManager.ActionCalls.hidePanel() end
    if not keepTags then
        SquadManager.tags = {}
        if SquadManager.Visuals then SquadManager.Visuals.clearTags() end
    end
    if SquadManager.Chat then SquadManager.Chat.removeTab() end
end

function SquadManager.applyState(args)
    local user = SquadManager.username()
    if type(args) ~= "table" then return end
    SquadManager.state = { key = args.key, user = args.user or user, squad = args.squad }
    if type(args.config) == "table" then SquadManager.config = SquadManager.sanitizeConfig(args.config) end
    local squad = SquadManager.getSquad()
    if not squad then
        SquadManager.clearAll(false)
        return
    end
    if squad.active then
        if SquadManager.Chat then SquadManager.Chat.addTab() end
    else
        SquadManager.clearAll(true)
        if SquadManager.Chat then SquadManager.Chat.removeTab() end
    end
    if SquadManager.Panel and SquadManager.Panel.instance and SquadManager.Panel.instance.refresh then
        SquadManager.Panel.instance:refresh()
    end
end

function SquadManager.playSound(name)
    local ok = pcall(function() getSoundManager():playUISound(name) end)
    return ok
end

function SquadManager.soundForEvent(event, isLeader)
    if event == "commenced" then
        SquadManager.playSound("ParadiseRestore_Squad_Ping_1")
    elseif event == "joined" then
        SquadManager.playSound("ParadiseRestore_Squad_Ping_2")
    elseif event == "left" then
        SquadManager.playSound("ParadiseRestore_Squad_Out")
    end
end

function SquadManager.showInvite(fromUser)
    if not fromUser or fromUser == "" then return end
    SquadManager.pendingInvite = fromUser
    local modal = ISModalDialog:new(0, 0, 420, 160,
        fromUser .. " has invited you to join their squad.",
        true, SquadManager, SquadManager.onInviteAnswered, nil, fromUser)
    modal:initialise()
    modal:addToUIManager()
    SquadManager.inviteModal = modal
end

function SquadManager.onInviteAnswered(target, button, fromUser)
    SquadManager.pendingInvite = nil
    SquadManager.inviteModal = nil
    if not button then return end
    SquadManager.send(SquadManager.commands.respond, { accept = button.internal == "YES", user = fromUser })
end

function SquadManager.onServerCommand(module, command, args)
    if module ~= SquadManager.module then return end
    args = type(args) == "table" and args or {}

    if command == SquadManager.commands.config then
        SquadManager.config = SquadManager.sanitizeConfig(args)
        SquadManager.loaded = true
        if not SquadManager.isEnabled() then SquadManager.clearAll(false) end
        if SquadManager.Panel and SquadManager.Panel.instance and SquadManager.Panel.instance.refresh then
            SquadManager.Panel.instance:refresh()
        end
    elseif command == SquadManager.commands.state then
        SquadManager.loaded = true
        SquadManager.applyState(args)
    elseif command == SquadManager.commands.positions then
        SquadManager.updateMembers(args.members)
        SquadManager.refreshVisuals()
    elseif command == SquadManager.commands.chatLine then
        if SquadManager.Chat then SquadManager.Chat.addMessage(args.user, args.text) end
    elseif command == SquadManager.commands.actionCall then
        if SquadManager.ActionCalls then SquadManager.ActionCalls.receive(args) end
    elseif command == SquadManager.commands.tagAdd then
        SquadManager.tags[tostring(args.id)] = args
        if SquadManager.Visuals then SquadManager.Visuals.addTag(args) end
        SquadManager.playSound("ParadiseRestore_Squad_Tag")
    elseif command == SquadManager.commands.tagExpire then
        SquadManager.tags[tostring(args.id)] = nil
        if SquadManager.Visuals then SquadManager.Visuals.removeTag(args.id) end
    elseif command == SquadManager.commands.invitePrompt then
        SquadManager.showInvite(args.fromUser)
    elseif command == SquadManager.commands.inviteResolved then
        if SquadManager.pendingInvite == args.fromUser then
            SquadManager.pendingInvite = nil
            if SquadManager.inviteModal then SquadManager.inviteModal:close() end
        end
    elseif command == SquadManager.commands.departed then
        SquadManager.clearAll(false)
        SquadManager.playSound("ParadiseRestore_Squad_Out")
        SquadManager.state = { key = nil, user = SquadManager.username(), squad = nil }
        if SquadManager.Panel and SquadManager.Panel.instance and SquadManager.Panel.instance.refresh then
            SquadManager.Panel.instance:refresh()
        end
    elseif command == SquadManager.commands.none then
        SquadManager.soundForEvent(args.event, false)
        if SquadManager.Panel and SquadManager.Panel.instance and SquadManager.Panel.instance.refresh then
            SquadManager.Panel.instance:refresh()
        end
    end
end
Events.OnServerCommand.Remove(SquadManager.onServerCommand)
Events.OnServerCommand.Add(SquadManager.onServerCommand)

function SquadManager.onCreatePlayer(plNum, pl)
    if not pl or not pl:isLocalPlayer() then return end
    SquadManager.tags = {}
    SquadManager.clearAll(false)
    SquadManager.send(SquadManager.commands.login)
    SquadManager.send(SquadManager.commands.requestState)
end
Events.OnCreatePlayer.Remove(SquadManager.onCreatePlayer)
Events.OnCreatePlayer.Add(SquadManager.onCreatePlayer)

function SquadManager.onGameStart()
    SquadManager.send(SquadManager.commands.login)
    SquadManager.send(SquadManager.commands.requestState)
end
Events.OnGameStart.Remove(SquadManager.onGameStart)
Events.OnGameStart.Add(SquadManager.onGameStart)

function SquadManager.onMainMenuEnter()
    SquadManager.tags = {}
    SquadManager.state = { key = nil, user = nil, squad = nil }
    SquadManager.clearAll(false)
end
Events.OnMainMenuEnter.Remove(SquadManager.onMainMenuEnter)
Events.OnMainMenuEnter.Add(SquadManager.onMainMenuEnter)

function SquadManager.onDisconnect()
    SquadManager.tags = {}
    SquadManager.state = { key = nil, user = nil, squad = nil }
    SquadManager.clearAll(false)
end
Events.OnDisconnect.Remove(SquadManager.onDisconnect)
Events.OnDisconnect.Add(SquadManager.onDisconnect)

function SquadManager.console()
    local squad = SquadManager.getSquad()
    print("[Squad] enabled=" .. tostring(SquadManager.isEnabled()))
    print("[Squad] config=" .. (squad and "loaded" or "nil") .. " members=" .. tostring(#SquadManager.members))
    if not squad then print("[Squad] you are not in a squad") return "no squad" end
    print("[Squad] key=" .. tostring(SquadManager.state.key) .. " leader=" .. tostring(SquadManager.leaderUser(squad)) .. " active=" .. tostring(squad.active))
    for _, item in ipairs(SquadManager.seatsOrdered(squad)) do
        print("  seat " .. item.seat .. " = " .. tostring(item.user))
    end
    return "ok"
end

function SquadManager.debugCalls()
    for _, entry in ipairs(SquadManager.actionCalls) do
        print(entry.index .. "\t" .. entry.label .. (entry.leader and "\tleader only" or "") .. "\t" .. tostring(entry.marker))
    end
end
