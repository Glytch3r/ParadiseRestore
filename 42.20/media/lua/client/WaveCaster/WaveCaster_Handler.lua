-- client/WaveCaster_Handler.lua
WaveCaster = WaveCaster or {}

function WaveCaster.processWave(castEvent)
    if not castEvent then return end
    if not castEvent.Waves or #castEvent.Waves == 0 then return end

    if not WaveCaster.hasCasterInside(castEvent.CastX, castEvent.CastY) then
        return
    end

    local wave = castEvent.Waves[1]
    if not wave then return end

    local success = WaveCaster.spawnWave(castEvent, wave)
    if not success then
        return
    end

    table.remove(castEvent.Waves, 1)

    if castEvent.Waves[1] then
        castEvent.Countdown = castEvent.Waves[1].Delay
    else
        castEvent.Countdown = 0
    end
end


--[[ 
    setImmortalTutorialZombie Link icon
    dressInRandomOutfit Link icon
    setUseless Link icon
    ddRandomBloodDirtHolesEtc()
    setKnifeDeath Link icon
    setTurnAlertedValues
    setNoTeeth 
    getPlayer():kill
    cantBite 
    setTurnAlertedValues(int soundX,
    int soundY)
    setJawStabAttach 
    addAggro(IsoMovingObject other,
    float damage)
    setOnlyJawStab 
    spottedNew Link icon
    setForceEatingAnimation 
    setAlwaysKnockedDown 
    setWalkType Link icon
    setCanWalk 
    setCanCrawlUnderVehicle 
    setSitAgainstWall 
    setSkeleton 
    makeInactive 
    setTurnDelta
    setBecomeCrawler(boolean)
 ]]
function WaveCaster.spawnWave(castEvent, wave)
    if not castEvent then return false end
    if not wave then return false end
    if not wave.ZData then return false end

    local zd = wave.ZData


    local WaveX = wave.WaveX or castEvent.WaveX
    local WaveY = wave.WaveY or castEvent.WaveY
    local WaveZ = wave.WaveZ or castEvent.WaveZ or 0

    if not (WaveX and WaveY) then
        print("WaveCaster: Invalid Wave Coordinates")
        return false
    end

    local outfit, femaleChance = WaveCaster.getSpawnRandomZedInfo(zd.outfit)
    if zd.femaleChance ~= nil then
        femaleChance = zd.femaleChance
    end

    local count         = zd.count or 1
    local radius        = zd.radius or 0
    local crawler       = zd.crawler or false
    local isFallOnFront = zd.isFallOnFront or false
    local isFakeDead    = zd.isFakeDead or false
    local knockedDown   = zd.knockedDown or false
    local health        = zd.health or 1

    if isClient() then
        local cmd = string.format(
            "/createhorde2 -x %d -y %d -z %d -count %d -radius %d -crawler %s -isFallOnFront %s -isFakeDead %s -knockedDown %s -health %s -outfit %s",
            WaveX,
            WaveY,
            WaveZ,
            count,
            radius,
            tostring(crawler),
            tostring(isFallOnFront),
            tostring(isFakeDead),
            tostring(knockedDown),
            tostring(health),
            outfit or ""
        )

        print(cmd)
        SendCommandToServer(cmd)
        return true
    end

    for i = 1, count do
        local x = ZombRand(WaveX - radius, WaveX + radius + 1)
        local y = ZombRand(WaveY - radius, WaveY + radius + 1)

        addZombiesInOutfit(
            x,
            y,
            WaveZ,
            1,
            outfit,
            femaleChance,
            crawler,
            isFallOnFront,
            isFakeDead,
            knockedDown,
            health
        )
    end

    return true
end

function WaveCaster.clientHandler()
    if not WaveCaster.Data or not WaveCaster.Data.events then return end
    for key, castEvent in pairs(WaveCaster.Data.events) do
        if castEvent.CastX and castEvent.CastY then
            if WaveCaster.getClosestPlayerToXY(castEvent.CastX, castEvent.CastY) == getPlayer() then
                if castEvent.Countdown and castEvent.Countdown > 0 then
                    castEvent.Countdown = castEvent.Countdown - 1
                    if castEvent.Countdown <= 0 then
                        WaveCaster.processWave(castEvent)
                    end
                    WaveCaster.saveData(WaveCaster.Data)
                end
            end
        end
    end
end
Events.EveryOneMinute.Add(WaveCaster.clientHandler)

function WaveCaster.getEventKey(x, y)
    local midX, midY = WaveCaster.getBldgMidXY(x, y)
    if not (midX and midY) then return end
    return string.format("%d_%d", midX, midY), midX, midY
end

function WaveCaster.getCastEvent(x, y)
    if not WaveCaster.Data or not WaveCaster.Data.events then return end
    local key = WaveCaster.getEventKey(x, y)
    if not key then return end
    return WaveCaster.Data.events[key]
end

function WaveCaster.isHasCastEvent(x, y)
    return WaveCaster.getCastEvent(x, y) ~= nil
end

function WaveCaster.getWaveData(x, y, waveIndex)
    local castEvent = WaveCaster.getCastEvent(x, y)
    if not castEvent or not castEvent.Waves then return end
    return castEvent.Waves[waveIndex]
end

function WaveCaster.getCastHandler(x, y)
    local onlinePlayers = getOnlinePlayers()

    for i = 0, onlinePlayers:size() - 1 do
        local chr = onlinePlayers:get(i)
        if chr and WaveCaster.isCaster(chr, x, y) then
            return chr
        end
    end

    return WaveCaster.getClosestPlayerToXY(x, y)
end

function WaveCaster.getWaveList(x, y)
    local castEvent = WaveCaster.getCastEvent(x, y)
    if not castEvent then return end

    return castEvent.Waves
end

function WaveCaster.isEmpty(x, y)
    local castEvent = WaveCaster.getCastEvent(x, y)
    if not castEvent then return true end
    if not castEvent.Waves then return true end
    return #castEvent.Waves == 0
end

function WaveCaster.getState(x, y)
    local castEvent = WaveCaster.getCastEvent(x, y)
    if not castEvent then return "Empty" end
    if WaveCaster.isEmpty(x, y) then return "Empty" end
    if castEvent.Countdown and castEvent.Countdown > 0 then
        return "Active"
    end
    return "Ready"
end

function WaveCaster.hasCasterInside(x, y)
    local onlinePlayers = getOnlinePlayers()
    for i = 0, onlinePlayers:size() - 1 do
        local chr = onlinePlayers:get(i)
        if chr and WaveCaster.isCaster(chr, x, y) then
            return true
        end
    end
    return false
end

--[[ 
function WaveCaster.spawnWave(castEvent, wave)
    if not castEvent or not wave then return end
    if not wave.ZData then return end
    local zd = wave.ZData
    local z = castEvent.CastZ or 0
    local outfit, femaleChance = WaveCaster.getSpawnRandomZedInfo(zd.outfit)
    if zd.femaleChance ~= nil then
        femaleChance = zd.femaleChance
    end
    local count          = zd.count or 1
    local crawler        = zd.crawler or false
    local isFallOnFront  = zd.isFallOnFront or false
    local isFakeDead     = zd.isFakeDead or false
    local knockedDown    = zd.knockedDown or false
    local health         = zd.health or 1
    --local sx             = castEvent.CastX
    --local sy             = castEvent.CastY
    local WaveX          = castEvent.WaveX
    local WaveY          = castEvent.WaveY
    local WaveZ          = castEvent.WaveZ    
    local radius         = castEvent.radius

    if isClient() then
        local cmd = string.format(
            "/createhorde2 -WaveX %d -WaveY %d -WaveZ %d -count %d -radius 0 -crawler %s -isFallOnFront %s -isFakeDead %s -knockedDown %s -health %s -outfit %s",
            WaveX, WaveY, WaveZ, count,
            tostring(crawler), tostring(isFallOnFront), tostring(isFakeDead), tostring(knockedDown), tostring(health),
            outfit or ""
        )
        SendCommandToServer(cmd)
    else
        for i = 1, count do
            addZombiesInOutfit(WaveX, WaveY, WaveZ, 1, outfit, femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, health)
        end
    end
end ]]




--[[
function WaveCaster.clientHandler()
    local pl = getPlayer()
    if not pl then return end
    if not WaveCaster.Data or not WaveCaster.Data.events then return end
    for key, castEvent in pairs(WaveCaster.Data.events) do
        if castEvent.WaveX and castEvent.WaveX then
            local getClosestPlayerToXY = WaveCaster.getClosestPlayerToXY(castEvent.CastX, castEvent.CastY) == pl

            if getClosestPlayerToXY then
                if castEvent.Waves and #castEvent.Waves > 0 then
                    if castEvent.Countdown and castEvent.Countdown > 0 then
                        castEvent.Countdown = castEvent.Countdown - 1
                    end

                    if not castEvent.Countdown or castEvent.Countdown <= 0 then
                        WaveCaster.processWave(castEvent)
                    end

                    WaveCaster.saveData(WaveCaster.Data)
                end
            end
        end
    end
end
Events.EveryOneMinute.Add(WaveCaster.clientHandler) 

function WaveCaster.clientHandler()
    local pl = getPlayer()
    if not pl then return end

    if not WaveCaster.Data or not WaveCaster.Data.events then return end
    for key, castEvent in pairs(WaveCaster.Data.events) do
        if castEvent.CastX and castEvent.CastY then
            local getClosestPlayerToXY = WaveCaster.getClosestPlayerToXY(castEvent.CastX, castEvent.CastY) == pl
            if castEvent.Waves and #castEvent.Waves > 0 then
                if castEvent.Countdown and castEvent.Countdown > 0 then
                        castEvent.Countdown = castEvent.Countdown - 1
                end
                if getClosestPlayerToXY then
                    if not castEvent.Countdown or castEvent.Countdown <= 0 then
                        WaveCaster.processWave(castEvent)
                    end
                    WaveCaster.saveData(WaveCaster.Data)
                end
            end
        end
    end
end
Events.EveryOneMinute.Add(WaveCaster.clientHandler) ]]
--[[ 
function WaveCaster.clientHandler()
    local pl = getPlayer()
    if not pl then return end
    if not WaveCaster.Data or not WaveCaster.Data.events then return end
    for key, castEvent in pairs(WaveCaster.Data.events) do
        if castEvent.CastX and castEvent.CastY then
            if WaveCaster.getClosestPlayerToXY(castEvent.CastX, castEvent.CastY) == pl then
                if castEvent.Waves and #castEvent.Waves > 0 then
                    if castEvent.Countdown and castEvent.Countdown > 0 then
                        castEvent.Countdown = castEvent.Countdown - 1
                        WaveCaster.saveData(WaveCaster.Data)
                    elseif not castEvent.Countdown or castEvent.Countdown <= 0 then
                        WaveCaster.processWave(castEvent)
                        WaveCaster.saveData(WaveCaster.Data)
                    end
                end
            end
        end
    end
end
Events.EveryOneMinute.Add(WaveCaster.clientHandler)
 ]]

--[[ 
function WaveCaster.spawnWave(castEvent, wave)
    if not (castEvent and wave) then return end
    if not wave.ZData then return end
    local z = castEvent.CastZ or 0
    local zd = wave.ZData
    local castMidSq = getCell():getOrCreateGridSquare(castEvent.CastX, castEvent.CastY, z)
    local outfit, femaleChance = WaveCaster.getSpawnRandomZedInfo(zd.outfit)
    if zd.femaleChance then femaleChance = zd.femaleChance end
    local knockedDown = zd.knockedDown
    local crawler = zd.crawler
    local isFallOnFront = zd.isFallOnFront
    local isFakeDead = zd.isFakeDead
    local health = zd.health
    local rad = zd.radius or 0
    local count = zd.count or 1
    local randSq = WaveCaster.getRandSq(castMidSq, rad)
    if randSq then
        local sx, sy, sz = randSq:getX(), randSq:getY(), randSq:getZ()
        WaveCaster.addTempMarker(randSq)
        if isClient() then 
            SendCommandToServer(string.format("/createhorde2 -x %d -y %d -z %d -count %d -rad %d -crawler %s -isFallOnFront %s -isFakeDead %s -knockedDown %s -health %s -outfit %s ",
            sx, sy, sz, count, rad, tostring(crawler), tostring(isFallOnFront), tostring(isFakeDead), tostring(knockedDown), tostring(health), outfit or ""))
        else	
            for i = 1, count do
                addZombiesInOutfit(sx, sy, sz, 1, outfit, femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, health)
            end
        end
    end
    for i = 1, count do
        local sq = WaveCaster.getRandSq(castMidSq, rad)
        if sq then
            local sx, sy, sz = sq:getX(), sq:getY(), sq:getZ()
            WaveCaster.addTempMarker(sq)       
        end
    end
end ]]


function WaveCaster.getRandSq(midSq, rad)
    local pl = getPlayer()
    if not pl or not pl:isAlive() then return end

    midSq = midSq or pl:getSquare()
    rad = math.max(rad or 0, 1)

    local cell = getCell()
    local x = midSq:getX()
    local y = midSq:getY()
    local z = midSq:getZ()

    while true do
        local ox = ZombRand(-rad, rad + 1)
        local oy = ZombRand(-rad, rad + 1)

        if ox ~= 0 or oy ~= 0 then
            local sq = cell:getOrCreateGridSquare(x + ox, y + oy, z)
            if sq then
                return sq
            end
        end
    end
end

function WaveCaster.getRandSq(midSq, rad)
    if not midSq then return nil end

    rad = math.max(1, rad or 1)

    local cell = getCell()
    local x = midSq:getX()
    local y = midSq:getY()
    local z = midSq:getZ()

    for i = 1, 100 do
        local rx = ZombRand(x - rad, x + rad + 1)
        local ry = ZombRand(y - rad, y + rad + 1)

        if IsoUtils.DistanceToSquared(x, y, rx, ry) <= (rad * rad) then
            local sq = cell:getOrCreateGridSquare(rx, ry, z)
            if sq then
                return sq
            end
        end
    end

    return midSq
end
--[[ 
function WaveCaster.getRandSq(CastSq, rad, minRad)
    minRad = minRad or 0

    local pl = getPlayer()

    if not CastSq then
        CastSq = pl:getSquare()
    end

    local cell = getCell()
    if not cell or not CastSq then return end

    local x = CastSq:getX()
    local y = CastSq:getY()

    for i = 1, 100 do
        local offsetX = ZombRand(-rad, rad + 1)
        local offsetY = ZombRand(-rad, rad + 1)

        local dist = math.sqrt(offsetX^2 + offsetY^2)

        if dist >= minRad and dist <= rad then
            local checkX = x + offsetX
            local checkY = y + offsetY

            local startZ = ZombRand(0, 8)

            for zOffset = 0, 7 do
                local z = (startZ + zOffset) % 8
                local sq = cell:getGridSquare(checkX, checkY, z)

                if sq and sq:getFloor() then
                    return sq
                end
            end
        end
    end

    return CastSq
end

-----------------------            ---------------------------
function WaveCaster.getRandSq(midSq, rad)
    local pl = getPlayer()
    if not pl then return end
    if not pl:isAlive() then return end

    if not midSq then midSq = pl:getSquare() end
    rad = rad or 30
    local minRad = 1 * rad
    local maxRad = 2 * rad



    local cell = getCell()
    local x = midSq:getX()
    local y = midSq:getY()
    local z = midSq:getZ()

    local nearbySquare = nil

    repeat
        local offsetX = ZombRand(-rad, rad + 1)
        local offsetY = ZombRand(-rad, rad + 1)
        local distance = math.sqrt(offsetX^2 + offsetY^2)

        if distance >= minRad and distance <= maxRad then
            nearbySquare = cell:getOrCreateGridSquare(x + offsetX, y + offsetY, z)
        end
    until nearbySquare

    return nearbySquare
end
 ]]
function WaveCaster.addTempMarker(sq)
    if not sq or not WaveCasterPanel.instance then return end
	local pl = getPlayer() 
	if not pl then return end
	sq = sq or pl:getSquare() 

	if sq == nil then 
		sq = pl:getSquare() 
	end
	if sq then	
		if not tempPointer then
			tempPointer = getWorldMarkers():addPlayerHomingPoint(pl, sq:getX(), sq:getY(), "arrow_triangle", 1, 1, 1, 1, true, 20);
			timer:Simple(5, function()
				tempPointer:remove()
				tempPointer = nil
			end)
		end
		if not tempMark1 then
			tempMark1  = getWorldMarkers():addGridSquareMarker("circle_center", "circle_only_highlight", sq, 1, 1, 1, true, 0.75);
			timer:Simple(5, function()
				tempMark1:remove()
				tempMark1 = nil
			end)
		end

		if not tempMark2 then
			tempMark2 = getWorldMarkers():addGridSquareMarker("circle_center", "circle_only_highlight", sq, 1, 1 , 1, true, 0.05);
			timer:Simple(3, function()
				tempMark2:remove()
				tempMark2 = nil
			end)
		end

		if not tempMark3 then
			tempMark3 = getWorldMarkers():addGridSquareMarker("circle_center", "circle_only_highlight", sq, 1, 1, 1, true, 0.7);
			timer:Simple(2, function()
				tempMark3:remove()
				tempMark3 = nil
			end)
		end
	end
end

