
ParadiseZ = ParadiseZ or {}
-----------------------            ---------------------------

function ParadiseZ.coinFlip()
	return ZombRand(2) == 0
end


function ParadiseZ.getRandOutfit()
	local maleOutfits = getAllOutfits(false)
	local femaleOutfits = getAllOutfits(true)

	local pool = {}

	for i=0, maleOutfits:size()-1 do
		local fit = maleOutfits:get(i)
		pool[#pool+1] = fit
	end

	for i=0, femaleOutfits:size()-1 do
		local fit = femaleOutfits:get(i)
		if not maleOutfits:contains(fit) then
			pool[#pool+1] = fit
		end
	end

	if #pool == 0 then return nil end

	local fit = pool[ZombRand(#pool) + 1]
	--ParadiseZ.echo(tostring(fit))
	--print(tostring(fit))
	return tostring(fit)
end

function ParadiseZ.spawnZedEvent(x, y, z, fit, pop)
	local pl = getPlayer()
	x = x or pl:getX()
	y = y or pl:getY()
	z = z or pl:getZ()
    pop = pop or 50
	local flip = ParadiseZ.coinFlip()
	for i=1, pop do
		local toSpawn = fit or ParadiseZ.getRandOutfit()

		SendCommandToServer(string.format(
			"/createhorde2 -x %d -y %d -z %d -count %d -radius %d -crawler %s -isFallOnFront %s -isFakeDead %s -knockedDown %s -health %s -outfit %s",
			x, y, z,
			1,
			1,
			tostring(false),
			tostring(flip),
			tostring(flip),
			tostring(flip),
			tostring(2),
			toSpawn
		))
	end
end
--  ParadiseZ.spawnZedEvent(x, y, z, fit, 1)

function ParadiseZ.killZeds(x, y, z, radius)
    radius = radius or 15
    local pl = getPlayer()
    x = x or pl:getX()
    y = y or pl:getY()
    z = z or pl:getZ()
    local cell = getCell()
    for xDelta = -radius, radius do
        for yDelta = -radius, radius do
            local sq = cell:getGridSquare(x + xDelta, y + yDelta, z)
            if sq then
                for i = sq:getMovingObjects():size(), 1, -1 do
                    local zed = sq:getMovingObjects():get(i - 1)
                    if zed and instanceof(zed, "IsoZombie") then
                        zed:setAttackedBy(cell:getFakeZombieForHit())
                        zed:setHealth(0)
                    end
                end
            end
        end
    end
end

function ParadiseZ.delZeds(x, y, z, radius)
	local pl = getPlayer()
	radius = radius or 15
	x = x or pl:getX()
	y = y or pl:getY()
	z = z or pl:getZ()

	local r = radius + 1

	if isClient() then
		SendCommandToServer(string.format("/removezombies -x %d -y %d -z %d -radius %d", x, y, z, r))
		return
	end
	for sx = x - r, x + r do
		for sy = y - r, y + r do
			local sq = getCell():getGridSquare(sx, sy, z)
			if sq then
				for i = sq:getMovingObjects():size(), 1, -1 do
					local obj = sq:getMovingObjects():get(i - 1)
					if instanceof(obj, "IsoZombie") then
						obj:removeFromWorld()
						obj:removeFromSquare()
					end
				end
			end
		end
	end
end
function ParadiseZ.countZed(x, y, z, radius)
	local count = 0
    radius = radius or 15
    local pl = getPlayer()
    x = x or pl:getX()
    y = y or pl:getY()
    z = z or pl:getZ()
    for xDelta = -radius, radius do
        for yDelta = -radius, radius do
            local sq = getCell():getGridSquare(x + xDelta, y + yDelta, z)
            if sq then
                for i = sq:getMovingObjects():size(), 1, -1 do
                    local zed = sq:getMovingObjects():get(i - 1)
                    if zed and instanceof(zed, "IsoZombie") then
						count = count + 1							
                    end
                end
            end
        end
    end
	ParadiseZ.echo(tostring(count))
	return count
end
function ParadiseZ.countDead(x, y, z, radius)
	local pl = getPlayer()
	radius = radius or 15
	x = x or pl:getX()
	y = y or pl:getY()
	z = z or pl:getZ()

	local r = radius + 1
	local count = 0

	for sx = x - r, x + r + 1 do
		for sy = y - r, y + r + 1 do
			if IsoUtils.DistanceTo(x, y, sx + 0.5, sy + 0.5) <= r then
				local sq = getCell():getGridSquare(sx, sy, z)
				if sq then
					local list = sq:getStaticMovingObjects()
					for i = 0, list:size() - 1 do
						if instanceof(list:get(i), "IsoDeadBody") then
							count = count + 1
						end
					end
				end
			end
		end
	end
	ParadiseZ.echo('CorpseCount: '..tostring(count))
	return count
end
function ParadiseZ.delBodies(x, y, z, radius)
	local pl = getPlayer()
	radius = radius or 15
	x = x or pl:getX()
	y = y or pl:getY()
	z = z or pl:getZ()

	local r = radius + 1
	if isClient() then
		SendCommandToServer(string.format("/removezombies -x %d -y %d -z %d -radius %d -clear true", x, y, z, r))
		return
	end
	for sx = x - r, x + r + 1 do
		for sy = y - r, y + r + 1 do
			if IsoUtils.DistanceTo(x, y, sx + 0.5, sy + 0.5) <= r then
				local sq = getCell():getGridSquare(sx, sy, z)
				if sq then
					local list = sq:getStaticMovingObjects()
					local bodies = {}
					for i = 0, list:size() - 1 do
						local obj = list:get(i)
						if instanceof(obj, "IsoDeadBody") then
							bodies[#bodies + 1] = obj
						end
					end
					for i = 1, #bodies do
						sq:removeCorpse(bodies[i], false)
					end
				end
			end
		end
	end
end

-----------------------            ---------------------------
--ParadiseZ.delay = nil
function ParadiseZ.delay(seconds, callback)
    local start = getTimestampMs()
    local duration = seconds * 1000
    local executed = false
    local function dTick()
        if executed then return end
        local now = getTimestampMs()
        if now - start >= duration then
            executed = true
            Events.OnTick.Remove(dTick)
            if callback then callback() end
        end
    end
    Events.OnTick.Add(dTick)
end

--ParadiseZ.runSpawnCycle = nil
function ParadiseZ.runSpawnCycle(x, y, z, duration, rest, population, rounds, rad)
    local pl = getPlayer()
    rad = rad or 15
    x = x or pl:getX()
    y = y or pl:getY()
    z = z or pl:getZ()
    local sq = getCell():getOrCreateGridSquare(x, y, z) 
    local sec = duration * 60    
    local wave = population / rounds
    local toSpawn = round(wave)
    local roundTime = sec/rounds
    local count = 0
    
    function ParadiseZ.runRound(i)
        if i > rounds then return end
        
        toSpawn = math.floor(toSpawn)
        local sq = getCell():getOrCreateGridSquare(x, y, z) 
        getSoundManager():PlayWorldSound('ParadiseZ_Event_Start', sq, 0, 5, 5, false)
        
        ParadiseZ.spawnZedEvent(x, y, z, nil, toSpawn)
        
        ParadiseZ.delay(roundTime, function()
            ParadiseZ.delZeds(x, y, z, rad)
            local corpse = ParadiseZ.countDead(x, y, z, rad)
            count = count + corpse
            ParadiseZ.echo('\nROUND:  '..i..' [ '..count..' / '..population..' ]\nSpawned: '..toSpawn..'\nCorpses: '..corpse)
            toSpawn = math.floor(wave + (toSpawn - corpse))
            
            ParadiseZ.delay(rest, function()
                ParadiseZ.delBodies(x, y, z, rad)
                getSoundManager():PlayWorldSound('ParadiseZ_Event_End', sq, 0, 5, 5, false)
                
                if i < rounds then
                    ParadiseZ.runRound(i + 1)
                end
            end)
        end)
    end
    
    ParadiseZ.runRound(1)
end


function ParadiseZ.getMidPoint(x1, y1, x2, y2)
    local midX = (x1 + x2) / 2
    local midY = (y1 + y2) / 2
    return midX, midY
end


-----------------------      tell*      ---------------------------
function ParadiseZ.TellAll(msg)
    sendClientCommand("ParadiseZ", "tellAll",  {msg = tostring(msg) })   
end

-----------------------            ---------------------------
--[[ 
function whereami()
	local pl = getPlayer(); if not pl then return end
	local whvarereVar = math.floor(pl:getX()) ..', '.. math.floor(pl:getY()) ..', '.. math.floor(pl:getZ());
	ParadiseZ.echo(var, true)
end
 ]]
-----------------------            ---------------------------

function ParadiseZ.CheckSafetyHook() 
    local pl = getPlayer() 
    if getCore():getDebug() then 
        local msg = 'Safety Hooked:' .. tostring(ParadiseZ.CheckSafetyHook)
		ParadiseZ.echo(msg, true)   
    end
end


function ParadiseZ.CheckSafety()
    local pl = getPlayer() 
    if getCore():getDebug() then 
        local isEnabled = pl:getSafety():isEnabled()
        local msg = tostring("Safety Toggled: "..tostring(isEnabled))
		ParadiseZ.echo(msg, true)   
    end
end

function ParadiseZ.CheckCanToggle()
    local pl = getPlayer() 
    if getCore():getDebug() then 
        local isCanToggle =  ParadiseZ.isCanToggle(pl)
        local msg = tostring("Can Toggle: "..tostring(isCanToggle))
		ParadiseZ.echo(msg, true)   
    end
end

function ParadiseZ.CheckLife()
    local pl = getPlayer() 
    if getCore():getDebug() then 	
		local msg = getPlayer():getModData()['LifePoints'] or 100
		ParadiseZ.echo(msg, true)   
    end
end

-----------------------            ---------------------------
function ParadiseZ.die()
	getPlayer():Kill(nil)
end

function ParadiseZ.boom()
    local sq = ParadiseZ.getPointer()
    if not sq then return end
	local args = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }
	sendClientCommand(getPlayer(), 'object', 'addExplosionOnSquare', args)
end



function ParadiseZ.setSprCursor(sprName)
	local pl = getPlayer()
	local cursor = ISBrushToolTileCursor:new(sprName, sprName, pl)
	getCell():setDrag(cursor, pl:getPlayerNum())
end


function ParadiseZ.addTempMarker(sq)
	local pl = getPlayer() 
	if not pl then return end
	sq = sq or pl:getSquare() 

	if sq == nil then 
		sq = pl:getSquare() 
	end
	if sq then	
		if not ParadiseZ.tempPointer then
			ParadiseZ.tempPointer = getWorldMarkers():addPlayerHomingPoint(pl, sq:getX(), sq:getY(), "arrow_triangle", 1, 1, 1, 1, true, 20);
			timer:Simple(5, function()
				ParadiseZ.tempPointer:remove()
				ParadiseZ.tempPointer = nil
			end)
		end
		if not ParadiseZ.tempMark1 then
			ParadiseZ.tempMark1  = getWorldMarkers():addGridSquareMarker("circle_center", "circle_only_highlight", sq, 1, 1, 1, true, 0.75);
			timer:Simple(5, function()
				ParadiseZ.tempMark1:remove()
				ParadiseZ.tempMark1 = nil
			end)
		end

		if not ParadiseZ.tempMark2 then
			ParadiseZ.tempMark2 = getWorldMarkers():addGridSquareMarker("circle_center", "circle_only_highlight", sq, 1, 1 , 1, true, 0.75);
			timer:Simple(3, function()
				ParadiseZ.tempMark2:remove()
				ParadiseZ.tempMark2 = nil
			end)
		end

		if not ParadiseZ.tempMark3 then
			ParadiseZ.tempMark3 = getWorldMarkers():addGridSquareMarker("circle_center", "circle_only_highlight", sq, 1, 1, 1, true, 0.75);
			timer:Simple(2, function()
				ParadiseZ.tempMark3:remove()
				ParadiseZ.tempMark3 = nil
			end)
		end
	end
end

function ParadiseZ.testDmg(targ, dmg, pushedDir)
    dmg = dmg or 15
    dmg = math.min(100, dmg)
    targ = targ or getPlayer() 
    if not targ then return end
    local md = targ:getModData()
    md.LifePoints = math.max(0, md.LifePoints - dmg)
    md.LifeBarFlash = 0.4
	
    local percent = SandboxVars.ParadiseZpvp.pvpStaggerChance or 34
    if ParadiseZ.doRoll(percent) then
		pushedDir = pushedDir or 'pushedbehind'
--[[         targ:setBumpType(pushedDir)
        targ:setVariable("BumpFall", true) ]]
        --targ:setVariable("BumpFallType", "pushedbehind")
		sendClientCommand("ParadiseZ", "knockDownPl", { targId = targ:getOnlineID(), pushedDir = pushedDir })

    end

--[[     local recoverHP = dmg / 3
    for i = 2, 6, 2 do
        timer:Simple(i, function()
            md.LifePoints = math.min(100, md.LifePoints + recoverHP)
        end)
    end ]]
end


function ParadiseZ.isTempMarkerActive()
	if ParadiseZ.isTempMarkerActive ~= nil or ParadiseZ.tempMark1 ~= nil then
		return true
	end
	return false
end
function ParadiseZ.getCar()
	local car = nil;
	local pl = getPlayer();
	if pl:getVehicle() then
		car = pl:getVehicle();
	elseif pl:getNearVehicle() then
		car = pl:getNearVehicle();
	elseif pl:getUseableVehicle() then
		car = pl:getUseableVehicle();
	end

	return car
end

function ParadiseZ.pickCar(sq)
	local car = IsoObjectPicker.Instance:PickVehicle(getMouseXScaled(), getMouseYScaled()) 
	if car ~= nil then return car end

	sq = sq or ParadiseZ.getPointer()
	if sq then car = sq:getVehicleContainer() end
	return car
end

function ParadiseZ.getPointer()
	if not isIngameState() then return nil end
	local sq = nil
	local zPos = getPlayer():getZ() or 0
	local mx, my = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), zPos)
	if mx and my then
		local sq = getCell():getGridSquare(math.floor(mx), math.floor(my), zPos)
		--if sq and sq:getFloor() then sq:getFloor():setHighlighted(true); return sq end
		if not sq then return nil end
	--[[ 	local flr = sq:getFloor()
		if flr then
			flr:setHighlighted(true, true)
		end ]]
		return sq 
	end
	return nil
end

function ParadiseZ.pickBldg()
	if not isIngameState() then return nil end
	local sq = getPointer()
	local bldg = nil
	if sq then
		local x, y = sq:getX(), sq:getY()
		if x and y then
			bldg = getWorld():getMetaGrid():getAssociatedBuildingAt(x,y)	
		end
	end
	return bldg
end



