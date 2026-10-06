if isClient() then return end

ParadiseLimboRecords = ParadiseLimboRecords or {}
ParadiseLimboRecords.module = "ParadiseLimboRecords"
ParadiseLimboRecords.dir = "ParadiseLimboTracker"

function ParadiseLimboRecords.isAdm(pl)
    return pl and pl.getAccessLevel and string.lower(tostring(pl:getAccessLevel() or "")) == "admin"
end

function ParadiseLimboRecords.isLeapYear(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

function ParadiseLimboRecords.normalizeDate(date)
    local year, month, day = tostring(date or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or not month or not day or month < 1 or month > 12 or day < 1 then return nil end
    local days = { 31, ParadiseLimboRecords.isLeapYear(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if day > days[month] then return nil end
    return string.format("%04d-%02d-%02d", year, month, day)
end

function ParadiseLimboRecords.normalizeFilter(value, min, max, digits)
    value = tostring(value or ""):match("^%s*(.-)%s*$")
    if value == "" then return nil, true end
    if not value:match("^%d+$") or #value > digits then return nil, false end
    local int = tonumber(value)
    if not int or int < min or int > max then return nil, false end
    return int, true
end

function ParadiseLimboRecords.getDates(args)
    local year, validYear = ParadiseLimboRecords.normalizeFilter(args and args.year, 1, 9999, 4)
    local month, validMonth = ParadiseLimboRecords.normalizeFilter(args and args.month, 1, 12, 2)
    local day, validDay = ParadiseLimboRecords.normalizeFilter(args and args.day, 1, 31, 2)
    if not validYear or not validMonth or not validDay then return nil end
    local files = listFilesInZomboidLuaDirectory(ParadiseLimboRecords.dir)
    local dates = {}
    if files then
        for int = 0, files:size() - 1 do
            local date = tostring(files:get(int) or ""):match("^(%d%d%d%d%-%d%d%-%d%d)%.log$")
            local normalized = ParadiseLimboRecords.normalizeDate(date)
            if normalized then
                local fileYear, fileMonth, fileDay = normalized:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
                if (not year or tonumber(fileYear) == year)
                    and (not month or tonumber(fileMonth) == month)
                    and (not day or tonumber(fileDay) == day) then
                    dates[#dates + 1] = normalized
                end
            end
        end
    end
    table.sort(dates, function(left, right) return left > right end)
    return dates
end

function ParadiseLimboRecords.readDate(date)
    date = ParadiseLimboRecords.normalizeDate(date)
    if not date then return nil end
    local reader = getFileReader(ParadiseLimboRecords.dir .. "/" .. date .. ".log", false)
    if not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    return table.concat(lines, "\n")
end

function ParadiseLimboRecords.sendError(pl, message)
    sendServerCommand(pl, ParadiseLimboRecords.module, "error", { message = message })
end

function ParadiseLimboRecords.onClientCommand(module, command, pl, args)
    if module ~= ParadiseLimboRecords.module or not ParadiseLimboRecords.isAdm(pl) then return end
    if command == "requestDates" then
        local dates = ParadiseLimboRecords.getDates(args)
        if not dates then
            ParadiseLimboRecords.sendError(pl, "Use a valid year, month, and day filter.")
            return
        end
        sendServerCommand(pl, ParadiseLimboRecords.module, "dates", { dates = dates })
    elseif command == "requestLog" then
        local date = ParadiseLimboRecords.normalizeDate(args and args.date)
        if not date then
            ParadiseLimboRecords.sendError(pl, "Invalid limbo log date.")
            return
        end
        local text = ParadiseLimboRecords.readDate(date)
        if text == nil then
            ParadiseLimboRecords.sendError(pl, "Limbo log not found: " .. date)
            return
        end
        sendServerCommand(pl, ParadiseLimboRecords.module, "log", { date = date, text = text })
    end
end
Events.OnClientCommand.Remove(ParadiseLimboRecords.onClientCommand)
Events.OnClientCommand.Add(ParadiseLimboRecords.onClientCommand)
