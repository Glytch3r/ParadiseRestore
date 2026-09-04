require "ISUI/ISServerSavingMessage"
require "lua_timers"

ParadiseDev = ParadiseDev or {}
ParadiseDev.Save = ParadiseDev.Save or {}
ParadiseDev.Save.module = "ParadiseSave"

local vanillaShowPauseMessage = ISServerSavingMessage.showPauseMessage
local vanillaShowSavingFinishMessage = ISServerSavingMessage.showSavingFinishMessage
Events.OnServerStartSaving.Remove(vanillaShowPauseMessage)
Events.OnServerFinishSaving.Remove(vanillaShowSavingFinishMessage)

ISServerSavingMessage.showPauseMessage = function() end
ISServerSavingMessage.showSavingFinishMessage = function() end


function ParadiseDev.Save.registerSavingHandlers()
    Events.OnServerStartSaving.Remove(ISServerSavingMessage.showPauseMessage);
    Events.OnServerFinishSaving.Remove(ISServerSavingMessage.showSavingFinishMessage);
end

ParadiseDev.Save.registerSavingHandlers()
Events.OnGameStart.Add(ParadiseDev.Save.registerSavingHandlers)

local modal = nil

function ParadiseDev.Save.showSavingMessage()
    if modal then return end
    local width = 225
    local height = 250
    local x = getCore():getScreenWidth() / 2 - width / 2
    local y = getCore():getScreenHeight() / 2 - 200
    local text = "<CENTRE> <SIZE:medium> Saving Paradise Server. <LINE> <LEFT> <IMAGE:media/ui/saveSpiffo.png> <LINE>"
    modal = ISServerSavingMessage:new(x, y, width, height, text)
    modal:initialise()
    modal:addToUIManager()
end

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
    ParadiseDev.Save.showSavingMessage()
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
