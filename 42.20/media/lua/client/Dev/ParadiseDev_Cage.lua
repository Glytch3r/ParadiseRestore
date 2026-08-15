ParadiseDev = ParadiseDev or {}
ParadiseDev.Cage = ParadiseDev.Cage or {}

require "ISUI/AdminPanel/ISUsersList"

ParadiseDev.Cage.entries = ParadiseDev.Cage.entries or {}
ParadiseDev.Cage.window = ParadiseDev.Cage.window or nil

function ParadiseDev.Cage.isSteamMode()
    return getSteamModeActive and getSteamModeActive() or false
end

function ParadiseDev.Cage.requestState()
    if sendClientCommand then sendClientCommand("ParadiseDevCage", "list", {}) end
end

function ParadiseDev.Cage.setLocal(username, key, isCaged)
    local pl = getPlayer and getPlayer() or nil
    if not key and pl and pl.getUsername and pl:getUsername() == username then
        if ParadiseDev.Cage.isSteamMode() then
            key = username
        elseif pl.getSteamID then
            key = tostring(pl:getSteamID())
        end
    end
    if not key or tostring(key) == "" or tostring(key) == "0" then return false end
    if ParadiseDev.Cage.set and pl and pl.getUsername and pl:getUsername() == username then
        return ParadiseDev.Cage.set(pl, isCaged == true)
    end
    local store = ModData and ModData.getOrCreate and ModData.getOrCreate("ParadiseDev_IsCaged") or nil
    if not store then return false end
    store.players = store.players or {}
    store.names = store.names or {}
    key = tostring(key)
    if isCaged then
        store.players[key] = true
        store.names[key] = tostring(username or "")
    else
        store.players[key] = nil
        store.names[key] = nil
    end
    if ModData.transmit then ModData.transmit("ParadiseDev_IsCaged") end
    return true
end

function ParadiseDev.Cage.requestSet(username, isCaged)
    if not username or username == "" then return false end
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand("ParadiseDevCage", "set", { username = username, isCaged = isCaged == true })
        return true
    end
    return ParadiseDev.Cage.setLocal(username, nil, isCaged == true)
end

function ParadiseDev.Cage.requestSteamIdSet(steamId, isCaged)
    ParadiseDev.Cage.requestKeySet(steamId, nil, isCaged)
end

function ParadiseDev.Cage.requestKeySet(key, username, isCaged)
    if not key or key == "" then return false end
    if isClient and isClient() then
        if not sendClientCommand then return false end
        sendClientCommand("ParadiseDevCage", "set", { key = key, username = username, isCaged = isCaged == true })
        return true
    end
    return ParadiseDev.Cage.setLocal(username, key, isCaged == true)
end

function ParadiseDev.Cage.isTargetCaged(targ)
    if not targ then return false end
    local player = targ
    if not player.getCharacterTraits then
        local username = targ.username or (targ.getUsername and targ:getUsername())
        player = username and getPlayerFromUsername(username) or nil
    end
    local trait = ParadiseDev.getTrait and ParadiseDev.getTrait("ParadiseDev:Caged") or nil
    return player and trait and ParadiseDev.hasTrait and ParadiseDev.hasTrait(player, trait) or false
end

function ParadiseDev.Cage.addTargetOptions(context, targ)
    if not ParadiseDev.isAdm() or not context or not targ then return end
    local user = targ.username or (targ.getUsername and targ:getUsername())
    if not user or user == "" then return end
    if ParadiseDev.Cage.isTargetCaged(targ) then
        context:addOption("Remove Caged Trait: " .. tostring(user), nil, ParadiseDev.Cage.requestSet, user, false)
    else
        context:addOption("Add Caged Trait: " .. tostring(user), nil, ParadiseDev.Cage.requestSet, user, true)
    end
end

function ParadiseDev.Cage.getWorldTarget(context)
    if not context or not context.options then return nil end
    for _, option in ipairs(context.options) do
        local target = option.param4
        if target and instanceof(target, "IsoPlayer") then return target end
    end
    return nil
end

function ParadiseDev.Cage.addWorldContext(plNum, context, worldobjects, test)
    if test or not ParadiseDev.isAdm() then return end
    ParadiseDev.Cage.addTargetOptions(context, ParadiseDev.Cage.getWorldTarget(context))
end

function ParadiseDev.Cage.addScoreboardOptions(scoreboard, target, x, y)
    if not scoreboard or not ParadiseDev.isAdm() then return end
    local context = ISContextMenu.get(scoreboard.admin:getPlayerNum(), x + scoreboard:getAbsoluteX(), y + scoreboard:getAbsoluteY())
    ParadiseDev.Cage.addTargetOptions(context, target)
end

function ParadiseDev.Cage.scoreboardContext(scoreboard, target, x, y)
    ParadiseDev.Cage.scoreboardOriginal(scoreboard, target, x, y)
    if ParadiseZ and ParadiseZ.Oversight and ParadiseZ.Oversight.addScoreboardOptions then
        ParadiseZ.Oversight.addScoreboardOptions(scoreboard, target, x, y)
    end
    ParadiseDev.Cage.addScoreboardOptions(scoreboard, target, x, y)
end

function ParadiseDev.Cage.addUsersListOptions(usersList, item, x, y)
    if not usersList or not item or not ParadiseDev.isAdm(usersList.player) then return end
    local username = item:getUsername()
    if not username or username == "" then return end
    local context = ISContextMenu.get(usersList.player:getPlayerNum(), x + usersList:getAbsoluteX(), y + usersList:getAbsoluteY())
    if not context then return end
    ParadiseDev.Cage.addTargetOptions(context, { username = username })
    if item:isOnline() and username ~= usersList.player:getUsername() then
        local role = usersList.player:getRole()
        if role and role:hasCapability(Capability.TeleportToPlayer) then
            context:addOption("Spectate: " .. username, nil, ParadiseZ.setSpectate, username)
            if ParadiseZ.isSpectating(usersList.player) then
                context:addOption("Stop Spectating", nil, ParadiseZ.stopSpectate)
            end
        end
    end
end

function ParadiseDev.Cage.usersListContext(usersList, item, x, y)
    ParadiseDev.Cage.usersListOriginal(usersList, item, x, y)
    ParadiseDev.Cage.addUsersListOptions(usersList, item, x, y)
end

function ParadiseDev.Cage.populateScoreboard(scoreboard)
    ParadiseDev.Cage.scoreboardPopulateOriginal(scoreboard)
    local admin = scoreboard.admin
    local username = admin and admin:getUsername()
    if not username then return end
    for _, item in ipairs(scoreboard.playerList.items) do
        if item.item and item.item.username == username then return end
    end
    local displayName = admin.getDisplayName and admin:getDisplayName() or username
    local item = scoreboard.playerList:addItem(displayName, { username = username, displayName = displayName })
    if username ~= displayName then item.tooltip = username end
end

function ParadiseDev.Cage.hookScoreboard()
    if ISMiniScoreboardUI then
        if not ParadiseDev.Cage.scoreboardOriginal then
            ParadiseDev.Cage.scoreboardOriginal = ISMiniScoreboardUI.doPlayerListContextMenu
            ISMiniScoreboardUI.doPlayerListContextMenu = ParadiseDev.Cage.scoreboardContext
        end
        if not ParadiseDev.Cage.scoreboardPopulateOriginal then
            ParadiseDev.Cage.scoreboardPopulateOriginal = ISMiniScoreboardUI.populateList
            ISMiniScoreboardUI.populateList = ParadiseDev.Cage.populateScoreboard
        end
    end
    if not ParadiseDev.Cage.usersListOriginal and ISUsersList then
        ParadiseDev.Cage.usersListOriginal = ISUsersList.doContextMenu
        ISUsersList.doContextMenu = ParadiseDev.Cage.usersListContext
    end
end

ParadiseDev.Cage.Panel = ISCollapsableWindow:derive("ParadiseDev.Cage.Panel")

function ParadiseDev.Cage.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 10
    self.info = ISLabel:new(12, top, 18, "Cage assignments", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.info:initialise()
    self.info:instantiate()
    self:addChild(self.info)
    self.usernameLabel = ISLabel:new(12, top + 27, 18, "Username", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.usernameLabel:initialise()
    self.usernameLabel:instantiate()
    self:addChild(self.usernameLabel)
    self.usernameEntry = ISTextEntryBox:new("", 84, top + 24, self.width - 222, 24)
    self.usernameEntry:initialise()
    self.usernameEntry:instantiate()
    self:addChild(self.usernameEntry)
    self.addButton = ISButton:new(self.width - 128, top + 24, 116, 24, "Add", self, ParadiseDev.Cage.Panel.onClick)
    self.addButton.internal = "ADD"
    self.addButton:initialise()
    self.addButton:instantiate()
    self:addChild(self.addButton)
    self.list = ISScrollingListBox:new(12, top + 54, self.width - 24, self.height - top - 108)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 22
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self:addChild(self.list)
    self.trueButton = ISButton:new(12, self.height - 42, 110, 26, "Set TRUE", self, ParadiseDev.Cage.Panel.onClick)
    self.trueButton.internal = "TRUE"
    self.trueButton:initialise()
    self.trueButton:instantiate()
    self:addChild(self.trueButton)
    self.falseButton = ISButton:new(128, self.height - 42, 110, 26, "Set FALSE", self, ParadiseDev.Cage.Panel.onClick)
    self.falseButton.internal = "FALSE"
    self.falseButton:initialise()
    self.falseButton:instantiate()
    self:addChild(self.falseButton)
    self.refreshButton = ISButton:new(self.width - 122, self.height - 42, 110, 26, "Refresh", self, ParadiseDev.Cage.Panel.onClick)
    self.refreshButton.internal = "REFRESH"
    self.refreshButton:initialise()
    self.refreshButton:instantiate()
    self:addChild(self.refreshButton)
    ParadiseDev.Cage.refreshPanel()
end

function ParadiseDev.Cage.Panel:onClick(button)
    if button.internal == "REFRESH" then
        ParadiseDev.Cage.requestState()
        return
    end
    if button.internal == "ADD" then
        local username = self.usernameEntry and self.usernameEntry:getText() or ""
        if username ~= "" then ParadiseDev.Cage.requestSet(username, true) end
        if self.usernameEntry then self.usernameEntry:setText("") end
        return
    end
    local item = self.list.items[self.list.selected]
    local entry = item and item.item or nil
    if not entry then return end
    local isCaged = button.internal == "TRUE"
    if (entry.online or string.sub(tostring(entry.key or ""), 1, 9) == "username:") and entry.username ~= "" then
        ParadiseDev.Cage.requestSet(entry.username, isCaged)
    else
        ParadiseDev.Cage.requestKeySet(entry.key or entry.steamId, entry.username, isCaged)
    end
end

function ParadiseDev.Cage.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.title = "ParadiseZ Cage Administration"
    panel.resizable = true
    return panel
end

function ParadiseDev.Cage.refreshPanel()
    local panel = ParadiseDev.Cage.window
    if not panel or not panel.list or not panel.list.clear or not panel.list.addItem then return end
    if type(ParadiseDev.Cage.entries) ~= "table" then ParadiseDev.Cage.entries = {} end
    panel.list:clear()
    for _, entry in ipairs(ParadiseDev.Cage.entries) do
        panel.list:addItem(ParadiseDev.Cage.getEntryText(entry), entry)
    end
end

function ParadiseDev.Cage.getEntryText(entry)
    entry = entry or {}
    local username = tostring(entry.username or "")
    if username == "" then username = tostring(entry.displayName or "") end
    if username == "" then username = tostring(entry.key or entry.steamId or "Unknown") end
    local status = entry.isCaged and "TRUE" or "FALSE"
    local online = entry.online and "online" or "offline"
    if ParadiseDev.Cage.isSteamMode() then return username .. " | isCaged: " .. status .. " | " .. online end
    local steamId = tostring(entry.steamId or entry.key or "")
    if steamId ~= "" then return username .. " | Steam ID " .. steamId .. " | isCaged: " .. status .. " | " .. online end
    return username .. " | isCaged: " .. status .. " | " .. online
end

function ParadiseDev.Cage.openPanel()
    if not ParadiseDev.isAdm() then return end
    if ParadiseDev.Cage.window then
        ParadiseDev.Cage.window:setVisible(true)
        ParadiseDev.Cage.window:bringToTop()
        ParadiseDev.Cage.requestState()
        return
    end
    local panel = ParadiseDev.Cage.Panel:new(220, 180, 700, 420)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    ParadiseDev.Cage.window = panel
    ParadiseDev.Cage.requestState()
end

function ParadiseDev.Cage.onServerCommand(module, command, args)
    if module ~= "ParadiseDevCage" or command ~= "state" then return end
    ParadiseDev.Cage.entries = args and type(args.entries) == "table" and args.entries or {}
    ParadiseDev.Cage.refreshPanel()
end

Events.OnServerCommand.Add(ParadiseDev.Cage.onServerCommand)
Events.OnFillWorldObjectContextMenu.Add(ParadiseDev.Cage.addWorldContext)
Events.OnGameStart.Add(ParadiseDev.Cage.hookScoreboard)
