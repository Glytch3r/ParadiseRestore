ParadiseGate = ParadiseGate or {}

local UNION_FILE = "ParadiseGate_Union.csv"
local PARADISE_FILE = "ParadiseGate_Paradise.csv"

function ParadiseGate.trim(value)
    return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end

function ParadiseGate.isValidSteamID(steamID)
    return SteamUtils and SteamUtils.isValidSteamID and SteamUtils.isValidSteamID(steamID)
end

function ParadiseGate.addFileRecords(filename, source, records, result)
    local reader = getFileReader(filename, false)
    if not reader then
        result.missing = result.missing + 1
        return
    end

    local firstLine = true
    local line = reader:readLine()
    while line do
        if firstLine then
            firstLine = false
            line = line:gsub("^\239\187\191", "")
            if string.lower(ParadiseGate.trim(line)) == "steamid,reason" then
                line = nil
            end
        end
        if line and ParadiseGate.trim(line) ~= "" then
            local comma = string.find(line, ",", 1, true)
            local steamID = ParadiseGate.trim(comma and string.sub(line, 1, comma - 1) or line)
            local reason = ParadiseGate.trim(comma and string.sub(line, comma + 1) or "")
            if not ParadiseGate.isValidSteamID(steamID) then
                result.invalid = result.invalid + 1
            elseif records[steamID] then
                result.duplicates = result.duplicates + 1
                if source == "Paradise" and reason ~= "" then
                    records[steamID].reason = reason
                    records[steamID].source = source
                end
            else
                records[steamID] = {
                    reason = reason ~= "" and reason or (source .. " blacklist"),
                    source = source
                }
            end
        end
        line = reader:readLine()
    end
    reader:close()
end

function ParadiseGate.import()
    local result = { banned = 0, duplicates = 0, invalid = 0, missing = 0, failed = 0, steam = true }
    if not SteamUtils or not SteamUtils.isSteamModeEnabled or not SteamUtils.isSteamModeEnabled() then
        result.steam = false
        print("ParadiseGate: disabled because the server is not running in Steam mode")
        return result
    end
    local records = {}
    ParadiseGate.addFileRecords(UNION_FILE, "Union", records, result)
    ParadiseGate.addFileRecords(PARADISE_FILE, "Paradise", records, result)

    for steamID, record in pairs(records) do
        local ok = pcall(BanSystem.BanUserBySteamID, steamID, nil, record.reason, true)
        if ok then
            result.banned = result.banned + 1
        else
            result.failed = result.failed + 1
        end
    end

    print("ParadiseGate: banned=" .. result.banned .. " duplicates=" .. result.duplicates .. " invalid=" .. result.invalid .. " missing=" .. result.missing .. " failed=" .. result.failed)
    return result
end

Events.OnServerStarted.Remove(ParadiseGate.import)
Events.OnServerStarted.Add(ParadiseGate.import)
