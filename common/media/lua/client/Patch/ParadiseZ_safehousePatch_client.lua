-- ParadiseZ Build 42 safehouse ownership-picker patch.
--
-- Vanilla only updates the selected ownership target while drawing the list,
-- and it leaves a prior invalid player's tooltip on the button. This produces
-- false "already in another safehouse" warnings and can submit the prior row.

if ParadiseZ_SafehousePickerPatchApplied then
    return
end

ParadiseZ_SafehousePickerPatchApplied = true

require "ISUI/UserPanel/ISSafehouseAddPlayerUI"

local function applySelection(panel, playerData)
    if not panel or not panel.addPlayer then
        return
    end

    if not playerData or playerData.tooltip then
        panel.selectedPlayer = nil
        panel.addPlayer.tooltip = playerData and playerData.tooltip or nil
        panel.addPlayer.enable = false
        return
    end

    panel.selectedPlayer = playerData.username
    panel.addPlayer.tooltip = nil
    panel.addPlayer.enable = true
end

local vanillaInitialise = ISSafehouseAddPlayerUI.initialise

function ISSafehouseAddPlayerUI:initialise()
    vanillaInitialise(self)

    -- ISScrollingListBox invokes this immediately on mouse/controller selection.
    self.playerList.target = self
    self.playerList.onmousedown = function(panel, playerData)
        applySelection(panel, playerData)
    end
end

local vanillaDrawPlayers = ISSafehouseAddPlayerUI.drawPlayers

function ISSafehouseAddPlayerUI:drawPlayers(y, item, alt)
    local nextY = vanillaDrawPlayers(self, y, item, alt)

    -- Keep the button state correct during the normal per-frame redraw too.
    if self.selected == item.index then
        applySelection(self.parent, item.item)
    end

    return nextY
end
