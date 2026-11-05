ParadiseDev = ParadiseDev or {}
ParadiseDev.PlayerCleanup = ParadiseDev.PlayerCleanup or {}

local cleanup = ParadiseDev.PlayerCleanup

cleanup.module = "ParadiseDevPlayerCleanup"
cleanup.storeName = "ParadiseDev_PlayerRoster"
cleanup.cageStore = "ParadiseDev_IsCaged"
cleanup.auditStore = "ParadiseDev_PlayerAuditPlaytime"
cleanup.economyStore = "ParadiseEconomy"
cleanup.logDir = "ParadisePlayerCleanup"
cleanup.dayMs = 86400000
cleanup.maxSessionDeletes = 50
cleanup.maxRequestTargets = 100
cleanup.defaultInactiveDays = 30
cleanup.defaultAccountDays = 30
cleanup.protectedLevels = { admin = true, overseer = true, moderator = true, gm = true, gm2 = true }

function cleanup.normalizeDays(value, fallback)
    local int = math.floor(tonumber(value) or 0)
    if int < 1 or int > 3650 then return fallback end
    return int
end

function cleanup.lowerName(username)
    return string.lower(tostring(username or ""))
end

function cleanup.isValidName(username)
    local name = tostring(username or ""):gsub("^%s*(.-)%s*$", "%1")
    if name == "" or #name > 64 or name:find("[%c]") then return nil end
    return name
end

function cleanup.rosterKey(username, steamId)
    if steamId and tostring(steamId) ~= "" and tostring(steamId) ~= "0" then
        return "steam:" .. tostring(steamId)
    end
    if not username then return nil end
    return "username:" .. cleanup.lowerName(username)
end

function cleanup.isProtectedLevel(level)
    return cleanup.protectedLevels[cleanup.lowerName(level)] == true
end

function cleanup.daysFromCivil(y, m, d)
    y = y - (m <= 2 and 1 or 0)
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

function cleanup.parseConnection(value)
    local year, month, day = tostring(value or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or not month or not day then return nil end
    if month < 1 or month > 12 or day < 1 or day > 31 then return nil end
    return cleanup.daysFromCivil(year, month, day)
end

function cleanup.msToDays(ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return nil end
    return math.floor(ms / cleanup.dayMs)
end

function cleanup.formatDate(ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return "" end
    return tostring(os.date("%Y-%m-%d", math.floor(ms / 1000)))
end

function cleanup.formatDuration(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local hours = math.floor(seconds / 3600)
    if hours >= 24 then return tostring(math.floor(hours / 24)) .. "d " .. tostring(hours % 24) .. "h" end
    return tostring(hours) .. "h " .. tostring(math.floor((seconds % 3600) / 60)) .. "m"
end
