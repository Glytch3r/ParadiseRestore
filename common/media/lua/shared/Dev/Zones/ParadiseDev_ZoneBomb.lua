if getCore():getGameVersion():getMajor() == 41 then return end
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Bomb = ParadiseDev.Zones.Bomb or {}

local Bomb = ParadiseDev.Zones.Bomb
Bomb.SOUND = Bomb.SOUND or "BurnedObjectExploded"
Bomb.SAMPLES = Bomb.SAMPLES or 8
Bomb.RADIUS_MIN = Bomb.RADIUS_MIN or 2
Bomb.RADIUS_MAX = Bomb.RADIUS_MAX or 6
Bomb.LEVEL_SPAN = Bomb.LEVEL_SPAN or 1
Bomb.SITE_RADIUS_MAX = Bomb.SITE_RADIUS_MAX or 64
Bomb.SOUND_RADIUS = Bomb.SOUND_RADIUS or 30

function Bomb.getOptions()
    return SandboxVars and SandboxVars.ParadiseZ or {}
end

function Bomb.danger()
    local val = math.floor(tonumber(Bomb.getOptions().BombDanger) or 50)
    if val < 1 then val = 1 end
    if val > 100 then val = 100 end
    return val
end

function Bomb.blastRadius()
    local rad = Bomb.RADIUS_MIN + math.floor(Bomb.danger() / 25)
    if rad > Bomb.RADIUS_MAX then rad = Bomb.RADIUS_MAX end
    return rad
end

function Bomb.siteRadius()
    local rad = math.floor(tonumber(Bomb.getOptions().BombRadius) or 30)
    if rad < 1 then rad = 1 end
    if rad > Bomb.SITE_RADIUS_MAX then rad = Bomb.SITE_RADIUS_MAX end
    return rad
end

function Bomb.baseDamage()
    return Bomb.danger() / 5
end

function Bomb.extraDamage()
    return math.max(0, tonumber(Bomb.getOptions().BombDamage) or 0)
end

function Bomb.makesFire()
    return Bomb.getOptions().BombFire ~= false
end

function Bomb.allowsIndoor()
    return Bomb.getOptions().BombIndoor == true
end

function Bomb.knocksDown()
    return Bomb.getOptions().BombFall ~= false
end

function Bomb.squareArgs(sq)
    return { x = math.floor(sq:getX()), y = math.floor(sq:getY()), z = math.floor(sq:getZ()) }
end

function Bomb.playSound(x, y, z)
    local snd = getSoundManager and getSoundManager() or nil
    if not snd or not snd.PlayWorldSoundImpl then return end
    snd:PlayWorldSoundImpl(Bomb.SOUND, false, x, y, z, 0, Bomb.SOUND_RADIUS, 1, false)
end

function Bomb.affect(pl, dmg, fall)
    if not pl or not pl:isAlive() then return end
    if dmg > 0 then
        local bd = pl:getBodyDamage()
        if bd then bd:ReduceGeneralHealth(dmg) end
    end
    if fall and pl.setKnockedDown then
        pl:setKnockedDown(true)
    end
end

function Bomb.damageAt(pl, x, y, z)
    local rad = Bomb.blastRadius()
    local dx = pl:getX() - x
    local dy = pl:getY() - y
    local dz = pl:getZ() - z
    if dz < 0 then dz = -dz end
    if dx < 0 then dx = -dx end
    if dy < 0 then dy = -dy end
    if dz > Bomb.LEVEL_SPAN then return 0, false end
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > rad then return 0, false end
    local dmg = Bomb.baseDamage() * (1 - dist / (rad + 1)) + Bomb.extraDamage()
    return dmg, Bomb.knocksDown()
end

function Bomb.onBlast(args)
    if not args then return 0 end
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    if not x or not y then return 0 end
    local z = tonumber(args.z) or 0
    Bomb.playSound(x, y, z)
    local pl = getPlayer and getPlayer() or nil
    if not pl then return 0 end
    local dmg, fall = Bomb.damageAt(pl, x, y, z)
    if dmg <= 0 and not fall then return 0 end
    Bomb.affect(pl, dmg, fall)
    return dmg
end

function Bomb.localSquare()
    local pl = getPlayer and getPlayer() or nil
    return pl and pl:getCurrentSquare() or nil
end

function Bomb.readout()
    local sq = Bomb.localSquare()
    if not sq then return "Bomb: no local player square" end
    return string.format("Bomb site=%d,%d,%d radius=%d damage=%.2f extra=%.2f fire=%s indoor=%s fall=%s",
        math.floor(sq:getX()), math.floor(sq:getY()), math.floor(sq:getZ()), Bomb.blastRadius(),
        Bomb.baseDamage(), Bomb.extraDamage(), tostring(Bomb.makesFire()), tostring(Bomb.allowsIndoor()),
        tostring(Bomb.knocksDown()))
end

function Bomb.testHere()
    local sq = Bomb.localSquare()
    if not sq then return "Bomb: no local player square" end
    return Bomb.onBlast(Bomb.squareArgs(sq))
end
