ParadiseDev = ParadiseDev or {}
ParadiseDev.Panels = ParadiseDev.Panels or {}

function ParadiseDev.Panels.onNetworkUsersReceived()
    local panel = ParadiseDev.Panels.usersList
    if panel and panel:isVisible() then panel:populateList() end
end
Events.OnNetworkUsersReceived.Remove(ParadiseDev.Panels.onNetworkUsersReceived)
Events.OnNetworkUsersReceived.Add(ParadiseDev.Panels.onNetworkUsersReceived)

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
