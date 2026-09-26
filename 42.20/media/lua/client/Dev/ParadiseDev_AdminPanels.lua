ParadiseDev = ParadiseDev or {}
ParadiseDev.Panels = ParadiseDev.Panels or {}

require "ISUI/ISTextEntryBox"

--[[ require "ISUI/AdminPanel/ISMiniScoreboardUI"
require "ISUI/AdminPanel/ISUsersList"
require "DebugUIs/DebugMenu/ISDebugUtils"
require "DebugUIs/DebugMenu/GlobalModData/GlobalModData"
require "ISUI/ISTextEntryBox" ]]


function ParadiseDev.Panels.isAdmin(player)
    return ParadiseDev.isAdm(player)
end
--[[ 
function ParadiseDev.Panels.addMissingScoreboardOptions(panel, player, x, y)
    if not ParadiseDev.Panels.isAdmin(panel.admin) then return end
    local role = panel.admin:getRole()
    local context = ISContextMenu.get(panel.admin:getPlayerNum(), x + panel:getAbsoluteX(), y + panel:getAbsoluteY())
    local function hasCapability(capability)
        return role and role.hasCapability and role:hasCapability(capability)
    end
    if not hasCapability(Capability.TeleportToPlayer) then
        context:addOption(getText("UI_Scoreboard_Teleport"), panel, ISMiniScoreboardUI.onCommand, player, "TELEPORT")
    end
    if not hasCapability(Capability.TeleportPlayerToAnotherPlayer) then
        context:addOption(getText("UI_Scoreboard_TeleportToYou"), panel, ISMiniScoreboardUI.onCommand, player, "TELEPORTTOYOU")
    end
    if not hasCapability(Capability.ToggleInvisibleEveryone) then
        context:addOption(getText("UI_Scoreboard_Invisible"), panel, ISMiniScoreboardUI.onCommand, player, "INVISIBLE")
    end
    if not hasCapability(Capability.ToggleGodModEveryone) then
        context:addOption(getText("UI_Scoreboard_GodMod"), panel, ISMiniScoreboardUI.onCommand, player, "GODMOD")
    end
    if not hasCapability(Capability.CanSeePlayersStats) then
        context:addOption("Check Stats", panel, ISMiniScoreboardUI.onCommand, player, "STATS")
    end
end

function ParadiseDev.Panels.addScoreboardOptions(panel, player, x, y)
    local context = ISContextMenu.get(panel.admin:getPlayerNum(), x + panel:getAbsoluteX(), y + panel:getAbsoluteY())
    if ParadiseZ and ParadiseZ.Oversight and ParadiseZ.Oversight.addScoreboardOptions then
        ParadiseZ.Oversight.addScoreboardOptions(panel, player, x, y)
    end
    if ParadiseDev.Cage and ParadiseDev.Cage.addTargetOptions then
        ParadiseDev.Cage.addTargetOptions(context, player)
    end
end
 ]]
--[[ 
function ParadiseDev.Panels.openUsersList()
    if ParadiseDev.Panels.usersList then
        ParadiseDev.Panels.usersList:setVisible(true)
        ParadiseDev.Panels.usersList:bringToTop()
        ISUsersList.refresh(ParadiseDev.Panels.usersList)
        return
    end
    requestUsers()
    local panel = ISUsersList:new(0, 0, 950, 600, getPlayer())
    panel.doContextMenu = function(self, item, x, y)
        ISUsersList.doContextMenu(self, item, x, y)
        local context = ISContextMenu.get(self.player:getPlayerNum(), x + self:getAbsoluteX(), y + self:getAbsoluteY())
        if ParadiseDev.Cage and ParadiseDev.Cage.addTargetOptions then
            ParadiseDev.Cage.addTargetOptions(context, { username = item:getUsername() })
        end
        local username = item:getUsername()
        if item:isOnline() and username ~= self.player:getUsername() and ParadiseZ and ParadiseZ.setSpectate then
            local role = self.player:getRole()
            if role and role:hasCapability(Capability.TeleportToPlayer) then
                context:addOption("Spectate: " .. username, nil, ParadiseZ.setSpectate, username)
                if ParadiseZ.isSpectating and ParadiseZ.isSpectating(self.player) then
                    context:addOption("Stop Spectating", nil, ParadiseZ.stopSpectate)
                end
            end
        end
    end
    panel.closeModal = function(self)
        self:setVisible(false)
        self:removeFromUIManager()
        ISUsersList.instance = nil
        ParadiseDev.Panels.usersList = nil
    end
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    ParadiseDev.Panels.usersList = panel
end
 ]]

function ParadiseDev.Panels.openWaveCaster()
    if WaveCaster and WaveCaster.panel then WaveCaster.panel(true) end
end

function ParadiseDev.Panels.onNetworkUsersReceived()
    local panel = ParadiseDev.Panels.usersList
    if panel and panel:isVisible() then panel:populateList() end
end
Events.OnNetworkUsersReceived.Remove(ParadiseDev.Panels.onNetworkUsersReceived)
Events.OnNetworkUsersReceived.Add(ParadiseDev.Panels.onNetworkUsersReceived)
