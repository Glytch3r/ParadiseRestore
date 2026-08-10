
WaveCaster = WaveCaster or {}
WaveCaster._tags = {}
function WaveCaster.addSqStr(str, x, y, z, r, g, b, font, xOffset, yOffset, visibility)
    if not isIngameState() then return nil end

    if x == nil or y == nil or z == nil then
        local player = getPlayer()
        if not player then return nil end
        local sq = player:getSquare()
        if not sq then return nil end
        x, y, z = sq:getX(), sq:getY(), sq:getZ()
    end

    r, g, b = r or 1, g or 1, b or 1
    font = font or UIFont.NewLarge
    xOffset = xOffset or 0
    yOffset = yOffset or 0
    visibility = visibility or 360

    local tag = TextDrawObject.new()
    tag:setDefaultFont(font)
    tag:ReadString(font, tostring(str), -1)
    tag:setDefaultColors(r, g, b)
    tag:setVisibleRadius(visibility)

    WaveCaster._tags[tag] = {
        x = x, y = y, z = z,
        r = r, g = g, b = b,
        xOffset = xOffset, yOffset = yOffset
    }
    return tag
end


function WaveCaster.delTagObj(tagObj)
    if WaveCaster._tags[tagObj] then
        WaveCaster._tags[tagObj] = nil
        return true
    end
    return false
end

function WaveCaster.delSqStr(x, y, z)
    for tag, data in pairs(WaveCaster._tags) do
        if data.x == x and data.y == y and data.z == z then
            WaveCaster._tags[tag] = nil
            return true
        end
    end
    return false
end



function WaveCaster.getSqStr(x, y, z)
    for tag, data in pairs(WaveCaster._tags) do
        if data.x == x and data.y == y and data.z == z then
            return tag
        end
    end
    return nil
end

function WaveCaster.tags()
    return WaveCaster._tags
end

function WaveCaster.clearAllTags()
    for tag in pairs(WaveCaster._tags) do
        WaveCaster._tags[tag] = nil
    end
end

function WaveCaster.renderAllTags()
    if not isIngameState() then return end
    local zoom = getCore():getZoom(0)
    for tag, data in pairs(WaveCaster._tags) do
        local screenX = (IsoUtils.XToScreen(data.x + data.xOffset, data.y, data.z, 0) - IsoCamera.getOffX()) / zoom 
        local screenY = (IsoUtils.YToScreen(data.x + data.yOffset, data.y, data.z, 0) - IsoCamera.getOffY()) / zoom
        tag:AddBatchedDraw(screenX, screenY, data.r, data.g, data.b, 1, false)
    end
end
Events.OnPostRender.Remove(WaveCaster.renderAllTags)
Events.OnPostRender.Add(WaveCaster.renderAllTags)

-----------------------            ---------------------------

