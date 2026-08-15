
--server/WaveCaster_Server.lua

WaveCaster = WaveCaster or {}

if isClient() then return end

function WaveCaster.init()
    WaveCaster.Data = ModData.getOrCreate("WaveCaster_Data")
end
Events.OnInitGlobalModData.Add(WaveCaster.init)

function WaveCaster.transmit()
    ModData.transmit("WaveCaster_Data")
end

function WaveCaster.applyZedData(zed, zd, pl, soundX, soundY)
    if zd.immortalTutorialZombie then zed:setImmortalTutorialZombie(true) end
    if zd.randomOutfit then zed:dressInRandomOutfit() end
    if zd.useless then zed:setUseless(true) end
    if zd.randomBloodDirtHoles then zed:ddRandomBloodDirtHolesEtc() end
    if zd.knifeDeath then zed:setKnifeDeath(true) end
    if zd.turnAlerted then zed:setTurnAlertedValues(soundX, soundY) end
    if zd.noTeeth then zed:setNoTeeth(true) end
    if zd.jawStabAttach then zed:setJawStabAttach(true) end
    if zd.onlyJawStab then zed:setOnlyJawStab(true) end
    if zd.spottedNew and pl then zed:spottedNew(pl) end
    if zd.aggro and pl then zed:addAggro(pl, zd.aggroDamage or 1) end
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

function WaveCaster.spawn(player, args)
    if not player or string.lower(player:getAccessLevel()) ~= "admin" then return end
    local zd = args.zedData
    if not zd or not args.x or not args.y then return end
    local count = math.min(math.max(tonumber(zd.count) or 1, 1), 500)
    local radius = tonumber(zd.radius) or 0
    for i = 1, count do
        local x = ZombRand(args.x - radius, args.x + radius + 1)
        local y = ZombRand(args.y - radius, args.y + radius + 1)
        local zeds = addZombiesInOutfit(x, y, args.z or 0, 1, zd.outfit, args.femaleChance, zd.crawler or false, zd.isFallOnFront or false, zd.isFakeDead or false, zd.knockedDown or false, zd.isInvulnerable or false, zd.isSitting or false, zd.health or 1, zd.isRecordingAnims or false, zd.heightOffset or 0, zd.isRagdolling or false, zd.onFire or false)
        for j = 0, zeds:size() - 1 do
            WaveCaster.applyZedData(zeds:get(j), zd, player, args.x, args.y)
        end
    end
end

function WaveCaster.processWave(castEvent)
    if not castEvent or not castEvent.Waves or #castEvent.Waves == 0 then return false end

    local wave = castEvent.Waves[1]
    local zd = wave and wave.ZData
    if not zd then return false end

    local pl = castEvent.Caster and getPlayerFromUsername(castEvent.Caster)
    local count = math.min(math.max(tonumber(zd.count) or 1, 1), 500)
    local radius = tonumber(zd.radius) or 0
    local x = wave.WaveX or castEvent.CastX
    local y = wave.WaveY or castEvent.CastY
    local z = wave.WaveZ or castEvent.CastZ or 0
    if not (x and y) then return false end

    for i = 1, count do
        local spawnX = ZombRand(x - radius, x + radius + 1)
        local spawnY = ZombRand(y - radius, y + radius + 1)
        local zeds = addZombiesInOutfit(spawnX, spawnY, z, 1, zd.outfit, zd.femaleChance, zd.crawler or false, zd.isFallOnFront or false, zd.isFakeDead or false, zd.knockedDown or false, zd.isInvulnerable or false, zd.isSitting or false, zd.health or 1, zd.isRecordingAnims or false, zd.heightOffset or 0, zd.isRagdolling or false, zd.onFire or false)
        for j = 0, zeds:size() - 1 do
            WaveCaster.applyZedData(zeds:get(j), zd, pl, x, y)
        end
    end

    table.remove(castEvent.Waves, 1)
    castEvent.Countdown = castEvent.Waves[1] and castEvent.Waves[1].Delay or 0
    return true
end

function WaveCaster.getClosestPlayerInRange(castEvent)
    if not castEvent then return nil end
    local wave = castEvent.Waves and castEvent.Waves[1] or nil
    local x = castEvent.CastX
    local y = castEvent.CastY
    local radius = tonumber(wave and wave.CastRadius) or 0
    if not (x and y) then return nil end

    local closestPlayer = nil
    local closestDistance = nil
    local checked = {}
    local function checkPlayer(pl)
        if not pl or checked[pl] then return end
        checked[pl] = true
        local playerX = pl:getX()
        local playerY = pl:getY()
        if not (playerX and playerY) then return end
        local distance = IsoUtils.DistanceTo(x, y, playerX, playerY)
        if distance <= radius and (not closestDistance or distance < closestDistance) then
            closestPlayer = pl
            closestDistance = distance
        end
    end

    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            checkPlayer(players:get(index))
        end
    end
    if castEvent.Caster and getPlayerFromUsername then
        checkPlayer(getPlayerFromUsername(castEvent.Caster))
    end
    return closestPlayer
end

function WaveCaster.processEvents()
    local data = ModData.getOrCreate("WaveCaster_Data")
    if not data.events then return end

    local changed = false
    for key, castEvent in pairs(data.events) do
        if castEvent.Waves and #castEvent.Waves > 0 then
            local countdown = tonumber(castEvent.Countdown) or 0
            if countdown > 0 then
                castEvent.Countdown = countdown - 1
            else
                castEvent.Countdown = 0
            end
            if castEvent.Countdown <= 0 then
                local nearbyPlayer = WaveCaster.getClosestPlayerInRange(castEvent)
                if nearbyPlayer then WaveCaster.processWave(castEvent) end
            end
            changed = true
        end
    end

    if changed then
        WaveCaster.Data = data
        ModData.transmit("WaveCaster_Data")
        sendServerCommand("WaveCaster", "Sync", { data = data })
    end
end
Events.EveryOneMinute.Add(WaveCaster.processEvents)

function WaveCaster.updateEvents(module, command, player, args)
    if module ~= "WaveCaster" then return end

    if command == "Spawn" then
        WaveCaster.spawn(player, args)
        return
    end

    if command == "Sync" and args.data then
        WaveCaster.Data = ModData.getOrCreate("WaveCaster_Data")

        for k in pairs(WaveCaster.Data) do
            WaveCaster.Data[k] = nil
        end

        for k, v in pairs(args.data) do
            WaveCaster.Data[k] = v
        end

        if WaveCaster.Data.events then
            for key, castEvent in pairs(WaveCaster.Data.events) do
                castEvent.Caster = player:getUsername()
            end
        end
        ModData.transmit("WaveCaster_Data")
        sendServerCommand("WaveCaster", "Sync", { data = WaveCaster.Data })
    end
end
Events.OnClientCommand.Add(WaveCaster.updateEvents)
