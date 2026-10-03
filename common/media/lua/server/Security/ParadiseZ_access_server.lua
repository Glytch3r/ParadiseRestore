-- Server-authoritative access check for ParadiseZ admin tools.
local MODULE = "ParadiseZ_access"
local COMMAND = "accessResult"

local function isParadiseZAdmin(player)
    return player and player:getAccessLevel() == "admin"
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "requestAccess" then
        return
    end

    sendServerCommand(player, MODULE, COMMAND, {
        authorized = isParadiseZAdmin(player),
    })
end)
