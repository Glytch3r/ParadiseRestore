if getCore():getGameVersion():getMajor() == 41 then return end
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.NoFire = ParadiseDev.Zones.NoFire or {}

local NoFire = ParadiseDev.Zones.NoFire
NoFire.SWEEP_RADIUS_MAX = NoFire.SWEEP_RADIUS_MAX or 12

function NoFire.getOptions()
    return SandboxVars and SandboxVars.ParadiseZ or {}
end

function NoFire.getZoneAt(x, y, z)
    if isClient and isClient() then
        local border = ParadiseDev.Zones.Border
        if not border or not border.getAuthorityAt then return nil end
        return border.getAuthorityAt(x, y, z, 0)
    end
    local engine = ParadiseDev.Zones.Engine
    if not engine or not engine.getAuthority then return nil end
    return engine.getAuthority(x, y, z, 0)
end

function NoFire.isNoFire(sq)
    if not sq then return false end
    local zone = NoFire.getZoneAt(sq:getX(), sq:getY(), sq:getZ())
    return zone ~= nil and zone.features ~= nil and zone.features.isNoFire == true
end

function NoFire.stopGround(sq)
    if not (sq:has(IsoFlagType.burning) or sq:haveFire()) then return end
    if isServer() then
        stopFire(sq)
        return
    end
    sq:transmitStopFire()
    sq:stopFire()
end

function NoFire.stopCampfire(sq)
    if not isServer() or not sq:hasLitCampfire() then return end
    local sys = SCampfireSystem and SCampfireSystem.instance or nil
    if not sys or not sys.getLuaObjectAt then return end
    local campfire = sys:getLuaObjectAt(sq:getX(), sq:getY(), sq:getZ())
    if campfire and campfire.putOut then campfire:putOut() end
end

function NoFire.stopObject(obj)
    if not obj then return end
    local stopped = false
    if instanceof(obj, "IsoFireplace") or instanceof(obj, "IsoBarbecue") then
        if obj:isLit() then
            obj:extinguish()
            stopped = true
        end
    elseif instanceof(obj, "IsoStove") then
        if obj:Activated() then
            obj:setActivated(false)
            stopped = true
        end
    end
    if stopped and isServer() then
        obj:sendObjectChange(IsoObjectChange.STATE)
    end
end

function NoFire.stopCharacter(chr)
    if not chr or not chr:isOnFire() then return end
    if isServer() then
        stopFire(chr)
    else
        chr:StopBurning()
    end
end

function NoFire.stopTarget(target)
    if instanceof(target, "IsoGameCharacter") then
        NoFire.stopCharacter(target)
    else
        NoFire.stopObject(target)
    end
end

function NoFire.stopSquare(sq)
    if not sq then return end
    NoFire.stopGround(sq)
    NoFire.stopCampfire(sq)
    local objs = sq:getObjects()
    if objs then
        for i = 0, objs:size() - 1 do
            NoFire.stopTarget(objs:get(i))
        end
    end
    local movers = sq:getMovingObjects()
    if movers then
        for i = 0, movers:size() - 1 do
            local chr = movers:get(i)
            if chr and instanceof(chr, "IsoGameCharacter") then
                NoFire.stopCharacter(chr)
            end
        end
    end
end

function NoFire.scanSquare(sq)
    if not sq then return end
    local objs = sq:getObjects()
    local movers = sq:getMovingObjects()
    local objCount = objs and objs:size() or 0
    local moverCount = movers and movers:size() or 0
    local ground = sq:has(IsoFlagType.burning) or sq:haveFire() or sq:hasLitCampfire() or sq:hasFireObject()
    if not ground and objCount == 0 and moverCount == 0 then return end

    local targets = nil
    for i = 0, objCount - 1 do
        local obj = objs:get(i)
        if (instanceof(obj, "IsoFireplace") or instanceof(obj, "IsoBarbecue")) and obj:isLit() then
            targets = targets or {}
            targets[#targets + 1] = obj
        elseif instanceof(obj, "IsoStove") and obj:Activated() then
            targets = targets or {}
            targets[#targets + 1] = obj
        end
    end
    for i = 0, moverCount - 1 do
        local chr = movers:get(i)
        if chr and instanceof(chr, "IsoGameCharacter") and chr:isOnFire() then
            targets = targets or {}
            targets[#targets + 1] = chr
        end
    end

    if not ground and not targets then return end
    if not NoFire.isNoFire(sq) then return end
    if ground then
        NoFire.stopGround(sq)
        NoFire.stopCampfire(sq)
    end
    if targets then
        for i = 1, #targets do
            NoFire.stopTarget(targets[i])
        end
    end
    return true
end

function NoFire.sweepRadius()
    local rad = math.floor(tonumber(NoFire.getOptions().ClearFireRadius) or 12)
    if rad < 1 then rad = 1 end
    if rad > NoFire.SWEEP_RADIUS_MAX then rad = NoFire.SWEEP_RADIUS_MAX end
    return rad
end

function NoFire.readout()
    local pl = getPlayer and getPlayer() or nil
    local sq = pl and pl:getCurrentSquare() or nil
    if not sq then return "NoFire: no local player square" end
    return string.format("NoFire square=%d,%d,%d inZone=%s radius=%d",
        math.floor(sq:getX()), math.floor(sq:getY()), math.floor(sq:getZ()),
        tostring(NoFire.isNoFire(sq)), NoFire.sweepRadius())
end

function NoFire.sweepAround(pl)
    local sq = pl and pl:getCurrentSquare() or nil
    if not sq then return 0 end
    local cell = pl:getCell()
    if not cell then return 0 end
    local rad = NoFire.sweepRadius()
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local cleared = 0
    for dx = -rad, rad do
        for dy = -rad, rad do
            local target = cell:getGridSquare(x + dx, y + dy, z)
            if target and NoFire.scanSquare(target) then
                cleared = cleared + 1
            end
        end
    end
    return cleared
end
