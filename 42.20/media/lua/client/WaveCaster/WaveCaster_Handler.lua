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
    local isInvulnerable = zd.isInvulnerable or false
    local isSitting = zd.isSitting or false
    local isRecordingAnims = zd.isRecordingAnims or false
    local heightOffset = zd.heightOffset or 0
    local isRagdolling = zd.isRagdolling or false
    local onFire = zd.onFire or false
    local health        = zd.health or 1

    if isClient() then
        sendClientCommand("WaveCaster", "Spawn", { x = WaveX, y = WaveY, z = WaveZ, zedData = zd, femaleChance = femaleChance })
        return true
    end

    for i = 1, count do
        local x = ZombRand(WaveX - radius, WaveX + radius + 1)
        local y = ZombRand(WaveY - radius, WaveY + radius + 1)

        local zeds = addZombiesInOutfit(
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
            health,
            isRecordingAnims,
            heightOffset,
            isRagdolling,
            onFire
        )
        for j = 0, zeds:size() - 1 do
            WaveCaster.applyZedData(zeds:get(j), zd, WaveX, WaveY)
        end
    end

    return true
end

function WaveCaster.applyZedData(zed, zd, soundX, soundY)
    if zd.immortalTutorialZombie then zed:setImmortalTutorialZombie(true) end
    if zd.randomOutfit then zed:dressInRandomOutfit() end
    if zd.useless then zed:setUseless(true) end
    if zd.randomBloodDirtHoles then zed:ddRandomBloodDirtHolesEtc() end
    if zd.knifeDeath then zed:setKnifeDeath(true) end
    if zd.turnAlerted then zed:setTurnAlertedValues(soundX, soundY) end
    if zd.noTeeth then zed:setNoTeeth(true) end
    if zd.jawStabAttach then zed:setJawStabAttach(true) end
    if zd.onlyJawStab then zed:setOnlyJawStab(true) end
    if zd.spottedNew then zed:spottedNew(getPlayer()) end
    if zd.aggro then zed:addAggro(getPlayer(), zd.aggroDamage or 1) end
    if zd.forceEatingAnimation then zed:setForceEatingAnimation(true) end
    if zd.alwaysKnockedDown then zed:setAlwaysKnockedDown(true) end
    if zd.walkType and zd.walkType ~= "" then zed:setWalkType(zd.walkType) end
    if zd.canWalk then zed:setCanWalk(true) end
    if zd.canCrawlUnderVehicle then zed:setCanCrawlUnderVehicle(true) end
    if zd.sitAgainstWall then zed:setSitAgainstWall(true) end
    if zd.skeleton then zed:setSkeleton(true) end
    if zd.inactive then zed:makeInactive(true) end
    if zd.turnDelta then zed:setTurnDelta(zd.turnDelta) end
    if zd.becomeCrawler then zed:setBecomeCrawler(true) end
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

function WaveCaster.getEventKey(x, y)
    if not (x and y) then return end
    return string.format("%d_%d", x, y), x, y
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

