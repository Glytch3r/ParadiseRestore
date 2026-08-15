--[[ 

ParadiseDev = ParadiseDev or {}
ParadiseDev.AdminPower = ParadiseDev.AdminPower or {}
ParadiseZ = ParadiseZ or {}

--require "ISUI/AdminPanel/ISAdminPowerUI"
--require "Dev/ParadiseDev_Players"
--require "Z/Oversight/Oversight_AdminTag"


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

ParadiseDev.AdminPower.lastRoleName = ParadiseDev.AdminPower.lastRoleName or nil
ParadiseDev.AdminPower.roleChangedAt = ParadiseDev.AdminPower.roleChangedAt or 0

function ParadiseDev.AdminPower.rememberRole()
    local pl = getPlayer()
    local role = pl and pl:getRole() or nil
    ParadiseDev.AdminPower.lastRoleName = role and role:getName() or nil
end

function ParadiseDev.AdminPower.onRefreshCheats()
    local pl = getPlayer()
    local role = pl and pl:getRole() or nil
    local roleName = role and role:getName() or nil
    if ParadiseDev.AdminPower.lastRoleName and roleName and ParadiseDev.AdminPower.lastRoleName ~= roleName then
        ParadiseDev.AdminPower.roleChangedAt = getTimestampMs()
    end
    ParadiseDev.AdminPower.lastRoleName = roleName
end

function ParadiseDev.AdminPower.deferSave(panel)
    local wait = ParadiseDev.AdminPower.roleChangedAt + 2000 - getTimestampMs()
    if wait <= 0 then return false end

    local selected = {}
    local function addOptions(tickBox, options)
        for index, option in pairs(options) do
            selected[#selected + 1] = { option = option, value = tickBox:isSelected(index) }
        end
    end
    addOptions(panel.tickBoxLeft, panel.optionsLeft)
    addOptions(panel.tickBoxRight, panel.optionsRight)

    ParadiseZ.delay(wait / 1000, function()
        if panel.player:isDead() or not panel.player:getRole():hasAdminPower() then return end
        for _, entry in ipairs(selected) do
            entry.option.player = panel.player
            entry.option:setValue(entry.value)
        end
        sendPlayerExtraInfo(panel.player)
    end)
    return true
end

function ParadiseDev.AdminPower.addOption()
    if ISAdminPowerUI.OptionById.HideAdminTags then return end
    local option = ISAdminPowerUI.AddOption("HideAdminTags", "right", Capability.ToggleWriteRoleNameAbove,
        ParadiseDev.AdminPower.getHideAdminTags, ParadiseDev.AdminPower.setHideAdminTags)
    option.text = "Hide Admin Tag"
    option.tooltip = "Hide your admin tag."
end

ParadiseDev.AdminPower.addOption()

Events.OnGameStart.Add(ParadiseDev.AdminPower.rememberRole)
Events.RefreshCheats.Add(ParadiseDev.AdminPower.onRefreshCheats)

if not ParadiseDev.AdminPower.originalOnOpenPanel then
    ParadiseDev.AdminPower.originalOnOpenPanel = ISAdminPowerUI.OnOpenPanel
    ISAdminPowerUI.OnOpenPanel = function()
        local panel = ParadiseDev.AdminPower.originalOnOpenPanel()
        ParadiseDev.AdminPower.syncPanel(panel)
        return panel
    end
end

if not ParadiseDev.AdminPower.originalOnClick then
    ParadiseDev.AdminPower.originalOnClick = ISAdminPowerUI.onClick
    ISAdminPowerUI.onClick = function(self, button)
        if button.internal == "SAVE" and isClient() and ParadiseDev.AdminPower.deferSave(self) then
            print("SAVE" )
            self:setVisible(false)
            self:removeFromUIManager()
            self:saveOptions()
            return
        end
        ParadiseDev.AdminPower.originalOnClick(self, button)
    end
end

-----------------------            ---------------------------
--ParadiseZ.isHideAdminTag(pl)
 ]]