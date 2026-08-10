
ParadiseDev = ParadiseDev or {}
ParadiseDev.hook = ParadiseDev.hook or {}
ParadiseDev.hook.ISChat_addLineInChat = ISChat.addLineInChat
ParadiseDev.hook.ISChat_logChatCommand = ISChat.logChatCommand


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

-----------------------            ---------------------------


function ParadiseDev.chatCmd(cmd)
    local pl = getPlayer()
    if not pl or type(cmd) ~= "string" then return end

    local command = string.lower(cmd)
    local debug = getCore():getDebug()

    if command == "/stuck" then
        if ParadiseDev.reboundCountdown then
            ParadiseDev.reboundCountdown(true)
        end
    elseif command == "/die" then
        pl:Kill(nil)
    elseif command == "/checktemp" then
        if ParadiseDev.getCliStr then
            ParadiseDev.getCliStr(pl:getSquare())
        end
    elseif command == "/glytch3r" or command == "/glytch" then
        local settings = SandboxVars and SandboxVars.ParadiseZ
        local item = settings and settings.Glytch3rGift
        if not item or item == "" or not pl:isAlive() then return end

        local modData = pl:getModData()
        if modData.GiftAttempt ~= nil then return end

        local user = pl:getUsername()
        if not user then return end

        if ParadiseDev.setTempTag then
            ParadiseDev.setTempTag(pl)
        end

        local isGiftReceived = ParadiseDev.isGiftReceived or ParadiseDev.isGiftRecieved
        local recordGifted = ParadiseDev.recordGifted
        if not (isGiftReceived and recordGifted) then return end

        local received = isGiftReceived(user)
        local msg = "Glytch3r: Thanks for your support " .. tostring(user) .. "! Take this " .. tostring(item) .. " as a gift! Enjoy Paradise! "

        if not received then
            local inventory = pl:getInventory()
            if not inventory then return end

            pl:playEmote("thankyou")
            recordGifted(user)
            inventory:AddItem(item)
            getSoundManager():playUISound("ParadiseZ_Intro_2")
        else
            modData.GiftAttempt = true
            pl:playEmote("shrug")
            msg = "Glytch3r: Can only recieve once per account."
            getSoundManager():playUISound("ZombieSurprisedPlayer")
        end

        pl:addLineChatElement(msg)
    elseif command == "/scare" and debug then
        getSoundManager():PlayWorldSound("ZombieSurprisedPlayer", pl:getSquare(), 0, 5, 5, false)
    end
end

function ISChat:logChatCommand(command)
    if self.chatText then
        self.chatText.logIndex = 0
    end

    ParadiseDev.chatCmd(command)
    ParadiseDev.hook.ISChat_logChatCommand(self, command)
end
