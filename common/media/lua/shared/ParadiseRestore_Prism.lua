ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.Prism = ParadiseRestore.Prism or {}

ParadiseRestore.Prism.module = "ParadiseRestore_Prism"
ParadiseRestore.Prism.command = "cast"
ParadiseRestore.Prism.activeLights = ParadiseRestore.Prism.activeLights or {}
ParadiseRestore.Prism.nextID = ParadiseRestore.Prism.nextID or 0
ParadiseRestore.Prism.weaponDefaults = ParadiseRestore.Prism.weaponDefaults or {}
ParadiseRestore.Prism.weaponDefaults.a = 1
ParadiseRestore.Prism.weaponDefaults.rad = 6
ParadiseRestore.Prism.weaponDefaults.decay = 2.5
ParadiseRestore.Prism.weaponDefaults.isFade = true

function ParadiseRestore.Prism.clamp(var, min, max)
    var = tonumber(var) or min
    if var < min then return min end
    if var > max then return max end
    return var
end

function ParadiseRestore.Prism.normalize(args)
    if type(args) ~= "table" then return nil end
    if tonumber(args.x) == nil or tonumber(args.y) == nil or tonumber(args.z) == nil then return nil end
    return {
        id = args.id and tostring(args.id) or nil,
        x = math.floor(tonumber(args.x)),
        y = math.floor(tonumber(args.y)),
        z = math.floor(ParadiseRestore.Prism.clamp(args.z, -32, 31)),
        r = ParadiseRestore.Prism.clamp(args.r, 0, 1),
        g = ParadiseRestore.Prism.clamp(args.g, 0, 1),
        b = ParadiseRestore.Prism.clamp(args.b, 0, 1),
        a = ParadiseRestore.Prism.clamp(args.a, 0, 1),
        rad = math.floor(ParadiseRestore.Prism.clamp(args.rad, 1, 30)),
        decay = ParadiseRestore.Prism.clamp(args.decay, 0.05, 3600),
        isFade = args.isFade == true,
    }
end

function ParadiseRestore.Prism.remove(id)
    local entry = ParadiseRestore.Prism.activeLights[id]
    if not entry then return end
    local cell = getCell and getCell() or nil
    if cell and entry.light then
        cell:removeLamppost(entry.light)
    end
    ParadiseRestore.Prism.activeLights[id] = nil
end

function ParadiseRestore.Prism.addLocal(args)
    args = ParadiseRestore.Prism.normalize(args)
    if not args then return nil end

    ParadiseRestore.Prism.nextID = ParadiseRestore.Prism.nextID + 1
    local id = args.id or "local:" .. tostring(getTimestampMs()) .. ":" .. tostring(ParadiseRestore.Prism.nextID)
    ParadiseRestore.Prism.remove(id)

    local cell = getCell and getCell() or nil
    if not cell then return nil end

    local light = cell:addLamppost(args.x, args.y, args.z, args.r * args.a, args.g * args.a, args.b * args.a, args.rad)
    if not light then return nil end

    ParadiseRestore.Prism.activeLights[id] = {
        id = id,
        light = light,
        args = args,
        startedAt = getTimestampMs(),
        expiresAt = getTimestampMs() + (args.decay * 1000),
        lastFactor = 1,
    }
    return id
end

function ParadiseRestore.Prism.refresh(entry, factor)
    local cell = getCell and getCell() or nil
    if not cell then return end
    if entry.light then
        cell:removeLamppost(entry.light)
    end
    local args = entry.args
    entry.light = cell:addLamppost(args.x, args.y, args.z, args.r * args.a * factor, args.g * args.a * factor, args.b * args.a * factor, args.rad)
    entry.lastFactor = factor
end

function ParadiseRestore.Prism.update()
    local now = getTimestampMs()
    local expired = {}
    for id, entry in pairs(ParadiseRestore.Prism.activeLights) do
        if now >= entry.expiresAt then
            expired[#expired + 1] = id
        elseif entry.args.isFade then
            local duration = entry.expiresAt - entry.startedAt
            local factor = ParadiseRestore.Prism.clamp((entry.expiresAt - now) / duration, 0, 1)
            if math.abs(factor - entry.lastFactor) >= 0.01 then
                ParadiseRestore.Prism.refresh(entry, factor)
            end
        end
    end
    for i = 1, #expired do
        ParadiseRestore.Prism.remove(expired[i])
    end
end

function ParadiseRestore.Prism.getActiveCount()
    local count = 0
    for _ in pairs(ParadiseRestore.Prism.activeLights) do
        count = count + 1
    end
    return count
end

function ParadiseRestore.Prism.cast(x, y, z, r, g, b, a, rad, decay, isFade)
    local args = ParadiseRestore.Prism.normalize({
        x = x,
        y = y,
        z = z,
        r = r,
        g = g,
        b = b,
        a = a,
        rad = rad,
        decay = decay,
        isFade = isFade,
    })
    if not args then return false end

    if isClient and isClient() then
        sendClientCommand(ParadiseRestore.Prism.module, ParadiseRestore.Prism.command, args)
        return true
    end
    if not (isServer and isServer()) then
        ParadiseRestore.Prism.addLocal(args)
        return true
    end
    return false
end

function ParadiseRestore.Prism.castOnPlayer(pl, r, g, b, a, rad, decay, isFade)
    pl = pl or getPlayer()
    if not pl then return false end
    return ParadiseRestore.Prism.cast(pl:getX(), pl:getY(), pl:getZ(), r, g, b, a, rad, decay, isFade)
end

function ParadiseRestore.Prism.parsePrismData(var)
    if type(var) ~= "string" then return nil end
    local params = {}
    for value in string.gmatch(var .. ":", "(.-):") do
        params[#params + 1] = string.match(value, "^%s*(.-)%s*$")
    end
    if #params < 3 or #params > 7 then return nil end
    local r, g, b = tonumber(params[1]), tonumber(params[2]), tonumber(params[3])
    if r == nil or g == nil or b == nil then return nil end
    local a = ParadiseRestore.Prism.weaponDefaults.a
    local rad = ParadiseRestore.Prism.weaponDefaults.rad
    local decay = ParadiseRestore.Prism.weaponDefaults.decay
    if params[4] ~= nil and params[4] ~= "" then
        a = tonumber(params[4])
    end
    if params[5] ~= nil and params[5] ~= "" then
        rad = tonumber(params[5])
    end
    if params[6] ~= nil and params[6] ~= "" then
        decay = tonumber(params[6])
    end
    local isFade = ParadiseRestore.Prism.weaponDefaults.isFade
    if params[7] ~= nil and params[7] ~= "" then
        if string.lower(params[7]) == "true" then
            isFade = true
        elseif string.lower(params[7]) == "false" then
            isFade = false
        else
            return nil
        end
    end
    if a == nil or rad == nil or decay == nil then return nil end
    return { r = r, g = g, b = b, a = a, rad = rad, decay = decay, isFade = isFade }
end

function ParadiseRestore.Prism.onWeaponSwing(pl, weapon)
    if not pl or not weapon or not weapon.getModData then return end
    local md = weapon:getModData()
    if not md then return end

    local prismData = ParadiseRestore.Prism.parsePrismData(md.PrismData)
    if not prismData then return end

    local x = round(pl:getX())
    local y = round(pl:getY())
    local z = round(pl:getZ()) or 0
    ParadiseRestore.Prism.cast(x, y, z, prismData.r, prismData.g, prismData.b, prismData.a, prismData.rad, prismData.decay, prismData.isFade)
end
if isClient and isClient() then
    Events.OnWeaponSwingHitPoint.Remove(ParadiseRestore.Prism.onWeaponSwing)
    Events.OnWeaponSwingHitPoint.Add(ParadiseRestore.Prism.onWeaponSwing)
end

function ParadiseRestore.Prism.debugTest()
    return ParadiseRestore.Prism.castOnPlayer(getPlayer(), 1, 1, 1, 1, 15, 5, true)
end

function ParadiseRestore.Prism.receive(module, command, args)
    if module ~= ParadiseRestore.Prism.module or command ~= ParadiseRestore.Prism.command then return end
    ParadiseRestore.Prism.addLocal(args)
end

function ParadiseRestore.Prism.relay(module, command, sender, args)
    if module ~= ParadiseRestore.Prism.module or command ~= ParadiseRestore.Prism.command then return end
    args = ParadiseRestore.Prism.normalize(args)
    if not args or not sender then return end
    ParadiseRestore.Prism.nextID = ParadiseRestore.Prism.nextID + 1
    local plID = sender:getOnlineID()
    args.id = tostring(plID) .. ":" .. tostring(getTimestampMs()) .. ":" .. tostring(ParadiseRestore.Prism.nextID)
    sendServerCommand(ParadiseRestore.Prism.module, ParadiseRestore.Prism.command, args)
end

if isClient and isClient() then
    Events.OnTick.Remove(ParadiseRestore.Prism.update)
    Events.OnTick.Add(ParadiseRestore.Prism.update)
    Events.OnServerCommand.Remove(ParadiseRestore.Prism.receive)
    Events.OnServerCommand.Add(ParadiseRestore.Prism.receive)
elseif isServer and isServer() then
    Events.OnClientCommand.Remove(ParadiseRestore.Prism.relay)
    Events.OnClientCommand.Add(ParadiseRestore.Prism.relay)
end
