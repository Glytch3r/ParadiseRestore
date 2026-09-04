require "ISUI/ISServerSavingMessage"
require "lua_timers"

ParadiseDev = ParadiseDev or {}
ParadiseDev.Save = ParadiseDev.Save or {}
ParadiseDev.Save.module = "ParadiseSave"

ISServerSavingMessage.showPauseMessage = function() end
ISServerSavingMessage.showSavingFinishMessage = function() end


function ParadiseDev.Save.registerSavingHandlers()
    Events.OnServerStartSaving.Remove(ISServerSavingMessage.showPauseMessage);
    Events.OnServerFinishSaving.Remove(ISServerSavingMessage.showSavingFinishMessage);
end

ParadiseDev.Save.registerSavingHandlers()
Events.OnGameStart.Add(ParadiseDev.Save.registerSavingHandlers)

function ParadiseDev.Save.exitToMenu()
    getCore():exitToMenu()
end

function ParadiseDev.Save.waitUntilAlone()
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() <= 1 then
        Events.OnTick.Remove(ParadiseDev.Save.waitUntilAlone)
        ParadiseDev.Save.exitToMenu()
    end
end

function ParadiseDev.Save.countdown(initiator)
    local pl = getPlayer()
    if not pl then return end
    timer:Create("ParadiseSaveCountdown", 1, 10, function()
        local remaining = timer:RepsLeft("ParadiseSaveCountdown")
        if remaining and remaining > 0 then
            pl:setHaloNote("Server save: " .. tostring(remaining), 250, 200, 0, 180)
        else
            ParadiseDev.Save.exitToMenu()
        end
    end)
end

function ParadiseDev.Save.onServerCommand(module, command, args)
    if module ~= ParadiseDev.Save.module or command ~= "countdown" then return end
    ParadiseDev.Save.countdown(args and args.initiator)
end

Events.OnServerCommand.Remove(ParadiseDev.Save.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Save.onServerCommand)
