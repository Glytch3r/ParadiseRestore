-- Server-authoritative access check for ParadiseZ admin tools.
local MODULE = "ParadiseZ_access"
local COMMAND = "accessResult"
local LOST_COMMAND = "accessLost"
local CHECK_INTERVAL = 1000

ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.Access = ParadiseRestore.Access or {}
ParadiseRestore.Access.prevAdm = ParadiseRestore.Access.prevAdm or {}
ParadiseRestore.Access.lastCheck = ParadiseRestore.Access.lastCheck or 0

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

function ParadiseRestore.Access.watchAdminLoss()
    if not isServer or not isServer() then return end

    local now = getTimestampMs and getTimestampMs() or os.time() * 1000
    if (now - ParadiseRestore.Access.lastCheck) < CHECK_INTERVAL then return end
    ParadiseRestore.Access.lastCheck = now

    local pls = getOnlinePlayers and getOnlinePlayers() or nil
    if not pls then return end

    local seen = {}
    local lost = {}

    for index = 0, pls:size() - 1 do
        local pl = pls:get(index)
        local user = pl and pl:getUsername() or nil
        if user and user ~= "" then
            local adm = ParadiseRestore.isAdm(pl)
            seen[user] = adm
            if ParadiseRestore.Access.prevAdm[user] and not adm then
                lost[#lost + 1] = pl
            end
            ParadiseRestore.Access.prevAdm[user] = adm
        end
    end

    for user in pairs(ParadiseRestore.Access.prevAdm) do
        if not seen[user] then
            ParadiseRestore.Access.prevAdm[user] = nil
        end
    end

    for i = 1, #lost do
        sendServerCommand(lost[i], MODULE, LOST_COMMAND, {})
    end
end
Events.OnTick.Remove(ParadiseRestore.Access.watchAdminLoss)
Events.OnTick.Add(ParadiseRestore.Access.watchAdminLoss)
