ParadiseDev = ParadiseDev or {}
ParadiseDev.Zones = ParadiseDev.Zones or {}
ParadiseDev.Zones.Harness = ParadiseDev.Zones.Harness or {}


local MODULE = "PZZoneHarness"
local RESULT = "result"
local ADMIN_STATE = "adminState"
local zoneBackup = nil

function ParadiseDev.Zones.Harness.copyTable(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do result[ParadiseDev.Zones.Harness.copyTable(key, seen)] = ParadiseDev.Zones.Harness.copyTable(item, seen) end
    return result
end

function ParadiseDev.Zones.Harness.trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function ParadiseDev.Zones.Harness.uniqueZoneId(engine, name)
    local base = string.lower(name):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if base == "" then base = "zone" end
    local id, suffix = base, 2
    while ParadiseDev.Zones.Engine.zones[id] do
        id = base .. "_" .. tostring(suffix)
        suffix = suffix + 1
    end
    return id
end

function ParadiseDev.Zones.Harness.reply(pl, text)
    sendServerCommand(pl, MODULE, RESULT, { text = text })
end

function ParadiseDev.Zones.Harness.tagsFor(profile)
    if profile == "pve" then return { pve = true } end
    if profile == "range_staff" then return { range_staff = true } end
    if profile == "both" then return { pve = true, range_staff = true } end
    return {}
end

function ParadiseDev.Zones.Harness.parseTags(value)
    local tags = {}
    for tag in string.gmatch(tostring(value or ""), "[^,%s]+") do
        tags[tag] = true
    end
    return tags
end

function ParadiseDev.Zones.Harness.tagsText(tags)
    local values = {}
    for tag, enabled in pairs(tags or {}) do
        if enabled then values[#values + 1] = tag end
    end
    table.sort(values)
    return table.concat(values, ",")
end

function ParadiseDev.Zones.Harness.editorOptions(args)
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
            denyTags = ParadiseDev.Zones.Harness.parseTags(args and args.denyTags),
            requireAnyTags = ParadiseDev.Zones.Harness.parseTags(args and args.requireTags),
            adminBypass = not (args and args.adminBypass == false),
        },
    }
end

function ParadiseDev.Zones.Harness.validRegionArgs(args)
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

function ParadiseDev.Zones.Harness.createDemo(pl)
    local engine = ParadiseDev.Zones.Engine
    if not engine then return false, "Zone engine is not loaded" end
    ParadiseDev.Zones.Engine.clear()
    local x, y = math.floor(pl:getX()), math.floor(pl:getY())

    ParadiseDev.Zones.Engine.addRegion("kos_demo", x + 10, y - 5, x + 19, y + 4, {
        name = "KoS Demo", priority = 100,
        policy = { denyTags = {}, requireAnyTags = {} },
        features = { isKos = true },
    })

    ParadiseDev.Zones.Engine.addRegion("range_l_demo", x + 30, y - 10, x + 34, y + 10, {
        name = "Range L Demo", priority = 200,
        policy = { denyTags = {}, requireAnyTags = {} },
        features = { isHunt = true },
    })
    ParadiseDev.Zones.Engine.addRegion("range_l_demo", x + 34, y + 6, x + 49, y + 10, {})

    ParadiseDev.Zones.Engine.addRegion("blocked_demo", x + 15, y - 2, x + 22, y + 2, {
        name = "Blocked Priority Demo", priority = 300,
        policy = { denyTags = {}, requireAnyTags = {} },
        features = { isBlocked = true },
    })

    return true, "Demo zones created east of you: KoS(priority 100), Range L(priority 200), Blocked(priority 300)."
end

function ParadiseDev.Zones.Harness.adminState(engine, pl)
    local zones = {}
    for _, zone in pairs(ParadiseDev.Zones.Engine.zones) do
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
            denyTags = ParadiseDev.Zones.Harness.tagsText(zone.policy.denyTags),
            requireTags = ParadiseDev.Zones.Harness.tagsText(zone.policy.requireAnyTags),
            features = ParadiseDev.Zones.Engine.copyFeatures(zone.features),
            segments = segments,
        }
    end
    table.sort(zones, function(a, b)
        local aName, bName = string.lower(a.name or a.id), string.lower(b.name or b.id)
        if aName ~= bName then return aName < bName end
        return a.id < b.id
    end)
    sendServerCommand(pl, MODULE, ADMIN_STATE, {
        zones = zones,
        vehicleMode = ParadiseDev.Zones.Engine.vehicleMode,
        borderWidth = ParadiseDev.Zones.Engine.BORDER_WIDTH,
    })
end

function ParadiseDev.Zones.Harness.publish(engine, pl, message)
    ParadiseDev.Zones.Engine.syncAllBoundaryStates()
    ParadiseDev.Zones.Harness.adminState(engine, pl)
    if message then ParadiseDev.Zones.Harness.reply(pl, message) end
end

function ParadiseDev.Zones.Harness.findOnlinePlayer(username, fallback)
    username = ParadiseDev.Zones.Harness.trim(username)
    if username == "" then return fallback end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    for index = 0, players:size() - 1 do
        local candidate = players:get(index)
        if string.lower(candidate:getUsername()) == string.lower(username) then return candidate end
    end
    return nil
end

function ParadiseDev.Zones.Harness.nearestFeatureZone(engine, target, feature)
    local winner, winnerRegion, winnerDistance
    for _, zone in pairs(ParadiseDev.Zones.Engine.zones) do
        if zone.features and zone.features[feature] then
            local region, distance = ParadiseDev.Zones.Engine.nearestRegion(zone, target:getX(), target:getY())
            if region and (not winner or distance < winnerDistance or
                (distance == winnerDistance and zone.id < winner.id)) then
                winner, winnerRegion, winnerDistance = zone, region, distance
            end
        end
    end
    return winner, winnerRegion
end

function ParadiseDev.Zones.Harness.moveTargetToRegion(engine, target, zone, region)
    local x, y = ParadiseDev.Zones.Engine.regionCenter(region)
    local z = zone.zMode == "floor" and zone.zMin or target:getZ()
    local vehicle = target:getVehicle()
    if vehicle and vehicle:getCharacter(0) == target then
        ParadiseDev.Zones.Engine.reboundVehicle(vehicle, vehicle:getX(), vehicle:getY(), x, y)
    elseif vehicle then
        ParadiseDev.Zones.Engine.forcePassengerOut(target, x, y, z)
    else
        ParadiseDev.Zones.Engine.teleportPlayer(target, x, y, z)
    end
end

function ParadiseDev.Zones.Harness.featureIsValid(engine, feature)
    for _, key in ipairs(ParadiseDev.Zones.Engine.FEATURE_KEYS) do
        if key == feature then return true end
    end
    return false
end
function ParadiseDev.Zones.Harness.onClientCommand(module, command, pl, args)
    if module ~= MODULE then return end
    if not pl or not ParadiseDev.isAdm(pl) then
        if pl then ParadiseDev.Zones.Harness.reply(pl, "Admin access is required for zone-harness commands.") end
        return
    end

    local engine = ParadiseDev.Zones.Engine
    if not engine then
        ParadiseDev.Zones.Harness.reply(pl, "PZZoneEngine_Test is not loaded.")
        return
    end

    if command == "requestAdminState" then
        ParadiseDev.Zones.Engine.syncBoundaryState(pl)
        ParadiseDev.Zones.Harness.adminState(engine, pl)
    elseif command == "syncZones" then
        ParadiseDev.Zones.Harness.publish(engine, pl, "Zone state re-broadcast to all players.")
    elseif command == "demoHere" then
        local ok, message = ParadiseDev.Zones.Harness.createDemo(pl)
        if ok then ParadiseDev.Zones.Harness.publish(engine, pl, message) else ParadiseDev.Zones.Harness.reply(pl, message) end
    elseif command == "clear" then
        ParadiseDev.Zones.Engine.clear()
        ParadiseDev.Zones.Harness.publish(engine, pl, "All test zones and movement state cleared.")
    elseif command == "profile" then
        local target = args and args.username or pl:getUsername()
        local profile = args and args.profile or "none"
        ParadiseDev.Zones.Engine.setProfile(target, ParadiseDev.Zones.Harness.tagsFor(profile))
        ParadiseDev.Zones.Harness.publish(engine, pl, "Profile for " .. tostring(target) .. " set to " .. tostring(profile) .. ".")
    elseif command == "vehicleMode" then
        ParadiseDev.Zones.Engine.vehicleMode = (args and args.mode == "rebound") and "rebound" or "observe"
        ParadiseDev.Zones.Harness.publish(engine, pl, "Vehicle mode: " .. ParadiseDev.Zones.Engine.vehicleMode)
    elseif command == "testFeature" then
        local feature = tostring(args and args.feature or "")
        if not ParadiseDev.Zones.Harness.featureIsValid(engine, feature) then ParadiseDev.Zones.Harness.reply(pl, "Select a valid zone feature.") return end
        local target = ParadiseDev.Zones.Harness.findOnlinePlayer(args and args.username, pl)
        if not target then ParadiseDev.Zones.Harness.reply(pl, "Target player is not online.") return end
        local zone, region = ParadiseDev.Zones.Harness.nearestFeatureZone(engine, target, feature)
        if not zone then ParadiseDev.Zones.Harness.reply(pl, "No zone currently has " .. feature .. " enabled.") return end
        ParadiseDev.Zones.Harness.moveTargetToRegion(engine, target, zone, region)
        ParadiseDev.Zones.Harness.reply(pl, "Moved " .. target:getUsername() .. " to nearest " .. feature .. " zone: " .. zone.name .. ".")
    elseif command == "probeFeature" then
        local target = ParadiseDev.Zones.Harness.findOnlinePlayer(args and args.username, pl)
        if not target then ParadiseDev.Zones.Harness.reply(pl, "Target player is not online.") return end
        local vehicle = target:getVehicle()
        local x, y = target:getX(), target:getY()
        if vehicle then x, y = vehicle:getX(), vehicle:getY() end
        local zone = ParadiseDev.Zones.Engine.getAuthority(x, y, target:getZ(), vehicle and 2.0 or 0)
        if not zone then ParadiseDev.Zones.Harness.reply(pl, target:getUsername() .. " is not in a zone.") return end
        local flags = {}
        for _, key in ipairs(ParadiseDev.Zones.Engine.FEATURE_KEYS) do
            if zone.features and zone.features[key] then flags[#flags + 1] = key end
        end
        ParadiseDev.Zones.Harness.reply(pl, target:getUsername() .. " authority: " .. zone.name .. " [" .. table.concat(flags, ", ") .. "]")
    elseif command == "cagePlayer" then
        local target = ParadiseDev.Zones.Harness.findOnlinePlayer(args and args.username, pl)
        if not target then ParadiseDev.Zones.Harness.reply(pl, "Target player is not online.") return end
        local zone = ParadiseDev.Zones.Harness.nearestFeatureZone(engine, target, "isCage")
        if not zone then ParadiseDev.Zones.Harness.reply(pl, "No Cage zone exists.") return end
        local ok, cageError = ParadiseDev.Zones.Engine.assignCage(target, zone)
        if not ok then ParadiseDev.Zones.Harness.reply(pl, tostring(cageError)) return end
        ParadiseDev.Zones.Harness.reply(pl, "Caged " .. target:getUsername() .. " in nearest Cage zone: " .. zone.name .. ".")
    elseif command == "uncagePlayer" then
        local target = ParadiseDev.Zones.Harness.findOnlinePlayer(args and args.username, pl)
        if not target then ParadiseDev.Zones.Harness.reply(pl, "Target player is not online.") return end
        if ParadiseDev.Zones.Engine.releaseCage(target) then
            ParadiseDev.Zones.Harness.reply(pl, "Released " .. target:getUsername() .. " from Cage assignment.")
        else
            ParadiseDev.Zones.Harness.reply(pl, target:getUsername() .. " is not caged.")
        end
    elseif command == "quickCreateZone" then
        local name = ParadiseDev.Zones.Harness.trim(args and args.name)
        if name == "" then name = "New Zone" end
        local px, py = math.floor(pl:getX()), math.floor(pl:getY())
        local region, regionError = ParadiseDev.Zones.Harness.validRegionArgs({
            x1 = tonumber(args and args.x1) or px - 5,
            y1 = tonumber(args and args.y1) or py - 5,
            x2 = tonumber(args and args.x2) or px + 5,
            y2 = tonumber(args and args.y2) or py + 5,
        })
        if not region then ParadiseDev.Zones.Harness.reply(pl, regionError) return end
        local id = ParadiseDev.Zones.Harness.uniqueZoneId(engine, name)
        local zone, addError = ParadiseDev.Zones.Engine.addRegion(id, region.x1, region.y1, region.x2, region.y2, {
            name = name,
            priority = 0,
            zMode = "all",
            policy = { denyTags = {}, requireAnyTags = {}, adminBypass = true },
            features = {},
        })
        if not zone then ParadiseDev.Zones.Harness.reply(pl, tostring(addError)) return end
        ParadiseDev.Zones.Harness.publish(engine, pl, "Created zone " .. name .. ". Select it and click feature icons.")
    elseif command == "toggleFeature" then
        local id = tostring(args and args.id or "")
        local key = tostring(args and args.feature or "")
        local enabled = args and args.enabled == true
        local ok, featureError = ParadiseDev.Zones.Engine.setZoneFeature(id, key, enabled)
        if not ok then ParadiseDev.Zones.Harness.reply(pl, tostring(featureError)) return end
        ParadiseDev.Zones.Harness.publish(engine, pl, tostring(ParadiseDev.Zones.Engine.zones[id].name) .. ": " .. key .. "=" .. tostring(enabled))
    elseif command == "setPrimaryPoint" then
        local id = tostring(args and args.id or "")
        local zone = ParadiseDev.Zones.Engine.zones[id]
        local region = zone and zone.regions[1] or nil
        if not region then ParadiseDev.Zones.Harness.reply(pl, "The selected zone has no primary segment.") return end
        local x1, y1 = region.xMin, region.yMin
        local x2, y2 = region.xMax - 1, region.yMax - 1
        local px, py = math.floor(pl:getX()), math.floor(pl:getY())
        if args and args.corner == 1 then x1, y1 = px, py else x2, y2 = px, py end
        local ok, pointError = ParadiseDev.Zones.Engine.updateRegion(id, 1, x1, y1, x2, y2)
        if not ok then ParadiseDev.Zones.Harness.reply(pl, tostring(pointError)) return end
        ParadiseDev.Zones.Harness.publish(engine, pl, "Updated primary point " .. tostring(args and args.corner or 2) .. " for " .. zone.name .. ".")
    elseif command == "teleportToZone" then
        local id = tostring(args and args.id or "")
        local zone = ParadiseDev.Zones.Engine.zones[id]
        local region = zone and zone.regions[1] or nil
        if not region then ParadiseDev.Zones.Harness.reply(pl, "The selected zone has no primary segment.") return end
        local x = math.floor((region.xMin + region.xMax - 1) / 2)
        local y = math.floor((region.yMin + region.yMax - 1) / 2)
        local z = zone.zMode == "floor" and zone.zMin or pl:getZ()
        local vehicle = pl:getVehicle()
        if vehicle and vehicle:getCharacter(0) == pl then
            ParadiseDev.Zones.Engine.reboundVehicle(vehicle, vehicle:getX(), vehicle:getY(), x, y)
        elseif vehicle then
            ParadiseDev.Zones.Engine.forcePassengerOut(pl, x, y, z)
        else
            ParadiseDev.Zones.Engine.teleportPlayer(pl, x, y, z)
        end
        ParadiseDev.Zones.Harness.reply(pl, "Teleported to " .. zone.name .. ".")
    elseif command == "backupZones" then
        zoneBackup = ParadiseDev.Zones.Harness.copyTable(ParadiseDev.Zones.Engine.zones)
        ParadiseDev.Zones.Harness.reply(pl, "Zone backup captured in server memory.")
    elseif command == "restoreZones" then
        if not zoneBackup then ParadiseDev.Zones.Harness.reply(pl, "No in-memory zone backup exists yet.") return end
        ParadiseDev.Zones.Engine.zones = ParadiseDev.Zones.Harness.copyTable(zoneBackup)
        ParadiseDev.Zones.Engine.lastValid = {}
        ParadiseDev.Zones.Engine.cageAssignments = {}
        ParadiseDev.Zones.Engine.rebuildIndex()
        ParadiseDev.Zones.Harness.publish(engine, pl, "Restored the in-memory zone backup.")
    elseif command == "createZone" then
        local id = tostring(args and args.id or "")
        if id == "" then ParadiseDev.Zones.Harness.reply(pl, "Zone ID is required.") return end
        if ParadiseDev.Zones.Engine.zones[id] then ParadiseDev.Zones.Harness.reply(pl, "Zone ID already exists: " .. id) return end
        local region, regionError = ParadiseDev.Zones.Harness.validRegionArgs(args)
        if not region then ParadiseDev.Zones.Harness.reply(pl, regionError) return end
        local options, optionError = ParadiseDev.Zones.Harness.editorOptions(args)
        if not options then ParadiseDev.Zones.Harness.reply(pl, optionError) return end
        local zone, addError = ParadiseDev.Zones.Engine.addRegion(id, region.x1, region.y1, region.x2, region.y2, options)
        if not zone then ParadiseDev.Zones.Harness.reply(pl, tostring(addError)) return end
        ParadiseDev.Zones.Harness.publish(engine, pl, "Created zone " .. id .. ".")
    elseif command == "updateZone" then
        local id = tostring(args and args.id or "")
        local options, optionError = ParadiseDev.Zones.Harness.editorOptions(args)
        if not options then ParadiseDev.Zones.Harness.reply(pl, optionError) return end
        local ok, updateError = ParadiseDev.Zones.Engine.updateZone(id, options)
        if not ok then ParadiseDev.Zones.Harness.reply(pl, tostring(updateError)) return end
        ParadiseDev.Zones.Harness.publish(engine, pl, "Updated zone " .. id .. ".")
    elseif command == "addSegment" then
        local id = tostring(args and args.id or "")
        if not ParadiseDev.Zones.Engine.zones[id] then ParadiseDev.Zones.Harness.reply(pl, "Select an existing zone first.") return end
        local region, regionError = ParadiseDev.Zones.Harness.validRegionArgs(args)
        if not region then ParadiseDev.Zones.Harness.reply(pl, regionError) return end
        local zone, addError = ParadiseDev.Zones.Engine.addRegion(id, region.x1, region.y1, region.x2, region.y2, {})
        if not zone then ParadiseDev.Zones.Harness.reply(pl, tostring(addError)) return end
        ParadiseDev.Zones.Harness.publish(engine, pl, "Added a segment to " .. id .. ".")
    elseif command == "updateSegment" then
        local id = tostring(args and args.id or "")
        local region, regionError = ParadiseDev.Zones.Harness.validRegionArgs(args)
        if not region then ParadiseDev.Zones.Harness.reply(pl, regionError) return end
        local ok, updateError = ParadiseDev.Zones.Engine.updateRegion(id, args and args.regionIndex,
            region.x1, region.y1, region.x2, region.y2)
        if not ok then ParadiseDev.Zones.Harness.reply(pl, tostring(updateError)) return end
        ParadiseDev.Zones.Harness.publish(engine, pl, "Updated the selected segment in " .. id .. ".")
    elseif command == "removeSegment" then
        local id = tostring(args and args.id or "")
        local ok, removeError = ParadiseDev.Zones.Engine.removeRegion(id, args and args.regionIndex)
        if not ok then ParadiseDev.Zones.Harness.reply(pl, tostring(removeError)) return end
        ParadiseDev.Zones.Harness.publish(engine, pl, "Removed the selected segment from " .. id .. ".")
    elseif command == "deleteZone" then
        local id = tostring(args and args.id or "")
        local ok, removeError = ParadiseDev.Zones.Engine.removeZone(id)
        if not ok then ParadiseDev.Zones.Harness.reply(pl, tostring(removeError)) return end
        ParadiseDev.Zones.Harness.publish(engine, pl, "Deleted zone " .. id .. ".")
    elseif command == "status" then
        local count = 0
        for _ in pairs(ParadiseDev.Zones.Engine.zones) do count = count + 1 end
        ParadiseDev.Zones.Harness.reply(pl, "Zones=" .. count .. " vehicleMode=" .. ParadiseDev.Zones.Engine.vehicleMode .. " events=" .. #ParadiseDev.Zones.Engine.eventLog)
    end
end

Events.OnClientCommand.Remove(ParadiseDev.Zones.Harness.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Zones.Harness.onClientCommand)
