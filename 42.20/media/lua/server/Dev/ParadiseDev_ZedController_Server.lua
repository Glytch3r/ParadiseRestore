ParadiseDev = ParadiseDev or {}
ParadiseDev.ZedControllerServer = ParadiseDev.ZedControllerServer or {}

if isClient() then return end

local Server = ParadiseDev.ZedControllerServer
local previousOnClientCommand = Server.onClientCommand

Server.module = "ParadiseDevZedController"
Server.locks = Server.locks or {}
Server.lockHours = 0.01

local walkTypes = {
    slow1 = true, slow2 = true, slow3 = true,
    ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true,
    sprint1 = true, sprint2 = true, sprint3 = true, sprint4 = true, sprint5 = true,
}

local skins = {
    ["F_ZedBody01_level1"] = true, ["F_ZedBody01_level2"] = true, ["F_ZedBody01_level3"] = true, ["F_ZedBody01"] = true,
    ["F_ZedBody02_level1"] = true, ["F_ZedBody02_level2"] = true, ["F_ZedBody02_level3"] = true, ["F_ZedBody02"] = true,
    ["F_ZedBody03_level1"] = true, ["F_ZedBody03_level2"] = true, ["F_ZedBody03_level3"] = true, ["F_ZedBody03"] = true,
    ["F_ZedBody04_level1"] = true, ["F_ZedBody04_level2"] = true, ["F_ZedBody04_level3"] = true, ["F_ZedBody04"] = true,
    ["M_ZedBody01_level1"] = true, ["M_ZedBody01_level2"] = true, ["M_ZedBody01_level3"] = true, ["M_ZedBody01"] = true,
    ["M_ZedBody02_level1"] = true, ["M_ZedBody02_level2"] = true, ["M_ZedBody02_level3"] = true, ["M_ZedBody02"] = true,
    ["M_ZedBody03_level1"] = true, ["M_ZedBody03_level2"] = true, ["M_ZedBody03_level3"] = true, ["M_ZedBody03"] = true,
    ["M_ZedBody04_level1"] = true, ["M_ZedBody04_level2"] = true, ["M_ZedBody04_level3"] = true, ["M_ZedBody04"] = true,
    FemaleBody01 = true, FemaleBody02 = true, FemaleBody03 = true, FemaleBody04 = true, FemaleBody05 = true,
    MaleBody01 = true, MaleBody01a = true, MaleBody02 = true, MaleBody02a = true, MaleBody03 = true, MaleBody03a = true, MaleBody04 = true, MaleBody04a = true, MaleBody05 = true,
    Skeleton_Mannequin = true, Skeleton = true, SkeletonBurned = true, SkeletonMuscle = true, F_Mannequin_White = true, F_Mannequin_Black = true, M_Mannequin_Black = true, M_Mannequin_White = true, Male_Scarecrow = true,
}

local zedSkins = {
    "F_ZedBody01_level1", "F_ZedBody01_level2", "F_ZedBody01_level3", "F_ZedBody01", "F_ZedBody02_level1", "F_ZedBody02_level2", "F_ZedBody02_level3", "F_ZedBody02",
    "F_ZedBody03_level1", "F_ZedBody03_level2", "F_ZedBody03_level3", "F_ZedBody03", "F_ZedBody04_level1", "F_ZedBody04_level2", "F_ZedBody04_level3", "F_ZedBody04",
    "M_ZedBody01_level1", "M_ZedBody01_level2", "M_ZedBody01_level3", "M_ZedBody01", "M_ZedBody02_level1", "M_ZedBody02_level2", "M_ZedBody02_level3", "M_ZedBody02",
    "M_ZedBody03_level1", "M_ZedBody03_level2", "M_ZedBody03_level3", "M_ZedBody03", "M_ZedBody04_level1", "M_ZedBody04_level2", "M_ZedBody04_level3", "M_ZedBody04",
}

local humanSkins = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04", "FemaleBody05", "MaleBody01", "MaleBody01a", "MaleBody02", "MaleBody02a", "MaleBody03", "MaleBody03a", "MaleBody04", "MaleBody04a", "MaleBody05" }
local skeletonSkins = { "Skeleton_Mannequin", "Skeleton", "SkeletonBurned", "SkeletonMuscle", "F_Mannequin_White", "F_Mannequin_Black", "M_Mannequin_Black", "M_Mannequin_White", "Male_Scarecrow" }

local function call(obj, name, ...)
    if not obj then return nil end
    local fn = obj[name]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, obj, ...)
    if ok then return value end
    return nil
end

local function isInstance(obj, className)
    return obj ~= nil and instanceof ~= nil and instanceof(obj, className) == true
end

local function getListSize(list)
    return tonumber(call(list, "size")) or 0
end

local function getListItem(list, index)
    return call(list, "get", index)
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

local function worldCell()
    local world = getWorld and getWorld() or nil
    return call(world, "getCell") or (getCell and getCell() or nil)
end

function Server.reply(pl, text)
    if pl and sendServerCommand then sendServerCommand(pl, Server.module, "message", { text = tostring(text) }) end
end

function Server.isAdmin(pl)
    if not pl then return false end
    if ParadiseDev.isAdm then return ParadiseDev.isAdm(pl) == true end
    return string.lower(tostring(call(pl, "getAccessLevel") or "")) == "admin"
end

function Server.validRef(ref)
    if type(ref) ~= "table" then return false end
    if ref.kind ~= "zed" and ref.kind ~= "corpse" then return false end
    for _, key in ipairs({ "x", "y", "z" }) do
        local value = tonumber(ref[key])
        if not value or value ~= math.floor(value) or math.abs(value) > 500000 then return false end
    end
    return true
end

function Server.getSquare(ref)
    if not Server.validRef(ref) then return nil end
    return call(worldCell(), "getGridSquare", ref.x, ref.y, ref.z)
end

function Server.sameRef(obj, ref)
    if not obj or not ref then return false end
    local id = tonumber(ref.id)
    if id ~= nil and tonumber(call(obj, "getID")) == id then return true end
    local onlineId = tonumber(ref.onlineId)
    return onlineId ~= nil and tonumber(call(obj, "getOnlineID")) == onlineId
end

function Server.isValidZed(zed)
    return isInstance(zed, "IsoZombie") and call(zed, "isDead") ~= true and call(zed, "getSquare") ~= nil
end

function Server.isValidBody(body)
    return isInstance(body, "IsoDeadBody") and call(body, "getSquare") ~= nil
end

function Server.resolveSource(ref)
    local sq = Server.getSquare(ref)
    if not sq then return nil end
    if ref.kind == "zed" then
        local objects = call(sq, "getMovingObjects")
        for index = 0, getListSize(objects) - 1 do
            local zed = getListItem(objects, index)
            if Server.isValidZed(zed) and Server.sameRef(zed, ref) then return zed end
        end
        return nil
    end
    local bodies = call(sq, "getDeadBodys")
    for index = 0, getListSize(bodies) - 1 do
        local body = getListItem(bodies, index)
        if Server.isValidBody(body) and Server.sameRef(body, ref) then return body end
    end
    local body = call(sq, "getDeadBody")
    if Server.isValidBody(body) and Server.sameRef(body, ref) then return body end
    return nil
end

function Server.lockKey(ref)
    return tostring(ref.kind) .. ":" .. tostring(ref.id or ref.onlineId or (ref.x .. ":" .. ref.y .. ":" .. ref.z))
end

function Server.getNow()
    local gameTime = GameTime and GameTime.getInstance and GameTime.getInstance() or nil
    return tonumber(call(gameTime, "getWorldAgeHours")) or 0
end

function Server.claim(pl, ref)
    local user = tostring(call(pl, "getUsername") or call(pl, "getDisplayName") or "admin")
    local key = Server.lockKey(ref)
    local now = Server.getNow()
    for staleKey, staleLock in pairs(Server.locks) do
        if not staleLock or staleLock.untilHour <= now then Server.locks[staleKey] = nil end
    end
    local lock = Server.locks[key]
    if lock and lock.user ~= user and lock.untilHour > now then
        return false, "That zed is being controlled by " .. tostring(lock.user) .. "."
    end
    Server.locks[key] = { user = user, untilHour = now + Server.lockHours }
    return true
end

function Server.clearZedWork(zed)
    if not Server.isValidZed(zed) then return false end
    call(zed, "setTarget", nil)
    call(zed, "setThumpTarget", nil)
    call(zed, "setEatBodyTarget", nil, true)
    call(zed, "setBodyToEat", nil)
    call(zed, "setForceEatingAnimation", false)
    local path = call(zed, "getPathFindBehavior2")
    call(path, "cancel")
    call(zed, "setPathing", false)
    call(zed, "setPath2", nil)
    return true
end

function Server.pathTo(zed, x, y, z)
    if not Server.isValidZed(zed) then return false end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z or math.abs(x) > 500000 or math.abs(y) > 500000 or math.abs(z) > 32 then return false end
    Server.clearZedWork(zed)
    call(zed, "setTurnAlertedValues", math.floor(x), math.floor(y))
    local path = call(zed, "getPathFindBehavior2")
    if path and path.pathToLocationF then
        call(path, "pathToLocationF", x, y, z)
    else
        call(zed, "pathToLocationF", x, y, z)
    end
    return true
end

function Server.findCharacter(sq, ref, zed)
    local objects = call(sq, "getMovingObjects")
    for index = 0, getListSize(objects) - 1 do
        local obj = getListItem(objects, index)
        if obj ~= zed and (isInstance(obj, "IsoPlayer") or isInstance(obj, "IsoZombie")) and Server.sameRef(obj, ref) then return obj end
    end
    return nil
end

function Server.findBody(sq, ref)
    local bodies = call(sq, "getDeadBodys")
    for index = 0, getListSize(bodies) - 1 do
        local body = getListItem(bodies, index)
        if Server.isValidBody(body) and (not ref or Server.sameRef(body, ref)) then return body end
    end
    local body = call(sq, "getDeadBody")
    if Server.isValidBody(body) and (not ref or Server.sameRef(body, ref)) then return body end
    return nil
end

function Server.canOpenDoor(zed, door)
    if not zed or not door or tonumber(zed.cognition) ~= 1 then return false end
    local open = call(door, "isOpen")
    if open == nil then open = call(door, "IsOpen") end
    if open == true then return true end
    local couldOpen = call(door, "couldBeOpen", zed)
    if couldOpen == false then return false end
    return door.ToggleDoor ~= nil or door.ToggleDoorActual ~= nil
end

function Server.canTraverse(zed, target, targetKind)
    if targetKind == "window" then return call(target, "canClimbThrough", zed) == true end
    if targetKind == "hop" then return call(target, "canClimbOver", zed) == true end
    return false
end

function Server.isAdjacentTo(zed, target)
    local zedX, zedY, zedZ = call(zed, "getX"), call(zed, "getY"), call(zed, "getZ")
    local targetX, targetY, targetZ = call(target, "getX"), call(target, "getY"), call(target, "getZ")
    if zedX == nil or zedY == nil or zedZ == nil or targetX == nil or targetY == nil or targetZ == nil then return false end
    return math.abs(math.floor(zedX) - math.floor(targetX)) <= 1 and math.abs(math.floor(zedY) - math.floor(targetY)) <= 1 and math.floor(zedZ) == math.floor(targetZ)
end

function Server.applyTarget(zed, ref)
    if not Server.isValidZed(zed) then return false, "Selected zed no longer exists." end
    if type(ref) ~= "table" then
        Server.clearZedWork(zed)
        return true, "Target cleared."
    end
    if ref.kind == "empty" then
        Server.clearZedWork(zed)
        return true, "Target cleared."
    end
    if not Server.validRef({ kind = "zed", x = ref.x, y = ref.y, z = ref.z }) then return false, "Invalid target square." end
    local sq = call(worldCell(), "getGridSquare", ref.x, ref.y, ref.z)
    if not sq then return false, "Target square is not loaded." end
    Server.clearZedWork(zed)
    if ref.kind == "character" then
        local target = Server.findCharacter(sq, ref, zed)
        if not target then return false, "Target character no longer exists." end
        call(zed, "setTarget", target)
        call(zed, "pathToCharacter", target)
        return true, "Character target set."
    end
    if ref.kind == "corpse" then
        local body = Server.findBody(sq, ref)
        if not body then return false, "Target corpse no longer exists." end
        call(zed, "setEatBodyTarget", body, true)
        call(zed, "setBodyToEat", body)
        return true, "Corpse target set."
    end
    local target = nil
    if ref.kind == "door" then target = call(sq, "getDoor", false)
    elseif ref.kind == "window" then target = call(sq, "getWindow", false)
    elseif ref.kind == "hop" then target = call(sq, "getHoppable", false) or call(sq, "getHoppableThumpable", false)
    elseif ref.kind == "thump" then target = call(sq, "getThumpable", false) or call(sq, "getThumpableWall", false)
    end
    if not target then return false, "Target object no longer exists." end
    if ref.kind == "door" and Server.canOpenDoor(zed, target) then
        local open = call(target, "isOpen")
        if open == nil then open = call(target, "IsOpen") end
        if not open then
            if target.ToggleDoor then call(target, "ToggleDoor", zed) else call(target, "ToggleDoorActual", zed) end
        end
        Server.pathTo(zed, ref.x, ref.y, ref.z)
        return true, "Door opened and path set."
    end
    if ref.kind == "window" or ref.kind == "hop" then
        if Server.canTraverse(zed, target, ref.kind) then
            if ref.kind == "window" and Server.isAdjacentTo(zed, target) then
                call(zed, "climbThroughWindow", target)
                return true, "Window climb requested."
            end
            Server.pathTo(zed, ref.x, ref.y, ref.z)
            return true, "Traversal path set."
        end
    end
    call(zed, "setThumpTarget", target)
    return true, "Thump target set."
end

function Server.randomFrom(list)
    if not list or #list == 0 then return nil end
    return list[ZombRand(#list) + 1]
end

function Server.applySkin(zed, skin)
    skin = tostring(skin or "")
    if skin == "Random Zed" then skin = Server.randomFrom(zedSkins) end
    if skin == "Random Human" then skin = Server.randomFrom(humanSkins) end
    if skin == "Random Skeleton" then skin = Server.randomFrom(skeletonSkins) end
    if skin == "Random Any" then
        local all = {}
        for value in pairs(skins) do all[#all + 1] = value end
        skin = Server.randomFrom(all)
    end
    if not skins[skin] then return false, "Invalid skin." end
    local visual = call(zed, "getHumanVisual")
    if not visual then return false, "Zombie visual is unavailable." end
    local human = string.find(skin, "Body") ~= nil and string.find(skin, "Zed") == nil
    local skeleton = string.find(skin, "Skeleton") ~= nil or string.find(skin, "Mannequin") ~= nil
    if string.sub(skin, 1, 2) == "F_" or string.sub(skin, 1, 6) == "Female" then call(zed, "setFemaleEtc", true) end
    if string.sub(skin, 1, 2) == "M_" or string.sub(skin, 1, 4) == "Male" then call(zed, "setFemaleEtc", false) end
    if human then
        call(zed, "clearAttachedItems")
        call(call(visual, "getBodyVisuals"), "clear")
        call(visual, "removeBlood")
        call(visual, "removeDirt")
        call(zed, "setSkeleton", false)
    end
    if skeleton then call(zed, "setSkeleton", true) end
    call(visual, "setSkinTextureName", skin)
    call(zed, "resetModelNextFrame")
    call(zed, "resetModel")
    return true, "Skin updated."
end

local toggleSetters = {
    noDamage = function(zed, value) call(zed, "setNoDamage", value) end,
    useless = function(zed, value) call(zed, "setUseless", value) end,
    alwaysKnocked = function(zed, value) call(zed, "setAlwaysKnockedDown", value) end,
    onlyJawStab = function(zed, value) call(zed, "setOnlyJawStab", value) end,
    noTeeth = function(zed, value) call(zed, "setNoTeeth", value) end,
    forceEat = function(zed, value) call(zed, "setForceEatingAnimation", value) end,
    canWalk = function(zed, value) call(zed, "setCanWalk", value) end,
    canCrawlVehicle = function(zed, value) call(zed, "setCanCrawlUnderVehicle", value) end,
    crawler = function(zed, value) call(zed, "setCrawler", value) end,
    fakeDead = function(zed, value) call(zed, "setFakeDead", value) end,
    inactive = function(zed, value) call(zed, "makeInactive", value) end,
    sitAgainstWall = function(zed, value) call(zed, "setSitAgainstWall", value) end,
    knifeDeath = function(zed, value) call(zed, "setKnifeDeath", value) end,
    jawAttach = function(zed, value) call(zed, "setJawStabAttach", value) end,
    reanimate = function(zed, value) call(zed, "setReanimate", value) end,
    onFire = function(zed, value) if value then call(zed, "SetOnFire") else call(zed, "StopBurning") end end,
    skeleton = function(zed, value) call(zed, "setSkeleton", value) end,
    female = function(zed, value) call(zed, "setFemaleEtc", value) end,
}

local statRanges = {
    strength = { 1, 5 }, cognition = { 0, 1 }, memory = { 0, 5000 }, sight = { 1, 3 }, hearing = { 1, 3 }, voice = { 1, 3 },
}

function Server.sync(zed)
    if not zed then return end
    local ok, networkAI = pcall(function() return zed:getNetworkCharacterAI() end)
    if ok and networkAI then pcall(function() networkAI:extraUpdate() end) end
end

function Server.reanimate(body, minutes)
    minutes = tonumber(minutes) or 0
    if minutes <= 0 then
        call(body, "reanimateNow")
        return true, "Reanimation requested."
    end
    local gameTime = GameTime and GameTime.getInstance and GameTime.getInstance() or nil
    local now = tonumber(call(gameTime, "getWorldAgeHours"))
    if not now then return false, "World time is unavailable." end
    call(body, "setReanimateTime", now + clamp(minutes, 0.01, 1440) / 60)
    return true, "Timed reanimation requested."
end

function Server.execute(pl, obj, kind, command, args)
    if command == "teleport" then
        sendServerCommand(pl, "ParadiseDevTP", "teleport", { x = call(obj, "getX"), y = call(obj, "getY"), z = call(obj, "getZ") })
        return true, "Teleported to selection."
    end
    if command == "despawn" then
        if kind == "zed" then Server.clearZedWork(obj) end
        call(obj, "removeFromWorld")
        call(obj, "removeFromSquare")
        return true, "Selection despawned."
    end
    if kind == "corpse" then
        if command == "resurrect" then return Server.reanimate(obj, args.minutes) end
        return false, "That action requires a live zed."
    end
    if command == "kill" then
        local fake = call(worldCell(), "getFakeZombieForHit")
        if fake then call(obj, "setAttackedBy", fake) end
        call(obj, "setHealth", 0)
        Server.sync(obj)
        return true, "Kill requested."
    elseif command == "stop" then
        Server.clearZedWork(obj)
        Server.sync(obj)
        return true, "Zed stopped."
    elseif command == "goto" then
        local ok = Server.pathTo(obj, args.x, args.y, args.z)
        if ok then Server.sync(obj) end
        return ok, ok and "Goto path set." or "Invalid goto coordinates."
    elseif command == "target" then
        local ok, message = Server.applyTarget(obj, args.target)
        if ok then Server.sync(obj) end
        return ok, message
    elseif command == "setHealth" then
        call(obj, "setHealth", clamp(args.value, 0, 1000))
        Server.sync(obj)
        return true, "Health updated."
    elseif command == "setWalkType" then
        local value = tostring(args.value or "")
        if not walkTypes[value] then return false, "Invalid walk type." end
        call(obj, "setWalkType", value)
        call(obj, "setSpeedTypeFromWalkType")
        Server.sync(obj)
        return true, "Walk type updated."
    elseif command == "setTurnDelta" then
        call(obj, "setTurnDelta", clamp(args.value, 0.05, 10))
        Server.sync(obj)
        return true, "Turn delta updated."
    elseif command == "setStat" then
        local range = statRanges[args.key]
        if not range then return false, "Invalid stat." end
        local value = args.key == "voice" and tonumber(args.value) or clamp(args.value, range[1], range[2])
        if args.key == "voice" then
            value = value and clamp(value, range[1], range[2]) or ZombRand(range[1], range[2] + 1)
            local ok = pcall(function()
                local field = obj:getClass():getDeclaredField("voiceChoice")
                field:setAccessible(true)
                field:setInt(obj, value)
            end)
            if not ok then return false, "Voice cannot be changed on this build." end
        else
            obj[args.key] = value
        end
        Server.sync(obj)
        return true, "Stat updated."
    elseif command == "toggle" then
        local setter = toggleSetters[args.key]
        if not setter then return false, "Invalid toggle." end
        setter(obj, args.value == true)
        Server.sync(obj)
        return true, "Toggle updated."
    elseif command == "skin" then
        local ok, message = Server.applySkin(obj, args.skin)
        if ok then Server.sync(obj) end
        return ok, message
    elseif command == "randomOutfit" then
        call(obj, "dressInRandomOutfit")
        call(obj, "onWornItemsChanged")
        call(obj, "resetModelNextFrame")
        Server.sync(obj)
        return true, "Random outfit applied."
    elseif command == "namedOutfit" then
        local outfit = tostring(args.outfit or "")
        if outfit == "" or #outfit > 80 or not string.match(outfit, "^[%w_%- ]+$") then return false, "Invalid outfit." end
        call(obj, "dressInNamedOutfit", outfit)
        call(obj, "onWornItemsChanged")
        call(obj, "resetModelNextFrame")
        Server.sync(obj)
        return true, "Outfit applied."
    elseif command == "randomBlood" then
        call(obj, "addRandomBloodDirtHolesEtc")
        call(obj, "resetModelNextFrame")
        Server.sync(obj)
        return true, "Blood and dirt applied."
    end
    return false, "Unknown command."
end

function Server.onClientCommand(module, command, pl, args)
    if module ~= Server.module or not Server.isAdmin(pl) or type(args) ~= "table" then return end
    local allowed = {
        teleport = true, despawn = true, resurrect = true, kill = true, stop = true, ["goto"] = true, target = true,
        setHealth = true, setWalkType = true, setTurnDelta = true, setStat = true, toggle = true, skin = true,
        randomOutfit = true, namedOutfit = true, randomBlood = true,
    }
    if not allowed[command] then return end
    if not Server.validRef(args.source) then Server.reply(pl, "Invalid zed selection."); return end
    local claimed, reason = Server.claim(pl, args.source)
    if not claimed then Server.reply(pl, reason); return end
    local obj = Server.resolveSource(args.source)
    if not obj then Server.reply(pl, "Selected zed no longer exists."); return end
    local ok, message = Server.execute(pl, obj, args.source.kind, command, args)
    Server.reply(pl, message or (ok and "Zed control updated." or "Zed control failed."))
end

if previousOnClientCommand then Events.OnClientCommand.Remove(previousOnClientCommand) end
Events.OnClientCommand.Remove(Server.onClientCommand)
Events.OnClientCommand.Add(Server.onClientCommand)
