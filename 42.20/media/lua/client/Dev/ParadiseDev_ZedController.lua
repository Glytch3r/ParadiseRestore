ParadiseDev = ParadiseDev or {}
ParadiseDev.ZedController = ParadiseDev.ZedController or {}

require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISLabel"
require "ISUI/ISComboBox"
require "ISUI/ISTextEntryBox"
require "RadioCom/ISUIRadio/ISSliderPanel"
require "ISUI/ISSelectCursor"

local ZedController = ParadiseDev.ZedController
local previousOnServerCommand = ZedController.onServerCommand
local previousOnResolutionChange = ZedController.onResolutionChange

ZedController.module = "ParadiseDevZedController"
ZedController.instance = ZedController.instance or nil
ZedController.selectedColor = { r = 0.2, g = 0.9, b = 1.0, a = 1.0 }
ZedController.targetColor = { r = 1.0, g = 0.75, b = 0.2, a = 1.0 }
ZedController.onColor = { r = 0.2, g = 0.9, b = 0.35, a = 1.0 }
ZedController.offColor = { r = 0.45, g = 0.45, b = 0.45, a = 0.85 }
ZedController.disabledColor = { r = 0.28, g = 0.28, b = 0.28, a = 0.55 }

ZedController.walkTypes = {
    { label = "Slow 1", value = "slow1" },
    { label = "Slow 2", value = "slow2" },
    { label = "Slow 3", value = "slow3" },
    { label = "Shambler 1", value = "1" },
    { label = "Shambler 2", value = "2" },
    { label = "Shambler 3", value = "3" },
    { label = "Shambler 4", value = "4" },
    { label = "Shambler 5", value = "5" },
    { label = "Sprinter 1", value = "sprint1" },
    { label = "Sprinter 2", value = "sprint2" },
    { label = "Sprinter 3", value = "sprint3" },
    { label = "Sprinter 4", value = "sprint4" },
    { label = "Sprinter 5", value = "sprint5" },
}

ZedController.statDefs = {
    { key = "strength", label = "Strength", options = { { "Weak", 1 }, { "Normal", 3 }, { "Superhuman", 5 } } },
    { key = "cognition", label = "Door Cognition", options = { { "Cannot Open", 0 }, { "Can Open", 1 } } },
    { key = "memory", label = "Memory", options = { { "None", 25 }, { "Short", 500 }, { "Normal", 800 }, { "Long", 1250 } } },
    { key = "sight", label = "Sight", options = { { "Eagle", 1 }, { "Normal", 2 }, { "Poor", 3 } } },
    { key = "hearing", label = "Hearing", options = { { "Pinpoint", 1 }, { "Normal", 2 }, { "Poor", 3 } } },
    { key = "voice", label = "Voice", options = { { "Random", nil }, { "Voice 1", 1 }, { "Voice 2", 2 }, { "Voice 3", 3 } } },
}

ZedController.skins = {
    "Random Zed", "Random Human", "Random Skeleton", "Random Any",
    "F_ZedBody01_level1", "F_ZedBody01_level2", "F_ZedBody01_level3", "F_ZedBody01",
    "F_ZedBody02_level1", "F_ZedBody02_level2", "F_ZedBody02_level3", "F_ZedBody02",
    "F_ZedBody03_level1", "F_ZedBody03_level2", "F_ZedBody03_level3", "F_ZedBody03",
    "F_ZedBody04_level1", "F_ZedBody04_level2", "F_ZedBody04_level3", "F_ZedBody04",
    "M_ZedBody01_level1", "M_ZedBody01_level2", "M_ZedBody01_level3", "M_ZedBody01",
    "M_ZedBody02_level1", "M_ZedBody02_level2", "M_ZedBody02_level3", "M_ZedBody02",
    "M_ZedBody03_level1", "M_ZedBody03_level2", "M_ZedBody03_level3", "M_ZedBody03",
    "M_ZedBody04_level1", "M_ZedBody04_level2", "M_ZedBody04_level3", "M_ZedBody04",
    "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04", "FemaleBody05",
    "MaleBody01", "MaleBody01a", "MaleBody02", "MaleBody02a", "MaleBody03", "MaleBody03a", "MaleBody04", "MaleBody04a", "MaleBody05",
    "Skeleton_Mannequin", "Skeleton", "SkeletonBurned", "SkeletonMuscle", "F_Mannequin_White", "F_Mannequin_Black", "M_Mannequin_Black", "M_Mannequin_White", "Male_Scarecrow",
}

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

local function getListItem(list, index)
    if not list then return nil end
    return call(list, "get", index)
end

local function getListSize(list)
    return tonumber(call(list, "size")) or 0
end

local function setVisible(ui, visible)
    if ui and ui.setVisible then ui:setVisible(visible == true) end
end

local function setEnabled(ui, enabled)
    if not ui then return end
    ui.enable = enabled == true
    if ui.setEnable then ui:setEnable(enabled == true) end
    if ui.setEnabled then ui:setEnabled(enabled == true) end
    if ui.javaObject and ui.setEditable then ui:setEditable(enabled == true) end
    if ui.isSlider then ui.disabled = enabled ~= true end
end

local function setLabel(label, text)
    if not label then return end
    if label.setNameWithoutMoving then
        label:setNameWithoutMoving(text)
    elseif label.setName then
        label:setName(text)
    end
end

function ZedController.clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then return low end
    if value > high then return high end
    return value
end

function ZedController.isValidZed(zed)
    if not isInstance(zed, "IsoZombie") then return false end
    if call(zed, "isDead") == true then return false end
    return call(zed, "getSquare") ~= nil
end

function ZedController.isValidBody(body)
    return isInstance(body, "IsoDeadBody") and call(body, "getSquare") ~= nil
end

function ZedController.getKind(obj)
    if ZedController.isValidZed(obj) then return "zed" end
    if ZedController.isValidBody(obj) then return "corpse" end
    return nil
end

function ZedController.selectionRef(obj, kind)
    if not obj then return nil end
    local sq = call(obj, "getSquare")
    local x = call(obj, "getX")
    local y = call(obj, "getY")
    local z = call(obj, "getZ")
    if sq then
        x = x or call(sq, "getX")
        y = y or call(sq, "getY")
        z = z or call(sq, "getZ")
    end
    if x == nil or y == nil or z == nil then return nil end
    return {
        id = call(obj, "getID"),
        onlineId = call(obj, "getOnlineID"),
        x = math.floor(tonumber(x) or 0),
        y = math.floor(tonumber(y) or 0),
        z = math.floor(tonumber(z) or 0),
        kind = kind or ZedController.getKind(obj),
    }
end

function ZedController.sameRef(obj, ref)
    if not obj or type(ref) ~= "table" then return false end
    local id = tonumber(ref.id)
    if id ~= nil and tonumber(call(obj, "getID")) == id then return true end
    local onlineId = tonumber(ref.onlineId)
    if onlineId ~= nil and tonumber(call(obj, "getOnlineID")) == onlineId then return true end
    return false
end

function ZedController.clearZedWork(zed)
    if not ZedController.isValidZed(zed) then return false end
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

function ZedController.hasZedWork(zed)
    if not ZedController.isValidZed(zed) then return false end
    if call(zed, "getTarget") or call(zed, "getThumpTarget") or call(zed, "getEatBodyTarget") or zed.bodyToEat ~= nil then return true end
    if call(zed, "isPathing") == true then return true end
    local path = call(zed, "getPathFindBehavior2")
    if path and call(path, "isGoalNone") == false then return true end
    return false
end

function ZedController.isAdmin(pl)
    if not pl then return false end
    if ParadiseDev.isAdm then return ParadiseDev.isAdm(pl) == true end
    return string.lower(tostring(call(pl, "getAccessLevel") or "")) == "admin"
end

function ZedController.setHighlight(obj, playerNum, active, color)
    if not obj then return end
    playerNum = tonumber(playerNum) or 0
    if obj.setOutlineHighlight then
        call(obj, "setOutlineHighlight", playerNum, active == true)
        if active and color then call(obj, "setOutlineHighlightCol", playerNum, color.r, color.g, color.b, color.a) end
    else
        call(obj, "setHighlighted", active == true)
    end
end

function ZedController.findMovingAtSquare(sq, predicate)
    local objects = call(sq, "getMovingObjects")
    for index = 0, getListSize(objects) - 1 do
        local obj = getListItem(objects, index)
        if obj and (not predicate or predicate(obj)) then return obj end
    end
    return nil
end

function ZedController.findBodyAtSquare(sq)
    local bodies = call(sq, "getDeadBodys")
    for index = 0, getListSize(bodies) - 1 do
        local body = getListItem(bodies, index)
        if ZedController.isValidBody(body) then return body end
    end
    local body = call(sq, "getDeadBody")
    if ZedController.isValidBody(body) then return body end
    return nil
end

function ZedController.findZedAtSquare(sq)
    return ZedController.findMovingAtSquare(sq, ZedController.isValidZed)
end

function ZedController.classifyTarget(zed, sq)
    if not sq then return "empty", nil end
    local chr = ZedController.findMovingAtSquare(sq, function(obj)
        return obj ~= zed and (isInstance(obj, "IsoPlayer") or isInstance(obj, "IsoZombie"))
    end)
    if chr then return "character", chr end
    local body = ZedController.findBodyAtSquare(sq)
    if body then return "corpse", body end
    local door = call(sq, "getDoor", false)
    if door then return "door", door end
    local window = call(sq, "getWindow", false)
    if window then return "window", window end
    local hoppable = call(sq, "getHoppable", false) or call(sq, "getHoppableThumpable", false)
    if hoppable then return "hop", hoppable end
    local thumpable = call(sq, "getThumpable", false) or call(sq, "getThumpableWall", false)
    if thumpable then return "thump", thumpable end
    return "empty", nil
end

function ZedController.canOpenDoor(zed, door)
    if not zed or not door then return false end
    if tonumber(zed.cognition) ~= 1 then return false end
    local open = call(door, "isOpen")
    if open == nil then open = call(door, "IsOpen") end
    if open == true then return true end
    local couldOpen = call(door, "couldBeOpen", zed)
    if couldOpen == false then return false end
    return door.ToggleDoor ~= nil or door.ToggleDoorActual ~= nil
end

function ZedController.canTraverse(zed, target, targetKind)
    if targetKind == "window" then return call(target, "canClimbThrough", zed) == true end
    if targetKind == "hop" then return call(target, "canClimbOver", zed) == true end
    return false
end

function ZedController.isAdjacentTo(zed, target)
    local zedX, zedY, zedZ = call(zed, "getX"), call(zed, "getY"), call(zed, "getZ")
    local targetX, targetY, targetZ = call(target, "getX"), call(target, "getY"), call(target, "getZ")
    if zedX == nil or zedY == nil or zedZ == nil or targetX == nil or targetY == nil or targetZ == nil then return false end
    return math.abs(math.floor(zedX) - math.floor(targetX)) <= 1 and math.abs(math.floor(zedY) - math.floor(targetY)) <= 1 and math.floor(zedZ) == math.floor(targetZ)
end

function ZedController.pathTo(zed, x, y, z)
    if not ZedController.isValidZed(zed) then return false end
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return false end
    ZedController.clearZedWork(zed)
    call(zed, "setTurnAlertedValues", math.floor(x), math.floor(y))
    local path = call(zed, "getPathFindBehavior2")
    if path and path.pathToLocationF then
        call(path, "pathToLocationF", x, y, z)
    else
        call(zed, "pathToLocationF", x, y, z)
    end
    return true
end

function ZedController.applyTarget(zed, sq)
    if not ZedController.isValidZed(zed) then return false, "No live zed selected." end
    local targetKind, target = ZedController.classifyTarget(zed, sq)
    ZedController.clearZedWork(zed)
    if targetKind == "empty" then return true, "Target cleared." end
    if targetKind == "character" then
        call(zed, "setTarget", target)
        call(zed, "pathToCharacter", target)
        return true, "Character target set."
    end
    if targetKind == "corpse" then
        call(zed, "setEatBodyTarget", target, true)
        call(zed, "setBodyToEat", target)
        return true, "Corpse target set."
    end
    local x, y, z = call(sq, "getX"), call(sq, "getY"), call(sq, "getZ")
    if targetKind == "door" and ZedController.canOpenDoor(zed, target) then
        local open = call(target, "isOpen")
        if open == nil then open = call(target, "IsOpen") end
        if not open then
            if target.ToggleDoor then call(target, "ToggleDoor", zed) else call(target, "ToggleDoorActual", zed) end
        end
        ZedController.pathTo(zed, x, y, z)
        return true, "Door opened and path set."
    end
    if targetKind == "window" or targetKind == "hop" then
        if ZedController.canTraverse(zed, target, targetKind) then
            if targetKind == "window" and ZedController.isAdjacentTo(zed, target) then
                call(zed, "climbThroughWindow", target)
                return true, "Window climb requested."
            end
            ZedController.pathTo(zed, x, y, z)
            return true, "Traversal path set."
        end
    end
    call(zed, "setThumpTarget", target)
    return true, "Thump target set."
end

function ZedController.randomSkin(list)
    if not list or #list == 0 then return nil end
    if ZombRand then return list[ZombRand(#list) + 1] end
    return list[math.random(#list)]
end

function ZedController.applySkin(zed, skin)
    if not ZedController.isValidZed(zed) then return false end
    skin = tostring(skin or "Random Zed")
    local zedSkins, humanSkins, skeletonSkins = {}, {}, {}
    for _, value in ipairs(ZedController.skins) do
        if string.find(value, "ZedBody") then zedSkins[#zedSkins + 1] = value
        elseif string.find(value, "Body") then humanSkins[#humanSkins + 1] = value
        elseif string.find(value, "Skeleton") or string.find(value, "Mannequin") or value == "Male_Scarecrow" then skeletonSkins[#skeletonSkins + 1] = value end
    end
    if skin == "Random Zed" then skin = ZedController.randomSkin(zedSkins) end
    if skin == "Random Human" then skin = ZedController.randomSkin(humanSkins) end
    if skin == "Random Skeleton" then skin = ZedController.randomSkin(skeletonSkins) end
    if skin == "Random Any" then skin = ZedController.randomSkin(ZedController.skins) end
    if not skin or string.find(skin, "Random") then return false end
    local visual = call(zed, "getHumanVisual")
    if not visual then return false end
    local human = string.find(skin, "Body") ~= nil and string.find(skin, "Zed") == nil
    local skeleton = string.find(skin, "Skeleton") ~= nil or string.find(skin, "Mannequin") ~= nil
    if string.sub(skin, 1, 2) == "F_" or string.sub(skin, 1, 6) == "Female" then call(zed, "setFemaleEtc", true) end
    if string.sub(skin, 1, 2) == "M_" or string.sub(skin, 1, 4) == "Male" then call(zed, "setFemaleEtc", false) end
    if human then
        call(zed, "clearAttachedItems")
        local bodyVisuals = call(visual, "getBodyVisuals")
        call(bodyVisuals, "clear")
        call(visual, "removeBlood")
        call(visual, "removeDirt")
        call(zed, "setSkeleton", false)
    end
    if skeleton then call(zed, "setSkeleton", true) end
    call(visual, "setSkinTextureName", skin)
    call(zed, "resetModelNextFrame")
    call(zed, "resetModel")
    return true
end

ZedController.toggleDefs = {
    { key = "noDamage", label = "No Damage", page = "state", get = function(zed) return call(zed, "getNoDamage") == true end, set = function(zed, value) call(zed, "setNoDamage", value) end },
    { key = "useless", label = "Useless", page = "state", get = function(zed) return call(zed, "isUseless") == true end, set = function(zed, value) call(zed, "setUseless", value) end },
    { key = "alwaysKnocked", label = "Always Knocked", page = "state", get = function(zed) return call(zed, "isAlwaysKnockedDown") == true end, set = function(zed, value) call(zed, "setAlwaysKnockedDown", value) end },
    { key = "onlyJawStab", label = "Only Jaw Stab", page = "state", get = function(zed) return call(zed, "isOnlyJawStab") == true end, set = function(zed, value) call(zed, "setOnlyJawStab", value) end },
    { key = "noTeeth", label = "No Teeth", page = "state", get = function(zed) return call(zed, "isNoTeeth") == true end, set = function(zed, value) call(zed, "setNoTeeth", value) end },
    { key = "forceEat", label = "Force Eating", page = "state", get = function(zed) return call(zed, "isForceEatingAnimation") == true end, set = function(zed, value) call(zed, "setForceEatingAnimation", value) end },
    { key = "canWalk", label = "Can Walk", page = "state", get = function(zed) return call(zed, "isCanWalk") == true end, set = function(zed, value) call(zed, "setCanWalk", value) end },
    { key = "canCrawlVehicle", label = "Crawl Vehicles", page = "state", get = function(zed) return call(zed, "isCanCrawlUnderVehicle") == true end, set = function(zed, value) call(zed, "setCanCrawlUnderVehicle", value) end },
    { key = "crawler", label = "Crawler", page = "state", get = function(zed) return call(zed, "isCrawling") == true end, set = function(zed, value) call(zed, "setCrawler", value) end },
    { key = "fakeDead", label = "Fake Dead", page = "state", get = function(zed) return call(zed, "isFakeDead") == true end, set = function(zed, value) call(zed, "setFakeDead", value) end },
    { key = "inactive", label = "Inactive", page = "state", get = function(zed) return zed.inactive == true end, set = function(zed, value) call(zed, "makeInactive", value) end },
    { key = "sitAgainstWall", label = "Sit Wall", page = "state", get = function(zed) return call(zed, "isSitAgainstWall") == true end, set = function(zed, value) call(zed, "setSitAgainstWall", value) end },
    { key = "knifeDeath", label = "Knife Death", page = "state", get = function(zed) return call(zed, "isKnifeDeath") == true end, set = function(zed, value) call(zed, "setKnifeDeath", value) end },
    { key = "jawAttach", label = "Jaw Attach", page = "state", get = function(zed) return call(zed, "isJawStabAttach") == true end, set = function(zed, value) call(zed, "setJawStabAttach", value) end },
    { key = "reanimate", label = "Reanimate", page = "state", get = function(zed) return call(zed, "isReanimate") == true end, set = function(zed, value) call(zed, "setReanimate", value) end },
    { key = "onFire", label = "On Fire", page = "appearance", get = function(zed) return call(zed, "isOnFire") == true end, set = function(zed, value) if value then call(zed, "SetOnFire") else call(zed, "StopBurning") end end },
    { key = "skeleton", label = "Skeleton", page = "appearance", get = function(zed) return call(zed, "isSkeleton") == true end, set = function(zed, value) call(zed, "setSkeleton", value) end },
    { key = "female", label = "Female", page = "appearance", get = function(zed) return call(zed, "isFemale") == true end, set = function(zed, value) call(zed, "setFemaleEtc", value) end },
}

function ZedController.getToggleDef(key)
    for _, def in ipairs(ZedController.toggleDefs) do
        if def.key == key then return def end
    end
    return nil
end

function ZedController.getWalkType(value)
    for _, def in ipairs(ZedController.walkTypes) do
        if def.value == value then return def end
    end
    return nil
end

function ZedController.findLocal(ref)
    if type(ref) ~= "table" or not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end
    local sq = call(cell, "getGridSquare", tonumber(ref.x), tonumber(ref.y), tonumber(ref.z))
    if not sq then return nil end
    if ref.kind == "corpse" then
        local bodies = call(sq, "getDeadBodys")
        for index = 0, getListSize(bodies) - 1 do
            local body = getListItem(bodies, index)
            if ZedController.isValidBody(body) and ZedController.sameRef(body, ref) then return body end
        end
        local body = ZedController.findBodyAtSquare(sq)
        if body and ZedController.sameRef(body, ref) then return body end
        return nil
    end
    local objects = call(sq, "getMovingObjects")
    for index = 0, getListSize(objects) - 1 do
        local zed = getListItem(objects, index)
        if ZedController.isValidZed(zed) and ZedController.sameRef(zed, ref) then return zed end
    end
    return nil
end

function ZedController.teleportLocal(pl, obj)
    if not pl or not obj then return false end
    local x, y, z = call(obj, "getX"), call(obj, "getY"), call(obj, "getZ")
    if not x or not y or not z then return false end
    if ParadiseDev.TP and ParadiseDev.TP.doRegularTp then return ParadiseDev.TP.doRegularTp(pl, x, y, z) end
    if pl.teleportTo then call(pl, "teleportTo", x, y, z); return true end
    return false
end

function ZedController.reanimate(body, minutes)
    if not ZedController.isValidBody(body) then return false end
    minutes = tonumber(minutes) or 0
    if minutes <= 0 then
        call(body, "reanimateNow")
        return true
    end
    local gameTime = GameTime and GameTime.getInstance and GameTime.getInstance() or nil
    local now = call(gameTime, "getWorldAgeHours")
    if now == nil then return false end
    call(body, "setReanimateTime", now + ZedController.clamp(minutes, 0.01, 1440) / 60)
    return true
end

function ZedController.executeLocal(pl, command, args)
    args = args or {}
    local obj = args.localSource or ZedController.findLocal(args.source)
    local kind = ZedController.getKind(obj)
    if not kind then return false, "Selected zed no longer exists." end
    if command == "teleport" then return ZedController.teleportLocal(pl, obj), "Teleported to selection." end
    if command == "despawn" then
        ZedController.clearZedWork(obj)
        call(obj, "removeFromWorld")
        call(obj, "removeFromSquare")
        return true, "Selection despawned."
    end
    if kind == "corpse" then
        if command == "resurrect" then return ZedController.reanimate(obj, args.minutes), "Reanimation requested." end
        return false, "That action requires a live zed."
    end
    if command == "kill" then
        local cell = getCell and getCell() or nil
        local fake = call(cell, "getFakeZombieForHit")
        if fake then call(obj, "setAttackedBy", fake) end
        call(obj, "setHealth", 0)
        return true, "Kill requested."
    elseif command == "stop" then
        return ZedController.clearZedWork(obj), "Zed stopped."
    elseif command == "goto" then
        return ZedController.pathTo(obj, args.x, args.y, args.z), "Goto path set."
    elseif command == "target" then
        return ZedController.applyTarget(obj, args.localSquare), "Target updated."
    elseif command == "setHealth" then
        call(obj, "setHealth", ZedController.clamp(args.value, 0, 1000))
        return true, "Health updated."
    elseif command == "setWalkType" then
        local walk = ZedController.getWalkType(args.value)
        if not walk then return false, "Invalid walk type." end
        call(obj, "setWalkType", walk.value)
        call(obj, "setSpeedTypeFromWalkType")
        return true, "Walk type updated."
    elseif command == "setTurnDelta" then
        call(obj, "setTurnDelta", ZedController.clamp(args.value, 0.05, 10))
        return true, "Turn delta updated."
    elseif command == "setStat" then
        local stat = nil
        for _, def in ipairs(ZedController.statDefs) do if def.key == args.key then stat = def; break end end
        if not stat then return false, "Invalid stat." end
        if args.key == "voice" then return false, "Voice is server-controlled in multiplayer." end
        obj[args.key] = tonumber(args.value)
        return true, "Stat updated."
    elseif command == "toggle" then
        local def = ZedController.getToggleDef(args.key)
        if not def then return false, "Invalid toggle." end
        def.set(obj, args.value == true)
        return true, "Toggle updated."
    elseif command == "skin" then
        return ZedController.applySkin(obj, args.skin), "Skin updated."
    elseif command == "randomOutfit" then
        call(obj, "dressInRandomOutfit")
        call(obj, "onWornItemsChanged")
        call(obj, "resetModelNextFrame")
        return true, "Random outfit applied."
    elseif command == "namedOutfit" then
        local outfit = tostring(args.outfit or "")
        if outfit == "" or #outfit > 80 then return false, "Invalid outfit." end
        call(obj, "dressInNamedOutfit", outfit)
        call(obj, "onWornItemsChanged")
        call(obj, "resetModelNextFrame")
        return true, "Outfit applied."
    elseif command == "randomBlood" then
        call(obj, "addRandomBloodDirtHolesEtc")
        call(obj, "resetModelNextFrame")
        return true, "Blood and dirt applied."
    end
    return false, "Unknown command."
end

function ZedController.request(pl, command, args)
    args = args or {}
    if isClient and isClient() then
        args.localSource = nil
        args.localSquare = nil
        sendClientCommand(ZedController.module, command, args)
        return true
    end
    return ZedController.executeLocal(pl, command, args)
end

ZedController.Panel = ISCollapsableWindow:derive("ParadiseDev.ZedController.Panel")

function ZedController.Panel:addContentChild(ui)
    if self.contentPanel then
        self.contentPanel:addChild(ui)
    else
        self:addChild(ui)
    end
end

function ZedController.Panel:addLabel(name, text, font)
    local label = ISLabel:new(0, 0, 18, text, 0.9, 0.9, 0.9, 1, font or UIFont.Small, true)
    label:initialise()
    label:instantiate()
    self:addContentChild(label)
    self[name] = label
    return label
end

function ZedController.Panel:addButton(name, text, callback)
    local btn = ISButton:new(0, 0, 120, 22, text, self, callback)
    btn:initialise()
    btn:instantiate()
    self:addContentChild(btn)
    self[name] = btn
    return btn
end

function ZedController.Panel:addEntry(name, text)
    local entry = ISTextEntryBox:new(text or "", 0, 0, 100, 22)
    entry:initialise()
    entry:instantiate()
    self:addContentChild(entry)
    self[name] = entry
    return entry
end

function ZedController.Panel:addCombo(name)
    local combo = ISComboBox:new(0, 0, 120, 22)
    combo:initialise()
    combo:instantiate()
    self:addContentChild(combo)
    self[name] = combo
    return combo
end

function ZedController.Panel:addToggle(def)
    local btn = self:addButton("toggle_" .. def.key, def.label .. ": OFF", ZedController.Panel.onToggle)
    btn.toggleKey = def.key
    btn.tooltip = def.label
    self.toggleButtons[#self.toggleButtons + 1] = { def = def, button = btn }
    return btn
end

function ZedController.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)
    self.contentPanel = ISPanel:new(0, self:titleBarHeight(), self.width, self.height - self:titleBarHeight())
    self.contentPanel:initialise()
    self.contentPanel:instantiate()
    self.contentPanel:noBackground()
    self.contentPanel:addScrollBars()
    self.contentPanel:setScrollChildren(true)
    self.contentPanel.doStencilRender = true
    self.contentPanel.onMouseWheel = function(panel, delta)
        panel:setYScroll(panel:getYScroll() - delta * 32)
        return true
    end
    self.contentPanel.prerender = function(panel)
        panel:setStencilRect(0, 0, panel:getWidth(), panel:getHeight())
        ISPanel.prerender(panel)
    end
    self.contentPanel.render = function(panel)
        ISPanel.render(panel)
        panel:clearStencilRect()
    end
    self:addChild(self.contentPanel)
    self.toggleButtons = {}
    self.pageWidgets = { stats = {}, state = {}, appearance = {} }
    self:addLabel("selectionLabel", "Selected: nil", UIFont.Medium)
    self:addLabel("coordsLabel", "X: nil   Y: nil   Z: nil", UIFont.Small)
    self:addLabel("noticeLabel", "Select a zed or corpse to begin.", UIFont.Small)
    self:addLabel("leftHeadLabel", "Property", UIFont.Small)
    self:addLabel("valueHeadLabel", "Live value", UIFont.Small)
    self:addLabel("controlHeadLabel", "Control", UIFont.Small)
    self:addLabel("actionHeadLabel", "Actions", UIFont.Small)
    for _, page in ipairs({ { "stats", "Stats" }, { "state", "State" }, { "appearance", "Appearance" } }) do
        local btn = self:addButton("page_" .. page[1], page[2], ZedController.Panel.onPage)
        btn.pageName = page[1]
    end
    self:addLabel("healthName", "Health")
    self:addLabel("healthValue", "nil")
    self.healthSlider = ISSliderPanel:new(0, 0, 100, 20, self, ZedController.Panel.onHealthSlider)
    self.healthSlider:initialise()
    self.healthSlider:instantiate()
    self.healthSlider:setValues(0, 100, 1, 10)
    self.healthSlider:setCurrentValue(1, true)
    self:addContentChild(self.healthSlider)
    self:addEntry("healthEntry", "1")
    self:addButton("healthApply", "Apply", ZedController.Panel.onHealthApply)
    self:addLabel("walkName", "Walk Type")
    self:addLabel("walkValue", "nil")
    self:addCombo("walkType")
    for _, def in ipairs(ZedController.walkTypes) do self.walkType:addOptionWithData(def.label, def.value) end
    self:addButton("walkApply", "Apply", ZedController.Panel.onWalkApply)
    self:addLabel("turnName", "Turn Delta")
    self:addLabel("turnValue", "nil")
    self:addEntry("turnEntry", "1")
    self:addButton("turnApply", "Apply", ZedController.Panel.onTurnApply)
    self.statsRows = {}
    for _, def in ipairs(ZedController.statDefs) do
        local row = { def = def }
        row.name = self:addLabel("statName_" .. def.key, def.label)
        row.value = self:addLabel("statValue_" .. def.key, "nil")
        row.combo = self:addCombo("statCombo_" .. def.key)
        for _, option in ipairs(def.options) do row.combo:addOptionWithData(option[1], option[2]) end
        row.apply = self:addButton("statApply_" .. def.key, "Apply", ZedController.Panel.onStatApply)
        row.apply.statKey = def.key
        self.statsRows[#self.statsRows + 1] = row
    end
    self.pageWidgets.stats = {
        self.healthName, self.healthValue, self.healthSlider, self.healthEntry, self.healthApply,
        self.walkName, self.walkValue, self.walkType, self.walkApply,
        self.turnName, self.turnValue, self.turnEntry, self.turnApply,
    }
    for _, row in ipairs(self.statsRows) do
        self.pageWidgets.stats[#self.pageWidgets.stats + 1] = row.name
        self.pageWidgets.stats[#self.pageWidgets.stats + 1] = row.value
        self.pageWidgets.stats[#self.pageWidgets.stats + 1] = row.combo
        self.pageWidgets.stats[#self.pageWidgets.stats + 1] = row.apply
    end
    for _, def in ipairs(ZedController.toggleDefs) do
        local btn = self:addToggle(def)
        self.pageWidgets[def.page][#self.pageWidgets[def.page] + 1] = btn
    end
    self:addLabel("skinName", "Skin Texture")
    self:addLabel("skinValue", "nil")
    self:addCombo("skinCombo")
    for _, skin in ipairs(ZedController.skins) do self.skinCombo:addOptionWithData(skin, skin) end
    self:addButton("skinApply", "Apply", ZedController.Panel.onSkinApply)
    self:addLabel("outfitName", "Named Outfit")
    self:addLabel("outfitValue", "nil")
    self:addEntry("outfitEntry", "")
    self:addButton("outfitApply", "Apply", ZedController.Panel.onOutfitApply)
    self:addButton("randomOutfit", "Random Outfit", ZedController.Panel.onRandomOutfit)
    self:addButton("randomBlood", "Random Blood/Dirt", ZedController.Panel.onRandomBlood)
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.skinName
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.skinValue
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.skinCombo
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.skinApply
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.outfitName
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.outfitValue
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.outfitEntry
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.outfitApply
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.randomOutfit
    self.pageWidgets.appearance[#self.pageWidgets.appearance + 1] = self.randomBlood
    self:addLabel("targetLabel", "Target: nil")
    self:addLabel("ownerLabel", "Network owner: nil")
    self:addButton("selectZed", "Select Zed", ZedController.Panel.onSelectZed)
    self:addButton("selectTarget", "Select Target", ZedController.Panel.onSelectTarget)
    self:addButton("gotoButton", "Goto", ZedController.Panel.onGoto)
    self:addButton("teleportButton", "Teleport To", ZedController.Panel.onTeleport)
    self:addButton("comeHere", "Come Here", ZedController.Panel.onComeHere)
    self:addButton("killButton", "Kill", ZedController.Panel.onKill)
    self:addButton("despawnButton", "Despawn", ZedController.Panel.onDespawn)
    self:addEntry("reanimateEntry", "0")
    self:addButton("reanimateButton", "Resurrect Now", ZedController.Panel.onReanimate)
    self:addLabel("reanimateHelp", "Delay minutes: 0 = instant")
    self:layoutChildren()
    self:refreshLive(true)
end

function ZedController.Panel:layoutWindowChrome()
    local rh = self:resizeWidgetHeight()
    local buttonHeight = self:titleBarHeight() - 2
    local rightX = self.width - 1 - buttonHeight
    if self.pinButton then self.pinButton:setX(rightX) end
    if self.collapseButton then self.collapseButton:setX(rightX) end
    if self.resizeWidget then self.resizeWidget:setX(self.width - rh); self.resizeWidget:setY(self.height - rh) end
    if self.resizeWidget2 then self.resizeWidget2:setY(self.height - rh); self.resizeWidget2:setWidth(self.width - rh) end
end

function ZedController.Panel.resizeWindow(panel, width, height)
    if not panel then return end
    local core = getCore()
    local maxW = math.max(120, core:getScreenWidth() - 16)
    local maxH = math.max(120, core:getScreenHeight() - 16)
    local minW = math.min(panel.minimumWidth or 120, maxW)
    local minH = math.min(panel.minimumHeight or 120, maxH)
    panel:setWidth(ZedController.clamp(width, minW, maxW))
    panel:setHeight(ZedController.clamp(height, minH, maxH))
    panel:layoutWindowChrome()
    panel:layoutChildren()
end

function ZedController.Panel:layoutChildren()
    local gap = 8
    local rowH = math.max(20, getTextManager():getFontHeight(UIFont.Small) + 6)
    local titleH = self:titleBarHeight()
    local resizeH = self:resizeWidgetHeight()
    local viewH = math.max(rowH * 4, self.height - titleH - resizeH)
    if self.contentPanel then
        self.contentPanel:setX(0)
        self.contentPanel:setY(titleH)
        self.contentPanel:setWidth(self.width)
        self.contentPanel:setHeight(viewH)
    end
    local scrollW = self.contentPanel and self.contentPanel.vscroll and math.max(13, self.contentPanel.vscroll:getWidth()) or 13
    local top = gap
    local width = math.max(120, self.width - gap * 2 - scrollW)
    local compact = width < 600
    local actionW = compact and width or math.max(165, math.min(255, math.floor(width * 0.3)))
    local leftW = compact and width or width - actionW - gap
    local labelW = math.max(48, math.floor(leftW * 0.26))
    local valueW = math.max(50, math.floor(leftW * 0.24))
    local controlW = leftW - labelW - valueW - gap
    if controlW < 52 then
        local short = 52 - controlW
        local reduce = math.min(short, math.max(0, labelW - 42))
        labelW = labelW - reduce
        short = short - reduce
        reduce = math.min(short, math.max(0, valueW - 42))
        valueW = valueW - reduce
        controlW = leftW - labelW - valueW - gap
    end
    controlW = math.max(52, controlW)
    local controlX = gap + labelW + valueW + gap
    local actionX = gap + leftW + gap
    if compact then actionX = gap end
    local applyW = math.min(52, math.max(36, math.floor(controlW * 0.38)))
    local fieldW = math.max(20, controlW - applyW - 4)
    self:layoutWindowChrome()
    self.selectionLabel:setX(gap); self.selectionLabel:setY(top)
    if compact then
        self.coordsLabel:setX(gap); self.coordsLabel:setY(top + rowH)
        self.noticeLabel:setX(gap); self.noticeLabel:setY(top + rowH * 2 + 2); self.noticeLabel:setWidth(width)
    else
        self.coordsLabel:setX(gap + math.floor(leftW * 0.43)); self.coordsLabel:setY(top + 3)
        self.noticeLabel:setX(actionX); self.noticeLabel:setY(top + 3); self.noticeLabel:setWidth(actionW)
    end
    local tabsY = top + (compact and rowH * 3 or rowH) + 4
    local tabGap = compact and 4 or gap
    local tabW = math.max(1, math.floor((leftW - tabGap * 2) / 3))
    for index, page in ipairs({ "stats", "state", "appearance" }) do
        local btn = self["page_" .. page]
        btn:setX(gap + (index - 1) * (tabW + tabGap)); btn:setY(tabsY); btn:setWidth(tabW); btn:setHeight(rowH)
    end
    local contentY = tabsY + rowH + gap + 2
    self.leftHeadLabel:setX(gap); self.leftHeadLabel:setY(contentY)
    self.valueHeadLabel:setX(gap + labelW); self.valueHeadLabel:setY(contentY)
    self.controlHeadLabel:setX(controlX); self.controlHeadLabel:setY(contentY)
    if not compact then self.actionHeadLabel:setX(actionX); self.actionHeadLabel:setY(contentY) end
    local y = contentY + rowH + 3
    local function row(name, value, control, apply)
        if name then name:setX(gap); name:setY(y + 3); name:setWidth(labelW - 2) end
        if value then value:setX(gap + labelW); value:setY(y + 3); value:setWidth(valueW - 2) end
        if control then control:setX(controlX); control:setY(y); control:setWidth(apply and fieldW or controlW); control:setHeight(rowH) end
        if apply then apply:setX(controlX + controlW - applyW); apply:setY(y); apply:setWidth(applyW); apply:setHeight(rowH) end
        y = y + rowH + 4
    end
    row(self.healthName, self.healthValue, self.healthSlider, nil)
    self.healthEntry:setX(controlX); self.healthEntry:setY(y); self.healthEntry:setWidth(fieldW); self.healthEntry:setHeight(rowH)
    self.healthApply:setX(controlX + controlW - applyW); self.healthApply:setY(y); self.healthApply:setWidth(applyW); self.healthApply:setHeight(rowH)
    y = y + rowH + 4
    row(self.walkName, self.walkValue, self.walkType, self.walkApply)
    row(self.turnName, self.turnValue, self.turnEntry, self.turnApply)
    for _, stat in ipairs(self.statsRows) do row(stat.name, stat.value, stat.combo, stat.apply) end
    local statsBottom = y
    local toggleY = contentY + rowH + 3
    local toggleW = math.floor((leftW - gap) / 2)
    local stateIndex, appearanceIndex = 0, 0
    for _, item in ipairs(self.toggleButtons) do
        local index = item.def.page == "state" and stateIndex or appearanceIndex
        local col = index % 2
        local line = math.floor(index / 2)
        item.button:setX(gap + col * (toggleW + gap))
        item.button:setY(toggleY + line * (rowH + 4))
        item.button:setWidth(toggleW)
        item.button:setHeight(rowH)
        if item.def.page == "state" then stateIndex = stateIndex + 1 else appearanceIndex = appearanceIndex + 1 end
    end
    local stateBottom = toggleY + math.ceil(stateIndex / 2) * (rowH + 4)
    local appearanceY = toggleY + math.ceil(appearanceIndex / 2) * (rowH + 4) + 2
    self.skinName:setX(gap); self.skinName:setY(appearanceY + 3); self.skinName:setWidth(labelW - 2)
    self.skinValue:setX(gap + labelW); self.skinValue:setY(appearanceY + 3); self.skinValue:setWidth(valueW - 2)
    self.skinCombo:setX(controlX); self.skinCombo:setY(appearanceY); self.skinCombo:setWidth(fieldW); self.skinCombo:setHeight(rowH)
    self.skinApply:setX(controlX + controlW - applyW); self.skinApply:setY(appearanceY); self.skinApply:setWidth(applyW); self.skinApply:setHeight(rowH)
    appearanceY = appearanceY + rowH + 4
    self.outfitName:setX(gap); self.outfitName:setY(appearanceY + 3); self.outfitName:setWidth(labelW - 2)
    self.outfitValue:setX(gap + labelW); self.outfitValue:setY(appearanceY + 3); self.outfitValue:setWidth(valueW - 2)
    self.outfitEntry:setX(controlX); self.outfitEntry:setY(appearanceY); self.outfitEntry:setWidth(fieldW); self.outfitEntry:setHeight(rowH)
    self.outfitApply:setX(controlX + controlW - applyW); self.outfitApply:setY(appearanceY); self.outfitApply:setWidth(applyW); self.outfitApply:setHeight(rowH)
    appearanceY = appearanceY + rowH + 4
    local halfControlW = math.max(20, math.floor((controlW - gap) / 2))
    self.randomOutfit:setX(controlX); self.randomOutfit:setY(appearanceY); self.randomOutfit:setWidth(halfControlW); self.randomOutfit:setHeight(rowH)
    self.randomBlood:setX(controlX + halfControlW + gap); self.randomBlood:setY(appearanceY); self.randomBlood:setWidth(halfControlW); self.randomBlood:setHeight(rowH)
    local appearanceBottom = appearanceY + rowH + 4
    local pageBottom = self.page == "stats" and statsBottom or (self.page == "state" and stateBottom or appearanceBottom)
    local actionY = compact and pageBottom + gap or contentY + rowH + 3
    if compact then
        self.actionHeadLabel:setX(actionX); self.actionHeadLabel:setY(actionY); self.actionHeadLabel:setWidth(actionW)
        actionY = actionY + rowH + 3
    end
    self.targetLabel:setX(actionX); self.targetLabel:setY(actionY); self.targetLabel:setWidth(actionW); actionY = actionY + rowH
    self.ownerLabel:setX(actionX); self.ownerLabel:setY(actionY); self.ownerLabel:setWidth(actionW); actionY = actionY + rowH + 4
    if compact then
        local compactActionW = math.max(40, math.floor((actionW - gap) / 2))
        local actionColumn = 0
        local function action(btn)
            btn:setX(actionX + actionColumn * (compactActionW + gap)); btn:setY(actionY); btn:setWidth(compactActionW); btn:setHeight(rowH)
            actionColumn = actionColumn + 1
            if actionColumn == 2 then actionColumn = 0; actionY = actionY + rowH + 4 end
        end
        action(self.selectZed)
        action(self.selectTarget)
        action(self.gotoButton)
        action(self.teleportButton)
        action(self.comeHere)
        action(self.killButton)
        action(self.despawnButton)
        if actionColumn ~= 0 then actionY = actionY + rowH + 4 end
        self.reanimateEntry:setX(actionX); self.reanimateEntry:setY(actionY); self.reanimateEntry:setWidth(compactActionW); self.reanimateEntry:setHeight(rowH)
        self.reanimateButton:setX(actionX + compactActionW + gap); self.reanimateButton:setY(actionY); self.reanimateButton:setWidth(compactActionW); self.reanimateButton:setHeight(rowH)
        actionY = actionY + rowH + 4
        self.reanimateHelp:setX(actionX); self.reanimateHelp:setY(actionY + 2); self.reanimateHelp:setWidth(actionW)
        actionY = actionY + rowH
    else
        local function action(btn)
            btn:setX(actionX); btn:setY(actionY); btn:setWidth(actionW); btn:setHeight(rowH); actionY = actionY + rowH + 4
        end
        action(self.selectZed)
        action(self.selectTarget)
        action(self.gotoButton)
        action(self.teleportButton)
        action(self.comeHere)
        action(self.killButton)
        action(self.despawnButton)
        self.reanimateEntry:setX(actionX); self.reanimateEntry:setY(actionY); self.reanimateEntry:setWidth(actionW); self.reanimateEntry:setHeight(rowH); actionY = actionY + rowH + 4
        action(self.reanimateButton)
        self.reanimateHelp:setX(actionX); self.reanimateHelp:setY(actionY + 2); self.reanimateHelp:setWidth(actionW)
        actionY = actionY + rowH
    end
    if self.contentPanel then
        self.contentPanel:setScrollHeight(math.max(viewH, actionY + gap))
        self.contentPanel:updateScrollbars()
    end
    self:applyPageVisibility()
end

function ZedController.Panel:applyPageVisibility()
    local live = self.selectedKind == "zed"
    for page, widgets in pairs(self.pageWidgets) do
        for _, ui in ipairs(widgets) do setVisible(ui, live and self.page == page) end
    end
    setVisible(self.leftHeadLabel, live)
    setVisible(self.valueHeadLabel, live)
    setVisible(self.controlHeadLabel, live)
    for _, page in ipairs({ "stats", "state", "appearance" }) do
        local btn = self["page_" .. page]
        setEnabled(btn, live)
        btn.borderColor = page == self.page and ZedController.selectedColor or ZedController.offColor
    end
    setVisible(self.selectTarget, live)
    setVisible(self.gotoButton, live)
    setVisible(self.comeHere, live)
    setVisible(self.killButton, live)
    setVisible(self.reanimateEntry, self.selectedKind == "corpse")
    setVisible(self.reanimateButton, self.selectedKind == "corpse")
    setVisible(self.reanimateHelp, self.selectedKind == "corpse")
end

function ZedController.Panel:updateButtonState(btn, enabled, active, text)
    if not btn then return end
    setEnabled(btn, enabled)
    if text then btn:setTitle(text) end
    btn.borderColor = not enabled and ZedController.disabledColor or (active == true and ZedController.onColor or ZedController.offColor)
end

function ZedController.Panel:updateToggleButtons(zed)
    for _, item in ipairs(self.toggleButtons) do
        local active = zed and item.def.get(zed) == true or false
        self:updateButtonState(item.button, zed ~= nil, active, item.def.label .. ": " .. (active and "ON" or "OFF"))
    end
end

function ZedController.Panel:setSelection(obj)
    local old = self.selected
    if old and old ~= obj then ZedController.setHighlight(old, self.playerNum, false) end
    if old ~= obj then self:clearTargetHighlight() end
    self.selected = obj
    self.selectedKind = ZedController.getKind(obj)
    if obj then ZedController.setHighlight(obj, self.playerNum, true, ZedController.selectedColor) end
end

function ZedController.Panel:clearTargetHighlight()
    if self.targetObject then ZedController.setHighlight(self.targetObject, self.playerNum, false) end
    self.targetObject = nil
    self.targetRef = nil
    setLabel(self.targetLabel, "Target: nil")
end

function ZedController.Panel:clearSelection()
    if self.selected then ZedController.setHighlight(self.selected, self.playerNum, false) end
    self:clearTargetHighlight()
    self.selected = nil
    self.selectedKind = nil
end

function ZedController.Panel:readCombo(combo)
    local option = combo and combo.options and combo.options[combo.selected] or nil
    return option and option.data or nil
end

function ZedController.Panel:setCombo(combo, value)
    if not combo or not combo.options then return end
    for index, option in ipairs(combo.options) do
        if option.data == value then combo:setSelected(index); return end
    end
end

function ZedController.Panel:updateSelectionLabels(obj)
    if not obj then
        setLabel(self.selectionLabel, "Selected: nil")
        setLabel(self.coordsLabel, "X: nil   Y: nil   Z: nil")
        setLabel(self.ownerLabel, "Network owner: nil")
        return
    end
    local kind = self.selectedKind == "corpse" and "Corpse" or "Zombie"
    local id = call(obj, "getID") or call(obj, "getOnlineID") or "?"
    setLabel(self.selectionLabel, "Selected: " .. kind .. " #" .. tostring(id))
    setLabel(self.coordsLabel, "X: " .. tostring(math.floor(call(obj, "getX") or 0)) .. "   Y: " .. tostring(math.floor(call(obj, "getY") or 0)) .. "   Z: " .. tostring(math.floor(call(obj, "getZ") or 0)))
    local owner = call(obj, "getOwnerPlayer")
    setLabel(self.ownerLabel, "Network owner: " .. tostring(owner and call(owner, "getUsername") or "server/local"))
end

function ZedController.Panel:updateStats(zed)
    local health = zed and tonumber(call(zed, "getHealth")) or nil
    setLabel(self.healthValue, health and string.format("%.2f", health) or "nil")
    if zed and not self.healthSlider.dragInside then self.healthSlider:setCurrentValue(ZedController.clamp(health, 0, 100), true) end
    if zed and not self.healthEntry:isFocused() then self.healthEntry:setText(tostring(health or 0)) end
    setLabel(self.walkValue, zed and tostring(call(zed, "getWalkType") or "nil") or "nil")
    setLabel(self.turnValue, zed and string.format("%.2f", tonumber(call(zed, "getTurnDelta")) or 0) or "nil")
    if zed and not self.turnEntry:isFocused() then self.turnEntry:setText(tostring(call(zed, "getTurnDelta") or 1)) end
    if zed then self:setCombo(self.walkType, call(zed, "getWalkType")) end
    for _, row in ipairs(self.statsRows) do
        local value = nil
        if zed then
            value = row.def.key == "voice" and call(zed, "getVoiceChoice") or zed[row.def.key]
        end
        setLabel(row.value, value == nil and "nil" or tostring(value))
        if zed then self:setCombo(row.combo, value) end
        setEnabled(row.combo, zed ~= nil)
        setEnabled(row.apply, zed ~= nil)
    end
    setEnabled(self.healthSlider, zed ~= nil)
    setEnabled(self.healthEntry, zed ~= nil)
    setEnabled(self.healthApply, zed ~= nil)
    setEnabled(self.walkType, zed ~= nil)
    setEnabled(self.walkApply, zed ~= nil)
    setEnabled(self.turnEntry, zed ~= nil)
    setEnabled(self.turnApply, zed ~= nil)
end

function ZedController.Panel:updateAppearance(zed)
    local skin = zed and call(call(zed, "getHumanVisual"), "getSkinTexture") or nil
    setLabel(self.skinValue, skin or "nil")
    if skin then self:setCombo(self.skinCombo, skin) end
    local outfit = zed and call(zed, "getOutfitName") or nil
    setLabel(self.outfitValue, outfit or "nil")
    if zed and not self.outfitEntry:isFocused() then self.outfitEntry:setText(outfit or "") end
    setEnabled(self.skinCombo, zed ~= nil)
    setEnabled(self.skinApply, zed ~= nil)
    setEnabled(self.outfitEntry, zed ~= nil)
    setEnabled(self.outfitApply, zed ~= nil)
    setEnabled(self.randomOutfit, zed ~= nil)
    setEnabled(self.randomBlood, zed ~= nil)
end

function ZedController.Panel:refreshActions()
    local live = self.selectedKind == "zed"
    local corpse = self.selectedKind == "corpse"
    local hasWork = live and ZedController.hasZedWork(self.selected)
    self:updateButtonState(self.selectZed, true, self.cursorMode == "zed", self.selected and "Deselect Zed" or "Select Zed")
    self:updateButtonState(self.selectTarget, live, self.cursorMode == "target", "Select Target")
    self:updateButtonState(self.gotoButton, live, hasWork, hasWork and "Stop" or "Goto")
    self:updateButtonState(self.teleportButton, live or corpse, false, "Teleport To")
    self:updateButtonState(self.comeHere, live, false, "Come Here")
    self:updateButtonState(self.killButton, live, false, "Kill")
    self:updateButtonState(self.despawnButton, live or corpse, false, "Despawn")
    self:updateButtonState(self.reanimateButton, corpse, false, "Resurrect" .. ((tonumber(self.reanimateEntry:getInternalText()) or 0) > 0 and " Timed" or " Now"))
    setEnabled(self.reanimateEntry, corpse)
end

function ZedController.Panel:refreshLive(force)
    if self.targetObject and call(self.targetObject, "getSquare") == nil then self:clearTargetHighlight() end
    local kind = ZedController.getKind(self.selected)
    if self.selected and not kind then
        self:clearSelection()
        setLabel(self.noticeLabel, "Selection despawned or changed state.")
    elseif kind then
        self.selectedKind = kind
    end
    local zed = self.selectedKind == "zed" and self.selected or nil
    self:updateSelectionLabels(self.selected)
    self:updateStats(zed)
    self:updateAppearance(zed)
    self:updateToggleButtons(zed)
    if self.selectedKind == "corpse" then
        local time = call(self.selected, "getReanimateTime")
        setLabel(self.noticeLabel, time and "Corpse selected. Reanimate is available." or "Corpse selected.")
    elseif zed then
        setLabel(self.noticeLabel, "Live state refreshes while this panel is open.")
    elseif force then
        setLabel(self.noticeLabel, "Select a zed or corpse to begin.")
    end
    self:applyPageVisibility()
    self:refreshActions()
end

function ZedController.Panel:clearCursor()
    if self.cursor and getCell then
        local cell = getCell()
        if cell then call(cell, "setDrag", nil, self.playerNum) end
    end
    self.cursor = nil
    self.cursorMode = nil
end

function ZedController.Panel:startCursor(mode)
    if not self.chr or not getCell then return false end
    if self.cursorMode == mode then
        self:clearCursor()
        self:refreshActions()
        return false
    end
    self:clearCursor()
    local cell = getCell()
    if not cell then return false end
    self.cursorMode = mode
    self.cursor = ISSelectCursor:new(self.chr, self, ZedController.Panel.onSquareSelected)
    self.cursor.skipWalk2 = true
    cell:setDrag(self.cursor, self.playerNum)
    self:refreshActions()
    return true
end

function ZedController.Panel:onSquareSelected(sq)
    local mode = self.cursorMode
    self:clearCursor()
    if mode == "zed" then
        local obj = ZedController.findZedAtSquare(sq) or ZedController.findBodyAtSquare(sq)
        if obj then
            self:setSelection(obj)
            setLabel(self.noticeLabel, "Selection updated.")
        else
            self:clearSelection()
            setLabel(self.noticeLabel, "No zed or corpse on that square.")
        end
    elseif mode == "target" and self.selectedKind == "zed" then
        local targetKind, target = ZedController.classifyTarget(self.selected, sq)
        self:clearTargetHighlight()
        if target then
            self.targetObject = target
            self.targetRef = ZedController.selectionRef(target, targetKind)
            if not self.targetRef then
                self.targetRef = { kind = targetKind, x = call(sq, "getX"), y = call(sq, "getY"), z = call(sq, "getZ") }
            end
            ZedController.setHighlight(target, self.playerNum, true, ZedController.targetColor)
            setLabel(self.targetLabel, "Target: " .. targetKind)
        else
            setLabel(self.targetLabel, "Target: cleared")
        end
        self:send("target", { target = self.targetRef, localSquare = sq })
    elseif mode == "goto" and self.selectedKind == "zed" then
        self:send("goto", { x = call(sq, "getX"), y = call(sq, "getY"), z = call(sq, "getZ") })
    end
    self:refreshLive()
end

function ZedController.Panel:send(command, args)
    if not self.selected then return false end
    args = args or {}
    args.source = ZedController.selectionRef(self.selected, self.selectedKind)
    args.localSource = self.selected
    local ok, message = ZedController.request(self.chr, command, args)
    if message then setLabel(self.noticeLabel, message) end
    return ok
end

function ZedController.Panel:onPage(btn)
    if not btn or not btn.pageName or self.selectedKind ~= "zed" then return end
    self.page = btn.pageName
    self:layoutChildren()
end

function ZedController.Panel:onHealthSlider(value)
    if self.healthEntry and not self.healthEntry:isFocused() then self.healthEntry:setText(tostring(value)) end
end

function ZedController.Panel:onHealthApply()
    self:send("setHealth", { value = tonumber(self.healthEntry:getInternalText()) })
end

function ZedController.Panel:onWalkApply()
    self:send("setWalkType", { value = self:readCombo(self.walkType) })
end

function ZedController.Panel:onTurnApply()
    self:send("setTurnDelta", { value = tonumber(self.turnEntry:getInternalText()) })
end

function ZedController.Panel:onStatApply(btn)
    if not btn or not btn.statKey then return end
    self:send("setStat", { key = btn.statKey, value = self:readCombo(self["statCombo_" .. btn.statKey]) })
end

function ZedController.Panel:onToggle(btn)
    local def = btn and ZedController.getToggleDef(btn.toggleKey) or nil
    if not def or self.selectedKind ~= "zed" then return end
    self:send("toggle", { key = def.key, value = not (def.get(self.selected) == true) })
end

function ZedController.Panel:onSkinApply()
    self:send("skin", { skin = self:readCombo(self.skinCombo) })
end

function ZedController.Panel:onOutfitApply()
    self:send("namedOutfit", { outfit = self.outfitEntry:getInternalText() })
end

function ZedController.Panel:onRandomOutfit()
    self:send("randomOutfit", {})
end

function ZedController.Panel:onRandomBlood()
    self:send("randomBlood", {})
end

function ZedController.Panel:onSelectZed()
    if self.selected then
        self:clearSelection()
        setLabel(self.noticeLabel, "Selection cleared.")
        self:refreshLive()
    else
        self:startCursor("zed")
    end
end

function ZedController.Panel:onSelectTarget()
    if self.selectedKind == "zed" then self:startCursor("target") end
end

function ZedController.Panel:onGoto()
    if self.selectedKind ~= "zed" then return end
    if ZedController.hasZedWork(self.selected) then
        self:clearTargetHighlight()
        self:send("stop", {})
    else
        self:startCursor("goto")
    end
end

function ZedController.Panel:onTeleport()
    self:send("teleport", {})
end

function ZedController.Panel:onComeHere()
    if not self.chr then return end
    self:send("goto", { x = self.chr:getX(), y = self.chr:getY(), z = self.chr:getZ() })
end

function ZedController.Panel:onKill()
    self:send("kill", {})
end

function ZedController.Panel:onDespawn()
    self:send("despawn", {})
end

function ZedController.Panel:onReanimate()
    self:send("resurrect", { minutes = tonumber(self.reanimateEntry:getInternalText()) or 0 })
end

function ZedController.Panel:prerender()
    ISCollapsableWindow.prerender(self)
    self:refreshLive()
end

function ZedController.Panel:close()
    self:clearCursor()
    self:clearSelection()
    self:setVisible(false)
    self:removeFromUIManager()
    if ZedController.instance == self then ZedController.instance = nil end
end

function ZedController.Panel:new(x, y, width, height, chr)
    local panel = ISCollapsableWindow.new(self, x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.chr = chr
    panel.playerNum = chr and call(chr, "getPlayerNum") or 0
    panel.page = "stats"
    panel.minimumWidth = math.min(660, width)
    panel.minimumHeight = math.min(430, height)
    panel.backgroundColor = { r = 0.08, g = 0.13, b = 0.08, a = 0.94 }
    panel.borderColor = { r = 0.35, g = 0.65, b = 0.38, a = 0.95 }
    panel.titleBarFont = UIFont.Medium
    panel.titleFontHgt = getTextManager():getFontHeight(UIFont.Medium)
    panel:setTitle("Paradise Zed Control")
    return panel
end

function ZedController.open(pl)
    pl = pl or getPlayer()
    if not ZedController.isAdmin(pl) then return nil end
    if ZedController.instance then
        ZedController.instance:setVisible(true)
        ZedController.instance:bringToTop()
        return ZedController.instance
    end
    local core = getCore()
    local width = math.min(920, math.max(360, core:getScreenWidth() - 16))
    local height = math.min(650, math.max(280, core:getScreenHeight() - 16))
    local panel = ZedController.Panel:new(math.max(8, math.floor((core:getScreenWidth() - width) / 2)), math.max(8, math.floor((core:getScreenHeight() - height) / 2)), width, height, pl)
    panel:initialise()
    panel:addToUIManager()
    if panel.resizeWidget then panel.resizeWidget.resizeFunction = ZedController.Panel.resizeWindow end
    if panel.resizeWidget2 then panel.resizeWidget2.resizeFunction = ZedController.Panel.resizeWindow end
    ZedController.instance = panel
    return panel
end

function ZedController.close()
    if ZedController.instance then ZedController.instance:close() end
    ZedController.instance = nil
end

function ZedController.onResolutionChange()
    local panel = ZedController.instance
    if not panel then return end
    local core = getCore()
    local maxW = math.max(120, core:getScreenWidth() - 16)
    local maxH = math.max(120, core:getScreenHeight() - 16)
    local minW = math.min(panel.minimumWidth or 120, maxW)
    local minH = math.min(panel.minimumHeight or 120, maxH)
    local width = ZedController.clamp(panel.width, minW, maxW)
    local height = ZedController.clamp(panel.height, minH, maxH)
    panel:setWidth(width)
    panel:setHeight(height)
    panel:setX(ZedController.clamp(panel.x, 0, math.max(0, core:getScreenWidth() - width)))
    panel:setY(ZedController.clamp(panel.y, 0, math.max(0, core:getScreenHeight() - height)))
    panel:layoutWindowChrome()
    panel:layoutChildren()
end

function ZedController.onServerCommand(module, command, args)
    if module ~= ZedController.module then return end
    if command == "message" and args and args.text then
        local panel = ZedController.instance
        if panel and panel.noticeLabel then setLabel(panel.noticeLabel, tostring(args.text)) end
        local pl = getPlayer()
        if pl then pl:setHaloNote(tostring(args.text), 250, 130, 40, 180) end
    end
end

if previousOnServerCommand then Events.OnServerCommand.Remove(previousOnServerCommand) end
Events.OnServerCommand.Remove(ZedController.onServerCommand)
Events.OnServerCommand.Add(ZedController.onServerCommand)
if Events.OnResolutionChange then
    if previousOnResolutionChange then Events.OnResolutionChange.Remove(previousOnResolutionChange) end
    Events.OnResolutionChange.Remove(ZedController.onResolutionChange)
    Events.OnResolutionChange.Add(ZedController.onResolutionChange)
end
