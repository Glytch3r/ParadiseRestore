ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.Placement = ParadisePOIBuilder.Placement or {}
if ParadisePOIBuilder.isB41() then return end

local P = ParadisePOIBuilder
local L = P.Placement

L.VISIBLE_RADIUS = 80
L.GHOST_CALL_CAP = 1500
L.ALPHA = 0.6
L.SCAN_INTERVAL_MS = 1000

L.cursor = nil
L.dragCell = nil
L.origin = nil
L.blueprint = nil
L.groups = nil
L.vetoReason = nil
L.nextScanAt = 0
L.onLock = nil
L.onScan = nil

L.Cursor = {}
L.Cursor.__index = L.Cursor

function L.Cursor:init()
    self.isLeftDown = false
    self.canBeBuild = false
    self.build = false
    self.square = nil
    self.north = false
    self.partialPreview = false
end

function L.Cursor:initialise()
    self:init()
    self.sprite = "cursor_16_16"
    self.chosenSprite = "cursor_16_16"
    self.spriteCache = {}
    self.skipBuildAction = true
    self.noNeedHammer = true
    self.skipWalk2 = true
end

function L.Cursor:new(player)
    local o = {}
    setmetatable(o, self)
    o:initialise()
    o.character = player
    o.player = player:getPlayerNum()
    return o
end

function L.Cursor:getSprite()
    return "cursor_16_16"
end

function L.Cursor:rotateMouse(x, y)
end

function L.Cursor:walkTo(x, y, z)
    return true
end

function L.Cursor:reinit()
    self:init()
end

function L.Cursor:update()
end

function L.Cursor:deactivate()
end

function L.Cursor:getAPrompt()
    if self.canBeBuild then return getText("ContextMenu_Build") end
    return nil
end

function L.Cursor:getBPrompt()
    return getText("UI_Cancel")
end

function L.Cursor:getYPrompt()
    return nil
end

function L.Cursor:getLBPrompt()
    return nil
end

function L.Cursor:getRBPrompt()
    return nil
end

function L.Cursor:onJoypadPressButton(joypadIndex, joypadData, button)
end

function L.Cursor:onJoypadDirUp(joypadData)
end

function L.Cursor:onJoypadDirDown(joypadData)
end

function L.Cursor:onJoypadDirLeft(joypadData)
end

function L.Cursor:onJoypadDirRight(joypadData)
end

function L.Cursor:isValid(square)
    if L.origin then return false end
    if not L.blueprint then return false end
    return square ~= nil
end

function L.Cursor:create(x, y, z, north, sprite)
    L.lock(x, y, z)
end

function L.Cursor:tryBuild(x, y, z)
    L.lock(x, y, z)
end

function L.Cursor:render(x, y, z, square)
    local groups = L.groups
    if not groups then return end

    local player = getSpecificPlayer(self.player)
    if not player then return end
    local px, py = player:getX(), player:getY()
    local playerZ = math.floor(player:getZ())

    local origin = L.origin
    if not origin then
        origin = { x = x, y = y, z = z or playerZ }
    end

    self.partialPreview = false
    local calls = 0
    local cap = L.GHOST_CALL_CAP
    local radiusSq = L.VISIBLE_RADIUS * L.VISIBLE_RADIUS
    local good = getCore():getGoodHighlitedColor()
    local bad = getCore():getBadHighlitedColor()
    local gr, gg, gb = good:getR(), good:getG(), good:getB()
    local br, bg, bb = bad:getR(), bad:getG(), bad:getB()
    local cell = getCell()
    local blocked = {}

    local order = { playerZ, playerZ + 1, playerZ - 1 }
    for oi = 1, #order do
        local worldZ = order[oi]
        local group = groups[worldZ - origin.z]
        if group then
            for i = 1, #group do
                local rec = group[i]
                local ax = origin.x + rec.x
                local ay = origin.y + rec.y
                local offX = ax - px
                local offY = ay - py
                if (offX * offX + offY * offY) <= radiusSq then
                    if calls >= cap then
                        self.partialPreview = true
                        return
                    end
                    local key = ax .. "," .. ay .. "," .. worldZ
                    local hit = blocked[key]
                    if hit == nil then
                        local sq = cell:getGridSquare(ax, ay, worldZ)
                        hit = false
                        if sq then hit = sq:isVehicleIntersecting() end
                        blocked[key] = hit
                    end
                    local r, g, b = gr, gg, gb
                    if hit then r, g, b = br, bg, bb end
                    local sprite = self.spriteCache[rec.s]
                    if not sprite then
                        sprite = getSprite(rec.s)
                        self.spriteCache[rec.s] = sprite
                    end
                    if sprite then
                        sprite:RenderGhostTileColor(ax, ay, worldZ, 0, 0, r, g, b, L.ALPHA)
                        calls = calls + 1
                    end
                end
            end
        end
    end
end

function L.setBlueprint(bp)
    L.blueprint = bp
    L.groups = nil
    L.origin = nil
    L.vetoReason = nil
    L.nextScanAt = 0
    if not bp then return end

    local groups = {}
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
        local key = keys[i]
        local dx, dy, dz = P.parseSquareKey(key)
        if dx then
            local sq = bp.squares[key]
            local group = groups[dz]
            if not group then
                group = {}
                groups[dz] = group
            end
            local objects = sq.objects or {}
            for j = 1, #objects do
                local rec = objects[j]
                if rec.s then
                    group[#group + 1] = { x = dx, y = dy, s = rec.s }
                end
            end
        end
    end
    L.groups = groups
end

function L.lock(x, y, z)
    L.origin = { x = x, y = y, z = z }
    L.nextScanAt = 0
    L.vehicleScan()
    if L.onLock then L.onLock(L.origin) end
    return L.origin
end

function L.unlock()
    L.origin = nil
    L.vetoReason = nil
    L.nextScanAt = 0
end

function L.isLocked()
    return L.origin ~= nil
end

function L.clearDrag(plNum)
    if L.dragCell then
        L.dragCell:setDrag(nil, plNum)
        L.dragCell = nil
    end
end

function L.install()
    local player = getPlayer()
    if not player then return nil end
    local plNum = player:getPlayerNum()
    local cell = getCell()
    if L.cursor and L.dragCell == cell and cell:getDrag(plNum) == L.cursor then return L.cursor end
    L.clearDrag(plNum)
    local cursor = L.Cursor:new(player)
    L.cursor = cursor
    L.dragCell = cell
    cell:setDrag(cursor, plNum)
    return cursor
end

function L.release()
    local plNum = nil
    local player = getPlayer()
    if player then
        plNum = player:getPlayerNum()
    elseif L.cursor then
        plNum = L.cursor.player
    end
    if plNum then L.clearDrag(plNum) end
    L.cursor = nil
    L.origin = nil
    L.vetoReason = nil
    L.nextScanAt = 0
end

function L.vehicleScan()
    local reason = L.doVehicleScan()
    if L.onScan then L.onScan(reason) end
    return reason
end

function L.doVehicleScan()
    L.vetoReason = nil
    local origin = L.origin
    local bp = L.blueprint
    if not origin or not bp then return nil end

    local size = bp.size or {}
    local dx = tonumber(size.dx) or 0
    local dy = tonumber(size.dy) or 0
    local dz = tonumber(size.dz) or 0
    if dx <= 0 or dy <= 0 or dz <= 0 then return nil end

    local cell = getCell()
    local hits = 0
    local firstX, firstY, firstZ
    local unresolved = 0
    for z = origin.z, origin.z + dz - 1 do
        for y = origin.y, origin.y + dy - 1 do
            for x = origin.x, origin.x + dx - 1 do
                local sq = cell:getGridSquare(x, y, z)
                if not sq then
                    unresolved = unresolved + 1
                elseif sq:isVehicleIntersecting() then
                    if hits == 0 then
                        firstX, firstY, firstZ = x, y, z
                    end
                    hits = hits + 1
                end
            end
        end
    end

    if hits > 0 then
        L.vetoReason = string.format("Cannot build: vehicle collision at %d, %d, %d.", firstX, firstY, firstZ)
    elseif unresolved > 0 then
        L.vetoReason = string.format("Cannot build: %d squares are not loaded.", unresolved)
    end
    return L.vetoReason
end

function L.statusText()
    local bp = L.blueprint
    if not bp then return nil end
    if L.vetoReason then return L.vetoReason end
    local size = bp.size or {}
    local levels = (tonumber(size.dz) or 0)
    local count = 0
    for _, sq in pairs(bp.squares or {}) do
        count = count + #(sq.objects or {})
    end
    return string.format("Ready to build. %s objects, %d levels.", tostring(count), levels)
end

function L.tick()
    local player = getPlayer()
    if player and L.cursor and not L.origin then
        local plNum = player:getPlayerNum()
        local cell = getCell()
        if cell:getDrag(plNum) ~= L.cursor then
            L.clearDrag(plNum)
            L.dragCell = cell
            cell:setDrag(L.cursor, plNum)
        end
    end
    if not L.origin then return end
    local now = getTimestampMs()
    if now < L.nextScanAt then return end
    L.nextScanAt = now + L.SCAN_INTERVAL_MS
    L.vehicleScan()
end
Events.OnTick.Remove(L.tick)
Events.OnTick.Add(L.tick)

function L.onGameStart()
    L.release()
    L.setBlueprint(nil)
end
Events.OnGameStart.Remove(L.onGameStart)
Events.OnGameStart.Add(L.onGameStart)
