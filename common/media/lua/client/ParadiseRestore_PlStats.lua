ParadisePlStats = ParadisePlStats or {}

ParadisePlStats.VANILLA_DRUNK_REDUCTION = 0.0042
ParadisePlStats.VANILLA_DRUNK_MAX_SECONDS = 100 / ParadisePlStats.VANILLA_DRUNK_REDUCTION

function ParadisePlStats.drunkHandler(_, pl)
    pl = pl or getPlayer()
    if not pl then return end

    local options = SandboxVars and SandboxVars.ParadiseZ or nil
    local maxSeconds = options and tonumber(options.DrunkMaxSeconds) or ParadisePlStats.VANILLA_DRUNK_MAX_SECONDS
    if not maxSeconds or maxSeconds <= 0 then
        maxSeconds = ParadisePlStats.VANILLA_DRUNK_MAX_SECONDS
    end

    local bodyDamage = pl:getBodyDamage()
    if bodyDamage then
        bodyDamage:setDrunkReductionValue(100 / maxSeconds)
    end
end
Events.OnCreatePlayer.Remove(ParadisePlStats.drunkHandler)
Events.OnCreatePlayer.Add(ParadisePlStats.drunkHandler)

LuaEventManager.AddEvent("OnSandboxModified")
Events.OnSandboxModified.Remove(ParadisePlStats.drunkHandler)
Events.OnSandboxModified.Add(ParadisePlStats.drunkHandler)



function ParadisePlStats.formatSecondsToTime(seconds)
    if not seconds or seconds <= 0 then
        return "00:00"
    end

    local hrs = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hrs > 0 then
        return string.format("%02d:%02d:%02d", hrs, mins, secs)
    else
        return string.format("%02d:%02d", mins, secs)
    end
end

function ParadisePlStats.getRemainingTime(plStat, pl)
    if plStat and plStat == 'paradise_drunk' then
        if not pl then return 0 end

        local stats = pl:getStats()
        local bodyDamage = pl:getBodyDamage()

        if stats and bodyDamage then
            local currentDrunkenness = stats:get(CharacterStat.INTOXICATION)
            local reductionPerTick = bodyDamage:getDrunkReductionValue()

            if currentDrunkenness > 0 and reductionPerTick > 0 then
                local remainingSeconds = currentDrunkenness / reductionPerTick
                return remainingSeconds
            end
        end
        return 0
    end
    return nil
end

function ParadisePlStats.getRemainingTimeStr(plStat, pl)
    local remainingSeconds = ParadisePlStats.getRemainingTime(plStat, pl)
    
    if remainingSeconds then
        return ParadisePlStats.formatSecondsToTime(remainingSeconds)
    end

    return "00:00"
end

function ParadisePlStats.getDrunkStr(plStat, pl)
    if not pl then return "" end

    local timeStr = ParadisePlStats.getRemainingTimeStr(plStat or 'paradise_drunk', pl)

    return string.format("Time till sober: [%s]", timeStr)
end
