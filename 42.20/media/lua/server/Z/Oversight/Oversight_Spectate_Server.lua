-- Server authority and state relay for B42.20 Oversight spectating.
local MODULE = "ParadiseZOversight"

local function setupSuspectRole()
    if not addRole or not getRoles or not setupRole then return end
    local roles = getRoles()
    local suspect = nil
    for index = 0, roles:size() - 1 do
        local role = roles:get(index)
        if role and role:getName() == "Suspect" then
            suspect = role
            break
        end
    end
    if not suspect then
        addRole("Suspect")
        roles = getRoles()
        for index = 0, roles:size() - 1 do
            local role = roles:get(index)
            if role and role:getName() == "Suspect" then
                suspect = role
                break
            end
        end
    end
    if suspect then setupRole(suspect, "", Color.new(1, 0, 0, 1), {}) end
end

Events.OnServerStarted.Remove(setupSuspectRole)
Events.OnServerStarted.Add(setupSuspectRole)

local function canSpectate(player)
    local role = player and player:getRole()
    return role and role:hasCapability(Capability.TeleportToPlayer)
end

local function findPlayer(username)
    if not username or not getOnlinePlayers then return nil end
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local candidate = players:get(index)
        if string.lower(candidate:getUsername()) == string.lower(tostring(username)) then
            return candidate
        end
    end
end

local function sendHideState(player)
    local entries = {}
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local candidate = players:get(index)
        local hidden = candidate:getModData().ParadiseZHideModel == true
        if hidden then
            entries[#entries + 1] = { username = candidate:getUsername(), hidden = true }
        end
    end
    sendServerCommand(player, MODULE, "hideState", { entries = entries })
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE then return end

    if command == "requestHideState" then
        sendHideState(player)
        return
    end
    if command == "setHideModel" then
        local hidden = args and args.hidden == true
        if hidden and not canSpectate(player) then return end
        player:getModData().ParadiseZHideModel = hidden
        sendServerCommand(MODULE, "hideModel", { username = player:getUsername(), hidden = hidden })
    elseif command == "follow" then
        if not canSpectate(player) then return end
        local target = findPlayer(args and args.username)
        if not target or target == player or (target.isDead and target:isDead()) then return end
        if ParadiseDev and ParadiseDev.TP then
            ParadiseDev.TP.teleportPlayer(player, target:getX() + (tonumber(args and args.x) or 0), target:getY() + (tonumber(args and args.y) or 0), target:getZ() + (tonumber(args and args.z) or 0))
        end
    end
end)
