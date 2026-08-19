
ParadiseDev = ParadiseDev or {}
ParadiseDev.hook = ParadiseDev.hook or {}
ParadiseDev.hook.ISChat_addLineInChat = ISChat.addLineInChat
ParadiseZ = ParadiseZ or {}
ParadiseDev.hook.ISChat_logChatCommand = ISChat.logChatCommand
ParadiseDev.hook.ISChat_onCommandEntered = ISChat.onCommandEntered


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

-----------------------            ---------------------------

function ParadiseDev.autoRemoveBlink()
    if not ParadiseDev.isAdm() then return end
    ISChat.setAllTabBlinking(false)
end

Events.EveryTenMinutes.Remove(ParadiseDev.autoRemoveBlink)
Events.EveryTenMinutes.Add(ParadiseDev.autoRemoveBlink)

function ParadiseDev.isInKosZone(pl)
    local border = ParadiseDev.Zones and ParadiseDev.Zones.Border
    local zone = border and border.getAuthorityAt and border.getAuthorityAt(pl:getX(), pl:getY(), pl:getZ())
    return zone and zone.features and zone.features.isKos == true
end

function ParadiseDev.serverMsgCmd(cmd)
    local pl = getPlayer()
    if not pl or type(cmd) ~= "string" then return false end

    local keyword, args = cmd:match("^%s*(/%S+)%s*(.-)%s*$")
    if not keyword or string.lower(keyword) ~= "/servermsg" then return false end

    local functionName, functionArgs = args:match("^(%S+)%s*(.-)%s*$")
    if not functionName or functionName:sub(1, 5) ~= "rcon_" then return false end
    if not ParadiseDev.isAdm(pl) then return true end

    local handler = _G[functionName:sub(6)]
    if type(handler) == "function" then
        handler(functionArgs)
    end
    return true
end

function ParadiseDev.chatCmd(cmd)
    local pl = getPlayer()
    if not pl or type(cmd) ~= "string" then return end
    local user = pl:getUsername()
    local keyword, args = cmd:match("^%s*(/%S+)%s*(.-)%s*$")
    local command = keyword and string.lower(keyword) or ""
    local isDbg = getCore():getDebug()
    local isAdm = ParadiseDev.isAdm(pl)  
    if command == "/stuck" or command == "/unstuck" then
        if ParadiseDev.isInKosZone(pl) then
            pl:setHaloNote("Cannot use unstuck command inside a KoS zone.", 250, 0, 0, 180)
            return
        end
        if ParadiseDev.reboundCountdown then
            ParadiseDev.reboundCountdown(true)
        end
    elseif command == "/rebound" then
        if isAdm then
            if isClient() then
                sendClientCommand("ParadiseDevTP", "adminRebound", { username = args ~= "" and args:gsub('^"(.*)"$', '%1') or nil })
            elseif (args == "" or args == user) then
                ParadiseDev.TP.rebound(pl)
            end
        end
    elseif command == "/cage" then
        local username, value = args:match('^"(.-)"%s+(%S+)$')
        if not username then username, value = args:match('^(.-)%s+(%S+)$') end
        if value and string.lower(value) ~= "true" and string.lower(value) ~= "false" then username, value = args, nil end
        username = (username or args):gsub('^"(.*)"$', '%1')
        local isCaged = value and string.lower(value) == "true" or nil
        if isClient() then
            sendClientCommand("ParadiseDevCage", "chatSet", { username = username ~= "" and username or nil, isCaged = isCaged })
        elseif ParadiseDev.isAdm(pl) and ParadiseDev.Cage and ParadiseDev.Cage.requestSet then
            username = username ~= "" and username or user
            if isCaged == nil then isCaged = not ParadiseDev.Cage.isTargetCaged(pl) end
            ParadiseDev.Cage.requestSet(username, isCaged)
        end
    elseif command == "/die" then
        if isClient() then
            sendClientCommand("ParadiseDevTP", "die", {})
        else
            pl:getBodyDamage():ReduceGeneralHealth(110)
        end
--[[ 
    elseif command == "/checktemp" then
        if ParadiseDev.getCliStr then
            ParadiseDev.getCliStr(pl:getSquare())
        end ]]
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
            local gift = inventory:AddItem(item)
            if ParadiseDev.Inventory and ParadiseDev.Inventory.syncAddedItem then
                ParadiseDev.Inventory.syncAddedItem(inventory, gift)
            end
            getSoundManager():playUISound("ParadiseZ_Intro_2")
        else
            modData.GiftAttempt = true
            pl:playEmote("shrug")
            msg = "Glytch3r: Can only recieve once per account."
            getSoundManager():playUISound("ZombieSurprisedPlayer")
        end

        pl:addLineChatElement(msg)
    elseif command == "/scare" and isDbg then
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

function ISChat:onCommandEntered()
    local command = self.textEntry and self.textEntry:getText()
    if ParadiseDev.serverMsgCmd(command) then
        self:unfocus()
        self:logChatCommand(command)
        doKeyPress(false)
        self.timerTextEntry = 20
        return
    end
    return ParadiseDev.hook.ISChat_onCommandEntered(self)
end
