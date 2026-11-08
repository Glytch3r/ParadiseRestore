ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.Client = ParadisePOIBuilder.Client or {}
if ParadisePOIBuilder.isB41() then return end

local P = ParadisePOIBuilder
local C = P.Client

C.blueprints = C.blueprints or {}
C.blueprint = nil
C.job = nil
C.status = C.status or "Ready."
C.listener = C.listener or nil

function C.notify()
    if C.listener then C.listener() end
end

function C.setStatus(text)
    C.status = text or ""
    C.notify()
end

function C.send(command, args)
    args = args or {}
    if isClient and isClient() then
        sendClientCommand(P.module, command, args)
        return true
    end
    if P.Server and P.Server.onClientCommand then
        P.Server.onClientCommand(P.module, command, getPlayer(), args)
        return true
    end
    return false
end

function C.requestIndex()
    C.send("index")
end

function C.requestCancel()
    C.send("cancel")
end

function C.requestWall(area, props, mode, axis)
    C.send("wall", {
        area = area,
        mode = mode,
        axis = axis,
        northSprite = props.northSprite or "",
        westSprite = props.westSprite or "",
        hp = props.hp,
        indestructible = props.indestructible == true,
        sledge = props.sledge == true,
        climb = props.climb == true,
    })
end

function C.requestObjectFill(area, props)
    C.send("objectFill", {
        area = area,
        percent = props.percent,
        entries = props.entries,
    })
end

function C.requestItemFill(area, props)
    C.send("itemFill", {
        area = area,
        percent = props.percent,
        count = props.count,
        entries = props.entries,
    })
end

function C.requestCopy(area, title)
    C.send("copy", {
        area = area,
        title = title,
    })
end

function C.requestGet(id)
    C.send("get", { id = id })
end

function C.requestRename(id, title)
    C.send("rename", { id = id, title = title })
end

function C.requestDelete(id)
    C.send("delete", { id = id })
end

function C.requestPaste(id, origin, zMin)
    C.send("paste", {
        id = id,
        origin = { x = origin.x, y = origin.y },
        zMin = zMin,
    })
end

function C.onServerCommand(module, command, args)
    if module ~= P.module then return end
    args = args or {}

    if command == "index" then
        C.blueprints = args.list or {}
        if not args.busy then C.job = nil end
        C.notify()
        return
    end

    if command == "blueprint" then
        C.blueprint = args.blueprint
        C.notify()
        return
    end

    if command == "job" then
        C.job = {
            id = args.id, kind = args.kind, phase = args.phase or "Working",
            total = args.total or 0, done = 0, skipped = 0, failed = 0,
        }
        C.setStatus(string.format("%s 0 / %d", C.job.phase, C.job.total))
        return
    end

    if command == "progress" then
        if not C.job then return end
        C.job.done = args.done or 0
        C.job.skipped = args.skipped or 0
        C.job.failed = args.failed or 0
        C.setStatus(string.format("%s %d / %d", args.phase or C.job.phase, C.job.done, C.job.total))
        return
    end

    if command == "result" then
        if not args.interim then C.job = nil end
        C.setStatus(args.text or "Done.")
        return
    end
end
Events.OnServerCommand.Remove(C.onServerCommand)
Events.OnServerCommand.Add(C.onServerCommand)

function C.onGameStart()
    C.job = nil
    C.blueprints = {}
    C.blueprint = nil
    C.setStatus("Ready.")
end
Events.OnGameStart.Remove(C.onGameStart)
Events.OnGameStart.Add(C.onGameStart)
