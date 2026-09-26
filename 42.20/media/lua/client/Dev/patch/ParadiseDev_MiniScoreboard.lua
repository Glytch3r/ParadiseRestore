require "ISUI/AdminPanel/ISMiniScoreboardUI"

ParadiseDev = ParadiseDev or {}
ParadiseDev.miniscoreboard = ParadiseDev.miniscoreboard or {}


local hook1 = ISMiniScoreboardUI.doPlayerListContextMenu
function ISMiniScoreboardUI:doPlayerListContextMenu(player, x,y)
    local playerNum = self.admin:getPlayerNum()
    local context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY());
    hook1(self, player, x,y)
    if ParadiseDev.isAdm(self.admin) then
        local caged = ParadiseDev.Cage and ParadiseDev.Cage.isTargetCaged and ParadiseDev.Cage.isTargetCaged(player)
        context:addOption((caged and "Uncage: " or "Cage: ") .. username, self, ISMiniScoreboardUI.onCommand, player, "CAGED")
        local role = self.admin:getRole()
        if role and role:hasCapability(Capability.TeleportToPlayer) then
            context:addOption("Spectate: " .. username, self, ISMiniScoreboardUI.onCommand, player, "SPECTATE")
        end
        if ParadiseDev.SkillRecovery and ParadiseDev.SkillRecovery.addTargetOptions then
            ParadiseDev.SkillRecovery.addTargetOptions(context, player)
        end
    end
end 

local hook2 = ISMiniScoreboardUI.onCommand
function ISMiniScoreboardUI:onCommand(player, command)    
    if command == "CAGED" then
        local username = player and player.username or nil
        if username and ParadiseDev.Cage and ParadiseDev.Cage.requestSet then
            local caged = ParadiseDev.Cage.isTargetCaged and ParadiseDev.Cage.isTargetCaged(player)
            ParadiseDev.Cage.requestSet(username, not caged)
        end
    elseif command == "SPECTATE" then
        if ParadiseZ and ParadiseZ.setSpectate and player and player.username then ParadiseZ.setSpectate(player.username) end
    else
        ParadiseDev.miniscoreboard.onCommand(player, command)
    end
    hook2(self, player, command)
end
