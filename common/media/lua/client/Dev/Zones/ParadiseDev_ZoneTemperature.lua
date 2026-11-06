if getCore():getGameVersion():getMajor() == 41 then return end
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Temp = ParadiseDev.Zones.Temp or {}

local Temp = ParadiseDev.Zones.Temp
Temp.tick = Temp.tick or 0
Temp.INTERVAL = Temp.INTERVAL or 100
Temp.BODY_MIN = Temp.BODY_MIN or 20.0
Temp.BODY_MAX = Temp.BODY_MAX or 42.0
Temp.AMOUNT_MAX = Temp.AMOUNT_MAX or 3.0
Temp.lastDelta = Temp.lastDelta or 0

function Temp.getOptions()
    return SandboxVars and SandboxVars.ParadiseZ or {}
end

function Temp.getZone(pl)
    local border = ParadiseDev.Zones.Border
    return border and border.getZoneFor and border.getZoneFor(pl) or nil
end

function Temp.getDelta(zone)
    local opt = Temp.getOptions()
    if opt.TempActive == false then return nil end
    if not zone or not zone.features then return nil end
    local hot = zone.features.isBlaze == true
    local cold = zone.features.isFrost == true
    if not hot and not cold then return nil end
    local amount = math.abs(tonumber(hot and opt.BlazeTemp or opt.FrostTemp) or 0.25)
    if amount > Temp.AMOUNT_MAX then amount = Temp.AMOUNT_MAX end
    if hot then return amount end
    return -amount
end

function Temp.apply(pl)
    if not pl or not pl:getStats() then return end
    local delta = Temp.getDelta(Temp.getZone(pl))
    if not delta then return end
    local temp = pl:getStats():get(CharacterStat.TEMPERATURE)
    local target = temp + delta
    if target < Temp.BODY_MIN then target = Temp.BODY_MIN end
    if target > Temp.BODY_MAX then target = Temp.BODY_MAX end
    if target == temp then return end
    pl:getStats():set(CharacterStat.TEMPERATURE, target)
    sendPlayerStat(pl, CharacterStat.TEMPERATURE)
    Temp.lastDelta = delta
end

function Temp.onTick(ticks)
    local pl = getPlayer()
    if not pl or not pl:isAlive() then return end
    Temp.tick = (tonumber(ticks) or Temp.tick + 1)
    if Temp.tick % Temp.INTERVAL ~= 0 then return end
    Temp.apply(pl)
end
Events.OnTick.Remove(Temp.onTick)
Events.OnTick.Add(Temp.onTick)

function Temp.readout()
    local pl = getPlayer()
    if not pl then return "Temp: no local player" end
    local zone = Temp.getZone(pl)
    local delta = Temp.getDelta(zone)
    return string.format("Temp zone=%s delta=%s body=%.2f tick=%d interval=%d",
        tostring(zone and zone.name or nil), tostring(delta),
        pl:getStats():get(CharacterStat.TEMPERATURE), Temp.tick, Temp.INTERVAL)
end
