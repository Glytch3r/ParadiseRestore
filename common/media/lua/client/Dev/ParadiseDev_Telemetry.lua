if not isClient() then return end

ParadiseDev = ParadiseDev or {}
ParadiseDev.Telemetry = ParadiseDev.Telemetry or {}
ParadiseDev.Telemetry.module = "ParadiseDevTelemetry"

function ParadiseDev.Telemetry.getFPS()
    local fps = getAverageFPS and tonumber(getAverageFPS()) or 0
    return math.max(0, math.floor(fps or 0))
end

function ParadiseDev.Telemetry.getPing()
    local status = getMPStatus and getMPStatus() or nil
    local ping = status and tonumber(status["lastPing"]) or 0
    return math.max(0, math.floor(ping or 0))
end

function ParadiseDev.Telemetry.report()
    sendClientCommand(ParadiseDev.Telemetry.module, "report", {
        fps = ParadiseDev.Telemetry.getFPS(),
        ping = ParadiseDev.Telemetry.getPing(),
    })
end

function ParadiseDev.Telemetry.isDamagingHit(char, targ)
    if char.isDoShove and char:isDoShove() then return false end
    if not ParadiseDev.PvP or not ParadiseDev.PvP.isEnabled or not ParadiseDev.PvP.isEnabled() then
        return true
    end
    if ParadiseDev.PvP.isHitProtected and ParadiseDev.PvP.isHitProtected(char, targ) then return false end
    return true
end

function ParadiseDev.Telemetry.onWeaponHit(char, targ, wpn)
    if not ol() then return end
    if not targ or targ ~= getPlayer() then return end
    if not char or not instanceof(char, "IsoPlayer") then return end
    if not ParadiseDev.Telemetry.isDamagingHit(char, targ) then return end
    ParadiseDev.Telemetry.report()
end
Events.OnWeaponHitCharacter.Remove(ParadiseDev.Telemetry.onWeaponHit)
Events.OnWeaponHitCharacter.Add(ParadiseDev.Telemetry.onWeaponHit)

function ParadiseDev.Telemetry.request(username)
    if not username or not ol() then return end
    sendClientCommand(ParadiseDev.Telemetry.module, "request", { target = tostring(username) })
end

function ParadiseDev.Telemetry.showResult(args)
    args = args or {}
    local user = tostring(args.user or "?")
    if args.none then
        if ISAlert.instance then
            ISAlert.instance.servermsg = "No telemetry yet for " .. user .. " (updates when hit by PvP)"
            ISAlert.instance.servermsgTimer = 5000
        end
        return
    end
    local fps = math.floor(tonumber(args.fps) or 0)
    local ping = math.floor(tonumber(args.ping) or 0)
    local text = user .. " - FPS: " .. fps .. ", Ping: " .. ping .. " ms"
    local age = tonumber(args.age)
    if age and age > 0 then
        text = text .. " (" .. math.floor(age / 1000) .. "s ago)"
    end
    if ISAlert.instance then
        ISAlert.instance.servermsg = text
        ISAlert.instance.servermsgTimer = 5000
    end
    print("[ParadiseDev] Telemetry " .. text)
end

function ParadiseDev.Telemetry.onServerCommand(module, command, args)
    if module ~= ParadiseDev.Telemetry.module then return end
    if command == "show" then
        ParadiseDev.Telemetry.showResult(args)
    end
end
Events.OnServerCommand.Remove(ParadiseDev.Telemetry.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Telemetry.onServerCommand)