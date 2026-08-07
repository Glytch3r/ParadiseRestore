ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Probe = ParadiseDev.Zones.Probe or {}

require "Dev/ParadiseDev_Players"

ParadiseDev.Zones.Probe.module = "PZZoneHarness"

function ParadiseDev.Zones.Probe.reply(pl, text)
    sendServerCommand(pl, ParadiseDev.Zones.Probe.module, "result", { text = text })
end

function ParadiseDev.Zones.Probe.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.Zones.Probe.module or command ~= "probe" then return end
    if not pl or not ParadiseDev.isAdm(pl) then return end

    if not ParadiseDev.Zones.Engine then
        ParadiseDev.Zones.Probe.reply(pl, "PROBE: engine missing")
        return
    end

    local username = pl:getUsername()
    local x, y, z = pl:getX(), pl:getY(), pl:getZ()
    local zone = ParadiseDev.Zones.Engine.getAuthority(x, y, z)
    local profile = ParadiseDev.Zones.Engine.getProfile(pl)
    local movement = ParadiseDev.Zones.Engine.moveProbe and ParadiseDev.Zones.Engine.moveProbe[username]
    local tags = profile.tags or {}

    ParadiseDev.Zones.Probe.reply(pl,
        "PROBE serverPos=" .. math.floor(x) .. "," .. math.floor(y) .. "," .. tostring(z) ..
        " authority=" .. tostring(zone and zone.id or "none") ..
        " pve=" .. tostring(tags.pve == true) ..
        " range_staff=" .. tostring(tags.range_staff == true) ..
        " adminBypass=" .. tostring(zone and zone.policy.adminBypass ~= false) ..
        " moveEvents=" .. tostring(movement and movement.count or 0) ..
        " lastMove=" .. tostring(movement and (math.floor(movement.x) .. "," .. math.floor(movement.y)) or "none")
    )
end

Events.OnClientCommand.Remove(ParadiseDev.Zones.Probe.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Zones.Probe.onClientCommand)
