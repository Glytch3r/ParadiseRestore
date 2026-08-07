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

function ParadiseDev.AdminPower.addOption()
    if not ISAdminPowerUI or not ISAdminPowerUI.OptionList or not ISAdminPowerUI.OptionById then return end
    if ISAdminPowerUI.OptionById and ISAdminPowerUI.OptionById.HideAdminTags then return end
    local option = {}
    option.id = "HideAdminTags"
    option.text = "Hide Admin Tag"
    option.tooltip = "Hide your admin tag."
    option.side = "right"
    option.capability = Capability.ToggleWriteRoleNameAbove
    option.getValue = ParadiseDev.AdminPower.getHideAdminTags
    option.setValue = ParadiseDev.AdminPower.setHideAdminTags
    table.insert(ISAdminPowerUI.OptionList, option)
    ISAdminPowerUI.OptionById[option.id] = option
end

ParadiseDev.AdminPower.addOption()
