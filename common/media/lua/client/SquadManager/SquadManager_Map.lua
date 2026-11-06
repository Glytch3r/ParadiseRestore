if not isClient() then return end

SquadManager = SquadManager or {}
if not SquadManager.isB41 then require "SquadManager/SquadManager_Shared" end
if SquadManager.isB41() then return end

SquadManager.Map = SquadManager.Map or {}

local M = SquadManager.Map
M.tags = M.tags or {}
M.installed = false
M.dotSize = 6
M.memberRing = 9
M.tagRing = 12
M.labelRing = 14

local circle = {}
for index = 1, 20 do
    local angle = (math.pi * 2 * index) / 20
    circle[index] = { math.cos(angle), math.sin(angle) }
end

function M.api(map)
    return map and map.mapAPI or nil
end

function M.toUI(api, x, y)
    local uiX = api:worldToUIX(x, y)
    local uiY = api:worldToUIY(x, y)
    if not uiX or not uiY then return nil end
    return uiX, uiY
end

function M.memberPos(entry)
    local obj = entry.user and SquadManager.Visuals and SquadManager.Visuals.plOf(entry.user) or nil
    if obj and obj:getSquare() then
        return obj:getX(), obj:getY()
    end
    if not entry.x or not entry.y then return nil end
    return entry.x, entry.y
end

function M.dot(map, cx, cy, col, size)
    local side = size or M.dotSize
    map:drawRect(cx - side / 2, cy - side / 2, side, side, col.a or 0.95, col.r, col.g, col.b)
end

function M.ring(map, cx, cy, radius, col)
    local lastX, lastY = cx + radius, cy
    for _, point in ipairs(circle) do
        local nextX = cx + point[1] * radius
        local nextY = cy + point[2] * radius
        M.line(map, lastX, lastY, nextX, nextY, col)
        lastX, lastY = nextX, nextY
    end
end

function M.line(map, x1, y1, x2, y2, col)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length <= 0 then return end
    local half = 1.2
    local nx, ny = -dy / length * half, dx / length * half
    map:drawPolygon(nil, x1 + nx, y1 + ny, x2 + nx, y2 + ny,
        x2 - nx, y2 - ny, x1 - nx, y1 - ny, col.r, col.g, col.b, col.a or 0.9)
end

function M.triangle(map, cx, cy, radius, col)
    local top = cy - radius
    local base = cy + radius * 0.6
    local spread = radius * 0.9
    map:drawPolygon(nil, cx, top, cx - spread, base, cx + spread, base,
        cx + spread, base, col.r, col.g, col.b, col.a or 0.95)
end

function M.label(map, text, cx, cy, col)
    if not text or text == "" then return end
    map:drawText(tostring(text), cx + M.labelRing, cy - 6, col.r, col.g, col.b, 0.95, UIFont.Small)
end

function M.drawMembers(map, mini)
    local api = M.api(map)
    if not api then return end
    local squad = SquadManager.getSquad()
    if not squad then return end
    for _, entry in ipairs(SquadManager.members) do
        if entry.user and entry.user ~= "" then
            local x, y = M.memberPos(entry)
            if x then
                local cx, cy = M.toUI(api, x, y)
                if cx then
                    local isLeader = squad.leader == entry.user
                    local col = isLeader and SquadManager.colors.leader or SquadManager.colors.squad
                    col = { r = col.r, g = col.g, b = col.b, a = 0.9 }
                    if isLeader then
                        M.triangle(map, cx, cy, M.memberRing * 0.8, col)
                    else
                        M.ring(map, cx, cy, M.memberRing, col)
                    end
                    M.dot(map, cx, cy, col, mini and 5 or M.dotSize)
                    if not mini then M.label(map, entry.user, cx, cy, col) end
                end
            end
        end
    end
end

function M.drawTags(map)
    local api = M.api(map)
    if not api then return end
    for _, tag in pairs(M.tags) do
        local cx, cy = M.toUI(api, tag.x, tag.y)
        if cx then
            local col = SquadManager.Visuals and SquadManager.Visuals.tagColor(tag.kind) or SquadManager.colors.playerTag
            col = { r = col.r, g = col.g, b = col.b, a = 0.85 }
            M.ring(map, cx, cy, M.tagRing, col)
            M.dot(map, cx, cy, col, 5)
            if tag.kind == "player" and tag.user then M.label(map, tag.user, cx, cy, col) end
        end
    end
end

function M.draw(map, clip, mini)
    if not map or not map.mapAPI then return end
    M.drawTags(map)
    if SquadManager.isActive() then M.drawMembers(map, mini) end
end

function M.addTag(tag)
    if not tag or not tag.id then return end
    M.tags[tag.id] = tag
end

function M.removeTag(id)
    M.tags[tostring(id)] = nil
end

function M.clearTags()
    M.tags = {}
end

function M.refresh()
end

function M.clearAll(keepTags)
    if not keepTags then M.clearTags() end
end

function M.install()
    if M.installed then return end
    if not ParadiseDev or not ParadiseDev.Map or not ParadiseDev.Map.addOverlayHook then return end
    M.installed = ParadiseDev.Map.addOverlayHook(M.draw) == true
end

function M.uninstall()
    if not M.installed then return end
    ParadiseDev.Map.removeOverlayHook(M.draw)
    M.installed = false
end

function M.onGameStart()
    M.uninstall()
    M.install()
end
Events.OnGameStart.Remove(M.onGameStart)
Events.OnGameStart.Add(M.onGameStart)

function M.onMainMenuEnter()
    M.clearTags()
end
Events.OnMainMenuEnter.Remove(M.onMainMenuEnter)
Events.OnMainMenuEnter.Add(M.onMainMenuEnter)

function M.test()
    local pl = getPlayer()
    if not pl then return "no player" end
    M.addTag({ id = "test", kind = "zombie", x = math.floor(pl:getX()) + 6, y = math.floor(pl:getY()) + 6 })
    return "tag drawn, M.clearTags() to remove"
end
