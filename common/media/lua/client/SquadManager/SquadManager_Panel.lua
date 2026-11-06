if not isClient() then return end

SquadManager = SquadManager or {}
if not SquadManager.isB41 then require "SquadManager/SquadManager_Shared" end
if SquadManager.isB41() then return end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"

SquadManager.Panel = SquadManager.Panel or {}
local P = SquadManager.Panel

P.rowHeight = 24
P.rowGap = 3
P.actionWidth = 62
P.seatCap = SquadManager.limits.SquadMaxMembers.max

function P.canOpen()
    return SquadManager.isEnabled and SquadManager.isEnabled() == true
end

function P.getSize()
    local width = math.min(520, getCore():getScreenWidth() - 40)
    local height = math.min(420, getCore():getScreenHeight() - 40)
    return width, height
end

function P.inviteClicked(target, user)
    local clean = SquadManager.sanitizeUser(user)
    if clean == "" then return end
    SquadManager.send(SquadManager.commands.invite, { user = clean })
end

function P.canInvite()
    if not SquadManager.isEnabled() then return false end
    if not SquadManager.inSquad() then return false end
    if not SquadManager.isLeader() then return false end
    local squad = SquadManager.getSquad()
    if not squad or squad.active then return false end
    return SquadManager.seatCount(squad) < SquadManager.maxSeats()
end

function P.onFillWorldObjectContextMenu(context, world, contextObjects, x, y)
    if not P.canInvite() then return end
    local me = getPlayer()
    if not me then return end
    local seen = {}
    for _, obj in ipairs(contextObjects) do
        if obj and instanceof(obj, "IsoPlayer") and obj ~= me then
            local user = obj:getUsername()
            if user and not seen[user] and user ~= me:getUsername() then
                seen[user] = true
                context:addOption("Invite to squad", P, P.inviteClicked, user)
            end
        end
    end
end
Events.OnFillWorldObjectContextMenu.Remove(P.onFillWorldObjectContextMenu)
Events.OnFillWorldObjectContextMenu.Add(P.onFillWorldObjectContextMenu)

P.Window = ISCollapsableWindow:derive("SquadManager.Window")

function P.Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)
    local th = self:titleBarHeight()
    local pad = 10
    local actionWidth = P.actionWidth
    local rowWidth = self.width - (pad * 2) - actionWidth - 4

    self.rows = {}
    self.kicks = {}
    for seat = 1, P.seatCap do
        local y = th + 68 + ((seat - 1) * (P.rowHeight + P.rowGap))
        local row = ISButton:new(pad, y, rowWidth, P.rowHeight, tostring(seat), self, P.Window.onRowClick)
        row.internal = seat
        row:initialise()
        row:instantiate()
        row.font = UIFont.Small
        self:addChild(row)
        self.rows[seat] = row

        local kick = ISButton:new(pad + rowWidth + 4, y, actionWidth, P.rowHeight, "Kick", self, P.Window.onKickClick)
        kick.internal = seat
        kick:initialise()
        kick:instantiate()
        kick.font = UIFont.Small
        kick:setVisible(false)
        self:addChild(kick)
        self.kicks[seat] = kick
    end

    local labels = {
        { internal = "create",   text = "Create Squad" },
        { internal = "commence", text = "Commence" },
        { internal = "disband",  text = "Disband" },
        { internal = "leave",    text = "Leave Squad" },
        { internal = "refresh",  text = "Refresh" },
        { internal = "close",    text = "Close" },
    }
    self.actions = {}
    local buttonY = self.height - 42
    for i, entry in ipairs(labels) do
        local width = math.floor((self.width - (pad * 2) - 5 * 4) / 6)
        local button = ISButton:new(pad + ((i - 1) * (width + 4)), buttonY, width, 28, entry.text, self, P.Window.onActionClick)
        button.internal = entry.internal
        button:initialise()
        button:instantiate()
        button.font = UIFont.Small
        self:addChild(button)
        self.actions[entry.internal] = button
    end

    self:refresh()
end

function P.Window:onActionClick(button)
    local id = button.internal
    if id == "close" then
        self:close()
    elseif id == "create" then
        SquadManager.send(SquadManager.commands.create)
    elseif id == "commence" then
        SquadManager.send(SquadManager.commands.commence)
    elseif id == "disband" then
        SquadManager.send(SquadManager.commands.disband)
    elseif id == "leave" then
        SquadManager.send(SquadManager.commands.leave)
    elseif id == "refresh" then
        SquadManager.send(SquadManager.commands.requestState)
    end
end

function P.Window:onRowClick(button)
    local seat = button.internal
    if not SquadManager.inSquad() then return end
    local squad = SquadManager.getSquad()
    local me = SquadManager.username()
    local mine = SquadManager.seat()
    if not mine then return end
    local occupant = squad and SquadManager.seatUser(squad, seat) or nil
    if occupant == me then return end
    if SquadManager.isLeader() then
        SquadManager.send(SquadManager.commands.transferSeat, { from = mine, to = seat })
        return
    end
    if not occupant then
        SquadManager.send(SquadManager.commands.transferSeat, { from = mine, to = seat })
    end
end

function P.Window:onKickClick(button)
    if not SquadManager.isLeader() then return end
    SquadManager.send(SquadManager.commands.kick, { seat = button.internal })
end

function P.Window:status()
    if not SquadManager.isEnabled() then
        return "The squad system is disabled on this server."
    end
    if not SquadManager.loaded then
        return "Waiting for squad data from the server..."
    end
    local squad = SquadManager.getSquad()
    if not squad then
        return "You are not in a squad. Create one to invite players."
    end
    if SquadManager.isActive() then
        return "Active. Squad chat, map visuals, action calls and tags are enabled."
    end
    if not SquadManager.leaderUser(squad) then
        return "No leader. Seat 1 is empty. Take seat 1 to lead the squad and Commence."
    end
    return "Forming. The leader must press Commence to enable squad features."
end

function P.Window:refresh()
    if not self.rows then return end
    local squad = SquadManager.getSquad()
    local me = SquadManager.username()
    local max = SquadManager.maxSeats()
    local leader = SquadManager.isLeader()

    for int = 1, P.seatCap do
        local row = self.rows[int]
        local kick = self.kicks[int]
        local show = int <= max
        local user = squad and SquadManager.seatUser(squad, int) or nil
        if row then
            row:setVisible(show == true)
            if show then
                local label = int .. ".  " .. (user or "(empty)")
                if user == me then label = label .. "  (you)" end
                if int == 1 and user then label = label .. "  <LEADER>" end
                row.title = label
            end
        end
        if kick then
            kick:setVisible(leader == true and show and int > 1 and user ~= nil)
        end
    end

    local inSquad = squad ~= nil
    local active = SquadManager.isActive()
    if self.actions then
        self.actions.create:setVisible(not inSquad and SquadManager.isEnabled() == true)
        self.actions.commence:setVisible(inSquad and leader and not active)
        self.actions.disband:setVisible(inSquad and leader == true)
        self.actions.leave:setVisible(inSquad)
        self.actions.refresh:setVisible(true)
        self.actions.close:setVisible(true)
    end
end

function P.Window:prerender()
    ISCollapsableWindow.prerender(self)
    if self.isCollapsed then return end
    local th = self:titleBarHeight()
    local squad = SquadManager.getSquad()
    local line = self:status()
    self:drawText(ParadiseZ and ParadiseZ.fitText and ParadiseZ.fitText(line, self.width - 20, UIFont.Small) or line,
        10, th + 8, 1, 0.92, 0.6, 1, UIFont.Small)

    local leaderUser = squad and SquadManager.leaderUser(squad) or nil
    local seats = squad and SquadManager.seatCount(squad) or 0
    local summary = leaderUser and ("Leader: " .. tostring(leaderUser) .. "    Seats: " .. tostring(seats) .. "/" .. tostring(SquadManager.maxSeats()))
        or ("No leader (seat 1 empty)    Seats: " .. tostring(seats) .. "/" .. tostring(SquadManager.maxSeats()))
    self:drawText(summary, 10, th + 26, 0.8, 0.9, 0.8, 1, UIFont.Small)

    local hint = P.canInvite() and "Right-click a nearby player to invite them."
        or (squad and not SquadManager.isActive() and "Invite players, then Commence to activate the squad." or nil)
    if hint then
        self:drawText(hint, 10, th + 44, 0.6, 0.8, 1, 1, UIFont.Small)
    end
end

function P.Window:close()
    P.ClosePanel()
end

function P.Window:new(x, y, width, height)
    local obj = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(obj, self)
    self.__index = self
    obj.title = "Squad"
    obj.minimumWidth = 460
    obj.minimumHeight = 300
    obj.resizable = true
    return obj
end

function P.test()
    P.OpenPanel()
    return "ok"
end
