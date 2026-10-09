ParadiseDev = ParadiseDev or {}
ParadiseDev.SafehouseAdmin = ParadiseDev.SafehouseAdmin or {}

function ParadiseDev.SafehouseAdmin.normalizeUser(user)
    return string.lower(tostring(user or ""))
end

function ParadiseDev.SafehouseAdmin.trim(str)
    return tostring(str or ""):match("^%s*(.-)%s*$")
end

function ParadiseDev.SafehouseAdmin.addPlayerSafehouse(byUser, user, safehouse, role)
    user = ParadiseDev.SafehouseAdmin.trim(user)
    local key = ParadiseDev.SafehouseAdmin.normalizeUser(user)
    if key == "" or not safehouse then return end
    local record = byUser[key]
    if not record then
        record = {username = user, safehouses = {}, safehouseKeys = {}}
        byUser[key] = record
    end
    local safehouseKey = tostring(safehouse)
    local existing = record.safehouseKeys[safehouseKey]
    if existing then
        if role == "Owner" then existing.role = role end
        return
    end
    local entry = {safehouse = safehouse, role = role}
    record.safehouses[#record.safehouses + 1] = entry
    record.safehouseKeys[safehouseKey] = entry
end

function ParadiseDev.SafehouseAdmin.buildPlayerRecords(safehouses)
    local byUser = {}
    if safehouses then
        for index = 0, safehouses:size() - 1 do
            local safehouse = safehouses:get(index)
            if safehouse then
                ParadiseDev.SafehouseAdmin.addPlayerSafehouse(byUser, safehouse:getOwner(), safehouse, "Owner")
                local players = safehouse:getPlayers()
                if players then
                    for playerIndex = 0, players:size() - 1 do
                        ParadiseDev.SafehouseAdmin.addPlayerSafehouse(byUser, players:get(playerIndex), safehouse, "Member")
                    end
                end
            end
        end
    end
    local records = {}
    for _, record in pairs(byUser) do
        record.safehouseKeys = nil
        table.sort(record.safehouses, function(left, right)
            return string.lower(tostring(left.safehouse:getTitle())) < string.lower(tostring(right.safehouse:getTitle()))
        end)
        records[#records + 1] = record
    end
    table.sort(records, function(left, right)
        return ParadiseDev.SafehouseAdmin.normalizeUser(left.username) < ParadiseDev.SafehouseAdmin.normalizeUser(right.username)
    end)
    return records
end

function ParadiseDev.SafehouseAdmin.filterPlayerRecords(records, filter)
    local result = {}
    filter = ParadiseDev.SafehouseAdmin.normalizeUser(ParadiseDev.SafehouseAdmin.trim(filter))
    for _, record in ipairs(records or {}) do
        if filter == "" or string.find(ParadiseDev.SafehouseAdmin.normalizeUser(record.username), filter, 1, true) then
            result[#result + 1] = record
        end
    end
    return result
end

function ParadiseDev.SafehouseAdmin.findPlayerRecord(records, user)
    local wanted = ParadiseDev.SafehouseAdmin.normalizeUser(ParadiseDev.SafehouseAdmin.trim(user))
    if wanted == "" then return nil end
    for _, record in ipairs(records or {}) do
        if ParadiseDev.SafehouseAdmin.normalizeUser(record.username) == wanted then return record end
    end
    return nil
end

function ParadiseDev.SafehouseAdmin.getTeleportCoordinates(safehouse)
    if not safehouse then return nil end
    local x = safehouse:getX() + safehouse:getW() / 2
    local y = safehouse:getY() + safehouse:getH() / 2
    return math.floor(x), math.floor(y), 0
end
