ParadiseDev = ParadiseDev or {}
ParadiseDev.AdminPower = ParadiseDev.AdminPower or {}
ParadiseZ = ParadiseZ or {}

require "ISUI/AdminPanel/ISAdminPowerUI"
require "Dev/ParadiseDev_Players"
require "Z/Oversight/Oversight_AdminTag"

function ParadiseDev.AdminPower.getHideAdminTags(self)
    if not self or not self.player then return false end
    return ParadiseZ.isHideAdminTag(self.player) or false
end

function ParadiseDev.AdminPower.setHideAdminTags(self, selected)
    if not self or not self.player then return end
    ParadiseZ.setHideAdminTag(selected, self.player)
    ParadiseZ.hideAdminTag(self.player)
end

function ParadiseDev.AdminPower.syncPanel(panel)
    if not panel then return end

    local function syncTickBox(tickBox, options)
        if not tickBox or not options then return end
        for index, option in pairs(options) do
            option.player = panel.player
            tickBox:setSelected(index, option:getValue() == true)
        end
    end

    syncTickBox(panel.tickBoxLeft, panel.optionsLeft)
    syncTickBox(panel.tickBoxRight, panel.optionsRight)
end

function ParadiseDev.AdminPower.addOption()
    if ISAdminPowerUI.OptionById.HideAdminTags then return end
    local option = ISAdminPowerUI.AddOption("HideAdminTags", "right", Capability.ToggleWriteRoleNameAbove,
        ParadiseDev.AdminPower.getHideAdminTags, ParadiseDev.AdminPower.setHideAdminTags)
    option.text = "Hide Admin Tag"
    option.tooltip = "Hide your admin tag."
end

ParadiseDev.AdminPower.addOption()

if not ParadiseDev.AdminPower.originalOnOpenPanel then
    ParadiseDev.AdminPower.originalOnOpenPanel = ISAdminPowerUI.OnOpenPanel
    ISAdminPowerUI.OnOpenPanel = function()
        local panel = ParadiseDev.AdminPower.originalOnOpenPanel()
        ParadiseDev.AdminPower.syncPanel(panel)
        return panel
    end
end
