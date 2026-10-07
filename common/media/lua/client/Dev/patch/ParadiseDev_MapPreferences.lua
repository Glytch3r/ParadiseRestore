ParadiseDev = ParadiseDev or {}
ParadiseDev.MapPreferences = ParadiseDev.MapPreferences or {}
local Preferences = ParadiseDev.MapPreferences
local FILE = "ParadiseZoneMapPrefs.ini"
local KEYS = {"coordinates", "zoneVisibility", "zoneHighlight", "applyToMinimap"}
local ALLOWED = {coordinates=true, zoneVisibility=true, zoneHighlight=true, applyToMinimap=true}
local MAX_CHARACTERS = 2048
Preferences.values = Preferences.values or {coordinates=true, zoneVisibility=true, zoneHighlight=true, applyToMinimap=true}

local function warnOnce(pl)
    if Preferences.warned then return end
    Preferences.warned = true
    local message = "Map settings are active for this session but could not be saved."
    if pl and pl.setHaloNote then pcall(function() pl:setHaloNote(message) end) end
    print("[ParadiseMapPreferences] " .. message)
end

-- Fixed ASCII keys and literal booleans only. No Lua/config execution.
local function parse(text)
    local result, seen = {}, {}
    for line in string.gmatch(text .. "\n", "([^\n]*)\n") do
        line = string.gsub(line, "\r$", "")
        if string.match(line, "%S") and not string.match(line, "^%s*#") then
            local key, value = string.match(line, "^%s*([%a]+)%s*=%s*([%w]+)%s*$")
            if not key or seen[key] then return nil end
            if key == "version" then
                if value ~= "1" then return nil end
            elseif ALLOWED[key] then
                if value ~= "true" and value ~= "false" then return nil end
                result[key] = value == "true"
            else
                return nil
            end
            seen[key] = true
        end
    end
    if not seen.version then return nil end
    for _, key in ipairs(KEYS) do if not seen[key] then return nil end end
    return result
end

local function readSaved()
    if not getFileReader then return nil, "unavailable" end
    local ok, reader = pcall(getFileReader, FILE, false)
    if not ok then return nil, "read-failed" end
    if not reader then return nil, "missing" end
    -- Reading characters bounds a huge single line too; readLine cannot do that.
    local chars = {}
    local complete, text = pcall(function()
        for index = 1, MAX_CHARACTERS + 1 do
            local code = reader:read()
            if code == -1 then return table.concat(chars) end
            if index > MAX_CHARACTERS or code < 0 or code > 127 then return nil end
            chars[#chars + 1] = string.char(code)
        end
    end)
    local closed = pcall(function() reader:close() end)
    if not complete or not closed then return nil, "read-failed" end
    if not text then return nil, "invalid" end
    local values = parse(text)
    return values, values and "saved" or "invalid"
end

local function serialize(values)
    local rows = {"version=1"}
    for _, key in ipairs(KEYS) do rows[#rows + 1] = key .. "=" .. tostring(values[key] == true) end
    return table.concat(rows, "\n") .. "\n"
end

local function persist(pl)
    local writer
    local ok = pcall(function()
        if not getFileWriter then error("writer unavailable") end
        writer = getFileWriter(FILE, true, false)
        if not writer then error("writer unavailable") end
        writer:write(serialize(Preferences.values))
    end)
    local closed = writer and pcall(function() writer:close() end)
    -- LuaFileWriter wraps PrintWriter, which can swallow I/O errors. Confirm
    -- the exact values by bounded readback instead of treating close as proof.
    local actual = ok and closed and readSaved() or nil
    local saved = actual ~= nil
    if actual then
        for _, key in ipairs(KEYS) do
            if actual[key] ~= Preferences.values[key] then saved = false end
        end
    end
    Preferences.pendingPersistence = not saved
    if not saved then warnOnce(pl) end
    return saved
end

function Preferences.get(pl)
    if Preferences.loaded then return Preferences.values end
    pl = pl or (getPlayer and getPlayer() or nil)
    -- A menu/render load before character creation must not consume migration.
    if not pl then return Preferences.values end
    local values, status = readSaved()
    Preferences.loaded = true
    if values then
        Preferences.values = values
    elseif status == "missing" then
        local modData = pl.getModData and pl:getModData() or nil
        local legacy = modData and (modData.HUDSettings or modData.ParadiseZHUDSettings)
        if type(legacy) == "table" and legacy.mapZoneVisuals == false then
            Preferences.values.zoneVisibility, Preferences.values.zoneHighlight = false, false
        end
        persist(pl)
    else
        -- Keep a malformed/unreadable file intact until the user changes a toggle.
        Preferences.pendingPersistence = true
    end
    return Preferences.values
end

function Preferences.toggle(key, pl)
    if not ALLOWED[key] then return false end
    pl = pl or (getPlayer and getPlayer() or nil)
    if not pl then return false end
    local values = Preferences.get(pl)
    values[key] = not values[key]
    return persist(pl)
end
