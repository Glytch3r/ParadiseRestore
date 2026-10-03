-- Performs one server-authoritative admin check per client session.
ParadiseZAccess = ParadiseZAccess or {}

local Access = ParadiseZAccess
Access.MODULE = "ParadiseZ_access"
Access.COMMAND = "accessResult"
Access.authorized = Access.authorized == true
Access.requested = Access.requested == true
Access.resolved = Access.resolved == true

function Access.isAuthorized()
    return Access.authorized == true
end

local function getTrailingLights()
    return rawget(_G, "ParadiseZTrailingLights")
end

local function startAdminTools()
    local trailingLights = getTrailingLights()
    if trailingLights and trailingLights.install then
        trailingLights.install()
    end

    local adminChat = rawget(_G, "ParadiseZAdminChat")
    if adminChat and adminChat.install then
        adminChat.install()
    end
end


function Access.resolve(isAuthorized)
    if Access.resolved then
        return
    end

    Access.resolved = true
    Access.authorized = isAuthorized == true
    if Access.authorized then
        startAdminTools()
    end
end

function Access.request()
    if Access.requested or Access.resolved then
        return
    end

    Access.requested = true

    -- This runs once after login. Debug mode already uses this same client-side
    -- privilege state, so it is the reliable fast path for the admin-only UI.
    local level = getAccessLevel and getAccessLevel() or nil
    local isLocalAdmin = (isAdmin and isAdmin()) or level == "admin"
    if isLocalAdmin then
        Access.resolve(true)
        return
    end

    -- Keep the server check as a fallback for clients whose access level has
    -- not finished synchronizing when the game-start event fires.
    if isClient and isClient() then
        sendClientCommand(Access.MODULE, "requestAccess", {})
        return
    end

    Access.resolve(false)
end

Events.OnServerCommand.Add(function(module, command, args)
    if module == Access.MODULE and command == Access.COMMAND then
        Access.resolve(args and args.authorized == true)
    end
end)

Events.OnCreatePlayer.Add(function()
    Access.request()
end)

Events.OnGameStart.Add(function()
    Access.request()
end)
