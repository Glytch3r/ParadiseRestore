local MODULE = "PZZoneHarness"

local function reply(player, text)
    sendServerCommand(player, MODULE, "result", { text = text })
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE or command ~= "probe" then return end
    if not player or player:getAccessLevel() ~= "admin" then return end

    local E = rawget(_G, "PZZoneEngine")
    if not E then
        reply(player, "PROBE: engine missing")
        return
    end

    local username = player:getUsername()
    local x, y, z = player:getX(), player:getY(), player:getZ()
    local zone = E.getAuthority(x, y, z)
    local profile = E.getProfile(player)
    local movement = E.moveProbe and E.moveProbe[username]
    local tags = profile.tags or {}

    reply(player,
        "PROBE serverPos=" .. math.floor(x) .. "," .. math.floor(y) .. "," .. tostring(z) ..
        " authority=" .. tostring(zone and zone.id or "none") ..
        " pve=" .. tostring(tags.pve == true) ..
        " range_staff=" .. tostring(tags.range_staff == true) ..
        " adminBypass=" .. tostring(zone and zone.policy.adminBypass ~= false) ..
        " moveEvents=" .. tostring(movement and movement.count or 0) ..
        " lastMove=" .. tostring(movement and (math.floor(movement.x) .. "," .. math.floor(movement.y)) or "none")
    )
end)
