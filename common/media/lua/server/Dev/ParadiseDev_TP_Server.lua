ParadiseDev = ParadiseDev or {}
ParadiseDev.TP = ParadiseDev.TP or {}
ParadiseDev.Debug = ParadiseDev.Debug or {}
ParadiseDev.POI = ParadiseDev.POI or {}



ParadiseDev.TP.module = "ParadiseDevTP"
ParadiseDev.Debug.module = "ParadiseDevDebug"
ParadiseDev.POI.module = "ParadisePOI"
function ParadiseDev.Debug.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.Debug.module or command ~= "testDmg" then return end
    if not pl or not ParadiseRestore.isAdm(pl) then return end
    local targ = args and getPlayerByOnlineID(args.targId) or nil
    if not targ then return end
    local dmg = math.min(100, math.max(0, tonumber(args.dmg) or 15))
    sendServerCommand(targ, ParadiseDev.Debug.module, "testDmg", { dmg = dmg, pushedDir = args.pushedDir })
end

function ParadiseDev.POI.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.POI.module then return end

    if command == "requestSync" then
        if not ParadiseRestore.isAdm(pl) then return end
        local data = ModData.getOrCreate("ParadisePOI_Data")
        sendServerCommand(pl, ParadiseDev.POI.module, "sync", { data = data })
        return
    end

    if not ParadiseRestore.isAdm(pl) then return end

    if command == "save" and args and args.label then
        local label = tostring(args.label):gsub("^%s*(.-)%s*$", "%1")
        if label == "" then return end
        local data = ModData.getOrCreate("ParadisePOI_Data")
        data[label] = { x = args.x, y = args.y, z = args.z, desc = args.desc }
        ModData.transmit("ParadisePOI_Data")
        sendServerCommand(ParadiseDev.POI.module, "sync", { data = data })
    elseif command == "delete" and args and args.label and args.label ~= "" then
        local data = ModData.getOrCreate("ParadisePOI_Data")
        data[args.label] = nil
        ModData.transmit("ParadisePOI_Data")
        sendServerCommand(ParadiseDev.POI.module, "sync", { data = data })
    end
end

function ParadiseDev.TP.validCoordinates(x, y, z)
    local function finite(value)
        local n = tonumber(value)
        return n ~= nil and n == n and n ~= math.huge and n ~= -math.huge
    end
    return finite(x) and finite(y) and finite(z)
end

-- One native transfer in flight per player. Native Teleport is reliable but not
-- ordered; wait for its resulting position before sending a different target.
ParadiseDev.TP.pendingTeleports = ParadiseDev.TP.pendingTeleports or {}

local function sameDestination(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z
end

local function arrived(pl, point)
    return not pl:getVehicle() and math.abs(pl:getX() - point.x) <= 1.25 and
        math.abs(pl:getY() - point.y) <= 1.25 and math.floor(pl:getZ()) == math.floor(point.z)
end

local function complete(point)
    if point.onArrive then
        local ok = pcall(point.onArrive)
        if not ok then print('[ParadiseTP] Transfer arrived; completion callback failed.') end
    end
end

local function sendNative(pl, point)
    if type(ParadiseLifeBridge) ~= 'function' then
        return false
    end
    local ok, accepted = pcall(ParadiseLifeBridge, 'teleport', pl, point.x, point.y, point.z)
    return ok and accepted == true
end

function ParadiseDev.TP.teleportPlayer(pl, x, y, z, onArrive)
    if not pl or not pl:isAlive() or not ParadiseDev.TP.validCoordinates(x, y, z) then return false end
    local point = { x = tonumber(x), y = tonumber(y), z = tonumber(z), onArrive = onArrive }
    if not isServer() then
        if isClient() or not pl.teleportTo then return false end
        pl:teleportTo(point.x, point.y, point.z)
        complete(point)
        return true, true
    end
    local pending = ParadiseDev.TP.pendingTeleports[pl]
    if pending then
        if sameDestination(pending.current, point) then
            if onArrive then pending.current.onArrive = onArrive end
            pending.next = nil
        elseif pending.next and sameDestination(pending.next, point) then
            if onArrive then pending.next.onArrive = onArrive end
        else
            pending.next = point
        end
        return true, false
    end
    if arrived(pl, point) then complete(point); return true, false end
    if not sendNative(pl, point) then
        local now = getTimestampMs()
        if not ParadiseDev.TP.lastBridgeWarning or now - ParadiseDev.TP.lastBridgeWarning >= 30000 then
            ParadiseDev.TP.lastBridgeWarning = now
            print('[ParadiseTP] Native transfer unavailable; verify the Paradise life bridge installation.')
        end
        return false
    end
    ParadiseDev.TP.pendingTeleports[pl] = { current = point, started = getTimestampMs() }
    return true, true
end

function ParadiseDev.TP.observeTeleports()
    if not isServer() then return end
    local now = getTimestampMs()
    for pl, pending in pairs(ParadiseDev.TP.pendingTeleports) do
        if not pl:isAlive() or getPlayerByOnlineID(pl:getOnlineID()) ~= pl then
            ParadiseDev.TP.pendingTeleports[pl] = nil
        elseif arrived(pl, pending.current) then
            if not pending.completed then complete(pending.current); pending.completed = true end
            local nextPoint = pending.next
            if not nextPoint then
                ParadiseDev.TP.pendingTeleports[pl] = nil
            elseif arrived(pl, nextPoint) then
                complete(nextPoint)
                ParadiseDev.TP.pendingTeleports[pl] = nil
            elseif not pending.retryAt or now >= pending.retryAt then
                if sendNative(pl, nextPoint) then
                    pending.current, pending.next, pending.started, pending.warned = nextPoint, nil, now, nil
                    pending.completed, pending.retryAt = nil, nil
                else
                    pending.retryAt = now + 5000
                    if not pending.warned then
                        pending.warned = true
                        print('[ParadiseTP] Queued native transfer unavailable; return location retained.')
                    end
                end
            end
        elseif now - pending.started >= 30000 and not pending.warned then
            pending.warned = true
            -- Do not send another unordered teleport on timeout. Keep watching
            -- for arrival or disconnect, preserving any cage return metadata.
            sendServerCommand(pl, ParadiseDev.TP.module, 'message', {
                text = 'Transfer is still awaiting synchronization. Reconnect if it does not finish.'
            })
        end
    end
end

function ParadiseDev.TP.saveRebound(pl, name)
    if not pl then return nil end
    local point = { x = pl:getX(), y = pl:getY(), z = pl:getZ(), name = name or "Rebound" }
    local modData = pl:getModData()
    modData.ParadiseZRebound = point
    modData.Rebound = point
    return point
end

function ParadiseDev.TP.reboundVehicle(vehicle, fromX, fromY, toX, toY, pl)
    if not vehicle or not fromX or not fromY or not toX or not toY then return false end
    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    origin:set(origin:x() + (tonumber(toX) - tonumber(fromX)), origin:y(), origin:z() + (tonumber(toY) - tonumber(fromY)))
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    if pl then sendServerCommand(pl, ParadiseDev.TP.module, "vehicleTeleport", {
        id = vehicle:getId(), x = tonumber(toX), y = tonumber(toY),
    }) end
    return true
end

function ParadiseDev.TP.teleportVehicle(vehicle, toX, toY, pl)
    if not vehicle or not ParadiseDev.TP.validCoordinates(toX, toY, 0) then return false end
    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    origin:set(origin:x() + (tonumber(toX) - vehicle:getX()), origin:y(), origin:z() + (tonumber(toY) - vehicle:getY()))
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    if pl then
        sendServerCommand(pl, ParadiseDev.TP.module, "vehicleTeleport", {
            id = vehicle:getId(), x = tonumber(toX), y = tonumber(toY),
        })
    end
    return true
end

function ParadiseDev.TP.teleportVehicleTo(vehicle, toX, toY, toZ, pl)
    if not vehicle or not ParadiseDev.TP.validCoordinates(toX, toY, toZ) then return false end
    local transform = BaseVehicle.allocTransform()
    vehicle:getWorldTransform(transform)
    local origin = transform:getOrigin()
    origin:set(origin:x() + (tonumber(toX) - vehicle:getX()), origin:y(), origin:z() + (tonumber(toZ) - vehicle:getZ()))
    vehicle:setWorldTransform(transform)
    BaseVehicle.releaseTransform(transform)
    if pl then
        sendServerCommand(pl, ParadiseDev.TP.module, "vehicleTeleport", {
            id = vehicle:getId(), x = tonumber(toX), y = tonumber(toY),
        })
    end
    return true
end

function ParadiseDev.TP.exitVehicleAndTeleport(pl, x, y, z, passengerOnly, onArrive)
    if not pl then return false end
    local vehicle = pl:getVehicle()
    if vehicle then
        local seat = vehicle:getSeat(pl)
        if seat < 0 or (passengerOnly and seat <= 0) then return false end
    end
    -- The native teleport exits the owning client and its player update clears
    -- the server seat. Do not detach only the server copy before that packet.
    return ParadiseDev.TP.teleportPlayer(pl, x, y, z, onArrive)
end

function ParadiseDev.TP.parseFallbackRebound()
    local options = SandboxVars and SandboxVars.ParadiseZ
    local value = options and options.Coords
    local x, y, z = type(value) == "string" and value:match("^%s*(-?%d+)%s*[;:]%s*(-?%d+)%s*[;:]%s*(-?%d+)%s*$")
    return tonumber(x), tonumber(y), tonumber(z)
end

function ParadiseDev.TP.getReboundXYZ(pl)
    local modData = pl and pl:getModData()
    local point = modData and (modData.ParadiseZRebound or modData.Rebound)
    if point and ParadiseDev.TP.validCoordinates(point.x, point.y, point.z) then return point.x, point.y, point.z end
    return ParadiseDev.TP.parseFallbackRebound()
end

function ParadiseDev.TP.isInKosZone(pl)
    local engine = ParadiseDev.Zones and ParadiseDev.Zones.Engine
    local zone = engine and engine.getAuthority and engine.getAuthority(pl:getX(), pl:getY(), pl:getZ())
    return zone and zone.features and zone.features.isKos == true
end

function ParadiseDev.TP.reboundPlayer(pl)
    local x, y, z = ParadiseDev.TP.getReboundXYZ(pl)
    if not ParadiseDev.TP.validCoordinates(x, y, z) then return false end
    return ParadiseDev.TP.exitVehicleAndTeleport(pl, x, y, z, false)
end

function ParadiseDev.TP.findPlayer(username, fallback)
    if not username or username == "" then return fallback end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players then
        for index = 0, players:size() - 1 do
            local player = players:get(index)
            if player and player:getUsername() == username then return player end
        end
    end
    if fallback and fallback:getUsername() == username then return fallback end
    return nil
end

function ParadiseDev.TP.reply(pl, message)
    sendServerCommand(pl, ParadiseDev.TP.module, "message", { text = message })
end

function ParadiseDev.TP.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.TP.module then return end
    if command == "saveRebound" then
        ParadiseDev.TP.saveRebound(pl, args and args.name)
    elseif command == "rebound" then
        if ParadiseDev.TP.isInKosZone(pl) then
            ParadiseDev.TP.reply(pl, "Cannot use /stuck inside a KoS zone.")
            return
        end
        ParadiseDev.TP.reboundPlayer(pl)
    elseif command == "adminRebound" and ParadiseRestore.isAdm(pl) then
        local target = ParadiseDev.TP.findPlayer(args and args.username, pl)
        if target then
            ParadiseDev.TP.reboundPlayer(target)
        else
            ParadiseDev.TP.reply(pl, "Player not found.")
        end
    elseif command == "teleport" and ParadiseRestore.isAdm(pl) then
        ParadiseDev.TP.exitVehicleAndTeleport(pl, args and args.x, args and args.y, args and args.z, false)
    elseif command == "teleportWithVehicle" and ParadiseRestore.isAdm(pl) then
        local x, y, z = args and args.x, args and args.y, args and args.z
        local vehicle = pl:getVehicle()
        if vehicle then
            ParadiseDev.TP.teleportVehicleTo(vehicle, x, y, z, pl)
        else
            ParadiseDev.TP.teleportPlayer(pl, x, y, z)
        end
    elseif command == "teleportVehicle" and ParadiseRestore.isAdm(pl) then
        local vehicle = pl:getVehicle()
        if vehicle then
            ParadiseDev.TP.teleportVehicle(vehicle, args and args.x, args and args.y, pl)
        end
    end
end

Events.OnClientCommand.Remove(ParadiseDev.TP.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.TP.onClientCommand)
Events.OnClientCommand.Remove(ParadiseDev.Debug.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Debug.onClientCommand)
Events.OnClientCommand.Remove(ParadiseDev.POI.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.POI.onClientCommand)

Events.OnTick.Remove(ParadiseDev.TP.observeTeleports)
Events.OnTick.Add(ParadiseDev.TP.observeTeleports)
