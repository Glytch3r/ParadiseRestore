require "ISUI/AdminPanel/ISMiniScoreboardUI"

ParadiseDev = ParadiseDev or {}
ParadiseDev.miniscoreboard = ParadiseDev.miniscoreboard or {}

ParadiseDev.miniscoreboard.doPlayerListContextMenu = ParadiseDev.miniscoreboard.doPlayerListContextMenu or ISMiniScoreboardUI.doPlayerListContextMenu
ParadiseDev.miniscoreboard.onCommand = ParadiseDev.miniscoreboard.onCommand or ISMiniScoreboardUI.onCommand


function ISMiniScoreboardUI:doPlayerListContextMenu(player, x,y)
    ParadiseDev.miniscoreboard.doPlayerListContextMenu(self, player, x,y)
    local context = ISContextMenu.get(self.admin:getPlayerNum(), x + self:getAbsoluteX(), y + self:getAbsoluteY())
    local username = player and player.username or nil
    if username and self.admin and ParadiseDev.isAdm(self.admin) then
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

--[[ 
    if self.admin:getRole():hasCapability(Capability.TeleportToPlayer) then
        context:addOption(getText("UI_Scoreboard_Teleport"), self, ISMiniScoreboardUI.onCommand, player, "TELEPORT");
    end
    if self.admin:getRole():hasCapability(Capability.TeleportPlayerToAnotherPlayer) then
        context:addOption(getText("UI_Scoreboard_TeleportToYou"), self, ISMiniScoreboardUI.onCommand, player, "TELEPORTTOYOU");
    end
    if self.admin:getRole():hasCapability(Capability.ToggleInvisibleEveryone) then
        context:addOption(getText("UI_Scoreboard_Invisible"), self, ISMiniScoreboardUI.onCommand, player, "INVISIBLE");
    end
    if self.admin:getRole():hasCapability(Capability.ToggleGodModEveryone) then
        context:addOption(getText("UI_Scoreboard_GodMod"), self, ISMiniScoreboardUI.onCommand, player, "GODMOD");
    end
    if self.admin:getRole():hasCapability(Capability.CanSeePlayersStats) then
        context:addOption("Check Stats", self, ISMiniScoreboardUI.onCommand, player, "STATS");
    end
 ]]
end

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
end
