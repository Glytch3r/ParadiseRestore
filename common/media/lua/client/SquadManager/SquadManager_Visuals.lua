if not isClient() then return end

SquadManager = SquadManager or {}
if not SquadManager.isB41 then require "SquadManager/SquadManager_Shared" end
if SquadManager.isB41() then return end

SquadManager.Visuals = SquadManager.Visuals or {}

local V = SquadManager.Visuals
V.circles = V.circles or {}
V.outlines = V.outlines or {}
V.tagObjs = V.tagObjs or {}
V.timed = V.timed or {}
V.frame = 0
V.updateEvery = 4

function V.worldMarkers()
    local ok, markers = pcall(getWorldMarkers)
    if not ok then return nil end
    return markers
end

function V.square(x, y, z)
    local cell = getCell and getCell() or nil
    if not cell then return nil end
    return cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z))
end

function V.plOf(user)
    if not user or user == "" then return nil end
    if not getPlayerFromUsername then return nil end
    return getPlayerFromUsername(user)
end

function V.now()
    return os.time()
end

function V.highlight(obj, col)
    local pl = getPlayer()
    if not obj or not pl then return false end
    local plNum = pl:getPlayerNum()
    obj:setHighlightColor(plNum, col.r, col.g, col.b, 1)
    obj:setHighlighted(plNum, true, false)
    obj:setOutlineHighlightCol(plNum, col.r, col.g, col.b, 1)
    obj:setOutlineHighlight(plNum, true)
    return true
end

function V.unhighlight(obj)
    local pl = getPlayer()
    if not obj or not pl then return end
    local plNum = pl:getPlayerNum()
    obj:setHighlighted(plNum, false, false)
    obj:setOutlineHighlight(plNum, false)
end

function V.drop(obj)
    if not obj then return end
    pcall(function() obj:remove() end)
end

function V.removeCircle(user)
    local entry = V.circles[user]
    if not entry then return end
    V.drop(entry.marker)
    V.circles[user] = nil
end

function V.setCircle(user, x, y, z, isLeader)
    if not x then return end
    local entry = V.circles[user]
    if entry and entry.leader ~= isLeader then
        V.removeCircle(user)
        entry = nil
    end
    if entry then
        entry.marker:setPosAndSize(math.floor(x), math.floor(y), math.floor(z), entry.size)
        return
    end
    local markers = V.worldMarkers()
    local sq = V.square(x, y, z)
    if not markers or not sq then return end
    local col = isLeader and SquadManager.colors.leader or SquadManager.colors.squad
    local size = isLeader and 1.25 or 1.0
    local marker = markers:addGridSquareMarker("circle_center", "circle_only_highlight", sq,
        col.r, col.g, col.b, true, size)
    if not marker then return end
    V.circles[user] = { marker = marker, leader = isLeader, size = size }
end

function V.clearOutline(user)
    local obj = V.outlines[user]
    if obj then V.unhighlight(obj) end
    V.outlines[user] = nil
end

function V.setOutline(user, obj, isLeader)
    if not obj then return end
    V.outlines[user] = obj
    V.highlight(obj, isLeader and SquadManager.colors.leader or SquadManager.colors.squad)
end

function V.refreshMembers()
    if not SquadManager.isActive() then
        V.clearMembers()
        return
    end
    local seen = {}
    for _, entry in ipairs(SquadManager.members) do
        local user = entry.user
        if user and user ~= "" and user ~= SquadManager.username() then
            seen[user] = true
            local isLeader = entry.seat == 1
            local obj = V.plOf(user)
            if obj and obj:getSquare() then
                V.setOutline(user, obj, isLeader)
                V.setCircle(user, obj:getX(), obj:getY(), obj:getZ(), isLeader)
            else
                V.clearOutline(user)
                V.setCircle(user, entry.x, entry.y, entry.z, isLeader)
            end
        end
    end
    for user in pairs(V.circles) do
        if not seen[user] then V.removeCircle(user) end
    end
    for user in pairs(V.outlines) do
        if not seen[user] then V.clearOutline(user) end
    end
end

function V.clearMembers()
    for user in pairs(V.circles) do V.removeCircle(user) end
    for user in pairs(V.outlines) do V.clearOutline(user) end
end

function V.tagColor(kind)
    if kind == "player" then return SquadManager.colors.playerTag end
    return SquadManager.colors.zombieTag
end

function V.resolveTag(tag)
    if tag.kind == "player" then
        local obj = V.plOf(tag.user)
        if obj and obj:isDead() then return nil end
        return obj
    end
    local sq = V.square(tag.x, tag.y, tag.z)
    if not sq then return nil end
    local ok, zed = pcall(function() return sq:getZombie() end)
    if not ok then return nil end
    return zed
end

function V.addTagRing(tag)
    if tag.ring or tag.obj then return end
    local markers = V.worldMarkers()
    local sq = V.square(tag.x, tag.y, tag.z)
    if not markers or not sq then return end
    local col = V.tagColor(tag.kind)
    local marker = markers:addGridSquareMarker("circle_center", "circle_only_highlight", sq,
        col.r, col.g, col.b, true, 0.8)
    tag.ring = marker
end

function V.removeTagRing(tag)
    if not tag.ring then return end
    V.drop(tag.ring)
    tag.ring = nil
end

function V.addTag(args)
    if type(args) ~= "table" then return nil end
    local id = tostring(args.id)
    local ttl = tonumber(args.ttl) or tonumber(SquadManager.configValue("TargetTagDuration")) or 8
    local tag = {
        id = id,
        kind = args.kind == "player" and "player" or "zombie",
        user = args.user,
        owner = args.owner,
        x = math.floor(tonumber(args.x) or 0),
        y = math.floor(tonumber(args.y) or 0),
        z = math.floor(tonumber(args.z) or 0),
        expire = V.now() + math.max(1, ttl),
        obj = nil,
        ring = nil,
    }
    local previous = V.tagObjs[id]
    if previous then V.removeTag(id) end
    V.tagObjs[id] = tag
    V.refreshTag(tag)
    if SquadManager.Map then SquadManager.Map.addTag(tag) end
    return tag
end

function V.refreshTag(tag)
    if not tag then return end
    local obj = V.resolveTag(tag)
    if tag.obj and tag.obj ~= obj then V.unhighlight(tag.obj) end
    tag.obj = obj
    if obj then
        V.removeTagRing(tag)
        V.highlight(obj, V.tagColor(tag.kind))
        return
    end
    V.addTagRing(tag)
end

function V.followTags()
    for _, tag in pairs(V.tagObjs) do
        if tag.kind == "player" and tag.obj and tag.obj:getSquare() then
            tag.x = math.floor(tag.obj:getX())
            tag.y = math.floor(tag.obj:getY())
            tag.z = math.floor(tag.obj:getZ())
        elseif tag.kind == "zombie" and tag.obj and not tag.obj:getSquare() then
            tag.obj = nil
        end
        V.refreshTag(tag)
    end
end

function V.removeTag(id)
    local key = tostring(id)
    local tag = V.tagObjs[key]
    SquadManager.tags[key] = nil
    if not tag then return end
    if tag.obj then V.unhighlight(tag.obj) end
    V.removeTagRing(tag)
    V.tagObjs[key] = nil
    if SquadManager.Map then SquadManager.Map.removeTag(key) end
end

function V.clearTags()
    for id in pairs(V.tagObjs) do V.removeTag(id) end
    V.tagObjs = {}
end

function V.expireTags()
    local stamp = V.now()
    for id, tag in pairs(V.tagObjs) do
        if stamp >= tag.expire then V.removeTag(id) end
    end
end

function V.clearActionCalls()
    for int = #V.timed, 1, -1 do
        local entry = V.timed[int]
        for _, item in ipairs(entry.objs) do V.drop(item.obj) end
        table.remove(V.timed, int)
    end
end

function V.expireActionCalls()
    local stamp = V.now()
    for int = #V.timed, 1, -1 do
        local entry = V.timed[int]
        if stamp >= entry.expire then
            for _, item in ipairs(entry.objs) do V.drop(item.obj) end
            table.remove(V.timed, int)
        else
            V.followCall(entry)
        end
    end
end

function V.followCall(entry)
    if not entry.follow then return end
    local obj = V.plOf(entry.follow)
    if not obj or not obj:getSquare() then return end
    local x = math.floor(obj:getX())
    local y = math.floor(obj:getY())
    local z = math.floor(obj:getZ())
    for _, item in ipairs(entry.objs) do
        if item.kind == "homing" then
            item.obj:setX(x)
            item.obj:setY(y)
        elseif item.kind == "arrow" then
            item.obj:setX(x)
            item.obj:setY(y)
            item.obj:setZ(z)
        end
    end
end

function V.callDuration()
    return math.max(1, tonumber(SquadManager.configValue("ActionCallVisualFadeDelay")) or 5)
end

function V.spawnCall(call, args)
    local markers = V.worldMarkers()
    local pl = getPlayer()
    if not markers or not pl or not call then return nil end
    args = type(args) == "table" and args or {}
    local x = math.floor(tonumber(args.x) or 0)
    local y = math.floor(tonumber(args.y) or 0)
    local z = math.floor(tonumber(args.z) or 0)
    local isLeader = args.leader == true
    local col = isLeader and SquadManager.colors.leader or SquadManager.colors.squad
    local urgent = call.urgent == true
    local entry = {
        expire = V.now() + V.callDuration() + (urgent and 5 or 0),
        follow = call.pin and args.user or nil,
        objs = {},
    }
    local kind = call.marker
    if kind == "homing" or kind == "rally" then
        local point = markers:addPlayerHomingPoint(pl, x, y, "arrow_triangle",
            col.r, col.g, col.b, 0.85, call.pin == true, 20)
        if point then entry.objs[#entry.objs + 1] = { obj = point, kind = "homing" } end
    end
    if kind == "arrow" then
        local ax = tonumber(args.tx) or x
        local ay = tonumber(args.ty) or y
        local az = tonumber(args.tz) or z
        local arrow = markers:addDirectionArrow(pl, math.floor(ax), math.floor(ay), math.floor(az),
            "arrow_triangle", col.r, col.g, col.b, 0.85)
        if arrow then entry.objs[#entry.objs + 1] = { obj = arrow, kind = "arrow" } end
    end
    if kind == "circle" or kind == "rally" then
        local sq = V.square(x, y, z)
        if sq then
            local size = urgent and 1.6 or 1.3
            local ring = markers:addGridSquareMarker("circle_center", "circle_only_highlight", sq,
                col.r, col.g, col.b, true, size)
            if ring then entry.objs[#entry.objs + 1] = { obj = ring, kind = "circle", size = size } end
        end
    end
    if #entry.objs > 0 then V.timed[#V.timed + 1] = entry end
    return entry
end

function V.refresh()
    V.refreshMembers()
    for _, tag in pairs(V.tagObjs) do V.refreshTag(tag) end
end

function V.clearAll()
    V.clearMembers()
    V.clearActionCalls()
end

function V.update()
    V.frame = V.frame + 1
    if V.frame < V.updateEvery then return end
    V.frame = 0
    if SquadManager.isActive() then
        V.refreshMembers()
    end
    V.followTags()
    V.expireTags()
    V.expireActionCalls()
end
Events.OnPlayerUpdate.Remove(V.update)
Events.OnPlayerUpdate.Add(V.update)

function V.expireAll()
    V.expireTags()
    V.expireActionCalls()
end
Events.OnTick.Remove(V.expireAll)
Events.OnTick.Add(V.expireAll)

function V.testCircle()
    local pl = getPlayer()
    if not pl then return "no player" end
    V.setCircle("__test__", pl:getX(), pl:getY(), pl:getZ(), false)
    return "circle added, V.clearMembers() to remove"
end

function V.testTag(kind)
    local pl = getPlayer()
    if not pl then return "no player" end
    V.addTag({
        id = "test" .. tostring(V.now()),
        kind = kind or "zombie",
        owner = SquadManager.username(),
        x = math.floor(pl:getX()) + 2,
        y = math.floor(pl:getY()) + 2,
        z = math.floor(pl:getZ()),
        ttl = 10,
    })
    return "tag added"
end

function V.testCall(index)
    local pl = getPlayer()
    if not pl then return "no player" end
    local call = SquadManager.actionCallByIndex(tonumber(index) or 1)
    if not call then return "unknown call index" end
    V.spawnCall(call, {
        x = pl:getX(), y = pl:getY(), z = pl:getZ(),
        user = SquadManager.username(),
        leader = call.leader == true,
    })
    return call.label .. " marker added"
end
