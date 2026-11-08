ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.Clone = ParadisePOIBuilder.Clone or {}
if ParadisePOIBuilder.isB41() then return end

local P = ParadisePOIBuilder
local C = P.Clone

C.store = C.store or nil

function C.load()
    local md = ModData.getOrCreate(P.BLUEPRINT_KEY)
    C.store = md or {}
    return C.store
end

function C.save(bp)
    if type(bp) ~= "table" or bp.id == nil then return false end
    local store = C.load()
    store[tostring(bp.id)] = bp
    return true
end

function C.get(id)
    if id == nil then return nil end
    local store = C.load()
    return store[tostring(id)]
end

function C.remove(id)
    if id == nil then return false end
    local store = C.load()
    local key = tostring(id)
    if store[key] == nil then return false end
    store[key] = nil
    return true
end

function C.list()
    local store = C.load()
    local list = {}
    for _, rec in pairs(store) do
        if type(rec) == "table" and rec.id ~= nil then
            list[#list + 1] = P.blueprintIndexEntry(rec)
        end
    end
    table.sort(list, function(a, b)
        local at = tostring(a.title or ""):lower()
        local bt = tostring(b.title or ""):lower()
        if at ~= bt then return at < bt end
        return tostring(a.id) < tostring(b.id)
    end)
    return list
end

function C.nextId()
    local store = C.load()
    local n = 1
    while store["bp" .. n] do n = n + 1 end
    return "bp" .. n
end

function C.findByTitle(title, ignoreId)
    if type(title) ~= "string" then return nil end
    local needle = title:lower()
    local store = C.load()
    for _, rec in pairs(store) do
        if type(rec) == "table" and rec.id ~= nil and tostring(rec.id) ~= tostring(ignoreId) then
            if type(rec.title) == "string" and rec.title:lower() == needle then
                return rec
            end
        end
    end
    return nil
end

function C.rename(id, title)
    local bp = C.get(id)
    if not bp then return nil, "That blueprint no longer exists." end
    bp.title = title
    C.save(bp)
    return bp
end

function C.logRename(actor, id, from, to)
    local log = ModData.getOrCreate(P.BLUEPRINT_KEY .. ".Log")
    local count = (tonumber(log.count) or 0) + 1
    log.count = count
    log["r" .. count] = {
        time = getTimestamp(),
        actor = actor or "",
        id = tostring(id or ""),
        from = from or "",
        to = to or "",
    }
    return true
end

function C.classify(obj, sq)
    if instanceof(obj, "IsoWorldInventoryObject") then return "item" end
    if instanceof(obj, "IsoThumpable") then return "thumpable" end
    if instanceof(obj, "IsoDoor") then return "door" end
    if sq and sq.getFloor and obj == sq:getFloor() then return "floor" end
    if obj.isFloor and obj:isFloor() then return "floor" end
    if instanceof(obj, "IsoTree") then return "tree" end
    if obj.getContainer and obj:getContainer() then return "container" end
    return "other"
end

function C.captureItem(worldObj)
    local item = worldObj.getItem and worldObj:getItem() or nil
    if not item then return nil end
    local fullType = item.getFullType and item:getFullType() or nil
    if type(fullType) ~= "string" or fullType == "" then return nil end
    local record = { fullType = fullType }
    if item.getCondition then record.condition = item:getCondition() end
    if item.getWetness then record.wetness = item:getWetness() end
    if item.getUsedDelta then record.usedDelta = item:getUsedDelta() end
    if item.getModData then record.modData = P.copyModData(item:getModData()) end
    return record
end

function C.northOf(obj)
    if not obj then return false end
    if obj.getNorth then return obj:getNorth() == true end
    if obj.isNorth then return obj:isNorth() == true end
    return false
end

function C.captureObject(obj, sq)
    local kind = C.classify(obj, sq)
    if kind == "item" then
        local record = C.captureItem(obj)
        if not record then return nil, kind end
        return record, kind
    end
    local spr = obj.getSprite and obj:getSprite() or nil
    local name = spr and spr.getName and spr:getName() or nil
    if type(name) ~= "string" or name == "" then return nil, kind end
    local record = { s = name, k = kind }
    record.i = obj.getObjectIndex and obj:getObjectIndex() or 0
    record.t = kind == "floor"
    if kind == "thumpable" or kind == "door" then
        record.n = C.northOf(obj)
        if obj.getHealth then record.h = obj:getHealth() end
        if obj.getMaxHealth then record.m = obj:getMaxHealth() end
    end
    if obj.getModData then record.d = P.copyModData(obj:getModData()) end
    return record, kind
end

function C.readSquare(sq, x, y, z, area, bp)
    if not sq or not area or not bp then return 0 end
    local key = P.squareKey(x - area.x1, y - area.y1, z - area.zMin)
    local objects = sq.getObjects and sq:getObjects() or nil
    local count = 0
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj then
                local record, kind = C.captureObject(obj, sq)
                if record then
                    if kind == "item" then
                        P.addBlueprintItem(bp, key, record)
                    else
                        P.addBlueprintRecord(bp, key, record)
                    end
                    count = count + 1
                end
            end
        end
    end
    return count
end

function C.copyStep(job, unit)
    local payload = job and job.payload
    if not payload or not payload.area or not payload.blueprint then return "skip" end
    local sq = getCell():getGridSquare(unit.x, unit.y, unit.z)
    if not sq then return "skip" end
    local count = C.readSquare(sq, unit.x, unit.y, unit.z, payload.area, payload.blueprint)
    payload.count = (payload.count or 0) + count
    if payload.count > P.MAX_OBJECTS_PER_BLUEPRINT then
        job.abortReason = string.format("That area holds more than %d objects. Nothing was copied.", P.MAX_OBJECTS_PER_BLUEPRINT)
        return "abort"
    end
    return nil
end

function C.finishCopy(job)
    if not job or not job.payload or not job.payload.blueprint then
        return "The copy job lost its blueprint.", false
    end
    if job.state == "cancelled" then
        return string.format("Copy cancelled after %d of %d squares. Nothing was saved.", job.cursor - 1, job.total), false
    end
    local bp = job.payload.blueprint
    if not C.save(bp) then
        return "The blueprint could not be saved.", false
    end
    return string.format("Copied %d objects into %s.", P.countBlueprintObjects(bp), tostring(bp.title)), true
end

function C.clearSquare(sq)
    if not sq then return 0 end
    local removed = 0

    local objects = sq.getObjects and sq:getObjects() or nil
    if objects then
        local floor = sq.getFloor and sq:getFloor() or nil
        for i = objects:size() - 1, 0, -1 do
            local obj = objects:get(i)
            if obj and obj ~= floor then
                sq:transmitRemoveItemFromSquare(obj)
                removed = removed + 1
            end
        end
    end

    if sq.removeBlood then sq:removeBlood(false, false) end
    if sq.removeGraffiti then sq:removeGraffiti() end

    local bodies = sq.getStaticMovingObjects and sq:getStaticMovingObjects() or nil
    if bodies then
        local doomed = {}
        for i = 0, bodies:size() - 1 do
            local body = bodies:get(i)
            if body and instanceof(body, "IsoDeadBody") and not body:isPlayer() then
                doomed[#doomed + 1] = body
            end
        end
        for i = 1, #doomed do
            if sq.removeCorpse then sq:removeCorpse(doomed[i], false) end
        end
    end

    local movers = sq.getMovingObjects and sq:getMovingObjects() or nil
    if movers then
        for i = movers:size() - 1, 0, -1 do
            local zed = movers:get(i)
            if zed and instanceof(zed, "IsoZombie") and not zed:isReanimatedPlayer() then
                zed:removeFromWorld()
                zed:removeFromSquare()
                removed = removed + 1
            end
        end
    end

    return removed
end

function C.vehicleVeto(area)
    for z = area.zMin, area.zMax - 1 do
        for y = area.y1, area.y2 do
            for x = area.x1, area.x2 do
                local sq = getCell():getGridSquare(x, y, z)
                if sq and sq.isVehicleIntersecting and sq:isVehicleIntersecting() then
                    return x, y, z
                end
            end
        end
    end
    return nil
end

function C.applyModData(obj, md)
    if not obj or type(md) ~= "table" then return end
    if not obj.getModData then return end
    local target = obj:getModData()
    if not target then return end
    for k, v in pairs(md) do
        target[k] = v
    end
end

function C.placeFloor(sq, rec)
    local floor = sq.getFloor and sq:getFloor() or nil
    if floor then sq:transmitRemoveItemFromSquare(floor) end
    local obj = IsoObject.new(sq, rec.s)
    if not obj then return nil end
    sq:AddTileObject(obj)
    C.applyModData(obj, rec.d)
    obj:transmitCompleteItemToClients()
    return obj
end

function C.placeThumpable(sq, rec)
    local obj = IsoThumpable.new(getCell(), sq, rec.s, rec.n == true, {})
    if not obj then return nil end
    if rec.m and obj.setMaxHealth then obj:setMaxHealth(rec.m) end
    if rec.h and obj.setHealth then obj:setHealth(rec.h) end
    sq:AddSpecialObject(obj)
    C.applyModData(obj, rec.d)
    obj:transmitCompleteItemToClients()
    return obj
end

function C.placeDoor(sq, rec)
    local obj = IsoDoor.new(getCell(), sq, rec.s, rec.n == true)
    if not obj then return nil end
    if rec.h and obj.setHealth then obj:setHealth(rec.h) end
    sq:AddSpecialObject(obj)
    C.applyModData(obj, rec.d)
    obj:transmitCompleteItemToClients()
    return obj
end

function C.placeTileObject(sq, rec)
    local obj = IsoObject.new(sq, rec.s)
    if not obj then return nil end
    sq:AddTileObject(obj)
    C.applyModData(obj, rec.d)
    obj:transmitCompleteItemToClients()
    return obj
end

function C.placeItem(sq, rec)
    local item = instanceItem(rec.fullType)
    if not item then return nil end
    if rec.condition and item.setCondition then item:setCondition(rec.condition) end
    if rec.wetness and item.setWetness then item:setWetness(rec.wetness) end
    if rec.usedDelta and item.setUsedDelta then item:setUsedDelta(rec.usedDelta) end
    C.applyModData(item, rec.modData)
    sq:AddWorldInventoryItem(item, ZombRand(100) / 100, ZombRand(100) / 100, 0)
    return item
end

function C.splitRecords(records)
    local floors, walls, rest = {}, {}, {}
    local sorted = P.sortObjectRecords(records)
    for i = 1, #sorted do
        local rec = sorted[i]
        local kind = rec.k
        if kind == "floor" then
            floors[#floors + 1] = rec
        elseif kind == "thumpable" or kind == "door" then
            walls[#walls + 1] = rec
        else
            rest[#rest + 1] = rec
        end
    end
    return floors, walls, rest
end

function C.writeSquare(sq, rec)
    if not sq or type(rec) ~= "table" then return 0, 0 end
    local placed, failed = 0, 0
    local floors, walls, rest = C.splitRecords(rec.objects or {})

    for i = 1, #floors do
        local ok, obj = pcall(C.placeFloor, sq, floors[i])
        if ok and obj then placed = placed + 1 else failed = failed + 1 end
    end
    for i = 1, #walls do
        local rec2 = walls[i]
        local ok, obj
        if rec2.k == "door" then
            ok, obj = pcall(C.placeDoor, sq, rec2)
        else
            ok, obj = pcall(C.placeThumpable, sq, rec2)
        end
        if ok and obj then placed = placed + 1 else failed = failed + 1 end
    end
    for i = 1, #rest do
        local ok, obj = pcall(C.placeTileObject, sq, rest[i])
        if ok and obj then placed = placed + 1 else failed = failed + 1 end
    end

    local items = rec.items or {}
    for i = 1, #items do
        local ok, item = pcall(C.placeItem, sq, items[i])
        if ok and item then placed = placed + 1 else failed = failed + 1 end
    end

    if sq.RecalcAllWithNeighbours then sq:RecalcAllWithNeighbours(true) end
    return placed, failed
end

function C.pasteUnits(bp, area)
    local units = {}
    for z = area.zMin, area.zMax - 1 do
        for y = area.y1, area.y2 do
            for x = area.x1, area.x2 do
                units[#units + 1] = { phase = "clear", x = x, y = y, z = z }
            end
        end
    end

    local keys = {}
    for key in pairs(bp.squares or {}) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local adx, ady, adz = P.parseSquareKey(a)
        local bdx, bdy, bdz = P.parseSquareKey(b)
        if adz ~= bdz then return adz < bdz end
        if ady ~= bdy then return ady < bdy end
        return adx < bdx
    end)
    for i = 1, #keys do
        local dx, dy, dz = P.parseSquareKey(keys[i])
        if dx then
            units[#units + 1] = {
                phase = "write",
                x = area.x1 + dx,
                y = area.y1 + dy,
                z = area.zMin + dz,
                key = keys[i],
            }
        end
    end
    return units
end

function C.pasteStep(job, unit)
    if not unit then return "skip" end
    if unit.phase == "clear" then
        job.phase = "Clearing"
        local sq = getCell():getGridSquare(unit.x, unit.y, unit.z)
        if not sq then return "skip" end
        C.clearSquare(sq)
        return nil
    end

    job.phase = "Rendering"
    local sq = getCell():getGridSquare(unit.x, unit.y, unit.z)
    if not sq then return "skip" end
    local rec = job.payload.blueprint.squares[unit.key]
    if not rec then return "skip" end
    local placed, failed = C.writeSquare(sq, rec)
    job.payload.placed = (job.payload.placed or 0) + placed
    job.payload.failed = (job.payload.failed or 0) + failed
    return nil
end

function C.finishPaste(job)
    invalidateLighting()
    if not job or not job.payload then return "The build job lost its data.", false end
    local bp = job.payload.blueprint
    local placed = job.payload.placed or 0
    if job.state == "cancelled" then
        local done = job.cursor - 1
        if job.phase == "Rendering" then
            return string.format("Build cancelled after %d of %d squares. The destination was cleared and %d objects were placed before it stopped.", done, job.total, placed), false
        end
        return string.format("Build cancelled after %d of %d squares. %d squares were cleared and nothing was placed.", done, job.total, done), false
    end
    local failed = job.payload.failed or 0
    if failed > 0 then
        return string.format("Built %s with %d errors. %d objects placed.", tostring(bp.title), failed, placed), false
    end
    return string.format("Built %s. %d objects placed.", tostring(bp.title), placed), true
end

function C.pasteJob(bp, area)
    return {
        kind = "paste",
        phase = "Clearing",
        area = area,
        units = C.pasteUnits(bp, area),
        payload = { id = bp.id, blueprint = bp, placed = 0, failed = 0 },
        step = C.pasteStep,
        onFinish = function(job)
            local text, ok = C.finishPaste(job)
            return text, ok
        end,
    }
end
