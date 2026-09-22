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
    if not ParadiseDev.Save.pendingFinalSave then return end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() <= 1 then
        Events.OnTick.Remove(ParadiseDev.Save.waitUntilAlone)
        ParadiseDev.Save.pendingFinalSave = false
        sendClientCommand(ParadiseDev.Save.module, "finalSave", {})
    end
end

function ParadiseDev.Save.countdown(initiator, seconds)
    local pl = getPlayer()
    if not pl then return end
    ParadiseDev.Save.initiator = initiator
    ParadiseDev.Save.pendingFinalSave = false
    ParadiseDev.Save.showSavingMessage()
    timer:Create("ParadiseSaveCountdown", 1, math.max(1, tonumber(seconds) or 60), function()
        local remaining = timer:RepsLeft("ParadiseSaveCountdown")
        if remaining and remaining > 0 then
            pl:setHaloNote("Server save: " .. tostring(remaining), 250, 200, 0, 180)
        else
            if pl:getUsername() == ParadiseDev.Save.initiator then
                ParadiseDev.Save.pendingFinalSave = true
                Events.OnTick.Remove(ParadiseDev.Save.waitUntilAlone)
                Events.OnTick.Add(ParadiseDev.Save.waitUntilAlone)
            else
                ParadiseDev.Save.exitToMenu()
            end
        end
    end)
end

function ParadiseDev.Save.onServerCommand(module, command, args)
    if module ~= ParadiseDev.Save.module or command ~= "countdown" then return end
    ParadiseDev.Save.countdown(args and args.initiator, args and args.seconds)
end

function ParadiseDev.Save.onFinalSaved(module, command)
    if module ~= ParadiseDev.Save.module or command ~= "finalSaved" then return end
    local pl = getPlayer and getPlayer() or nil
    if pl then pl:addLineChatElement("Everyone Successfully logged out") end
end

Events.OnServerCommand.Remove(ParadiseDev.Save.onServerCommand)
Events.OnServerCommand.Add(ParadiseDev.Save.onServerCommand)
Events.OnServerCommand.Remove(ParadiseDev.Save.onFinalSaved)
Events.OnServerCommand.Add(ParadiseDev.Save.onFinalSaved)
