ParadiseDev = ParadiseDev or {}
ParadiseDev.UI = ParadiseDev.UI or {}

local UI = ParadiseDev.UI

local function call(element, method, fallback)
    if not element or not element[method] then return fallback end
    local ok, value = pcall(element[method], element)
    return ok and value or fallback
end

function UI.describe(element, rootIndex, parent, childIndex)
    return {
        element = element,
        rootIndex = rootIndex,
        parent = parent,
        childIndex = childIndex,
        name = call(element, "getUIName", tostring(element)),
        visible = call(element, "isVisible", false),
        x = call(element, "getAbsoluteX", call(element, "getX", 0)),
        y = call(element, "getAbsoluteY", call(element, "getY", 0)),
        width = call(element, "getWidth", 0),
        height = call(element, "getHeight", 0),
    }
end

function UI.collectChildren(results, element, rootIndex, includeHidden)
    local controls = call(element, "getControls", nil)
    if not controls or not controls.size or not controls.get then return end

    for index = 0, controls:size() - 1 do
        local child = controls:get(index)
        if child and (includeHidden or call(child, "isVisible", false)) then
            results[#results + 1] = UI.describe(child, rootIndex, element, index)
            UI.collectChildren(results, child, rootIndex, includeHidden)
        end
    end
end

function UI.getOpen(includeHidden)
    local results = {}
    if not UIManager or not UIManager.getUI then return results end

    local roots = UIManager.getUI()
    if not roots or not roots.size or not roots.get then return results end

    for index = 0, roots:size() - 1 do
        local element = roots:get(index)
        if element and (includeHidden or call(element, "isVisible", false)) then
            results[#results + 1] = UI.describe(element, index, nil, nil)
            UI.collectChildren(results, element, index, includeHidden)
        end
    end

    return results
end

function UI.printOpen(includeHidden)
    for _, entry in ipairs(UI.getOpen(includeHidden)) do
        print(string.format(
            "[ParadiseDev.UI] root=%d child=%s %s visible=%s x=%s y=%s w=%s h=%s",
            entry.rootIndex,
            tostring(entry.childIndex),
            tostring(entry.name),
            tostring(entry.visible),
            tostring(entry.x), tostring(entry.y),
            tostring(entry.width), tostring(entry.height)
        ))
    end
end
