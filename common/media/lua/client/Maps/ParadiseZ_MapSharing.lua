-- Prevent non-admins from sharing world-map symbols with every player or a
-- hand-picked player list. Faction and safehouse sharing remain available.
require "ISUI/Maps/ISWorldMapSharing"

ParadiseZMapSharing = ParadiseZMapSharing or {}

local function isAuthorized()
    if ParadiseZAccess and ParadiseZAccess.isAuthorized and ParadiseZAccess.isAuthorized() then
        return true
    end

    local level = getAccessLevel and getAccessLevel() or nil
    return string.lower(tostring(level or "")) == "admin"
end

local function restrictPlayerSelector(sharingUI)
    if isAuthorized() then
        return
    end

    local panelMain = sharingUI.panelMain
    if not panelMain then
        return
    end

    -- Do not let switching radio options re-enable the Players button.
    local radioBtns = panelMain.radioBtns
    if radioBtns and not radioBtns.ParadiseZPlayerSelectorHooked then
        radioBtns.ParadiseZPlayerSelectorHooked = true
        local originalChanged = radioBtns.changeOptionFunc
        radioBtns.changeOptionFunc = function(target, buttons, index, ...)
            originalChanged(target, buttons, index, ...)
            if not isAuthorized() then
                target.buttonPlayers:setEnable(false)
            end
        end
    end

    if panelMain.buttonPlayers then
        panelMain.buttonPlayers:setEnable(false)
    end
end

local originalSetCurrentSymbol = ISWorldMapSharing.setCurrentSymbol
function ISWorldMapSharing:setCurrentSymbol(symbol)
    originalSetCurrentSymbol(self, symbol)

    if isAuthorized() then
        return
    end

    local radioBtns = self.panelMain and self.panelMain.radioBtns or nil
    if not radioBtns then
        return
    end

    -- Option 2 is B42's "Everyone" sharing mode.
    radioBtns:setOptionEnabled(2, false)
    if radioBtns:isSelected(2) then
        radioBtns:setSelected(3)
        self.panelMain:onRadioButton(radioBtns, 3)
    end

    restrictPlayerSelector(self)
end

local originalSetCurrentPanel = ISWorldMapSharing.setCurrentPanel
function ISWorldMapSharing:setCurrentPanel(panel)
    if panel == self.panelPlayers and not isAuthorized() then
        return
    end

    return originalSetCurrentPanel(self, panel)
end

local originalApplyChanges = ISWorldMapSharing.applyChanges
function ISWorldMapSharing:applyChanges()
    if not isAuthorized() then
        local radioBtns = self.panelMain and self.panelMain.radioBtns or nil
        if radioBtns and radioBtns:isSelected(2) then
            -- Defensive check: never allow the standard UI to serialize an
            -- everyone=true sharing object for a non-admin.
            radioBtns:setSelected(3)
            self.panelMain:onRadioButton(radioBtns, 3)
        end

        restrictPlayerSelector(self)
    end

    return originalApplyChanges(self)
end

print("[ParadiseZ] Map sharing protection loaded.")