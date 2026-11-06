if getCore():getGameVersion():getMajor() == 41 then return end
require "Dev/Zones/ParadiseDev_ZoneNoFire"
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.NoFire = ParadiseDev.Zones.NoFire or {}

local NoFire = ParadiseDev.Zones.NoFire
NoFire.tick = NoFire.tick or 0

function NoFire.interval()
    local int = math.floor(tonumber(NoFire.getOptions().NoFireZoneInterval) or 50)
    if int < 1 then int = 1 end
    return int
end

function NoFire.onTick()
    if not isServer() then return end
    NoFire.tick = NoFire.tick + 1
    if NoFire.tick % NoFire.interval() ~= 0 then return end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return end
    for i = 0, players:size() - 1 do
        local pl = players:get(i)
        local sq = pl and pl:getCurrentSquare() or nil
        if NoFire.isNoFire(sq) then
            NoFire.sweepAround(pl)
        end
    end
end
Events.OnTick.Remove(NoFire.onTick)
Events.OnTick.Add(NoFire.onTick)

function NoFire.onGridBurnt(sq)
    if not NoFire.isNoFire(sq) then return end
    NoFire.stopSquare(sq)
end
Events.OnGridBurnt.Remove(NoFire.onGridBurnt)
Events.OnGridBurnt.Add(NoFire.onGridBurnt)
