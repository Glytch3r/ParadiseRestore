ParadiseDev = ParadiseDev or {}
ParadiseDev.Notes = ParadiseDev.Notes or {}



ParadiseDev.Notes.module = "ParadiseDevNotes"
ParadiseDev.Notes.key = "ParadiseDevNote"
ParadiseDev.Notes.maxLength = 160

function ParadiseDev.Notes.normalizeNote(note)
    if note == nil then return nil end
    note = tostring(note):gsub("[\r\n]+", " ")
    note = note:match("^%s*(.-)%s*$")
    if note == "" then return nil end
    return string.sub(note, 1, ParadiseDev.Notes.maxLength)
end

function ParadiseDev.Notes.getFloor(args)
    if type(args) ~= "table" then return nil end
    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z)
    if not x or not y or not z then return nil end
    if x ~= math.floor(x) or y ~= math.floor(y) or z ~= math.floor(z) then return nil end
    local cell = getCell and getCell() or nil
    local sq = cell and cell:getGridSquare(x, y, z) or nil
    return sq and sq:getFloor() or nil
end

function ParadiseDev.Notes.setNote(floor, note)
    if not floor or not floor.getModData then return false end
    floor:getModData()[ParadiseDev.Notes.key] = ParadiseDev.Notes.normalizeNote(note)
    if floor.transmitModData then floor:transmitModData() end
    return true
end

function ParadiseDev.Notes.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.Notes.module or command ~= "set" then return end
    local floor = ParadiseDev.Notes.getFloor(args)
    if not floor then return end
    ParadiseDev.Notes.setNote(floor, args.note)
end

Events.OnClientCommand.Remove(ParadiseDev.Notes.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Notes.onClientCommand)
