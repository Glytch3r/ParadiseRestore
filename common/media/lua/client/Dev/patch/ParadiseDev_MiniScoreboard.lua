
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

ParadiseDev.miniscoreboard.drawPlayersHook = ParadiseDev.miniscoreboard.drawPlayersHook or ISMiniScoreboardUI.drawPlayers
function ISMiniScoreboardUI:drawPlayers(y, item, alt)
    local username = item and item.item and item.item.username or nil
    local pl = username and ParadiseRestore.getTarg(username) or nil
    if pl and pl:getAccessLevel() and string.lower(tostring(pl:getAccessLevel())) == "admin" then
        local a = 0.9
        self:drawRectBorder(0, y, self:getWidth(), self.itemheight - 1, a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
        if self.selected == item.index then
            self:drawRect(0, y, self:getWidth(), self.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
        end
        self:drawText(item.text, 10, y + 2, 1, 0, 0, a, self.font)
        return y + self.itemheight
    end
    return ParadiseDev.miniscoreboard.drawPlayersHook(self, y, item, alt)
end
