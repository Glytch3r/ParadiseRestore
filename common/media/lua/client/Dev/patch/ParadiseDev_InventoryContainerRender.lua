require "ISUI/ISInventoryPage"

-- The loot strip already uses a stencil. Let the native UI skip wholly clipped
-- children too, while keeping their updates, input, selection and pooling intact.
ParadiseDev_InventoryContainerRender = ParadiseDev_InventoryContainerRender or {}
if ParadiseDev_InventoryContainerRender.installed then return end
ParadiseDev_InventoryContainerRender.installed = true
ParadiseDev_InventoryContainerRender.version = 1

local function lootPage(page)
    return page and page.onCharacter == false and page.containerButtonPanel
end

local function clearInteraction(page, button)
    if button.tooltipUI and button.tooltipUI:getIsVisible() then
        button.tooltipUI:setVisible(false)
        button.tooltipUI:removeFromUIManager()
    end
    button.mouseOver = false
    button._paradiseContainerHoverReset = true
    -- Another button may have acquired the hover since this one last rendered.
    -- Vanilla's mouse-out callback clears the page-wide hover unconditionally.
    if page.mouseOverButton == button and button.onmouseoutfunction then
        button.onmouseoutfunction(button.target, button, 0, 0)
    end
end

local function flush(page)
    local tracked = page._paradiseRenderedContainerButtons
    if not tracked then return end
    for button in pairs(tracked) do
        clearInteraction(page, button)
        tracked[button] = nil
    end
end

local function wrapButton(button)
    if button and not button._paradiseContainerPrerender then
        local original = button.prerender
        local inheritedButtonMethod = original == ISButton.prerender
        local wrapped = function(control, ...)
            local page = control.parent and control.parent.parent
            if lootPage(page) and control.parent == page.containerButtonPanel then
                local tracked = page._paradiseRenderedContainerButtons
                if not tracked then
                    tracked = {}
                    page._paradiseRenderedContainerButtons = tracked
                end
                -- Only native-rendered buttons enter this small set. Register
                -- before prerender so a tooltip is tracked even if a mod errors.
                tracked[control] = true
                if control._paradiseContainerHoverReset then
                    control.mouseOver = control:isMouseOver()
                    control._paradiseContainerHoverReset = nil
                end
            end
            if inheritedButtonMethod then return ISButton.prerender(control, ...) end
            return original(control, ...)
        end
        button.prerender = wrapped
        button._paradiseContainerPrerender = wrapped
    end
end

local oldAdd = ISInventoryPage.addContainerButton
function ISInventoryPage:addContainerButton(...)
    local button = oldAdd(self, ...)
    if lootPage(self) then wrapButton(button) end
    return button
end

local oldPanelPrerender = ISInventoryPageContainerButtonPanel.prerender
function ISInventoryPageContainerButtonPanel:prerender(...)
    local page = self.parent
    if not lootPage(page) or page.containerButtonPanel ~= self then
        if self._paradiseContainerRenderAdopted then
            self.javaObject:setRenderClippedChildren(true)
        end
        return oldPanelPrerender(self, ...)
    end
    -- Fail visibly, with ordinary rendering retained if a prior hook or cleanup
    -- callback throws. Native UI catches callback errors before drawing children.
    self.javaObject:setRenderClippedChildren(true)
    oldPanelPrerender(self, ...)
    if not self._paradiseContainerRenderAdopted then
        -- A Lua reload can encounter a page created before this module loaded.
        -- Adopt it once; normal frames never scan the whole container list.
        local tracked = page._paradiseRenderedContainerButtons or {}
        page._paradiseRenderedContainerButtons = tracked
        for _, button in ipairs(page.backpacks) do
            wrapButton(button)
            tracked[button] = true
        end
        self._paradiseContainerRenderAdopted = true
    end
    local tracked = page._paradiseRenderedContainerButtons
    if tracked then
        local top = self:getAbsoluteY()
        local bottom = top + self:getHeight()
        for button in pairs(tracked) do
            -- removeChild does not clear the Lua parent field in this build.
            local clipped = button.parent ~= self or self.children[button.ID] ~= button
            if not clipped then
                local y = button:getAbsoluteY()
                clipped = y + button:getHeight() <= top or y >= bottom
            end
            if clipped then
                clearInteraction(page, button)
                tracked[button] = nil
            end
        end
    end
    self.javaObject:setRenderClippedChildren(false)
end

local oldRefresh = ISInventoryPage.refreshBackpacks
function ISInventoryPage:refreshBackpacks(...)
    -- Clear interactions before pooled buttons acquire different containers.
    if lootPage(self) then flush(self) end
    return oldRefresh(self, ...)
end

local oldCollapse = ISInventoryPage.collapseNow
function ISInventoryPage:collapseNow(...)
    if lootPage(self) then flush(self) end
    return oldCollapse(self, ...)
end

local oldVisible = ISInventoryPage.setVisible
function ISInventoryPage:setVisible(visible, ...)
    if not visible and lootPage(self) then flush(self) end
    return oldVisible(self, visible, ...)
end

local oldRemove = ISInventoryPage.removeFromUIManager
function ISInventoryPage:removeFromUIManager(...)
    if lootPage(self) then flush(self) end
    return oldRemove(self, ...)
end

local oldUpdate = ISInventoryPage.update
function ISInventoryPage:update(...)
    -- Ancestors may hide without calling this page's setVisible. Native updates
    -- still run then, even though render (and tooltip maintenance) does not.
    if lootPage(self) and (self.isCollapsed or not self:isReallyVisible()) then
        flush(self)
    end
    return oldUpdate(self, ...)
end
