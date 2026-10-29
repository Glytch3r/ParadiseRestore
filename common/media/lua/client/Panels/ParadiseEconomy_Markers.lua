ParadiseEconomy = ParadiseEconomy or {}

ParadiseEconomy.SquareMarkerOverlay = ISUIElement:derive("ParadiseEconomySquareMarkerOverlay")

function ParadiseEconomy.SquareMarkerOverlay:new(x, y, w, h)
    local o = ISUIElement:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.wantMouseEvents = false
    o.forceCursorVisible = false
    return o
end

-- Native right-click dispatch consumes nil even when mouse consumption is disabled.
-- Match ISToolTip so this drawing overlay passes both right-click events.
function ParadiseEconomy.SquareMarkerOverlay:onRightMouseDown(x, y)
    return false
end

function ParadiseEconomy.SquareMarkerOverlay:onRightMouseUp(x, y)
    return false
end

function ParadiseEconomy.SquareMarkerOverlay:update()
    local width, height = getCore():getScreenWidth(), getCore():getScreenHeight()
    if self.width ~= width then self:setWidth(width) end
    if self.height ~= height then self:setHeight(height) end
end

function ParadiseEconomy.collectMarkerGroups()
    local groups = {}
    local pl = getPlayer()
    local state = ParadiseEconomy.clientState
    if not pl or not state then return groups end
    local px, py, pz = pl:getX(), pl:getY(), math.floor(pl:getZ())
    local maxDistSq = 35 * 35
    for _, shop in ipairs(state.shops or {}) do
        local x, y, z = tonumber(shop.x), tonumber(shop.y), math.floor(tonumber(shop.z) or 0)
        if x and y and z == pz then
            local dx, dy = x + 0.5 - px, y + 0.5 - py
            if dx * dx + dy * dy <= maxDistSq then
                local sx, sy = math.floor(x), math.floor(y)
                local key = tostring(sx) .. ":" .. tostring(sy) .. ":" .. tostring(z)
                local group = groups[key]
                if not group then
                    group = { x = sx, y = sy, z = z, stores = 0, marts = 0, anyOpen = false }
                    groups[key] = group
                end
                if shop.kind == "store" then
                    group.stores = group.stores + 1
                    group.title = group.title or tostring(shop.title or shop.id or "Store")
                    if not shop.closed then group.anyOpen = true end
                elseif shop.kind == "mart" then
                    group.marts = group.marts + 1
                    group.title = group.title or tostring(shop.title or shop.id or "Mart")
                    group.anyOpen = true
                end
            end
        end
    end
    return groups
end

function ParadiseEconomy.getMarkerLabel(group)
    local function kindLabel(count, one, many)
        if count <= 0 then return nil end
        if count == 1 then return one end
        return many .. " x" .. tostring(count)
    end
    local storeLabel = kindLabel(group.stores, "STORE", "STORES")
    local martLabel = kindLabel(group.marts, "MART", "MARTS")
    local label = storeLabel and martLabel and (storeLabel .. " | " .. martLabel)
        or storeLabel or martLabel or "SHOP"
    if group.stores + group.marts == 1 and group.title then
        label = label .. " | " .. group.title
        if not group.anyOpen then label = label .. " (closed)" end
    end
    if ParadiseEconomy.fitText then return ParadiseEconomy.fitText(label, 190, UIFont.Small) end
    return label
end

function ParadiseEconomy.getMarkerTint(group)
    if group.stores > 0 and group.marts > 0 then return { r = 0.86, g = 0.92, b = 0.96 } end
    if group.marts > 0 then
        local accent = ParadiseEconomy.Theme and ParadiseEconomy.Theme.accent or nil
        return accent or { r = 0.35, g = 0.78, b = 0.82 }
    end
    return { r = 0.95, g = 0.78, b = 0.30 }
end

function ParadiseEconomy.SquareMarkerOverlay:render()
    if not isIngameState() then return end
    if not ParadiseEconomy.isEnabled() then return end
    local pl = getPlayer()
    if not pl then return end
    local groups = ParadiseEconomy.collectMarkerGroups()
    local zoom = getCore():getZoom(pl:getPlayerNum()) or 1.0
    if zoom == 0 then zoom = 1.0 end
    local screenW, screenH = getCore():getScreenWidth(), getCore():getScreenHeight()
    local textManager = getTextManager()
    for _, group in pairs(groups) do
        local sx = (IsoUtils.XToScreen(group.x + 0.5, group.y + 0.5, group.z, 0) - IsoCamera.getOffX()) / zoom
        local sy = (IsoUtils.YToScreen(group.x + 0.5, group.y + 0.5, group.z, 0) - IsoCamera.getOffY()) / zoom
        local label = ParadiseEconomy.getMarkerLabel(group)
        local tint = ParadiseEconomy.getMarkerTint(group)
        local pillW = textManager:MeasureStringX(UIFont.Small, label) + 26
        local pillH = 16
        local x, y = sx - pillW / 2, sy - 24
        if x + pillW >= 0 and x <= screenW and y + pillH >= 0 and y <= screenH then
            local pillAlpha = group.anyOpen and 0.82 or 0.55
            local textAlpha = group.anyOpen and 1 or 0.65
            self:drawRect(x, y, pillW, pillH, pillAlpha, 0.03, 0.045, 0.06)
            self:drawRectBorder(x, y, pillW, pillH, 0.9, tint.r, tint.g, tint.b)
            self:drawRect(x + 6, y + 4, 8, 8, 1, tint.r, tint.g, tint.b)
            self:drawText(label, x + 19, y + 1, 1, 1, 1, textAlpha, UIFont.Small)
        end
    end
end

function ParadiseEconomy.createMarkerOverlay()
    if not ParadiseEconomy.isEnabled() then return end
    if ParadiseEconomy.markerOverlay then return end
    local overlay = ParadiseEconomy.SquareMarkerOverlay:new(0, 0,
        getCore():getScreenWidth(), getCore():getScreenHeight())
    overlay:initialise()
    overlay:addToUIManager()
    ParadiseEconomy.markerOverlay = overlay
end
Events.OnCreatePlayer.Remove(ParadiseEconomy.createMarkerOverlay)
Events.OnCreatePlayer.Add(ParadiseEconomy.createMarkerOverlay)
