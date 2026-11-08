ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.Server = ParadisePOIBuilder.Server or {}
if ParadisePOIBuilder.isB41() then return end

local P = ParadisePOIBuilder
local S = P.Server

function S.findPlayer(username)
    if not username or username == "" then return nil end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    for i = 0, players:size() - 1 do
        local pl = players:get(i)
        if pl and pl:getUsername() == username then return pl end
    end
    return nil
end

function S.emit(username, command, args)
    args = args or {}
    if isServer and isServer() then
        local pl = S.findPlayer(username)
        if pl then sendServerCommand(pl, P.module, command, args) end
    elseif P.Client and P.Client.onServerCommand then
        P.Client.onServerCommand(P.module, command, args)
    end
end

function S.reject(pl, text)
    S.emit(pl:getUsername(), "result", { ok = false, text = text, interim = true })
end

function S.sendIndex(pl)
    local Q = P.Queue
    local C = P.Clone
    local list = C and C.list() or {}
    S.emit(pl:getUsername(), "index", {
        list = list,
        busy = Q and Q.isBusy(pl:getUsername()) or false,
    })
end

function S.pasteRunning(id)
    local Q = P.Queue
    if not Q or not Q.jobs then return false end
    for _, job in pairs(Q.jobs) do
        if job.kind == "paste" and job.payload and tostring(job.payload.id) == tostring(id) then
            return true
        end
    end
    return false
end

function S.checkWallSprite(sprName, flag)
    local spr = getSprite(sprName)
    if not spr then
        return tostring(sprName) .. " is not a known tile. Pick a tile from a wall or fencing sheet."
    end
    local props = spr:getProperties()
    if not props then
        return tostring(sprName) .. " has no tile properties. Pick a tile from a wall or fencing sheet."
    end
    local trans = flag .. "Trans"
    if not (props:has(flag) or props:has(trans)) then
        return tostring(sprName) .. " is not a " .. flag .. " wall tile. Pick a tile from a wall or fencing sheet."
    end
    return nil
end

function S.requestWall(pl, args)
    local Q = P.Queue
    local W = P.Wall
    if not Q or not W then return S.reject(pl, "POI Builder is not fully loaded.") end
    Q.emitter = S.emit
    local username = pl:getUsername()
    local area, areaReason = P.normalizeArea(args.area)
    if not area then return S.reject(pl, areaReason) end

    local mode = args.mode
    if mode ~= "box" and mode ~= "linear" then
        return S.reject(pl, "Wall mode must be box or linear.")
    end

    local units = P.wallUnits(area, mode, args.axis)
    if not units then return S.reject(pl, "Wall mode must be box or linear.") end
    if #units == 0 then return S.reject(pl, "That selection has no wall edges.") end

    local needNorth, needWest = P.wallDirections(units)
    local props, propReason = P.wallProps(args, needNorth, needWest)
    if not props then return S.reject(pl, propReason) end

    if needNorth then
        local northReason = S.checkWallSprite(props.northSprite, "WallN")
        if northReason then return S.reject(pl, northReason) end
    end
    if needWest then
        local westReason = S.checkWallSprite(props.westSprite, "WallW")
        if westReason then return S.reject(pl, westReason) end
    end

    local dist = P.distanceToArea(pl:getX(), pl:getY(), area)
    if dist > P.MAX_DISTANCE then
        return S.reject(pl, string.format("That area is too far from you. You are %.0f tiles away. Move within %d tiles.", dist, P.MAX_DISTANCE))
    end

    local job, startReason = Q.start(username, {
        kind = "wall",
        phase = "Building",
        area = area,
        units = units,
        payload = props,
        step = W.place,
    })
    if not job then return S.reject(pl, startReason) end
end

function S.requestFill(pl, args, kind)
    local Q = P.Queue
    local F = P.Fill
    if not Q or not F then return S.reject(pl, "POI Builder is not fully loaded.") end
    Q.emitter = S.emit
    local username = pl:getUsername()
    local area, areaReason = P.normalizeArea(args.area)
    if not area then return S.reject(pl, areaReason) end

    local props, propReason = P.fillProps(args, kind)
    if not props then return S.reject(pl, propReason) end

    local check = kind == "item" and F.checkItemEntry or F.checkObjectEntry
    for i = 1, #props.entries do
        local reason = check(props.entries[i])
        if reason then return S.reject(pl, reason) end
    end

    local dist = P.distanceToArea(pl:getX(), pl:getY(), area)
    if dist > P.MAX_DISTANCE then
        return S.reject(pl, string.format("That area is too far from you. You are %.0f tiles away. Move within %d tiles.", dist, P.MAX_DISTANCE))
    end

    local units = P.squareUnits(area)
    if #units == 0 then return S.reject(pl, "That selection has no squares.") end

    local job, startReason = Q.start(username, {
        kind = kind == "item" and "itemFill" or "objectFill",
        phase = "Filling",
        area = area,
        units = units,
        payload = props,
        step = kind == "item" and F.placeItem or F.placeObject,
    })
    if not job then return S.reject(pl, startReason) end
end

function S.requestCopy(pl, args)
    local Q = P.Queue
    local C = P.Clone
    if not Q or not C then return S.reject(pl, "POI Builder is not fully loaded.") end
    Q.emitter = S.emit
    local username = pl:getUsername()
    local area, areaReason = P.normalizeArea(args.area)
    if not area then return S.reject(pl, areaReason) end

    local title, titleReason = P.cleanString(args.title, P.MAX_TITLE)
    if not title then return S.reject(pl, titleReason or "Give the blueprint a title.") end
    if C.findByTitle(title) then
        return S.reject(pl, "A blueprint named " .. title .. " already exists.")
    end
    if #C.list() >= P.MAX_BLUEPRINTS then
        return S.reject(pl, string.format("You already have the maximum of %d blueprints.", P.MAX_BLUEPRINTS))
    end

    local dist = P.distanceToArea(pl:getX(), pl:getY(), area)
    if dist > P.MAX_DISTANCE then
        return S.reject(pl, string.format("That area is too far from you. You are %.0f tiles away. Move within %d tiles.", dist, P.MAX_DISTANCE))
    end

    local bp = P.newBlueprint(C.nextId(), title, username, area, getTimestamp())
    local job, startReason = Q.start(username, {
        kind = "copy",
        phase = "Copying",
        area = area,
        units = P.squareUnits(area),
        payload = { area = area, blueprint = bp, count = 0 },
        step = C.copyStep,
        onFinish = function(finished)
            local text, ok = C.finishCopy(finished)
            S.sendIndex(pl)
            return text, ok
        end,
    })
    if not job then return S.reject(pl, startReason) end
end

function S.requestGet(pl, args)
    local C = P.Clone
    if not C then return S.reject(pl, "POI Builder is not fully loaded.") end
    local id = args.id
    if type(id) ~= "string" or id == "" then return S.reject(pl, "Blueprint id is missing.") end
    local bp = C.get(id)
    if not bp then return S.reject(pl, "That blueprint no longer exists.") end
    S.emit(pl:getUsername(), "blueprint", { blueprint = bp })
end

function S.requestRename(pl, args)
    local C = P.Clone
    if not C then return S.reject(pl, "POI Builder is not fully loaded.") end
    local id = args.id
    if type(id) ~= "string" or id == "" then return S.reject(pl, "Blueprint id is missing.") end
    local title, titleReason = P.cleanString(args.title, P.MAX_TITLE)
    if not title then return S.reject(pl, titleReason or "Give the blueprint a title.") end
    local bp = C.get(id)
    if not bp then return S.reject(pl, "That blueprint no longer exists.") end
    if C.findByTitle(title, id) then
        return S.reject(pl, "A blueprint named " .. title .. " already exists.")
    end
    local old = bp.title
    C.rename(id, title)
    C.logRename(pl:getUsername(), id, old, title)
    S.emit(pl:getUsername(), "result", { ok = true, text = "Renamed to " .. title })
    S.sendIndex(pl)
end

function S.requestDelete(pl, args)
    local C = P.Clone
    if not C then return S.reject(pl, "POI Builder is not fully loaded.") end
    local id = args.id
    if type(id) ~= "string" or id == "" then return S.reject(pl, "Blueprint id is missing.") end
    local bp = C.get(id)
    if not bp then return S.reject(pl, "That blueprint no longer exists.") end
    if S.pasteRunning(id) then
        return S.reject(pl, "That blueprint is being placed right now. Wait for the build to finish.")
    end
    C.remove(id)
    S.emit(pl:getUsername(), "result", { ok = true, text = "Deleted " .. tostring(bp.title) })
    S.sendIndex(pl)
end

function S.requestPaste(pl, args)
    local Q = P.Queue
    local C = P.Clone
    if not Q or not C then return S.reject(pl, "POI Builder is not fully loaded.") end
    Q.emitter = S.emit
    local username = pl:getUsername()
    local id = args.id
    if type(id) ~= "string" or id == "" then return S.reject(pl, "Blueprint id is missing.") end
    local bp = C.get(id)
    if not bp then return S.reject(pl, "That blueprint no longer exists.") end
    if S.pasteRunning(id) then return S.reject(pl, "That blueprint is already being built.") end

    local origin = args.origin
    if type(origin) ~= "table" then return S.reject(pl, "Pick where the blueprint goes first.") end
    local ox, oy = tonumber(origin.x), tonumber(origin.y)
    local zMin = tonumber(args.zMin)
    if not ox or not oy or not zMin then return S.reject(pl, "The placement point is missing.") end
    ox, oy, zMin = math.floor(ox), math.floor(oy), math.floor(zMin)

    local size = bp.size or {}
    local dx = tonumber(size.dx) or 0
    local dy = tonumber(size.dy) or 0
    local dz = tonumber(size.dz) or 0
    if dx <= 0 or dy <= 0 or dz <= 0 then return S.reject(pl, "That blueprint has no size.") end
    if zMin < P.Z_MIN or zMin + dz > P.Z_MAX_EXCLUSIVE then
        return S.reject(pl, "That blueprint does not fit between Z 0 and 7.")
    end

    local area, areaReason = P.normalizeArea({
        x1 = ox, y1 = oy, x2 = ox + dx - 1, y2 = oy + dy - 1, zMin = zMin, zMax = zMin + dz,
    })
    if not area then return S.reject(pl, areaReason) end

    local dist = P.distanceToArea(pl:getX(), pl:getY(), area)
    if dist > P.MAX_DISTANCE then
        return S.reject(pl, string.format("That spot is too far from you. You are %.0f tiles away. Move within %d tiles.", dist, P.MAX_DISTANCE))
    end

    local vx, vy, vz = C.vehicleVeto(area)
    if vx then
        return S.reject(pl, string.format("Cannot build here. A vehicle overlaps %d, %d, %d.", vx, vy, vz))
    end

    local job, startReason = Q.start(username, C.pasteJob(bp, area))
    if not job then return S.reject(pl, startReason) end
end

function S.onClientCommand(module, command, pl, args)
    if module ~= P.module then return end
    if not pl then return end
    args = type(args) == "table" and args or {}
    local Q = P.Queue

    if not ParadiseRestore.isAdm(pl) then
        S.reject(pl, "POI Builder requires admin.")
        return
    end

    if command == "index" then
        S.sendIndex(pl)
        return
    end

    if command == "copy" then
        S.requestCopy(pl, args)
        return
    end

    if command == "get" then
        S.requestGet(pl, args)
        return
    end

    if command == "rename" then
        S.requestRename(pl, args)
        return
    end

    if command == "delete" then
        S.requestDelete(pl, args)
        return
    end

    if command == "paste" then
        S.requestPaste(pl, args)
        return
    end

    if command == "wall" then
        S.requestWall(pl, args)
        return
    end

    if command == "objectFill" then
        S.requestFill(pl, args, "object")
        return
    end

    if command == "itemFill" then
        S.requestFill(pl, args, "item")
        return
    end

    if command == "cancel" then
        if Q.cancel(pl:getUsername()) then
            S.emit(pl:getUsername(), "result", { ok = false, text = "Cancelling. The destination keeps whatever was already built.", interim = true })
        else
            S.reject(pl, "No job is running.")
        end
        return
    end
end
Events.OnClientCommand.Remove(S.onClientCommand)
Events.OnClientCommand.Add(S.onClientCommand)
