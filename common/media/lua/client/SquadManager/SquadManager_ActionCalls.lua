if not isClient() then return end

SquadManager = SquadManager or {}
if not SquadManager.isB41 then require "SquadManager/SquadManager_Shared" end
if SquadManager.isB41() then return end

require "ISUI/ISPanel"
require "ISUI/ISButton"

SquadManager.ActionCalls = SquadManager.ActionCalls or {}

local A = SquadManager.ActionCalls
A.panel = nil
A.callout = nil
A.bindKey = nil
A.pressCount = 0
A.lastPress = 0
A.pressWindow = 420
A.announcements = {}
A.hotbarGuarded = false

function A.stamp()
    if getTimestampMs then return getTimestampMs() end
    return os.time() * 1000
end

function A.rows(mode)
    local result = {}
    for _, entry in ipairs(SquadManager.actionCalls) do
        local isLeaderRow = entry.leader == true
        if mode == "leader" then
            if isLeaderRow then result[#result + 1] = entry end
        elseif not isLeaderRow then
            result[#result + 1] = entry
        end
    end
    return result
end

function A.bindKeyCode()
    local key = tonumber(SquadManager.configValue("ActionCallKey")) or SquadManager.defaults.ActionCallKey
    return math.floor(key)
end

function A.applyBind()
    local key = A.bindKeyCode()
    if A.bindKey == key then return end
    A.bindKey = key
    if not getCore().addKeyBinding then return end
    getCore():addKeyBinding(SquadManager.bindId, key, 0, false, false, false)
end

function A.isBind(key)
    if not key or key == 0 then return false end
    if key ~= A.bindKeyCode() then return false end
    return getCore():getKey(SquadManager.bindId) == key
end

function A.numberSlot(key)
    local first = Keyboard.KEY_1
    if key >= first and key <= first + 8 then return key - first + 1 end
    return nil
end

function A.isOpen()
    return A.panel ~= nil and A.panel:isVisible() == true
end

function A.chatBusy()
    return ISChat and ISChat.focused == true
end

function A.mouseTarget()
    if not IsoObjectPicker or not IsoObjectPicker.Instance then return nil end
    local ok, obj = pcall(function()
        return IsoObjectPicker.Instance:PickTarget(getMouseXScaled(), getMouseYScaled())
    end)
    if not ok then return nil end
    return obj
end

function A.mouseSquare()
    local pl = getPlayer()
    if not pl or not ISCoordConversion then return nil end
    local level = math.floor(pl:getZ())
    local wx, wy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), level)
    if not wx or not wy then return nil end
    local cell = getCell and getCell() or nil
    if not cell then return nil end
    return cell:getGridSquare(math.floor(wx), math.floor(wy), level)
end

function A.hoverTag()
    if not SquadManager.isActive() then return false end
    local pl = getPlayer()
    if not pl then return false end
    local target = A.mouseTarget()
    if target and instanceof(target, "IsoPlayer") then
        local user = target:getUsername()
        if user == pl:getUsername() then return false end
        if SquadManager.memberByUser(user) then return false end
        SquadManager.send(SquadManager.commands.tag, { kind = "player", user = user })
        return true
    end
    if target and instanceof(target, "IsoZombie") then
        SquadManager.send(SquadManager.commands.tag, {
            kind = "zombie",
            x = math.floor(target:getX()),
            y = math.floor(target:getY()),
            z = math.floor(target:getZ()),
        })
        return true
    end
    local sq = A.mouseSquare()
    if not sq then return false end
    if pl:DistTo(sq:getX(), sq:getY()) > 60 then return false end
    SquadManager.send(SquadManager.commands.tag, {
        kind = "zombie",
        x = math.floor(sq:getX()),
        y = math.floor(sq:getY()),
        z = math.floor(sq:getZ()),
    })
    return true
end

function A.onBindPress()
    if A.hoverTag() then
        A.pressCount = 0
        A.hidePanel()
        return
    end
    local now = A.stamp()
    if now - A.lastPress > A.pressWindow then A.pressCount = 0 end
    A.lastPress = now
    A.pressCount = A.pressCount + 1
    if A.pressCount >= 3 then
        A.pressCount = 0
        A.hidePanel()
        return
    end
    if A.pressCount == 2 then
        if SquadManager.isLeader() then
            A.show("leader")
        else
            A.pressCount = 0
            A.hidePanel()
        end
        return
    end
    A.show("member")
end

function A.onKeyPressed(key)
    if A.chatBusy() then return end
    if A.isBind(key) then
        A.onBindPress()
        return
    end
    if key == Keyboard.KEY_ESCAPE then
        A.hidePanel()
        A.pressCount = 0
        return
    end
end
Events.OnKeyPressed.Remove(A.onKeyPressed)
Events.OnKeyPressed.Add(A.onKeyPressed)

function A.hotbarFilter(key)
    if A.isOpen() and not A.chatBusy() then
        local slot = A.numberSlot(key)
        if slot then
            A.pickSlot(slot)
            return
        end
    end
    A.hotbarHook(key)
end

function A.installHotbarGuard()
    if A.hotbarGuarded then return end
    if not ISHotbar or not ISHotbar.onKeyPressed then return end
    A.hotbarHook = ISHotbar.onKeyPressed
    Events.OnKeyPressed.Remove(A.hotbarHook)
    Events.OnKeyPressed.Add(A.hotbarFilter)
    A.hotbarGuarded = true
end

function A.uninstallHotbarGuard()
    if not A.hotbarGuarded then return end
    Events.OnKeyPressed.Remove(A.hotbarFilter)
    Events.OnKeyPressed.Add(A.hotbarHook)
    A.hotbarGuarded = false
end

function A.fadeDelay()
    return math.max(1, tonumber(SquadManager.configValue("ActionCallPanelFadeDelay")) or 5)
end

function A.hidePanel()
    if not A.panel then return end
    A.panel:setVisible(false)
    A.panel:removeFromUIManager()
    A.panel = nil
end

function A.show(mode)
    if not SquadManager.isActive() then return end
    A.installHotbarGuard()
    if mode ~= "leader" then mode = "member" end
    if A.panel then
        if A.panel.actionCallMode == mode then
            A.panel:setExpires()
            A.panel:bringToTop()
            return
        end
        A.hidePanel()
    end
    local panel = A.Panel:new(0, 0, 300, 40, mode)
    panel:initialise()
    panel:addToUIManager()
    panel:setExpires()
    A.panel = panel
end

function A.pickSlot(slot)
    if not A.panel then return end
    local entry = A.panel.rows[slot]
    if not entry then return end
    A.trigger(entry)
end

function A.markerPosition()
    local pl = getPlayer()
    if not pl then return nil end
    local args = {
        x = math.floor(pl:getX()),
        y = math.floor(pl:getY()),
        z = math.floor(pl:getZ()),
    }
    local sq = A.mouseSquare()
    if sq and pl:DistTo(sq:getX(), sq:getY()) <= 60 then
        args.tx = math.floor(sq:getX())
        args.ty = math.floor(sq:getY())
        args.tz = math.floor(sq:getZ())
    end
    return args
end

function A.trigger(entry)
    if not entry then return end
    if not SquadManager.isActive() then return end
    if entry.leader and not SquadManager.isLeader() then return end
    local args = A.markerPosition()
    if not args then return end
    args.index = entry.index
    A.hidePanel()
    A.pressCount = 0
    SquadManager.send(SquadManager.commands.actionCall, args)
end

function A.addAnnouncement(text, col)
    A.announcements[#A.announcements + 1] = {
        text = text,
        col = col,
        expire = A.stamp() + 3200,
    }
    if #A.announcements > 4 then table.remove(A.announcements, 1) end
end

function A.drawAnnouncements()
    if not isIngameState() then return end
    local stamp = A.stamp()
    local kept = {}
    for _, line in ipairs(A.announcements) do
        if stamp < line.expire then kept[#kept + 1] = line end
    end
    A.announcements = kept
    if #kept <= 0 then return end
    local core = getCore()
    local cx = core:getScreenWidth() / 2
    local baseY = core:getScreenHeight() - 190
    for index, line in ipairs(kept) do
        local col = line.col or SquadManager.colors.squad
        local y = baseY - (#kept - index) * 26
        getTextManager():DrawStringCentre(UIFont.Medium, cx - 1, y - 1, line.text, 0, 0, 0, 1)
        getTextManager():DrawStringCentre(UIFont.Medium, cx + 1, y + 1, line.text, 0, 0, 0, 1)
        getTextManager():DrawStringCentre(UIFont.Medium, cx, y, line.text, col.r, col.g, col.b, 1)
    end
end
Events.OnPostUIDraw.Remove(A.drawAnnouncements)
Events.OnPostUIDraw.Add(A.drawAnnouncements)

function A.receive(args)
    if type(args) ~= "table" then return end
    local entry = SquadManager.actionCallByIndex(tonumber(args.index))
    if not entry then return end
    SquadManager.playSound(args.leader and "ParadiseRestore_Squad_Ping_1" or "ParadiseRestore_Squad_Ping_2")
    local name = tostring(args.user or "")
    A.addAnnouncement(name .. ": " .. entry.label,
        args.leader and SquadManager.colors.leader or SquadManager.colors.squad)
    if SquadManager.Chat then
        SquadManager.Chat.addSystemLine("/" .. string.lower(entry.label))
    end
    if SquadManager.Visuals then
        SquadManager.Visuals.spawnCall(entry, args)
    end
    if SquadManager.Map then SquadManager.Map.refresh() end
end

SquadManager.ActionCalls.Panel = SquadManager.ActionCalls.Panel or ISPanel:derive("SquadManager_ActionCallsPanel")
local P = SquadManager.ActionCalls.Panel
P.__index = P

function P:new(x, y, width, height, mode)
    local obj = ISPanel:new(x, y, width, height)
    setmetatable(obj, P)
    obj.actionCallMode = mode
    obj.rows = A.rows(mode)
    obj.rowHeight = 24
    obj.padding = 8
    obj.title = mode == "leader" and "Leader Calls" or "Squad Calls"
    obj:recalcSize()
    return obj
end

function P:recalcSize()
    self.height = #self.rows * self.rowHeight + self.padding * 2 + 22
    self:setHeight(self.height)
    local core = getCore()
    self:setX(math.max(0, (core:getScreenWidth() - self.width) / 2))
    self:setY(math.max(0, core:getScreenHeight() - self.height - 150))
end

function P:createChildren()
    ISPanel.createChildren(self)
    self.backgroundColor.a = 0.75
    self.current = -1
    local y = self.padding + 20
    for slot, entry in ipairs(self.rows) do
        local label = tostring(slot) .. ".  " .. entry.label
        local button = ISButton:new(self.padding, y, self.width - self.padding * 2, self.rowHeight - 2, label, self, P.onRowClick)
        button.internal = slot
        button:initialise()
        button:instantiate()
        button.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }
        self:addChild(button)
        y = y + self.rowHeight
    end
end

function P:onRowClick(button)
    A.pickSlot(button.internal)
end

function P:setExpires()
    self.expires = A.stamp() + A.fadeDelay() * 1000
end

function P:isExpired()
    return A.stamp() >= (self.expires or 0)
end

function P:prerender()
    ISPanel.prerender(self)
    if self:isExpired() then
        A.hidePanel()
        return
    end
    local col = self.actionCallMode == "leader" and SquadManager.colors.leader or SquadManager.colors.squad
    self:drawText(self.title, self.padding, self.padding, col.r, col.g, col.b, 1, UIFont.Small)
end

function P:bringToTop()
    ISPanel.bringToTop(self)
end

function A.onGameStart()
    A.applyBind()
    A.installHotbarGuard()
end
Events.OnGameStart.Remove(A.onGameStart)
Events.OnGameStart.Add(A.onGameStart)

function A.onCreatePlayer(plNum, pl)
    if not pl or not pl:isLocalPlayer() then return end
    A.hidePanel()
    A.announcements = {}
    A.pressCount = 0
    A.applyBind()
    A.installHotbarGuard()
end
Events.OnCreatePlayer.Remove(A.onCreatePlayer)
Events.OnCreatePlayer.Add(A.onCreatePlayer)

function A.onMainMenuEnter()
    A.hidePanel()
    A.announcements = {}
    A.pressCount = 0
    A.uninstallHotbarGuard()
end
Events.OnMainMenuEnter.Remove(A.onMainMenuEnter)
Events.OnMainMenuEnter.Add(A.onMainMenuEnter)

function A.test(index)
    local entry = SquadManager.actionCallByIndex(tonumber(index) or 1)
    if not entry then return "unknown index" end
    A.receive({
        index = entry.index,
        user = SquadManager.username(),
        leader = entry.leader == true,
        x = math.floor(getPlayer():getX()),
        y = math.floor(getPlayer():getY()),
        z = math.floor(getPlayer():getZ()),
    })
    return entry.label
end
