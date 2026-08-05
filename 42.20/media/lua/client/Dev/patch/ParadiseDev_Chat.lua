
ParadiseDev = ParadiseDev or {}
ParadiseDev.hook = ParadiseDev.hook or {}
ParadiseDev.hook.ISChat_addLineInChat = ISChat.addLineInChat

ISChat.BlinkEnabled = true

function ISChat.setAllTabBlinking(enabled)
    ISChat.BlinkEnabled = enabled ~= false

    local chat = ISChat.instance
    if chat and chat.panel and not ISChat.BlinkEnabled then
        chat.panel.blinkTabs = {}
    end
end

function ISChat.addLineInChat(message, tabID)
    local panel

    if not ISChat.BlinkEnabled and ISChat.instance then
        panel = ISChat.instance.panel
        if panel then
            panel._savedBlinkTabs = panel.blinkTabs
            panel.blinkTabs = {}
        end
    end

    ParadiseDev.hook.ISChat_addLineInChat(message, tabID)

    if panel and panel._savedBlinkTabs then
        panel.blinkTabs = panel._savedBlinkTabs
        panel._savedBlinkTabs = nil
    end
end

function ParadiseDev.isAdm()
    local pl = getPlayer()
    return pl and ( string.lower(pl:getAccessLevel()) == "admin" or (isClient() and isAdmin())) and pl:isBuildCheat()
end

function ParadiseDev.autoRemoveBlink()
    if not ParadiseDev.isAdm() then return end
    ISChat.setAllTabBlinking(false)
end

Events.EveryTenMinutes.Remove(ParadiseDev.autoRemoveBlink)
Events.EveryTenMinutes.Add(ParadiseDev.autoRemoveBlink)