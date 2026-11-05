require "Dev/ParadiseDev_PvEPolicy"
ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.NoSafe = ParadiseDev.Zones.NoSafe or {}
local NoSafe = ParadiseDev.Zones.NoSafe

NoSafe.lastSweep = NoSafe.lastSweep or {}
NoSafe.sweeping = false

function NoSafe.isNoSafeZone(zone)
    return zone ~= nil and zone.features ~= nil and zone.features.isNoCamp == true
end

function NoSafe.zonesOverlapping(xMin, yMin, xMax, yMax)
    local result = {}
    local engine = ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    if not engine or not engine.zones then return result end
    for _, zone in pairs(engine.zones) do
        if NoSafe.isNoSafeZone(zone) then
            for _, region in ipairs(zone.regions or {}) do
                if xMin < region.xMax and region.xMin < xMax
                    and yMin < region.yMax and region.yMin < yMax then
                    result[#result + 1] = { zone = zone, region = region }
                    break
                end
            end
        end
    end
    return result
end

function NoSafe.safehouseBounds(house)
    local x = tonumber(house and house:getX()) or 0
    local y = tonumber(house and house:getY()) or 0
    local w = tonumber(house and house:getW()) or 0
    local h = tonumber(house and house:getH()) or 0
    return x, y, x + w, y + h
end

function NoSafe.collidingSafehouses()
    local removed, owners = {}, {}
    local list = SafeHouse and SafeHouse.getSafehouseList and SafeHouse.getSafehouseList() or nil
    if not list then return removed, owners end
    for index = list:size() - 1, 0, -1 do
        local house = list:get(index)
        if house then
            local xMin, yMin, xMax, yMax = NoSafe.safehouseBounds(house)
            local hits = NoSafe.zonesOverlapping(xMin, yMin, xMax, yMax)
            if #hits > 0 then
                local owner = tostring(house:getOwner() or "")
                removed[#removed + 1] = {
                    title = tostring(house:getTitle() or ""),
                    owner = owner,
                    zoneName = tostring(hits[1].zone.name or hits[1].zone.id),
                    x = xMin, y = yMin,
                }
                owners[owner] = (owners[owner] or 0) + 1
                SafeHouse.removeSafeHouse(house)
            end
        end
    end
    return removed, owners
end

function NoSafe.authorityActive()
    if GameServer and GameServer.server then return true end
    return not (isClient and isClient())
end

function NoSafe.sweep(reason)
    if NoSafe.sweeping then return nil end
    if not NoSafe.authorityActive() then return nil end
    NoSafe.sweeping = true
    local ok, removed, owners = pcall(NoSafe.collidingSafehouses)
    NoSafe.sweeping = false
    if not ok then
        print("[PZNoSafe] safehouse sweep failed: " .. tostring(removed))
        return nil
    end
    if #removed > 0 then
        print("[PZNoSafe] removed " .. #removed .. " safehouse(s) colliding with NoCamp zones (" .. tostring(reason) .. ")")
    end
    return removed, owners
end

function NoSafe.runSweep(reason, engine, notify)
    local removed = NoSafe.sweep(reason)
    if engine then NoSafe.lastSweep.zoneRevision = engine.zoneRevision end
    if notify and removed and #removed > 0 then NoSafe.notifyOwners(removed) end
end

function NoSafe.sweepOnZoneEdit()
    if not NoSafe.authorityActive() then return end
    local engine = ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    if not engine then return end
    if NoSafe.lastSweep.zoneRevision == engine.zoneRevision then return end
    NoSafe.runSweep("zone edit", engine, true)
end

function NoSafe.findPlayer(username)
    if not username or username == "" then return nil end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            local pl = players:get(index)
            if pl and pl:getUsername() == username then return pl end
        end
    end
    return getPlayerFromUsername(username)
end

function NoSafe.notifyOwners(removed)
    if not removed then return end
    local seen = {}
    for _, entry in ipairs(removed) do
        if entry.owner and entry.owner ~= "" and not seen[entry.owner] then
            seen[entry.owner] = true
            local pl = NoSafe.findPlayer(entry.owner)
            if pl then
                sendServerCommand(pl, "ParadiseDevTP", "message", {
                    text = "Your safehouse at " .. tostring(entry.x) .. "," .. tostring(entry.y) ..
                        " was inside the NoCamp zone \"" .. tostring(entry.zoneName) .. "\" and has been removed.",
                })
            end
        end
    end
end
