
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
            if copy then targetWorn:setItem(location, copy) end
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

function WaveCaster.applyZedData(zed, zd, pl, soundX, soundY)
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
    if zd.copyVisual then WaveCaster.copyPlayerVisuals(pl, zed) end
    if zd.walkTargetX ~= nil and zd.walkTargetY ~= nil and zd.walkTargetZ ~= nil then
        zed:setTurnAlertedValues(zd.walkTargetX, zd.walkTargetY)
        zed:setTarget(nil)
        zed:getPathFindBehavior2():pathToLocationF(zd.walkTargetX, zd.walkTargetY, zd.walkTargetZ)
    end
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
        local zeds = addZombiesInOutfit(x, y, args.z or 0, 1, zd.outfit, args.femaleChance, zd.crawler or false, zd.isFallOnFront or false, zd.isFakeDead or false, zd.knockedDown or false, zd.isInvulnerable or false, zd.isSitting or false, zd.health or 1, zd.isRecordingAnims or false, zd.heightOffset or 0, false, zd.onFire or false)
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
        local zeds = addZombiesInOutfit(spawnX, spawnY, z, 1, zd.outfit, zd.femaleChance, zd.crawler or false, zd.isFallOnFront or false, zd.isFakeDead or false, zd.knockedDown or false, zd.isInvulnerable or false, zd.isSitting or false, zd.health or 1, zd.isRecordingAnims or false, zd.heightOffset or 0, false, zd.onFire or false)
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
