require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISPanel"

ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.Immortality = ParadiseRestore.Immortality or {}

local Immortality = ParadiseRestore.Immortality

Immortality.entries = Immortality.entries or {}
Immortality.window = Immortality.window or nil
Immortality.selfState = Immortality.selfState or false

function Immortality.getSelfState()
    if isClient and isClient() then return Immortality.selfState == true end
    local pl = getPlayer and getPlayer() or nil
    if not pl or not Immortality.isImmortal then return false end
    return Immortality.isImmortal(pl) == true
end

function Immortality.requestState()
    if isClient and isClient() then
        if sendClientCommand then
            sendClientCommand(Immortality.MODULE, "list", {})
            sendClientCommand(Immortality.MODULE, "query", {})
        end
        return
    end
    Immortality.entries = Immortality.getEntries and Immortality.getEntries() or {}
    Immortality.refreshPanel()
end

function Immortality.onServerCommand(module, command, args)
    if module ~= Immortality.MODULE then return end
    if command == "state" then
        Immortality.entries = args and args.entries or {}
        Immortality.refreshPanel()
        return
    end
    if command == "self" then
        Immortality.selfState = args and args.isImmortal == true or false
        Immortality.refreshPanel()
    end
end

function Immortality.applyLocal(username, key, isImmortal)
    if key and Immortality.setByKey then
        return Immortality.setByKey(key, username, isImmortal == true)
    end
    local targ = username and Immortality.findPlayer and Immortality.findPlayer(username) or nil
    if targ and Immortality.set then
        return Immortality.set(targ, isImmortal == true)
    end
    if username and Immortality.setPending then
        return Immortality.setPending(username, isImmortal == true)
    end
    return false
end

function Immortality.requestSet(username, isImmortal)
    if not username or tostring(username) == "" then return false end
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand(Immortality.MODULE, "set", {
            username = tostring(username),
            isImmortal = isImmortal == true,
        })
        return true
    end
    local ok = Immortality.applyLocal(username, nil, isImmortal == true)
    Immortality.requestState()
    return ok
end

function Immortality.requestKeySet(key, username, isImmortal)
    if not key or tostring(key) == "" then return false end
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand(Immortality.MODULE, "set", {
            key = tostring(key),
            username = username,
            isImmortal = isImmortal == true,
        })
        return true
    end
    local ok = Immortality.applyLocal(username, key, isImmortal == true)
    Immortality.requestState()
    return ok
end

function Immortality.requestSelfToggle()
    local pl = getPlayer and getPlayer() or nil
    if not pl then return false end
    local next = not Immortality.getSelfState()
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand(Immortality.MODULE, "self", { isImmortal = next })
        return true
    end
    if Immortality.set then Immortality.set(pl, next) end
    Immortality.selfState = next
    Immortality.requestState()
    return true
end

function Immortality.refreshPanel()
    local panel = Immortality.window
    if not panel or not panel.list then return end
    local list = panel.list
    local selected = list.items[list.selected]
    selected = selected and selected.item
    list:clear()
    for _, entry in ipairs(Immortality.entries or {}) do
        local state = "mortal"
        if entry.isImmortal then
            if entry.online and not entry.isActive then
                state = "outside Special zone"
            else
                state = "IMMORTAL"
            end
        end
        local label = tostring(entry.username or entry.key or "")
            .. (entry.online and " | online" or " | offline")
            .. " | " .. state
        list:addItem(label, entry)
    end
    list.selected = 0
    if selected then
        for index, item in ipairs(list.items) do
            local current = item.item
            if current and current.key == selected.key then
                list.selected = index
                break
            end
        end
    end
    if panel.selfButton then
        panel.selfButton.title = Immortality.getSelfState() and "Self: IMMORTAL" or "Self: mortal"
    end
end

Immortality.Panel = ISCollapsableWindow:derive("ParadiseRestore.Immortality.Panel")

function Immortality.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 10
    self.info = ISLabel:new(12, top, 18, "Zombies ignore these players. Admins: anywhere. Others: Special zone only.", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.info:initialise(); self.info:instantiate(); self:addChild(self.info)
    self.usernameEntry = ISTextEntryBox:new("", 84, top + 24, self.width - 222, 24)
    self.usernameEntry:initialise(); self.usernameEntry:instantiate(); self:addChild(self.usernameEntry)
    self.addButton = ISButton:new(self.width - 128, top + 24, 116, 24, "Add", self, Immortality.Panel.onClick)
    self.addButton.internal = "ADD"; self.addButton:initialise(); self.addButton:instantiate(); self:addChild(self.addButton)
    self.list = ISScrollingListBox:new(12, top + 54, self.width - 24, self.height - top - 108)
    self.list:initialise(); self.list:instantiate(); self.list.itemheight = 22; self.list.font = UIFont.Small; self.list.drawBorder = true; self:addChild(self.list)
    self.selfButton = ISButton:new(12, self.height - 42, 150, 26, "Self: mortal", self, Immortality.Panel.onClick)
    self.selfButton.internal = "SELF"; self.selfButton:initialise(); self.selfButton:instantiate(); self:addChild(self.selfButton)
    self.trueButton = ISButton:new(170, self.height - 42, 110, 26, "Immortal", self, Immortality.Panel.onClick)
    self.trueButton.internal = "TRUE"; self.trueButton:initialise(); self.trueButton:instantiate(); self:addChild(self.trueButton)
    self.falseButton = ISButton:new(288, self.height - 42, 110, 26, "Mortal", self, Immortality.Panel.onClick)
    self.falseButton.internal = "FALSE"; self.falseButton:initialise(); self.falseButton:instantiate(); self:addChild(self.falseButton)
    self.refreshButton = ISButton:new(self.width - 122, self.height - 42, 110, 26, "Refresh", self, Immortality.Panel.onClick)
    self.refreshButton.internal = "REFRESH"; self.refreshButton:initialise(); self.refreshButton:instantiate(); self:addChild(self.refreshButton)
    Immortality.refreshPanel()
end

function Immortality.Panel:onClick(button)
    if button.internal == "REFRESH" then
        Immortality.requestState()
        return
    end
    if button.internal == "SELF" then
        Immortality.requestSelfToggle()
        return
    end
    if button.internal == "ADD" then
        local user = self.usernameEntry and self.usernameEntry:getText() or ""
        if user ~= "" then
            Immortality.requestSet(user, true)
            self.usernameEntry:setText("")
        end
        return
    end
    if button.internal == "TRUE" or button.internal == "FALSE" then
        local item = self.list.items[self.list.selected]
        local entry = item and item.item or nil
        if not entry then return end
        Immortality.requestKeySet(entry.key, entry.username, button.internal == "TRUE")
    end
end

function Immortality.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "ParadiseRestore Immortality"
    panel.resizable = true
    panel.minimumWidth = 560
    panel.minimumHeight = 320
    return panel
end

function Immortality.Panel:close()
    Immortality.ClosePanel()
end

function Immortality.ClosePanel()
    local panel = Immortality.window
    Immortality.window = nil
    if panel then
        panel:setVisible(false)
        panel:removeFromUIManager()
    end
end

function Immortality.OpenPanel()
    if not Immortality.window then
        local width, height = 640, 420
        local core = getCore()
        local panel = Immortality.Panel:new((core:getScreenWidth() - width) / 2, (core:getScreenHeight() - height) / 2, width, height)
        Immortality.window = panel
        panel:initialise()
        panel:addToUIManager()
    end
    Immortality.window:setVisible(true)
    Immortality.requestState()
    return Immortality.window
end

function Immortality.TogglePanel()
    if Immortality.window then
        Immortality.ClosePanel()
        return nil
    end
    return Immortality.OpenPanel()
end

Events.OnServerCommand.Remove(Immortality.onServerCommand)
Events.OnServerCommand.Add(Immortality.onServerCommand)
Events.OnConnected.Remove(Immortality.requestState)
Events.OnConnected.Add(Immortality.requestState)