
ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.Highlight = ParadiseRestore.Highlight or {}
ParadiseRestore.Highlight.objs = ParadiseRestore.Highlight.objs or setmetatable({}, { __mode = "k" })

function ParadiseRestore.Highlight.apply(obj)
    local pl = getPlayer()
    if not obj or not pl then return false end
    if not instanceof(obj, "IsoObject") then return false end

    local plNum = pl:getPlayerNum()

    obj:setHighlightColor(plNum, 0, 0.3, 1, 1)
    obj:setHighlighted(plNum, true, false)
    obj:setOutlineHighlightCol(plNum, 0, 0.3, 1, 1)
    obj:setOutlineHighlight(plNum, true)

    return true
end

function ParadiseRestore.Highlight.set(obj)
    if not ParadiseRestore.Highlight.apply(obj) then return false end
    ParadiseRestore.Highlight.objs[obj] = true
    return true
end

function ParadiseRestore.Highlight.clear(obj)
    local pl = getPlayer()
    if not obj or not pl then return false end
    if not instanceof(obj, "IsoObject") then return false end

    local plNum = pl:getPlayerNum()

    obj:setHighlighted(plNum, false, false)
    obj:setOutlineHighlight(plNum, false)
    ParadiseRestore.Highlight.objs[obj] = nil

    return true
end

function ParadiseRestore.Highlight.clearAll()
    for obj in pairs(ParadiseRestore.Highlight.objs) do
        ParadiseRestore.Highlight.clear(obj)
    end
end

function ParadiseRestore.Highlight.update()
    for obj in pairs(ParadiseRestore.Highlight.objs) do
        if obj:getSquare() then
            ParadiseRestore.Highlight.apply(obj)
        else
            ParadiseRestore.Highlight.objs[obj] = nil
        end
    end
end
--Events.OnTick.Remove(ParadiseRestore.Highlight.update)
--Events.OnTick.Add(ParadiseRestore.Highlight.update)
