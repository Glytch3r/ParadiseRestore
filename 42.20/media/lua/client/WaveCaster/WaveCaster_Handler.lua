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
            false,
            onFire
        )
        for j = 0, zeds:size() - 1 do
            WaveCaster.applyZedData(zeds:get(j), zd, WaveX, WaveY)
        end
    end

    return true
end

local ZED_SKINS = { "F_ZedBody01_level1", "F_ZedBody01_level2", "F_ZedBody01_level3", "F_ZedBody01", "F_ZedBody02_level1", "F_ZedBody02_level2", "F_ZedBody02_level3", "F_ZedBody02", "F_ZedBody03_level1", "F_ZedBody03_level2", "F_ZedBody03_level3", "F_ZedBody03", "F_ZedBody04_level1", "F_ZedBody04_level2", "F_ZedBody04_level3", "F_ZedBody04", "M_ZedBody01_level1", "M_ZedBody01_level2", "M_ZedBody01_level3", "M_ZedBody01", "M_ZedBody02_level1", "M_ZedBody02_level2", "M_ZedBody02_level3", "M_ZedBody02", "M_ZedBody03_level1", "M_ZedBody03_level2", "M_ZedBody03_level3", "M_ZedBody03", "M_ZedBody04_level1", "M_ZedBody04_level2", "M_ZedBody04_level3", "M_ZedBody04" }
local HUMAN_SKINS = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04", "FemaleBody05", "MaleBody01", "MaleBody01a", "MaleBody02", "MaleBody02a", "MaleBody03", "MaleBody03a", "MaleBody04", "MaleBody04a", "MaleBody05", "MaleBody05a" }
local SKELETON_SKINS = { "Skeleton_Mannequin", "Skeleton", "SkeletonBurned", "SkeletonMuscle", "F_Mannequin_White", "F_Mannequin_Black", "M_Mannequin_Black", "M_Mannequin_White", "Male_Scarecrow" }

local copyContainer
local function copyItem(item, target)
    if not item or not target then return end
    local copy = target:AddItem(item:getFullType())
    if not copy then return end
    local sourceVisual = item.getVisual and item:getVisual() or nil
    local targetVisual = copy.getVisual and copy:getVisual() or nil
    if sourceVisual and targetVisual then targetVisual:copyVisualFrom(sourceVisual) end
    if item.getCondition and copy.setCondition then copy:setCondition(item:getCondition()) end
    if item.getInventory and copy.getInventory then copyContainer(item:getInventory(), copy:getInventory()) end
    return copy
end

copyContainer = function(source, target)
    if not source or not target then return end
    local items = source:getItems()
    for i = 0, items:size() - 1 do copyItem(items:get(i), target) end
end

function WaveCaster.copyPlayerVisuals(player, zed)
    if not player or not zed then return end
    zed:setFemaleEtc(player:isFemale())
    local sourceVisual = player:getHumanVisual()
    local targetVisual = zed:getHumanVisual()
    if sourceVisual and targetVisual then targetVisual:copyFrom(sourceVisual) end
    local sourceDescriptor = player:getDescriptor()
    local targetDescriptor = zed:getDescriptor()
    if sourceVisual and targetDescriptor then targetDescriptor:getHumanVisual():copyFrom(sourceVisual) end
    local sourceInventory = player:getInventory()
    local targetInventory = zed:getInventory()
    if not sourceInventory or not targetInventory then return end
    local targetItems = targetInventory:getItems()
    for i = targetItems:size() - 1, 0, -1 do targetInventory:Remove(targetItems:get(i)) end
    local worn = player:getWornItems()
    local targetWorn = zed:getWornItems()
    targetWorn:clear()
    local sourceItems = sourceInventory:getItems()
    for i = 0, sourceItems:size() - 1 do
        local item = sourceItems:get(i)
        local isWorn = false
        for j = 0, worn:size() - 1 do if worn:getItemByIndex(j) == item then isWorn = true; break end end
        if not isWorn then copyItem(item, targetInventory) end
    end
    for i = 0, worn:size() - 1 do
        local item = worn:getItemByIndex(i)
        local location = worn:getLocation(item)
        if item and location then
            local copy = copyItem(item, targetInventory)
            if copy then
                targetWorn:setItem(location, copy)
            end
        end
    end
    zed:onWornItemsChanged()
    zed:resetModelNextFrame()
end

function WaveCaster.applySkin(zed, zd)
    local skin = zd and zd.skin
    if zd and zd.humanize and (not skin or skin == "Random Zed") then skin = "Random Human" end
    if not zed or not skin or skin == "Random Zed" then return end
    if skin == "Random Human" then skin = HUMAN_SKINS[ZombRand(#HUMAN_SKINS) + 1] end
    if skin == "Random Skeleton" then skin = SKELETON_SKINS[ZombRand(#SKELETON_SKINS) + 1] end
    if skin == "Random Any" then
        local all = {}
        for _, value in ipairs(ZED_SKINS) do table.insert(all, value) end
        for _, value in ipairs(HUMAN_SKINS) do table.insert(all, value) end
        for _, value in ipairs(SKELETON_SKINS) do table.insert(all, value) end
        skin = all[ZombRand(#all) + 1]
    end
    local visual = zed:getHumanVisual()
    if not visual then return end
    local human = string.find(skin, "Body") ~= nil and string.find(skin, "Zed") == nil
    local skeleton = string.find(skin, "Skeleton") ~= nil
    if string.sub(skin, 1, 2) == "F_" or string.sub(skin, 1, 6) == "Female" then zed:setFemaleEtc(true) end
    if string.sub(skin, 1, 2) == "M_" or string.sub(skin, 1, 4) == "Male" then zed:setFemaleEtc(false) end
    if human then
        zed:clearAttachedItems()
        visual:getBodyVisuals():clear()
        visual:removeBlood()
        visual:removeDirt()
    end
    if skeleton then zed:setSkeleton(true) end
    visual:setSkinTextureName(skin)
    zed:resetModelNextFrame()
    zed:resetModel()
end

function WaveCaster.applyZedData(zed, zd, soundX, soundY)
    if zd.immortalTutorialZombie then zed:setImmortalTutorialZombie(true) end
    if zd.randomOutfit then zed:dressInRandomOutfit() end
    if zd.useless then zed:setUseless(true) end
    if zd.randomBloodDirtHoles then zed:ddRandomBloodDirtHolesEtc() end
    if zd.knifeDeath then zed:setKnifeDeath(true) end
    if zd.noTeeth then zed:setNoTeeth(true) end
    if zd.jawStabAttach then zed:setJawStabAttach(true) end
    if zd.onlyJawStab then zed:setOnlyJawStab(true) end
    if zd.forceEatingAnimation then zed:setForceEatingAnimation(true) end
    if zd.alwaysKnockedDown then zed:setAlwaysKnockedDown(true) end
    if zd.walkType and zd.walkType ~= "" then zed:setWalkType(zd.walkType) end
    if zd.canWalk then zed:setCanWalk(true) end
    if zd.canCrawlUnderVehicle then zed:setCanCrawlUnderVehicle(true) end
    if zd.sitAgainstWall then zed:setSitAgainstWall(true) end
    if zd.skeleton then zed:setSkeleton(true) end
    if zd.inactive then zed:makeInactive(true) end
    if zd.reanimatedPlayer then zed:setReanimatedPlayer(true) end
    if zd.scratch then zed.scratch = true end
    if zd.laceration then zed.laceration = true end
    if zd.keepItReal then zed.keepItReal = true end
    if zd.strength ~= nil then zed.strength = zd.strength end
    if zd.cognition ~= nil then zed.cognition = zd.cognition end
    if zd.memory ~= nil then zed.memory = zd.memory end
    if zd.sight ~= nil then zed.sight = zd.sight end
    if zd.hearing ~= nil then zed.hearing = zd.hearing end
    if zd.voice ~= nil then
        pcall(function()
            local field = zed:getClass():getDeclaredField("voiceChoice")
            field:setAccessible(true)
            field:setInt(zed, zd.voice)
        end)
    end
    if zd.turnDelta then zed:setTurnDelta(zd.turnDelta) end
    if zd.becomeCrawler then zed:setBecomeCrawler(true) end
    WaveCaster.applySkin(zed, zd)
    if zd.copyVisual then WaveCaster.copyPlayerVisuals(getPlayer(), zed) end
    if zd.walkTargetX ~= nil and zd.walkTargetY ~= nil and zd.walkTargetZ ~= nil then
        zed:setTurnAlertedValues(zd.walkTargetX, zd.walkTargetY)
        zed:setTarget(nil)
        zed:getPathFindBehavior2():pathToLocationF(zd.walkTargetX, zd.walkTargetY, zd.walkTargetZ)
    end
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

