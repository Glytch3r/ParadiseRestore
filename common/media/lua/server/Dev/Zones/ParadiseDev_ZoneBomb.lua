if getCore():getGameVersion():getMajor() == 41 then return end
require "Dev/Zones/ParadiseDev_ZoneBomb"
require "Dev/Zones/ParadiseDev_ZoneNoFire"
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Bomb = ParadiseDev.Zones.Bomb or {}

local Bomb = ParadiseDev.Zones.Bomb
local NoFire = ParadiseDev.Zones.NoFire
Bomb.tick = Bomb.tick or 0

function Bomb.interval()
    local int = math.floor(tonumber(Bomb.getOptions().BombInterval) or 200)
    if int < 1 then int = 1 end
    return int
end

function Bomb.chance()
    local pct = math.floor(tonumber(Bomb.getOptions().BombChance) or 30)
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    return pct
end

function Bomb.isBombSite(x, y, z)
    local engine = ParadiseDev.Zones.Engine
    if not engine or not engine.getAuthority then return false end
    local zone = engine.getAuthority(x, y, z, 0)
    return zone ~= nil and zone.features ~= nil and zone.features.isBomb == true
end

function Bomb.validSquare(sq)
    if not sq or not sq:getChunk() then return false end
    if sq:isWaterSquare() or sq:has(IsoFlagType.water) then return false end
    if not Bomb.allowsIndoor() and not sq:isOutside() then return false end
    return true
end

function Bomb.pickSquare(pl)
    local cell = pl:getCell()
    local sq = pl:getCurrentSquare()
    if not cell or not sq then return nil end
    local x = math.floor(sq:getX())
    local y = math.floor(sq:getY())
    local z = math.floor(sq:getZ())
    local rad = Bomb.siteRadius()
    for _ = 1, Bomb.SAMPLES do
        local tx = math.floor(x + ZombRand(-rad, rad + 1))
        local ty = math.floor(y + ZombRand(-rad, rad + 1))
        local target = cell:getGridSquare(tx, ty, z)
        if Bomb.validSquare(target) and Bomb.isBombSite(tx, ty, z) then
            return target
        end
    end
    return nil
end

function Bomb.detonate(sq)
    if Bomb.makesFire() and not NoFire.isNoFire(sq) then
        IsoFireManager.explode(sq:getCell(), sq, Bomb.danger())
    end
    local args = Bomb.squareArgs(sq)
    if isServer() then
        sendServerCommand("PZZoneBomb", "blast", args)
        return
    end
    Bomb.onBlast(args)
end

function Bomb.collect(list)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return 0 end
    local count = 0
    for i = 0, players:size() - 1 do
        local pl = players:get(i)
        local sq = pl and pl:getCurrentSquare() or nil
        if sq and Bomb.isBombSite(math.floor(sq:getX()), math.floor(sq:getY()), math.floor(sq:getZ())) then
            count = count + 1
            list[#list + 1] = pl
        end
    end
    return count
end

function Bomb.roll()
    local candidates = {}
    local count = Bomb.collect(candidates)
    if count == 0 and not isServer() then
        local pl = getPlayer and getPlayer() or nil
        local sq = pl and pl:getCurrentSquare() or nil
        if sq and Bomb.isBombSite(math.floor(sq:getX()), math.floor(sq:getY()), math.floor(sq:getZ())) then
            candidates[#candidates + 1] = pl
        end
    end
    if #candidates == 0 then return nil end
    local pl = candidates[ZombRand(#candidates) + 1]
    local site = Bomb.pickSquare(pl)
    if not site then return nil end
    Bomb.detonate(site)
    return site
end

function Bomb.onTick()
    if not isServer() then return end
    Bomb.tick = Bomb.tick + 1
    if Bomb.tick % Bomb.interval() ~= 0 then return end
    if ZombRand(100) >= Bomb.chance() then return end
    Bomb.roll()
end
Events.OnTick.Remove(Bomb.onTick)
Events.OnTick.Add(Bomb.onTick)

function Bomb.testZone()
    local pl = getPlayer and getPlayer() or nil
    local sq = pl and pl:getCurrentSquare() or nil
    if not sq then return "Bomb: no local player square" end
    return string.format("Bomb interval=%d chance=%d inBombZone=%s siteRadius=%d",
        Bomb.interval(), Bomb.chance(),
        tostring(Bomb.isBombSite(math.floor(sq:getX()), math.floor(sq:getY()), math.floor(sq:getZ()))),
        Bomb.siteRadius())
end
