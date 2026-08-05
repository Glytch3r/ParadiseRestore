-- Admin-only harness and zone-editor command surface. This remains separate
-- from PZZoneEngine so the engine has no dependency on test profiles or UI.
local MODULE = "PZZoneHarness"
local RESULT = "result"
local ADMIN_STATE = "adminState"
local zoneBackup = nil

local function copyTable(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[copyTable(key, seen)] = copyTable(item, seen) end
    return result
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function uniqueZoneId(E, name)
    local base = string.lower(name):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if base == "" then base = "zone" end
    local id, suffix = base, 2
    while E.zones[id] do
        id = base .. "_" .. tostring(suffix)
        suffix = suffix + 1
    end
    return id
end

local function reply(player, text)
    sendServerCommand(player, MODULE, RESULT, { text = text })
end

local function tagsFor(profile)
    if profile == "pve" then return { pve = true } end
    if profile == "range_staff" then return { range_staff = true } end
    if profile == "both" then return { pve = true, range_staff = true } end
    return {}
end

local function parseTags(value)
    local tags = {}
    for tag in string.gmatch(tostring(value or ""), "[^,%s]+") do
        tags[tag] = true
    end
    return tags
end

local function tagsText(tags)
    local values = {}
    for tag, enabled in pairs(tags or {}) do
        if enabled then values[#values + 1] = tag end
    end
    table.sort(values)
    return table.concat(values, ",")
end

local function editorOptions(args)
    local zMode = args and args.zMode == "floor" and "floor" or "all"
    local zMin = tonumber(args and args.zMin) or 0
    local zMaxExclusive = tonumber(args and args.zMaxExclusive) or 1
    if zMode == "floor" and zMaxExclusive <= zMin then
        return nil, "Z maximum must be greater than Z minimum."
    end
    return {
        name = tostring(args and args.name or args and args.id or ""),
        priority = tonumber(args and args.priority) or 0,
        zMode = zMode,
        zMin = zMin,
        zMaxExclusive = zMaxExclusive,
        policy = {
            denyTags = parseTags(args and args.denyTags),
            requireAnyTags = parseTags(args and args.requireTags),
            adminBypass = not (args and args.adminBypass == false),
        },
    }
end

local function validRegionArgs(args)
    local x1 = tonumber(args and args.x1)
    local y1 = tonumber(args and args.y1)
    local x2 = tonumber(args and args.x2)
    local y2 = tonumber(args and args.y2)
    if not x1 or not y1 or not x2 or not y2 then
        return nil, "Both segment corners are required."
    end
    x1, y1, x2, y2 = math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2)
    if x1 == x2 or y1 == y2 then return nil, "A segment must have width and height." end
    return { x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
end

local function createDemo(player)
    local E = rawget(_G, "PZZoneEngine")
    if not E then return false, "Zone engine is not loaded" end
    E.clear()
    local x, y = math.floor(player:getX()), math.floor(player:getY())

    E.addRegion("kos_demo", x + 10, y - 5, x + 19, y + 4, {
        name = "KoS Demo", priority = 100,
        policy = { denyTags = {}, requireAnyTags = {} },
        features = { isKos = true },
    })

    E.addRegion("range_l_demo", x + 30, y - 10, x + 34, y + 10, {
        name = "Range L Demo", priority = 200,
        policy = { denyTags = {}, requireAnyTags = {} },
        features = { isHunt = true },
    })
    E.addRegion("range_l_demo", x + 34, y + 6, x + 49, y + 10, {})

    E.addRegion("blocked_demo", x + 15, y - 2, x + 22, y + 2, {
        name = "Blocked Priority Demo", priority = 300,
        policy = { denyTags = {}, requireAnyTags = {} },
        features = { isBlocked = true },
    })

    return true, "Demo zones created east of you: KoS(priority 100), Range L(priority 200), Blocked(priority 300)."
end

local function adminState(E, player)
    local zones = {}
    for _, zone in pairs(E.zones) do
        local segments = {}
        for index, region in ipairs(zone.regions) do
            segments[#segments + 1] = {
                index = index,
                x1 = region.xMin, y1 = region.yMin,
                x2 = region.xMax - 1, y2 = region.yMax - 1,
            }
        end
        zones[#zones + 1] = {
            id = zone.id,
            name = zone.name,
            priority = zone.priority,
            zMode = zone.zMode,
            zMin = zone.zMin,
            zMaxExclusive = zone.zMaxExclusive,
            adminBypass = zone.policy.adminBypass ~= false,
            denyTags = tagsText(zone.policy.denyTags),
            requireTags = tagsText(zone.policy.requireAnyTags),
            features = E.copyFeatures(zone.features),
            segments = segments,
        }
    end
    table.sort(zones, function(a, b)
        local aName, bName = string.lower(a.name or a.id), string.lower(b.name or b.id)
        if aName ~= bName then return aName < bName end
        return a.id < b.id
    end)
    sendServerCommand(player, MODULE, ADMIN_STATE, {
        zones = zones,
        vehicleMode = E.vehicleMode,
        borderWidth = E.BORDER_WIDTH,
    })
end

local function publish(E, player, message)
    E.syncAllBoundaryStates()
    adminState(E, player)
    if message then reply(player, message) end
end

local function findOnlinePlayer(username, fallback)
    username = trim(username)
    if username == "" then return fallback end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    for index = 0, players:size() - 1 do
        local candidate = players:get(index)
        if string.lower(candidate:getUsername()) == string.lower(username) then return candidate end
    end
    return nil
end

local function nearestFeatureZone(E, target, feature)
    local winner, winnerRegion, winnerDistance
    for _, zone in pairs(E.zones) do
        if zone.features and zone.features[feature] then
            local region, distance = E.nearestRegion(zone, target:getX(), target:getY())
            if region and (not winner or distance < winnerDistance or
                (distance == winnerDistance and zone.id < winner.id)) then
                winner, winnerRegion, winnerDistance = zone, region, distance
            end
        end
    end
    return winner, winnerRegion
end

local function moveTargetToRegion(E, target, zone, region)
    local x, y = E.regionCenter(region)
    local z = zone.zMode == "floor" and zone.zMin or target:getZ()
    local vehicle = target:getVehicle()
    if vehicle and vehicle:getCharacter(0) == target then
        E.reboundVehicle(vehicle, vehicle:getX(), vehicle:getY(), x, y)
    elseif vehicle then
        E.forcePassengerOut(target, x, y, z)
    else
        E.teleportPlayer(target, x, y, z)
    end
end

local function featureIsValid(E, feature)
    for _, key in ipairs(E.FEATURE_KEYS) do
        if key == feature then return true end
    end
    return false
end
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= MODULE then return end
    if not player or player:getAccessLevel() ~= "admin" then
        if player then reply(player, "Admin access is required for zone-harness commands.") end
        return
    end

    local E = rawget(_G, "PZZoneEngine")
    if not E then
        reply(player, "PZZoneEngine_Test is not loaded.")
        return
    end

    if command == "requestAdminState" then
        E.syncBoundaryState(player)
        adminState(E, player)
    elseif command == "syncZones" then
        publish(E, player, "Zone state re-broadcast to all players.")
    elseif command == "demoHere" then
        local ok, message = createDemo(player)
        if ok then publish(E, player, message) else reply(player, message) end
    elseif command == "clear" then
        E.clear()
        publish(E, player, "All test zones and movement state cleared.")
    elseif command == "profile" then
        local target = args and args.username or player:getUsername()
        local profile = args and args.profile or "none"
        E.setProfile(target, tagsFor(profile))
        publish(E, player, "Profile for " .. tostring(target) .. " set to " .. tostring(profile) .. ".")
    elseif command == "vehicleMode" then
        E.vehicleMode = (args and args.mode == "rebound") and "rebound" or "observe"
        publish(E, player, "Vehicle mode: " .. E.vehicleMode)
    elseif command == "testFeature" then
        local feature = tostring(args and args.feature or "")
        if not featureIsValid(E, feature) then reply(player, "Select a valid zone feature.") return end
        local target = findOnlinePlayer(args and args.username, player)
        if not target then reply(player, "Target player is not online.") return end
        local zone, region = nearestFeatureZone(E, target, feature)
        if not zone then reply(player, "No zone currently has " .. feature .. " enabled.") return end
        moveTargetToRegion(E, target, zone, region)
        reply(player, "Moved " .. target:getUsername() .. " to nearest " .. feature .. " zone: " .. zone.name .. ".")
    elseif command == "probeFeature" then
        local target = findOnlinePlayer(args and args.username, player)
        if not target then reply(player, "Target player is not online.") return end
        local vehicle = target:getVehicle()
        local x, y = target:getX(), target:getY()
        if vehicle then x, y = vehicle:getX(), vehicle:getY() end
        local zone = E.getAuthority(x, y, target:getZ(), vehicle and 2.0 or 0)
        if not zone then reply(player, target:getUsername() .. " is not in a zone.") return end
        local flags = {}
        for _, key in ipairs(E.FEATURE_KEYS) do
            if zone.features and zone.features[key] then flags[#flags + 1] = key end
        end
        reply(player, target:getUsername() .. " authority: " .. zone.name .. " [" .. table.concat(flags, ", ") .. "]")
    elseif command == "cagePlayer" then
        local target = findOnlinePlayer(args and args.username, player)
        if not target then reply(player, "Target player is not online.") return end
        local zone = nearestFeatureZone(E, target, "isCage")
        if not zone then reply(player, "No Cage zone exists.") return end
        local ok, cageError = E.assignCage(target, zone)
        if not ok then reply(player, tostring(cageError)) return end
        reply(player, "Caged " .. target:getUsername() .. " in nearest Cage zone: " .. zone.name .. ".")
    elseif command == "uncagePlayer" then
        local target = findOnlinePlayer(args and args.username, player)
        if not target then reply(player, "Target player is not online.") return end
        if E.releaseCage(target) then
            reply(player, "Released " .. target:getUsername() .. " from Cage assignment.")
        else
            reply(player, target:getUsername() .. " is not caged.")
        end
    elseif command == "quickCreateZone" then
        local name = trim(args and args.name)
        if name == "" then name = "New Zone" end
        local px, py = math.floor(player:getX()), math.floor(player:getY())
        local region, regionError = validRegionArgs({
            x1 = tonumber(args and args.x1) or px - 5,
            y1 = tonumber(args and args.y1) or py - 5,
            x2 = tonumber(args and args.x2) or px + 5,
            y2 = tonumber(args and args.y2) or py + 5,
        })
        if not region then reply(player, regionError) return end
        local id = uniqueZoneId(E, name)
        local zone, addError = E.addRegion(id, region.x1, region.y1, region.x2, region.y2, {
            name = name,
            priority = 0,
            zMode = "all",
            policy = { denyTags = {}, requireAnyTags = {}, adminBypass = true },
            features = {},
        })
        if not zone then reply(player, tostring(addError)) return end
        publish(E, player, "Created zone " .. name .. ". Select it and click feature icons.")
    elseif command == "toggleFeature" then
        local id = tostring(args and args.id or "")
        local key = tostring(args and args.feature or "")
        local enabled = args and args.enabled == true
        local ok, featureError = E.setZoneFeature(id, key, enabled)
        if not ok then reply(player, tostring(featureError)) return end
        publish(E, player, tostring(E.zones[id].name) .. ": " .. key .. "=" .. tostring(enabled))
    elseif command == "setPrimaryPoint" then
        local id = tostring(args and args.id or "")
        local zone = E.zones[id]
        local region = zone and zone.regions[1] or nil
        if not region then reply(player, "The selected zone has no primary segment.") return end
        local x1, y1 = region.xMin, region.yMin
        local x2, y2 = region.xMax - 1, region.yMax - 1
        local px, py = math.floor(player:getX()), math.floor(player:getY())
        if args and args.corner == 1 then x1, y1 = px, py else x2, y2 = px, py end
        local ok, pointError = E.updateRegion(id, 1, x1, y1, x2, y2)
        if not ok then reply(player, tostring(pointError)) return end
        publish(E, player, "Updated primary point " .. tostring(args and args.corner or 2) .. " for " .. zone.name .. ".")
    elseif command == "teleportToZone" then
        local id = tostring(args and args.id or "")
        local zone = E.zones[id]
        local region = zone and zone.regions[1] or nil
        if not region then reply(player, "The selected zone has no primary segment.") return end
        local x = math.floor((region.xMin + region.xMax - 1) / 2)
        local y = math.floor((region.yMin + region.yMax - 1) / 2)
        local z = zone.zMode == "floor" and zone.zMin or player:getZ()
        local vehicle = player:getVehicle()
        if vehicle and vehicle:getCharacter(0) == player then
            E.reboundVehicle(vehicle, vehicle:getX(), vehicle:getY(), x, y)
        elseif vehicle then
            E.forcePassengerOut(player, x, y, z)
        else
            E.teleportPlayer(player, x, y, z)
        end
        reply(player, "Teleported to " .. zone.name .. ".")
    elseif command == "backupZones" then
        zoneBackup = copyTable(E.zones)
        reply(player, "Zone backup captured in server memory.")
    elseif command == "restoreZones" then
        if not zoneBackup then reply(player, "No in-memory zone backup exists yet.") return end
        E.zones = copyTable(zoneBackup)
        E.lastValid = {}
        E.cageAssignments = {}
        E.rebuildIndex()
        publish(E, player, "Restored the in-memory zone backup.")
    elseif command == "createZone" then
        local id = tostring(args and args.id or "")
        if id == "" then reply(player, "Zone ID is required.") return end
        if E.zones[id] then reply(player, "Zone ID already exists: " .. id) return end
        local region, regionError = validRegionArgs(args)
        if not region then reply(player, regionError) return end
        local options, optionError = editorOptions(args)
        if not options then reply(player, optionError) return end
        local zone, addError = E.addRegion(id, region.x1, region.y1, region.x2, region.y2, options)
        if not zone then reply(player, tostring(addError)) return end
        publish(E, player, "Created zone " .. id .. ".")
    elseif command == "updateZone" then
        local id = tostring(args and args.id or "")
        local options, optionError = editorOptions(args)
        if not options then reply(player, optionError) return end
        local ok, updateError = E.updateZone(id, options)
        if not ok then reply(player, tostring(updateError)) return end
        publish(E, player, "Updated zone " .. id .. ".")
    elseif command == "addSegment" then
        local id = tostring(args and args.id or "")
        if not E.zones[id] then reply(player, "Select an existing zone first.") return end
        local region, regionError = validRegionArgs(args)
        if not region then reply(player, regionError) return end
        local zone, addError = E.addRegion(id, region.x1, region.y1, region.x2, region.y2, {})
        if not zone then reply(player, tostring(addError)) return end
        publish(E, player, "Added a segment to " .. id .. ".")
    elseif command == "updateSegment" then
        local id = tostring(args and args.id or "")
        local region, regionError = validRegionArgs(args)
        if not region then reply(player, regionError) return end
        local ok, updateError = E.updateRegion(id, args and args.regionIndex,
            region.x1, region.y1, region.x2, region.y2)
        if not ok then reply(player, tostring(updateError)) return end
        publish(E, player, "Updated the selected segment in " .. id .. ".")
    elseif command == "removeSegment" then
        local id = tostring(args and args.id or "")
        local ok, removeError = E.removeRegion(id, args and args.regionIndex)
        if not ok then reply(player, tostring(removeError)) return end
        publish(E, player, "Removed the selected segment from " .. id .. ".")
    elseif command == "deleteZone" then
        local id = tostring(args and args.id or "")
        local ok, removeError = E.removeZone(id)
        if not ok then reply(player, tostring(removeError)) return end
        publish(E, player, "Deleted zone " .. id .. ".")
    elseif command == "status" then
        local count = 0
        for _ in pairs(E.zones) do count = count + 1 end
        reply(player, "Zones=" .. count .. " vehicleMode=" .. E.vehicleMode .. " events=" .. #E.eventLog)
    end
end)