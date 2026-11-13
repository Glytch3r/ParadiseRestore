if not isServer() then return end

ParadiseDev = ParadiseDev or {}
ParadiseDev.Telemetry = ParadiseDev.Telemetry or {}
ParadiseDev.Telemetry.module = "ParadiseDevTelemetry"
ParadiseDev.Telemetry.cache = ParadiseDev.Telemetry.cache or {}

function ParadiseDev.Telemetry.now()
    return getTimestampMs and getTimestampMs() or getTimestamp() * 1000
end

function ParadiseDev.Telemetry.onClientCommand(module, command, pl, args)
    if module ~= ParadiseDev.Telemetry.module then return end
    if not pl then return end
    args = type(args) == "table" and args or {}

    if command == "report" then
        local fps = tonumber(args.fps)
        local ping = tonumber(args.ping)
        if not fps or not ping then return end
        fps = math.max(0, math.min(1000, math.floor(fps)))
        ping = math.max(0, math.min(100000, math.floor(ping)))
        ParadiseDev.Telemetry.cache[pl:getUsername()] = { fps = fps, ping = ping, time = ParadiseDev.Telemetry.now() }
        return
    end

    if command == "request" then
        if not ParadiseRestore.isAdm(pl) then return end
        local targetUser = tostring(args.target or "")
        if targetUser == "" or #targetUser > 30 then return end
        local entry = ParadiseDev.Telemetry.cache[targetUser]
        if not entry then
            sendServerCommand(pl, ParadiseDev.Telemetry.module, "show", { user = targetUser, none = true })
            return
        end
        sendServerCommand(pl, ParadiseDev.Telemetry.module, "show", {
            user = targetUser,
            fps = entry.fps,
            ping = entry.ping,
            age = ParadiseDev.Telemetry.now() - entry.time,
        })
    end
end
Events.OnClientCommand.Remove(ParadiseDev.Telemetry.onClientCommand)
Events.OnClientCommand.Add(ParadiseDev.Telemetry.onClientCommand)