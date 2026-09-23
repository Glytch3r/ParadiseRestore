require "ISUI/ISImage"
require "lua_timers"

ParadiseDev = ParadiseDev or {}
ParadiseDev.ClearAndSave = ParadiseDev.ClearAndSave or {}

ParadiseDev.ClearAndSave.module = "ClearAndSave"
ParadiseDev.ClearAndSave.saveIcon = ParadiseDev.ClearAndSave.saveIcon or nil
ParadiseDev.ClearAndSave.pendingLogout = false

function ParadiseDev.ClearAndSave.showIcon()
    if ParadiseDev.ClearAndSave.saveIcon then return end
    local width = 200
    local height = 300
    ParadiseDev.ClearAndSave.saveIcon = ISImage:new(
        getCore():getScreenWidth() / 2 - width / 2,
        getCore():getScreenHeight() / 2 - 250,
        width,
        height,
        getTexture("media/ui/saveSpiffo.png")
    )
    ParadiseDev.ClearAndSave.saveIcon.autoScale = true
    ParadiseDev.ClearAndSave.saveIcon:initialise()
    ParadiseDev.ClearAndSave.saveIcon:addToUIManager()
end

function ParadiseDev.ClearAndSave.closeIcon()
    if not ParadiseDev.ClearAndSave.saveIcon then return end
    ParadiseDev.ClearAndSave.saveIcon:setVisible(false)
    ParadiseDev.ClearAndSave.saveIcon:removeFromUIManager()
    ParadiseDev.ClearAndSave.saveIcon = nil
end


function ParadiseDev.ClearAndSave.waitUntilAlone()
    if not ParadiseDev.ClearAndSave.pendingLogout then return end
    local pl = getPlayer()
    if not pl then return end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() <= 1 then
        Events.OnTick.Remove(ParadiseDev.ClearAndSave.waitUntilAlone)
        ParadiseDev.ClearAndSave.pendingLogout = false
        ParadiseDev.ClearAndSave.closeIcon()
        pl:Say("Server is now empty")
    end
end

function ParadiseDev.ClearAndSave.countdown(delay, senderName)
    local pl = getPlayer()
    if not pl then return end
    timer:Remove(ParadiseDev.ClearAndSave.module)
    Events.OnTick.Remove(ParadiseDev.ClearAndSave.waitUntilAlone)
    ParadiseDev.ClearAndSave.pendingLogout = false
    ParadiseDev.ClearAndSave.showIcon()
    timer:Create(ParadiseDev.ClearAndSave.module, 1, math.max(1, tonumber(delay) or 60), function()
        local remaining = timer:RepsLeft(ParadiseDev.ClearAndSave.module)
        if remaining and remaining > 0 then
            pl:setHaloNote("Server: " .. tostring(remaining), 250, 200, 0, 180)
        elseif pl:getUsername() == senderName then
            SendCommandToServer("/save")
            ParadiseDev.ClearAndSave.pendingLogout = true
            Events.OnTick.Add(ParadiseDev.ClearAndSave.waitUntilAlone)
        else
            ParadiseDev.ClearAndSave.closeIcon()
            getCore():exitToMenu()
        end
    end)
end

function ParadiseDev.ClearAndSave.reciever(module, command, args)
    if module ~= ParadiseDev.ClearAndSave.module or command ~= ParadiseDev.ClearAndSave.module then return end
    ParadiseDev.ClearAndSave.countdown(args.delay, args.senderName)
end

Events.OnServerCommand.Remove(ParadiseDev.ClearAndSave.reciever)
Events.OnServerCommand.Add(ParadiseDev.ClearAndSave.reciever)
