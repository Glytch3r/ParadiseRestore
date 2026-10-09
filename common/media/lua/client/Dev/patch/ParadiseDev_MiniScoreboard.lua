
ParadiseDev = ParadiseDev or {}
ParadiseDev.miniscoreboard = ParadiseDev.miniscoreboard or {}


ParadiseDev.miniscoreboard.doPlayerListContextMenuHook = ParadiseDev.miniscoreboard.doPlayerListContextMenuHook or ISMiniScoreboardUI.doPlayerListContextMenu
function ISMiniScoreboardUI:doPlayerListContextMenu(player, x,y)
    local playerNum = self.admin:getPlayerNum()
    local context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY());
    ParadiseDev.miniscoreboard.doPlayerListContextMenuHook(self, player, x,y)
    local username = player and player.username or nil
    if username and ParadiseRestore.isAdm(self.admin) then
        if ParadiseDev.TargContext and ParadiseDev.TargContext.addPlayerActions then
            ParadiseDev.TargContext.addPlayerActions(context, player, self.admin, false)
        end
    end
end 

ParadiseDev.miniscoreboard.closeHook = ParadiseDev.miniscoreboard.closeHook or ISMiniScoreboardUI.close
function ISMiniScoreboardUI:close()
    local options = SandboxVars and SandboxVars.ParadiseZ or {}
    if options.StopSpectateOnScoreboardClose ~= false and
        ParadiseZ and ParadiseZ.isSpectating and ParadiseZ.isSpectating(self.admin) and ParadiseZ.stopSpectate then
        ParadiseZ.stopSpectate()
    end
    ParadiseDev.miniscoreboard.closeHook(self)
end
