ParadiseDev = ParadiseDev or {}
ParadiseDev.Notes = ParadiseDev.Notes or {}

ParadiseDev.Notes.module = "ParadiseDevNotes"
ParadiseDev.Notes.key = "ParadiseDevNote"
ParadiseDev.Notes.colorKey = "ParadiseDevNoteColor"
ParadiseDev.Notes.ownerKey = "ParadiseDevNoteOwner"
ParadiseDev.Notes.globalStore = "ParadiseDev_GlobalNotes"
ParadiseDev.Notes.maxLength = 160

function ParadiseDev.Notes.getMaxLength()
    local value = SandboxVars and SandboxVars.ParadiseZnotes and tonumber(SandboxVars.ParadiseZnotes.NotesMaxLineWidth) or ParadiseDev.Notes.maxLength
    return math.max(1, math.min(1000, math.floor(value or ParadiseDev.Notes.maxLength)))
end

function ParadiseDev.Notes.normalizeNote(note)
    if note == nil then return nil end
    note = tostring(note):gsub("[\r\n]+", " ")
    note = note:match("^%s*(.-)%s*$")
    if note == "" then return nil end
    return string.sub(note, 1, ParadiseDev.Notes.getMaxLength())
end

function ParadiseDev.Notes.normalizeColor(color)
    color = type(color) == "table" and color or {}
    local function channel(value, fallback)
        value = tonumber(value) or fallback
        return math.max(0, math.min(1, value))
    end
    return { r = channel(color.r, 1), g = channel(color.g, 0.85), b = channel(color.b, 0.2) }
end

function ParadiseDev.Notes.getFloor(args)
    if type(args) ~= "table" then return nil end
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not x or not y or not z or x ~= math.floor(x) or y ~= math.floor(y) or z ~= math.floor(z) then return nil end
    local cell = getCell and getCell() or nil
    local sq = cell and cell:getGridSquare(x, y, z) or nil
    return sq and sq:getFloor() or nil
end

function ParadiseDev.Notes.getUsername(pl)
    pl = pl or (getPlayer and getPlayer() or nil)
    return pl and pl.getUsername and tostring(pl:getUsername()) or nil
end

function ParadiseDev.Notes.isAdmin(pl)
    return ParadiseDev.isAdm and ParadiseDev.isAdm(pl) or false
end

function ParadiseDev.Notes.canModifyFloor(pl, floor)
    local owner = floor and floor.getModData and floor:getModData()[ParadiseDev.Notes.ownerKey] or nil
    return not owner or ParadiseDev.Notes.isAdmin(pl) or tostring(owner) == ParadiseDev.Notes.getUsername(pl)
end

function ParadiseDev.Notes.setNote(floor, note, color, owner)
    if not floor or not floor.getModData then return false end
    local md = floor:getModData()
    note = ParadiseDev.Notes.normalizeNote(note)
    md[ParadiseDev.Notes.key] = note
    if note then
        md[ParadiseDev.Notes.colorKey] = ParadiseDev.Notes.normalizeColor(color or md[ParadiseDev.Notes.colorKey])
        md[ParadiseDev.Notes.ownerKey] = md[ParadiseDev.Notes.ownerKey] or owner or ParadiseDev.Notes.getUsername()
    else
        md[ParadiseDev.Notes.colorKey] = nil
        md[ParadiseDev.Notes.ownerKey] = nil
    end
    if floor.transmitModData then floor:transmitModData() end
    return true
end

function ParadiseDev.Notes.getGlobalStore()
    local store = ModData.getOrCreate(ParadiseDev.Notes.globalStore)
    store.notes = store.notes or {}
    return store
end

function ParadiseDev.Notes.globalKey(args)
    return tostring(math.floor(args.x)) .. ":" .. tostring(math.floor(args.y)) .. ":" .. tostring(math.floor(args.z))
end

function ParadiseDev.Notes.setGlobal(args)
    local store, key = ParadiseDev.Notes.getGlobalStore(), ParadiseDev.Notes.globalKey(args)
    local note = ParadiseDev.Notes.normalizeNote(args.note)
    if not note then
        store.notes[key] = nil
    else
        store.notes[key] = { x = math.floor(args.x), y = math.floor(args.y), z = math.floor(args.z), text = note, color = ParadiseDev.Notes.normalizeColor(args.color) }
    end
    ModData.transmit(ParadiseDev.Notes.globalStore)
end

function ParadiseDev.Notes.onInitGlobalModData()
    ParadiseDev.Notes.getGlobalStore()
end

function ParadiseDev.Notes.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.Notes.module or type(args) ~= "table" then return end
    if command == "globalSet" then
        if ParadiseDev.Notes.isAdmin(pl) and ParadiseDev.Notes.getFloor(args) then ParadiseDev.Notes.setGlobal(args) end
        return
    end
    if command ~= "set" then return end
    local floor = ParadiseDev.Notes.getFloor(args)
    if not floor or not ParadiseDev.Notes.canModifyFloor(pl, floor) then return end
    ParadiseDev.Notes.setNote(floor, args.note, args.color, ParadiseDev.Notes.getUsername(pl))
end

Events.OnInitGlobalModData.Remove(ParadiseDev.Notes.onInitGlobalModData)
Events.OnInitGlobalModData.Add(ParadiseDev.Notes.onInitGlobalModData)
Events.OnClientCommand.Remove(ParadiseDev.Notes.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Notes.onClientCommand)
