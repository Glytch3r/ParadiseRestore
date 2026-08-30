ParadiseDev = ParadiseDev or {}
ParadiseDev.Visual = ParadiseDev.Visual or {}

local Visual = ParadiseDev.Visual

Visual.hidden = Visual.hidden or setmetatable({}, { __mode = "k" })

function Visual.getTarget(target)
    if type(target) == "string" and ParadiseDev.getTarg then
        target = ParadiseDev.getTarg(target)
    end

    if not target then return nil end
    if instanceof(target, "IsoPlayer") or instanceof(target, "IsoZombie") then
        return target
    end

    return nil
end

function Visual.hide(target)
    target = Visual.getTarget(target)
    if not target or not target.getItemVisuals then return nil end
    if Visual.hidden[target] then return target end

    local visuals = target:getItemVisuals()
    if not visuals then return nil end

    local saved = { visuals = {}, worn = {} }
    for index = 0, visuals:size() - 1 do
        saved.visuals[#saved.visuals + 1] = visuals:get(index)
    end

    local worn = target.getWornItems and target:getWornItems() or nil
    if worn then
        for index = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(index)
            saved.worn[#saved.worn + 1] = { item = item, location = worn:getLocation(item) }
        end
        worn:clear()
    end

    Visual.hidden[target] = saved
    visuals:clear()

    if target.onWornItemsChanged then target:onWornItemsChanged() end
    if target.resetModelNextFrame then target:resetModelNextFrame() end
    return target
end

function Visual.replace(target)
    target = Visual.getTarget(target)
    if not target or not target.getItemVisuals then return nil end

    local saved = Visual.hidden[target]
    if not saved then return nil end

    local visuals = target:getItemVisuals()
    if not visuals then return nil end

    visuals:clear()
    for index = 1, #(saved.visuals or saved) do
        visuals:add((saved.visuals or saved)[index])
    end

    local worn = target.getWornItems and target:getWornItems() or nil
    if worn and saved.worn then
        worn:clear()
        for index = 1, #saved.worn do
            local entry = saved.worn[index]
            if entry.item and entry.location then worn:setItem(entry.location, entry.item) end
        end
    end

    Visual.hidden[target] = nil
    if target.onWornItemsChanged then target:onWornItemsChanged() end
    if target.resetModelNextFrame then target:resetModelNextFrame() end
    return target
end
