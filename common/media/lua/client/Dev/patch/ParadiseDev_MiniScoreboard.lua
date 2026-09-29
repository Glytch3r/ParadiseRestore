
ParadiseDev = ParadiseDev or {}
ParadiseDev.miniscoreboard = ParadiseDev.miniscoreboard or {}


local hook1 = ISMiniScoreboardUI.doPlayerListContextMenu
function ISMiniScoreboardUI:doPlayerListContextMenu(player, x,y)
    local playerNum = self.admin:getPlayerNum()
    local context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY());
    hook1(self, player, x,y)
    local username = player and player.username or nil
    if username and ParadiseRestore.isAdm(self.admin) then
        if ParadiseDev.TargContext and ParadiseDev.TargContext.addPlayerActions then
            ParadiseDev.TargContext.addPlayerActions(context, player, self.admin)
        end
    end
end 

local closeHook = ISMiniScoreboardUI.close
function ISMiniScoreboardUI:close()
    local options = SandboxVars and SandboxVars.ParadiseZ or {}
    if options.StopSpectateOnScoreboardClose ~= false and
        ParadiseZ and ParadiseZ.isSpectating and ParadiseZ.isSpectating(self.admin) and ParadiseZ.stopSpectate then
        ParadiseZ.stopSpectate()
    end
    closeHook(self)
end
