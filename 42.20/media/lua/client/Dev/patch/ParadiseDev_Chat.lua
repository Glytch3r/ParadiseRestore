
ParadiseDev = ParadiseDev or {}
ParadiseDev.hook = ParadiseDev.hook or {}
ParadiseDev.hook.ISChat_addLineInChat = ISChat.addLineInChat
ParadiseZ = ParadiseZ or {}

require "Dev/ParadiseDev_Players"

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



function ParadiseDev.autoRemoveBlink()
    if not ParadiseDev.isAdm() then return end
    ISChat.setAllTabBlinking(false)
end

Events.EveryTenMinutes.Remove(ParadiseDev.autoRemoveBlink)
Events.EveryTenMinutes.Add(ParadiseDev.autoRemoveBlink)

function ParadiseZ.parseCoords()
    if ParadiseZ.coords then
        return ParadiseZ.coords[1], ParadiseZ.coords[2], ParadiseZ.coords[3]
    end

    local strList = SandboxVars.ParadiseZ.Coords
    local tx, ty, tz = strList:match("^(-?%d+)[;:](-?%d+)[;:](-?%d+)")
    tx, ty, tz = tonumber(tx), tonumber(ty), tonumber(tz)

    ParadiseZ.coords = { tx, ty, tz }
    return tx, ty, tz
end

LuaEventManager.AddEvent("OnChatCmd")
local hook = ISChat.logChatCommand
function ISChat:logChatCommand(command)
    self.chatText.logIndex = 0
    print(command)
    triggerEvent("OnChatCmd", command)
    hook(self, command)
end

function ParadiseZ.chatCmd(cmd)
    local pl = getPlayer()
    if not pl then return end

    local dbg = getCore():getDebug()

    if cmd == "/stuck" then
        ParadiseZ.reboundCountdown(true)
    elseif cmd == "/die" then
        pl:Kill(nil)
    elseif cmd == "/checktemp" then
        local sq = pl:getSquare()
        ParadiseZ.getCliStr(sq)
    elseif string.lower(cmd) == "/glytch3r" or string.lower(cmd) == "/glytch" then
        local item = SandboxVars.ParadiseZ.Glytch3rGift
        if not item or item == '' then return end

        if not pl:isAlive() then return end
        if pl:getModData()['GiftAttempt'] ~= nil then return end
        local user = pl:getUsername()
        if not user then return end

        local msg = 'Glytch3r: Thanks for your support '..tostring(user)..'! Take this '..tostring(item)..' as a gift! Enjoy Paradise! '
        ParadiseZ.setTempTag(pl)

        if not ParadiseZ.isGiftRecieved(user) then
            pl:playEmote('thankyou')
            ParadiseZ.recordGifted(user)
            local inv = pl:getInventory()
            if not inv then return end
            inv:AddItem(item)
            getSoundManager():playUISound("ParadiseZ_Intro_2")
        else
            pl:getModData()['GiftAttempt'] = true
            pl:playEmote('shrug')
            msg = 'Glytch3r: Can only recieve once per account.'
            getSoundManager():playUISound("ZombieSurprisedPlayer")
        end

        pl:addLineChatElement(tostring(msg))
    elseif cmd == "/scare" then
        if not dbg then return end
        getSoundManager():PlayWorldSound("ZombieSurprisedPlayer", pl:getSquare(), 0, 5, 5, false)
    end
end

Events.OnChatCmd.Remove(ParadiseZ.chatCmd)
Events.OnChatCmd.Add(ParadiseZ.chatCmd)
