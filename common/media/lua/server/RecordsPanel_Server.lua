if isClient() then return end

RecordsPanel = RecordsPanel or {}
RecordsPanel.module = "RecordsPanel"
RecordsPanel.loggers = {
    LimboTracker = {
        title = "Limbo Tracker",
        dir = "ParadiseLimboTracker",
        columns = { "time", "key", "username", "firstname", "surname", "profKey", "fps", "ping", "exitMode", "exitLabel" },
    },
    SoulCatcher = {
        title = "Soul Catcher",
        dir = "SoulCatcher",
        columns = { "time", "key", "username", "firstname", "surname", "profKey", "reportMsg", "reincarnatedTimes", "lifeHours", "totalHours", "x", "y", "z" },
    },
    ParadiseEconomy = {
        title = "Paradise Economy",
        dir = "ParadiseEconomy",
        columns = { "time", "username", "steamid", "action", "currency", "amount", "from", "to", "detail" },
    },
}

function RecordsPanel.isLeapYear(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

function RecordsPanel.normalizeDate(date)
    local year, month, day = tostring(date or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or not month or not day or month < 1 or month > 12 or day < 1 then return nil end
    local days = { 31, RecordsPanel.isLeapYear(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if day > days[month] then return nil end
    return string.format("%04d-%02d-%02d", year, month, day)
end

function RecordsPanel.normalizeFilter(value, min, max, digits)
    value = tostring(value or ""):match("^%s*(.-)%s*$")
    if value == "" then return nil, true end
    if not value:match("^%d+$") or #value > digits then return nil, false end
    local int = tonumber(value)
    if not int or int < min or int > max then return nil, false end
    return int, true
end

function RecordsPanel.getExitModeLabel(exitMode)
    local labels = {
        [-1] = "Possible Force Exit or Crash",
        [0] = "Character Died",
        [1] = "Reincarnate Selected",
        [2] = "New Character Selected",
        [3] = "Exit to Main Menu",
        [4] = "Quit to Desktop",
        [5] = "Event Respawn Selected",
    }
    return labels[tonumber(exitMode)] or "Unknown"
end

function RecordsPanel.parseLabeled(line)
    local tag = tostring(line or ""):match("^%[([^%]]+)%]")
    if not tag then return nil end
    local values = {}
    for field in tostring(line):gmatch("|([^|]+)") do
        local key, value = field:match("^([^:]+):(.*)$")
        if key then values[key] = value end
    end
    values.loggerTag = tag
    if tag == "LimboTracker" then
        local mode, label = tostring(values.exitmode or ""):match("^(-?%d+):(.*)$")
        values.exitMode = mode or values.exitmode or ""
        values.exitLabel = label or RecordsPanel.getExitModeLabel(values.exitMode)
        values.exitmode = nil
    elseif tag == "SoulCatcher" then
        values.time = tonumber(values.serverTimestamp) and os.date("%H:%M:%S", tonumber(values.serverTimestamp)) or ""
    end
    return values
end

function RecordsPanel.parseLegacyLimbo(line)
    local values = {}
    for value in tostring(line or ""):gmatch("%S+") do values[#values + 1] = value end
    if #values ~= 5 and #values ~= 6 then return nil end
    local hasUsername = #values == 6
    local mode = values[hasUsername and 6 or 5]
    return {
        loggerTag = "LimboTracker",
        time = values[1],
        key = values[2],
        username = hasUsername and values[3] or "Unknown",
        firstname = "",
        surname = "",
        profKey = "",
        fps = values[hasUsername and 4 or 3],
        ping = values[hasUsername and 5 or 4],
        exitMode = mode,
        exitLabel = RecordsPanel.getExitModeLabel(mode),
    }
end

function RecordsPanel.parseLegacySoul(line)
    local values = {}
    for value in (tostring(line or "") .. "|"):gmatch("(.-)|") do values[#values + 1] = value end
    if #values ~= 9 then return nil end
    return {
        loggerTag = "SoulCatcher",
        serverTimestamp = values[5],
        time = tonumber(values[5]) and os.date("%H:%M:%S", tonumber(values[5])) or "",
        key = values[1],
        username = values[2],
        firstname = values[3],
        surname = values[4],
        profKey = "",
        soulKey = "",
        reportMsg = values[6],
        reincarnatedTimes = "",
        lifeHours = "",
        totalHours = "",
        x = values[7],
        y = values[8],
        z = values[9],
    }
end

function RecordsPanel.isCompleteLabeledRow(loggerTag, row)
    if loggerTag == "LimboTracker" then
        return row.time ~= nil and row.key ~= nil and row.username ~= nil
            and row.firstname ~= nil and row.surname ~= nil and row.profKey ~= nil
            and row.fps ~= nil and row.ping ~= nil and row.exitMode ~= nil
    end
    if loggerTag == "SoulCatcher" then
        return row.serverTimestamp ~= nil and row.key ~= nil and row.username ~= nil
            and row.firstname ~= nil and row.surname ~= nil and row.profKey ~= nil
            and row.soulKey ~= nil and row.reportMsg ~= nil and row.reincarnatedTimes ~= nil
            and row.lifeHours ~= nil and row.totalHours ~= nil
            and row.x ~= nil and row.y ~= nil and row.z ~= nil
    end
    if loggerTag == "ParadiseEconomy" then
        return row.time ~= nil and row.username ~= nil and row.steamid ~= nil and row.action ~= nil
            and row.currency ~= nil and row.amount ~= nil and row.from ~= nil and row.to ~= nil and row.detail ~= nil
    end
    return false
end

function RecordsPanel.parseLine(loggerTag, line)
    if not RecordsPanel.loggers[loggerTag] or type(line) ~= "string" or line == "" then return nil end
    local row = RecordsPanel.parseLabeled(line)
    if row then return row.loggerTag == loggerTag and RecordsPanel.isCompleteLabeledRow(loggerTag, row) and row or nil end
    if loggerTag == "LimboTracker" then return RecordsPanel.parseLegacyLimbo(line) end
    if loggerTag == "SoulCatcher" then return RecordsPanel.parseLegacySoul(line) end
    if loggerTag == "ParadiseEconomy" then return nil end
    return nil
end

function RecordsPanel.readLines(loggerTag, date)
    local logger = RecordsPanel.loggers[loggerTag]
    date = RecordsPanel.normalizeDate(date)
    if not logger or not date then return nil end
    local reader = getFileReader(logger.dir .. "/" .. date .. ".log", false)
    if not reader then return nil end
    local lines = {}
    local line = reader:readLine()
    while line do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    return lines
end

function RecordsPanel.isMatch(row, search)
    search = string.lower(tostring(search or ""):match("^%s*(.-)%s*$"))
    if search == "" then return true end
    for _, value in pairs(row or {}) do
        if string.lower(tostring(value)):find(search, 1, true) then return true end
    end
    return false
end

function RecordsPanel.getRecords(loggerTag, date, search)
    local lines = RecordsPanel.readLines(loggerTag, date)
    if not lines then return nil end
    local rows = {}
    for index = #lines, 1, -1 do
        local row = RecordsPanel.parseLine(loggerTag, lines[index])
        if row and RecordsPanel.isMatch(row, search) then rows[#rows + 1] = row end
    end
    return rows
end

function RecordsPanel.getDates(loggerTag, args)
    local logger = RecordsPanel.loggers[loggerTag]
    if not logger then return nil end
    local year, validYear = RecordsPanel.normalizeFilter(args and args.year, 1, 9999, 4)
    local month, validMonth = RecordsPanel.normalizeFilter(args and args.month, 1, 12, 2)
    local day, validDay = RecordsPanel.normalizeFilter(args and args.day, 1, 31, 2)
    if not validYear or not validMonth or not validDay then return nil end
    local files = listFilesInZomboidLuaDirectory(logger.dir)
    local dates = {}
    if files then
        for int = 0, files:size() - 1 do
            local date = tostring(files:get(int) or ""):match("^(%d%d%d%d%-%d%d%-%d%d)%.log$")
            local normalized = RecordsPanel.normalizeDate(date)
            if normalized then
                local fileYear, fileMonth, fileDay = normalized:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
                if (not year or tonumber(fileYear) == year)
                    and (not month or tonumber(fileMonth) == month)
                    and (not day or tonumber(fileDay) == day) then
                    local rows = RecordsPanel.getRecords(loggerTag, normalized, "") or {}
                    dates[#dates + 1] = { date = normalized, count = #rows }
                end
            end
        end
    end
    table.sort(dates, function(left, right) return left.date > right.date end)
    return dates
end

function RecordsPanel.sendError(pl, message)
    sendServerCommand(pl, RecordsPanel.module, "error", { message = message })
end

function RecordsPanel.onClientCommand(module, command, pl, args)
    if module ~= RecordsPanel.module then return end
    if not ParadiseRestore or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(pl) then return end
    local loggerTag = args and args.loggerTag or nil
    local logger = RecordsPanel.loggers[loggerTag]
    if not logger then RecordsPanel.sendError(pl, "Invalid records logger.") return end
    if command == "requestDates" then
        local dates = RecordsPanel.getDates(loggerTag, args)
        if not dates then RecordsPanel.sendError(pl, "Use a valid year, month, and day filter.") return end
        sendServerCommand(pl, RecordsPanel.module, "dates", { loggerTag = loggerTag, dates = dates })
    elseif command == "requestRecords" then
        local date = RecordsPanel.normalizeDate(args and args.date)
        if not date then RecordsPanel.sendError(pl, "Invalid records date.") return end
        local rows = RecordsPanel.getRecords(loggerTag, date, tostring(args and args.search or ""):sub(1, 128))
        if not rows then RecordsPanel.sendError(pl, "Records log not found: " .. date) return end
        sendServerCommand(pl, RecordsPanel.module, "records", { loggerTag = loggerTag, date = date, rows = rows })
    end
end
Events.OnClientCommand.Remove(RecordsPanel.onClientCommand)
Events.OnClientCommand.Add(RecordsPanel.onClientCommand)
