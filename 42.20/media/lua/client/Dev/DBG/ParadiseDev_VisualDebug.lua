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

    local visuals = target:getItemVisuals()
    if not visuals then return nil end

    local saved = {}
    for index = 0, visuals:size() - 1 do
        saved[#saved + 1] = visuals:get(index)
    end

    Visual.hidden[target] = saved
    visuals:clear()

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
    for index = 1, #saved do
        visuals:add(saved[index])
    end

    Visual.hidden[target] = nil
    if target.resetModelNextFrame then target:resetModelNextFrame() end
    return target
end
