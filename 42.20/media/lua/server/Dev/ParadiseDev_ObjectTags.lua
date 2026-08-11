ParadiseDev = ParadiseDev or {}
ParadiseDev.ObjectTags = ParadiseDev.ObjectTags or {}



ParadiseDev.ObjectTags.module = "ParadiseDevObjectTags"
ParadiseDev.ObjectTags.key = "ParadiseDevObjectTag"
ParadiseDev.ObjectTags.maxLength = 96

function ParadiseDev.ObjectTags.normalizeTag(tag)
    if tag == nil then return nil end
    tag = tostring(tag):gsub("[\r\n]+", " ")
    tag = tag:match("^%s*(.-)%s*$")
    if tag == "" then return nil end
    return string.sub(tag, 1, ParadiseDev.ObjectTags.maxLength)
end

function ParadiseDev.ObjectTags.getObject(args)
    if type(args) ~= "table" then return nil end
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z)
    local index = tonumber(args.index)
    if not x or not y or not z or not index then return nil end
    if x ~= math.floor(x) or y ~= math.floor(y) or z ~= math.floor(z) or index ~= math.floor(index) then return nil end
    local cell = getCell and getCell() or nil
    local sq = cell and cell:getGridSquare(x, y, z) or nil
    local objects = sq and sq:getObjects() or nil
    if not objects or index < 0 or index >= objects:size() then return nil end
    return objects:get(index)
end

function ParadiseDev.ObjectTags.setTag(obj, tag)
    if not obj or not obj.getModData then return false end
    obj:getModData()[ParadiseDev.ObjectTags.key] = ParadiseDev.ObjectTags.normalizeTag(tag)
    if obj.transmitModData then obj:transmitModData() end
    return true
end

function ParadiseDev.ObjectTags.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.ObjectTags.module or command ~= "set" or not ParadiseDev.isAdm(pl) then return end
    local obj = ParadiseDev.ObjectTags.getObject(args)
    if not obj then return end
    ParadiseDev.ObjectTags.setTag(obj, args.tag)
end

Events.OnClientCommand.Remove(ParadiseDev.ObjectTags.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.ObjectTags.onClientCommand)
