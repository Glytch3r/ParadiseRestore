ParadiseZ = ParadiseZ or {}

function ParadiseZ.doBackupZones()
    local filename = "ZoneDataBackup.ini"
    ParadiseZ.IO(filename, ParadiseZ.ZoneDataBackup, false)
end

function ParadiseZ.doRestoreZones()
    local filename = "ZoneDataBackup.ini"
    local reader = getFileReader(filename, true)
    if reader then
        reader:close()
        ParadiseZ.ZoneDataBackup = ParadiseZ.IO(filename, ParadiseZ.ZoneDataBackup, true) or {}
    else
        ParadiseZ.IO(filename, ParadiseZ.ZoneDataBackup, false)
    end
end
Events.OnInitGlobalModData.Add(ParadiseZ.doRestoreZones)

function ParadiseZ.IO(filename, tbl, isLoad)
    if isLoad then
        local reader = getFileReader(filename, true)
        if not reader then return nil end
        local result = {}
        local line = reader:readLine()
        while line do
            local eq = string.find(line, "=")
            if eq then
                local key = string.sub(line, 1, eq-1)
                local val = string.sub(line, eq+1)
                if string.find(val, ":") then
                    local sub = {}
                    for pair in string.gmatch(val, "([^,]+)") do
                        local sep = string.find(pair, ":")
                        if sep then
                            local k2 = string.sub(pair, 1, sep-1)
                            local v2 = string.sub(pair, sep+1)
                            if v2 == "true" then
                                sub[k2] = true
                            elseif v2 == "false" then
                                sub[k2] = false
                            else
                                sub[k2] = tonumber(v2) or v2
                            end
                        end
                    end
                    result[key] = sub
                else
                    if val == "true" then
                        result[key] = true
                    elseif val == "false" then
                        result[key] = false
                    else
                        result[key] = tonumber(val) or val
                    end
                end
            end
            line = reader:readLine()
        end
        reader:close()
        return result
    else
        if not tbl then return end
        local writer = getFileWriter(filename, true, false)
        if not writer then return end
        for k,v in pairs(tbl) do
            if type(v) == "table" then
                local str = ""
                for k2,v2 in pairs(v) do
                    str = str .. tostring(k2) .. ":" .. tostring(v2) .. ","
                end
                if str ~= "" then str = string.sub(str, 1, -2) end
                writer:write(k .. "=" .. str .. "\n")
            else
                writer:write(k .. "=" .. tostring(v) .. "\n")
            end
        end
        writer:close()
    end
end