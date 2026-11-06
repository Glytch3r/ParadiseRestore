if not isClient() then return end

SquadManager = SquadManager or {}
if not SquadManager.isB41 then require "SquadManager/SquadManager_Shared" end
if SquadManager.isB41() then return end

require "Chat/ISChat"

SquadManager.Chat = SquadManager.Chat or {}
local C = SquadManager.Chat

C.tab = nil
C.stream = nil
C.pending = {}

function C.isSquadTab(chatText)
    return chatText ~= nil and chatText.tabID == SquadManager.tabID
end

function C.exists()
    local chat = ISChat.instance
    if not chat or type(chat.tabs) ~= "table" then return false end
    for _, tab in ipairs(chat.tabs) do
        if tab and tab.tabID == SquadManager.tabID then
            C.tab = tab
            return true
        end
    end
    C.tab = nil
    return false
end

function C.installStream()
    if C.stream then return C.stream end
    for _, stream in ipairs(ISChat.allChatStreams) do
        if stream.name == "squad" then
            C.stream = stream
            return stream
        end
    end
    C.stream = {
        name = "squad",
        command = "/squad ",
        shortCommand = "/sq ",
        tabID = SquadManager.tabID + 1,
    }
    table.insert(ISChat.allChatStreams, C.stream)
    return C.stream
end

function C.uninstallStream()
    if not C.stream then return end
    for i, stream in ipairs(ISChat.allChatStreams) do
        if stream == C.stream then
            table.remove(ISChat.allChatStreams, i)
            break
        end
    end
    C.stream = nil
end

function C.escape(str)
    return tostring(str or ""):gsub("<", "&lt;"):gsub(">", "&gt;")
end

function C.fontSize()
    local chat = ISChat.instance
    local font = chat and chat.chatFont or nil
    if font == nil or font == "" then font = "medium" end
    return font
end

function C.prefix(author)
    local chat = ISChat.instance
    local col = SquadManager.colors.squad
    local line = "<RGB:" .. col.r .. "," .. col.g .. "," .. col.b .. "> <SIZE:" .. C.fontSize() .. "> "
    if not chat or chat.showTimestamp then
        local ok, stamp = pcall(getHourMinute)
        if ok and stamp then line = line .. "[" .. stamp .. "]" end
    end
    if not chat or chat.showTitle then
        line = line .. "[" .. SquadManager.tabTitle .. "]"
    end
    if author and (not chat or chat.showAuthor ~= false) then
        line = line .. "[" .. C.escape(author) .. "]"
    end
    if author then line = line .. ": " end
    return line
end

function C.message(author, text)
    local msg = { author = author, text = tostring(text or "") }
    function msg:getAuthor() return self.author end
    function msg:getText() return self.text end
    function msg:setText(value) self.text = tostring(value or "") end
    function msg:getTextWithPrefix()
        return C.prefix(self.author) .. C.escape(self.text)
    end
    return msg
end

function C.addTab()
    local chat = ISChat.instance
    if not chat or type(chat.createTab) ~= "function" then return end
    if C.exists() then return end
    C.installStream()
    ISChat.onTabAdded(SquadManager.tabTitle, SquadManager.tabID)
    if not C.exists() then
        C.uninstallStream()
        return
    end
    C.flushPending()
end

function C.removeTab()
    local chat = ISChat.instance
    if not chat then C.tab = nil; C.pending = {}; return end
    if not C.exists() then return end
    if C.isSquadTab(chat.chatText) then
        local fallback = chat.defaultTab or chat.tabs[1]
        if fallback and chat.panel and fallback ~= C.tab and chat.panel.viewList then
            chat.panel:activateView(fallback.tabTitle)
        end
    end
    ISChat.onTabRemoved(SquadManager.tabTitle, SquadManager.tabID)
    C.tab = nil
    C.uninstallStream()
    C.pending = {}
end

function C.flushPending()
    for _, entry in ipairs(C.pending) do
        C.addLine(entry.author, entry.text)
    end
    C.pending = {}
end

function C.addLine(author, text)
    local chat = ISChat.instance
    if not chat then return end
    if not C.exists() then
        if #C.pending < 20 then
            table.insert(C.pending, { author = author, text = text })
        end
        return
    end
    local message = C.message(author, text)
    local ok = pcall(ISChat.addLineInChat, message, SquadManager.tabID)
    if not ok then C.tab = nil end
end

function C.addMessage(user, text)
    C.addLine(user, text)
end

function C.addSystemLine(text)
    C.addLine(nil, text)
end

function C.slowBlocked(chat, pl)
    if pl:getRole():hasCapability(Capability.IgnoreChatSlowMode) then return false end
    return (chat.timerMessageSlowMode or 0) > getTimestampMs()
end

function C.armSlowMode(chat, pl)
    if pl:getRole():hasCapability(Capability.IgnoreChatSlowMode) then return end
    local seconds = getServerOptions():getInteger("ChatMessageSlowModeTime") or 0
    chat.timerMessageSlowMode = getTimestampMs() + (seconds * 1000)
end

function C.squadPrefix(command)
    if type(command) ~= "string" then return nil end
    if luautils.stringStarts(command, "/squad ") or luautils.stringStarts(command, "/sq ") then
        return command
    end
    if command == "/squad" or command == "/sq" then return command end
    return nil
end

function C.stripPrefix(command)
    local _, last = command:find("^(%/%S+)")
    if last then return command:sub(last + 1) end
    return ""
end

function C.onCommandEntered(self)
    local chat = ISChat.instance
    local command = chat and chat.textEntry and chat.textEntry:getText() or nil
    local prefixed = C.squadPrefix(command)
    if not prefixed and not C.isSquadTab(chat and chat.chatText) then
        local base = C.commandHook
        if not base or base == C.onCommandEntered or C.inCommand then return end
        C.inCommand = true
        local result = base(self)
        C.inCommand = nil
        return result
    end
    chat:unfocus()
    if prefixed then
        command = C.stripPrefix(prefixed)
    end
    command = command and command:gsub("[\n\r]", " ") or ""
    command = command:match("^%s*(.-)%s*$") or ""
    if command == "" then return end

    local pl = getPlayer()
    if not pl then return end
    if not SquadManager.isActive() then
        pl:setHaloNote("No active squad. Commence the squad first.", 200, 60, 60, 255)
        return
    end
    if C.slowBlocked(chat, pl) then
        chat.showSlowModeFeedback = true
        return
    end
    if #command > 140 then
        command = command:sub(1, 140)
    end
    chat:logChatCommand(prefixed or command)
    SquadManager.send(SquadManager.commands.chat, { text = command })
    C.armSlowMode(chat, pl)
end

function C.onActivateView(self)
    if C.inActivate then return end
    local base = C.activateViewHook
    if not base or base == C.onActivateView then return end
    C.inActivate = true
    local ok, err = pcall(base, self)
    C.inActivate = nil
    if ok then return end
    if C.isSquadTab(self.chatText) then return end
    error(err)
end

function C.refreshHooks()
    local view = ISChat.onActivateView
    if view ~= C.onActivateView then
        if C.activateViewHook == nil or (view ~= C.installedActivate and view ~= C.activateViewHook) then
            C.activateViewHook = view
        end
        C.installedActivate = C.onActivateView
        ISChat.onActivateView = C.onActivateView
    end

    local entered = ISChat.onCommandEntered
    if entered ~= C.onCommandEntered then
        if C.commandHook == nil or (entered ~= C.installedCommand and entered ~= C.commandHook) then
            C.commandHook = entered
        end
        C.installedCommand = C.onCommandEntered
        ISChat.onCommandEntered = C.onCommandEntered
        local chat = ISChat.instance
        if chat and chat.textEntry then
            chat.textEntry.onCommandEntered = ISChat.onCommandEntered
        end
    end
end

C.refreshHooks()

function C.onGameStart()
    C.refreshHooks()
    if SquadManager.isActive() then
        C.addTab()
    else
        C.removeTab()
    end
end
Events.OnGameStart.Remove(C.onGameStart)
Events.OnGameStart.Add(C.onGameStart)

function C.onCreatePlayer(plNum, pl)
    C.refreshHooks()
    if not pl or not pl:isLocalPlayer() then return end
    C.pending = {}
    if SquadManager.isActive() then C.addTab() end
end
Events.OnCreatePlayer.Remove(C.onCreatePlayer)
Events.OnCreatePlayer.Add(C.onCreatePlayer)

function C.onMainMenuEnter()
    C.removeTab()
end
Events.OnMainMenuEnter.Remove(C.onMainMenuEnter)
Events.OnMainMenuEnter.Add(C.onMainMenuEnter)

function C.onDisconnect()
    C.removeTab()
end
Events.OnDisconnect.Remove(C.onDisconnect)
Events.OnDisconnect.Add(C.onDisconnect)

function C.test(text)
    C.addMessage(SquadManager.username() or "Tester", text or "Squad chat test.")
    return "ok"
end
