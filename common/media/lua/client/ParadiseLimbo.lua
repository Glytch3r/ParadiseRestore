if not isClient() then return end

ParadiseLimbo = ParadiseLimbo or {}
ParadiseLimbo.module = "ParadiseLimbo"

function ParadiseLimbo.getFPS()
    local fps = getAverageFPS and tonumber(getAverageFPS()) or 0
    return math.max(0, math.floor(fps or 0))
end

function ParadiseLimbo.getPing()
    local status = getMPStatus and getMPStatus() or nil
    local ping = status and tonumber(status["lastPing"]) or 0
    return math.max(0, math.floor(ping or 0))
end

function ParadiseLimbo.report(exitMode)
    exitMode = tonumber(exitMode)
    if not exitMode or exitMode ~= math.floor(exitMode) or exitMode < 0 or exitMode > 5 then return false end
    sendClientCommand(ParadiseLimbo.module, "state", {
        fps = ParadiseLimbo.getFPS(),
        ping = ParadiseLimbo.getPing(),
        exitMode = exitMode,
    })
    return true
end
