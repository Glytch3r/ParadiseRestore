ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.DeadTracker = ParadiseRestore.DeadTracker or {}


ParadiseRestore.DeadTracker.usernameKey = "ParadiseRestoreDeadPlayerUsername"
ParadiseRestore.DeadTracker.visible = ParadiseRestore.DeadTracker.visible ~= false
ParadiseRestore.DeadTracker.defaultCorpseColor = { r = 0.82, g = 0.18, b = 1.0 }
ParadiseRestore.DeadTracker.defaultZombieColor = { r = 0.58, g = 0.08, b = 0.78 }
ParadiseRestore.DeadTracker.dotRadius = 5

local function clamp(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    return math.max(0, math.min(1, value))
end

function ParadiseRestore.DeadTracker.getMarkerColor(isZombie)
    local options = SandboxVars and SandboxVars.ParadiseZ or nil
    local prefix = isZombie and "ParadiseRestore.DeadTrackerZombieColor" or "ParadiseRestore.DeadTrackerCorpseColor"
    local fallback = isZombie and ParadiseRestore.DeadTracker.defaultZombieColor or ParadiseRestore.DeadTracker.defaultCorpseColor
    return clamp(options and options[prefix .. "R"], fallback.r),
        clamp(options and options[prefix .. "G"], fallback.g),
        clamp(options and options[prefix .. "B"], fallback.b)
end

function ParadiseRestore.DeadTracker.rememberDeath(player)
    if not player or not player.getModData or not player.getUsername then return end
    local username = player:getUsername()
    if not username or username == "" then return end
    player:getModData()[ParadiseRestore.DeadTracker.usernameKey] = tostring(username)
    if player.transmitModData then player:transmitModData() end
end

function ParadiseRestore.DeadTracker.onCreatePlayer(playerNum)
    local player = getSpecificPlayer and getSpecificPlayer(playerNum) or nil
    ParadiseRestore.DeadTracker.rememberDeath(player)
end

function ParadiseRestore.DeadTracker.getOwnerUsername(target)
    local data = target and target.getModData and target:getModData() or nil
    local username = data and data[ParadiseRestore.DeadTracker.usernameKey] or nil
    if username == nil or username == "" then return nil end
    return tostring(username)
end

function ParadiseRestore.DeadTracker.isTrackedTarget(target)
    if not target or not instanceof then return false end
    if instanceof(target, "IsoDeadBody") then
        return target.isPlayer and target:isPlayer() == true
    end
    return instanceof(target, "IsoZombie") and target.isReanimatedPlayer and target:isReanimatedPlayer() == true
end

function ParadiseRestore.DeadTracker.isAdminViewer()
    local pl = getPlayer and getPlayer() or nil
    return pl ~= nil and ParadiseDev and ParadiseDev.isAdm and ParadiseDev.isAdm(pl) == true or false
end

function ParadiseRestore.DeadTracker.canViewerSee()
    return ParadiseRestore.DeadTracker.visible == true and ParadiseRestore.DeadTracker.isAdminViewer()
end

function ParadiseRestore.DeadTracker.getTrackedTargets()
    local result = {}
    local cell = getCell and getCell() or nil
    local objects = cell and cell.getObjectListForLua and cell:getObjectListForLua() or nil
    if not objects then return result end
    for index = 0, objects:size() - 1 do
        local target = objects:get(index)
        if ParadiseRestore.DeadTracker.isTrackedTarget(target) then result[#result + 1] = target end
    end
    return result
end

local function drawDot(cx, cy, radius, r, g, b)
    local renderer = getRenderer and getRenderer() or nil
    if not renderer then return end
    -- Fixed UI-pixel octagon: it remains readable at every map zoom level.
    local diagonal = radius * 0.7
    local points = {
        { cx, cy - radius }, { cx + diagonal, cy - diagonal },
        { cx + radius, cy }, { cx + diagonal, cy + diagonal },
        { cx, cy + radius }, { cx - diagonal, cy + diagonal },
        { cx - radius, cy }, { cx - diagonal, cy - diagonal },
    }
    for index = 1, #points do
        local nextIndex = index == #points and 1 or index + 1
        renderer:renderPoly(cx, cy, points[index][1], points[index][2],
            points[nextIndex][1], points[nextIndex][2], cx, cy, r, g, b, 0.95)
    end
end

function ParadiseRestore.DeadTracker.drawMapMarkers(map)
    if not map or not map.mapAPI or not ParadiseRestore.DeadTracker.canViewerSee() then return end
    for _, target in ipairs(ParadiseRestore.DeadTracker.getTrackedTargets()) do
        local isZombie = instanceof(target, "IsoZombie") and target:isReanimatedPlayer() == true
        local r, g, b = ParadiseRestore.DeadTracker.getMarkerColor(isZombie)
        local x, y = target:getX(), target:getY()
        local uiX, uiY = map.mapAPI:worldToUIX(x, y), map.mapAPI:worldToUIY(x, y)
        if uiX and uiY then drawDot(uiX, uiY, ParadiseRestore.DeadTracker.dotRadius, r, g, b) end
    end
end

function ParadiseRestore.DeadTracker.toggleVisibility()
    ParadiseRestore.DeadTracker.visible = not ParadiseRestore.DeadTracker.visible
end

if Events and Events.OnPlayerDeath then
    Events.OnPlayerDeath.Remove(ParadiseRestore.DeadTracker.rememberDeath)
    Events.OnPlayerDeath.Add(ParadiseRestore.DeadTracker.rememberDeath)
end

-- Seed the key while the player is alive so IsoDeadBody's mod-data copy retains it.
if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Remove(ParadiseRestore.DeadTracker.onCreatePlayer)
    Events.OnCreatePlayer.Add(ParadiseRestore.DeadTracker.onCreatePlayer)
end
