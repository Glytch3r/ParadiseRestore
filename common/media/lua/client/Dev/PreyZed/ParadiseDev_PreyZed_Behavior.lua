ParadiseDev = ParadiseDev or {}
ParadiseDev.PreyZed = ParadiseDev.PreyZed or {}

ParadiseDev.PreyZed.fleeRange = 20
ParadiseDev.PreyZed.fleeDistance = 15
ParadiseDev.PreyZed.fleeCooldown = 3

function ParadiseDev.PreyZed.getGameSeconds()
    return math.floor(getGameTime():getWorldAgeHours() * 3600)
end

function ParadiseDev.PreyZed.isWalkable(sq)
    if not sq or sq:isSolid() or sq:isSolidTrans() then return false end
    return not (IsoFlagType and sq:Is(IsoFlagType.water))
end

function ParadiseDev.PreyZed.moveAway(zed, pl)
    if not zed or not pl then return end
    local zedX = math.floor(zed:getX())
    local zedY = math.floor(zed:getY())
    local zedZ = math.floor(zed:getZ())
    local dx = zedX - pl:getX()
    local dy = zedY - pl:getY()
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then return end
    dx = dx / length
    dy = dy / length
    for index = 1, 10 do
        local scatter = math.floor(ParadiseDev.PreyZed.fleeDistance * 0.3)
        local x = math.floor(zedX + dx * ParadiseDev.PreyZed.fleeDistance + ZombRand(-scatter, scatter + 1))
        local y = math.floor(zedY + dy * ParadiseDev.PreyZed.fleeDistance + ZombRand(-scatter, scatter + 1))
        local sq = getCell():getGridSquare(x, y, zedZ)
        if ParadiseDev.PreyZed.isWalkable(sq) then
            if zed.setTarget then zed:setTarget(nil) end
            if zed.pathToLocation then zed:pathToLocation(x, y, zedZ) end
            if zed.setVariable then
                zed:setVariable("bPathfind", true)
                zed:setVariable("bMoving", false)
            end
            return
        end
    end
end

function ParadiseDev.PreyZed.behaviorHandler(zed)
    if not ParadiseDev.PreyZed.isPrey or not ParadiseDev.PreyZed.isPrey(zed) then return end
    local pl = getPlayer()
    if not pl or pl:isInvisible() then return end
    local dx = zed:getX() - pl:getX()
    local dy = zed:getY() - pl:getY()
    if dx * dx + dy * dy > ParadiseDev.PreyZed.fleeRange * ParadiseDev.PreyZed.fleeRange then return end
    local modData = zed:getModData()
    local now = ParadiseDev.PreyZed.getGameSeconds()
    if tonumber(modData.ParadiseDevPreyNextMove) and modData.ParadiseDevPreyNextMove > now then return end
    modData.ParadiseDevPreyNextMove = now + ParadiseDev.PreyZed.fleeCooldown
    ParadiseDev.PreyZed.moveAway(zed, pl)
end

Events.OnZombieUpdate.Remove(ParadiseDev.PreyZed.behaviorHandler)
Events.OnZombieUpdate.Add(ParadiseDev.PreyZed.behaviorHandler)
