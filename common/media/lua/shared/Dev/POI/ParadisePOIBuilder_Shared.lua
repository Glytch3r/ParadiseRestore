ParadisePOIBuilder = ParadisePOIBuilder or {}

local P = ParadisePOIBuilder

P.module = "ParadisePOIBuilder"
P.BLUEPRINT_KEY = "ParadisePOIBuilder.Blueprints"
P.MAX_BLUEPRINTS = 50
P.MAX_VOLUME = 250000
P.MAX_SPAN = 200
P.MAX_DISTANCE = 300
P.Z_MIN = 0
P.Z_MAX_EXCLUSIVE = 8
P.MAX_TITLE = 64
P.JOB_BUDGET = 128
P.PROGRESS_MS = 250
P.WALL_HP_MIN = 1
P.WALL_HP_MAX = 100000
P.WALL_NAME = "POI Wall"
P.WALL_BREAK_SOUND = "BreakObject"
P.MAX_FILL_ENTRIES = 64
P.ITEM_COUNT_MAX = 64
P.BLOOD_MAX = 100
P.MAX_OBJECTS_PER_BLUEPRINT = 20000

function P.isB41()
    return getCore():getGameVersion():getMajor() == 41
end

function P.clampInt(value, min, max)
    local n = tonumber(value)
    if not n then return nil end
    n = math.floor(n)
    if n < min then n = min end
    if n > max then n = max end
    return n
end

function P.cleanString(value, maxLen)
    if type(value) ~= "string" then return nil, "Expected text." end
    local str = value:match("^%s*(.-)%s*$")
    if str == "" then return nil, "Text is empty." end
    if #str > maxLen then
        return nil, string.format("Text is longer than %d characters.", maxLen)
    end
    for i = 1, #str do
        local b = string.byte(str, i)
        if b < 32 or b == 127 then return nil, "Text contains control characters." end
    end
    return str
end

function P.normalizeArea(raw)
    if type(raw) ~= "table" then return nil, "Area is missing." end
    local x1, y1 = tonumber(raw.x1), tonumber(raw.y1)
    local x2, y2 = tonumber(raw.x2), tonumber(raw.y2)
    local zMin, zMax = tonumber(raw.zMin), tonumber(raw.zMax)
    if not x1 or not y1 or not x2 or not y2 or not zMin or not zMax then
        return nil, "Area needs two points and a Z range."
    end
    x1, x2 = math.floor(math.min(x1, x2)), math.floor(math.max(x1, x2))
    y1, y2 = math.floor(math.min(y1, y2)), math.floor(math.max(y1, y2))
    zMin, zMax = math.floor(zMin), math.floor(zMax)
    if zMin < P.Z_MIN then zMin = P.Z_MIN end
    if zMax > P.Z_MAX_EXCLUSIVE then zMax = P.Z_MAX_EXCLUSIVE end
    if zMax <= zMin then zMax = zMin + 1 end
    if zMax > P.Z_MAX_EXCLUSIVE then
        return nil, "Z range is outside 0 to 7."
    end
    local spanX, spanY = x2 - x1 + 1, y2 - y1 + 1
    if spanX > P.MAX_SPAN or spanY > P.MAX_SPAN then
        return nil, string.format("Area span %d x %d exceeds %d tiles per axis.", spanX, spanY, P.MAX_SPAN)
    end
    local volume = spanX * spanY * (zMax - zMin)
    if volume > P.MAX_VOLUME then
        return nil, string.format("Area volume %d exceeds %d squares.", volume, P.MAX_VOLUME)
    end
    return { x1 = x1, y1 = y1, x2 = x2, y2 = y2, zMin = zMin, zMax = zMax, volume = volume }
end

function P.distanceToArea(x, y, area)
    local dx = 0
    if x < area.x1 then dx = area.x1 - x
    elseif x > area.x2 then dx = x - area.x2 end
    local dy = 0
    if y < area.y1 then dy = area.y1 - y
    elseif y > area.y2 then dy = y - area.y2 end
    return math.sqrt(dx * dx + dy * dy)
end

function P.boxUnits(area)
    local units = {}
    for z = area.zMin, area.zMax - 1 do
        if area.x1 == area.x2 then
            for y = area.y1, area.y2 do
                units[#units + 1] = { x = area.x1, y = y, z = z, north = false }
            end
        elseif area.y1 == area.y2 then
            for x = area.x1, area.x2 do
                units[#units + 1] = { x = x, y = area.y1, z = z, north = true }
            end
        else
            for x = area.x1, area.x2 do
                units[#units + 1] = { x = x, y = area.y1, z = z, north = true }
                units[#units + 1] = { x = x, y = area.y2, z = z, north = true }
            end
            for y = area.y1, area.y2 do
                units[#units + 1] = { x = area.x1, y = y, z = z, north = false }
                units[#units + 1] = { x = area.x2, y = y, z = z, north = false }
            end
        end
    end
    return units
end

function P.resolveAxis(area, axis)
    if axis == "x" or axis == "y" then return axis end
    local spanX, spanY = area.x2 - area.x1 + 1, area.y2 - area.y1 + 1
    if spanY > spanX then return "y" end
    return "x"
end

function P.linearUnits(area, axis)
    local resolved = P.resolveAxis(area, axis)
    local units = {}
    for z = area.zMin, area.zMax - 1 do
        if resolved == "x" then
            for x = area.x1, area.x2 do
                units[#units + 1] = { x = x, y = area.y1, z = z, north = true }
            end
        else
            for y = area.y1, area.y2 do
                units[#units + 1] = { x = area.x1, y = y, z = z, north = false }
            end
        end
    end
    return units, resolved
end

function P.wallUnits(area, mode, axis)
    if mode == "box" then
        return P.boxUnits(area), nil
    end
    if mode == "linear" then
        return P.linearUnits(area, axis)
    end
    return nil, nil
end

function P.wallDirections(units)
    local needNorth, needWest = false, false
    for i = 1, #units do
        if units[i].north then needNorth = true else needWest = true end
    end
    return needNorth, needWest
end

function P.wallProps(raw, needNorth, needWest)
    if type(raw) ~= "table" then return nil, "Wall settings are missing." end
    if needNorth == nil then needNorth = true end
    if needWest == nil then needWest = true end
    local props = {
        indestructible = raw.indestructible == true,
        sledge = raw.sledge == true,
        climb = raw.climb == true,
    }
    if needNorth then
        local northSprite, northReason = P.cleanString(raw.northSprite, 128)
        if not northSprite then
            if raw.northSprite == nil or raw.northSprite == "" then
                return nil, "Pick a north edge tile."
            end
            return nil, northReason or "Pick a north edge tile."
        end
        props.northSprite = northSprite
    end
    if needWest then
        local westSprite, westReason = P.cleanString(raw.westSprite, 128)
        if not westSprite then
            if raw.westSprite == nil or raw.westSprite == "" then
                return nil, "Pick a west edge tile."
            end
            return nil, westReason or "Pick a west edge tile."
        end
        props.westSprite = westSprite
    end
    local hp = P.clampInt(raw.hp, P.WALL_HP_MIN, P.WALL_HP_MAX)
    if not hp then return nil, "Wall health must be a number." end
    props.hp = hp
    return props
end

function P.isSledgeProof(obj)
    if not obj then return false end
    if not obj.getModData then return false end
    local md = obj:getModData()
    if not md then return false end
    local tag = md.ParadisePOIBuilder
    return type(tag) == "table" and tag.sledge == false
end

function P.squareUnits(area)
    local units = {}
    for z = area.zMin, area.zMax - 1 do
        for y = area.y1, area.y2 do
            for x = area.x1, area.x2 do
                units[#units + 1] = { x = x, y = y, z = z }
            end
        end
    end
    return units
end

function P.parseBlood(entry)
    if type(entry) ~= "string" then return nil end
    local n = entry:match("^blood:(%d+)$")
    if not n then return nil end
    return P.clampInt(n, 1, P.BLOOD_MAX)
end

function P.fillProps(raw, kind)
    if type(raw) ~= "table" then return nil, "Fill settings are missing." end
    local percent = P.clampInt(raw.percent, 1, 100)
    if not percent then return nil, "Percent must be a number from 1 to 100." end
    if type(raw.entries) ~= "table" or #raw.entries == 0 then
        return nil, "Add at least one entry to the fill list."
    end
    if #raw.entries > P.MAX_FILL_ENTRIES then
        return nil, string.format("The fill list holds at most %d entries.", P.MAX_FILL_ENTRIES)
    end
    local entries = {}
    for i = 1, #raw.entries do
        local str, reason = P.cleanString(raw.entries[i], 128)
        if not str then return nil, reason end
        entries[#entries + 1] = str
    end
    local count = 1
    if kind == "item" then
        count = P.clampInt(raw.count == nil and 1 or raw.count, 1, P.ITEM_COUNT_MAX)
        if not count then return nil, string.format("Count must be a number from 1 to %d.", P.ITEM_COUNT_MAX) end
    end
    return { percent = percent, entries = entries, count = count }
end

function P.pickEntry(entries)
    return entries[ZombRand(1, #entries + 1)]
end

function P.rollHit(percent)
    return ZombRand(100) < percent
end

function P.squareKey(dx, dy, dz)
    return tostring(dx) .. "," .. tostring(dy) .. "," .. tostring(dz)
end

function P.parseSquareKey(key)
    if type(key) ~= "string" then return nil end
    local dx, dy, dz = key:match("^(-?%d+),(-?%d+),(-?%d+)$")
    if not dx then return nil end
    return tonumber(dx), tonumber(dy), tonumber(dz)
end

function P.copyModData(md)
    if type(md) ~= "table" then return {} end
    local out = {}
    for k, v in pairs(md) do
        if type(v) == "table" then
            out[k] = P.copyModData(v)
        else
            out[k] = v
        end
    end
    return out
end

function P.sortObjectRecords(list)
    local copy = {}
    for i = 1, #list do copy[i] = list[i] end
    table.sort(copy, function(a, b)
        local ai = tonumber(a.i) or 0
        local bi = tonumber(b.i) or 0
        if ai ~= bi then return ai < bi end
        return tostring(a.s or "") < tostring(b.s or "")
    end)
    return copy
end

function P.newBlueprint(id, title, author, area, created)
    return {
        id = id,
        title = title,
        created = tonumber(created) or 0,
        author = author or "",
        size = {
            dx = area.x2 - area.x1 + 1,
            dy = area.y2 - area.y1 + 1,
            dz = area.zMax - area.zMin,
        },
        objectCount = 0,
        itemCount = 0,
        squares = {},
    }
end

function P.addBlueprintRecord(bp, key, record)
    local sq = bp.squares[key]
    if not sq then
        sq = { objects = {}, items = {} }
        bp.squares[key] = sq
    end
    sq.objects[#sq.objects + 1] = record
    bp.objectCount = (bp.objectCount or 0) + 1
    return sq
end

function P.addBlueprintItem(bp, key, record)
    local sq = bp.squares[key]
    if not sq then
        sq = { objects = {}, items = {} }
        bp.squares[key] = sq
    end
    sq.items[#sq.items + 1] = record
    bp.itemCount = (bp.itemCount or 0) + 1
    return sq
end

function P.countBlueprintObjects(bp)
    local total = 0
    for _, sq in pairs(bp.squares or {}) do
        total = total + #(sq.objects or {})
        total = total + #(sq.items or {})
    end
    return total
end

function P.blueprintIndexEntry(bp)
    return {
        id = bp.id,
        title = bp.title,
        created = bp.created or 0,
        author = bp.author or "",
        dx = bp.size and bp.size.dx or 0,
        dy = bp.size and bp.size.dy or 0,
        dz = bp.size and bp.size.dz or 0,
        objectCount = bp.objectCount or 0,
        itemCount = bp.itemCount or 0,
    }
end

function P.findBlueprintByTitle(list, title, ignoreId)
    if type(title) ~= "string" then return nil end
    local needle = title:lower()
    for _, entry in ipairs(list or {}) do
        if entry.id ~= ignoreId and type(entry.title) == "string" and entry.title:lower() == needle then
            return entry
        end
    end
    return nil
end
