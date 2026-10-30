ParadiseAdminHub = ParadiseAdminHub or {}
ParadiseAdminHub.hook = ParadiseAdminHub.hook or {}

local SIDEBAR_SPACING = 15
local TOOLTIP_TEXT = "Paradise Admin Hub"
local ICON_PATH = "media/ui/Paradise/Logo.png"

local function overlapsSidebarColumn(child, buttonWidth)
    local childX = child:getX()
    return childX < buttonWidth and childX + child:getWidth() > 0
end

local function getLastButtonBottom(sidebar, buttonWidth, button)
    local bottom = 0
    for _, child in pairs(sidebar:getChildren()) do
        if child ~= button
            and child ~= sidebar.paradiseAdminHubButton
            and child.Type == "ISButton"
            and child:isVisible()
            and child:getHeight() > 0
            and overlapsSidebarColumn(child, buttonWidth) then
            bottom = math.max(bottom, child:getBottom())
        end
    end
    return bottom
end

local function isHubVisible()
    return ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
end

local function updateHubButtonPosition(sidebar)
    local button = sidebar.paradiseAdminHubButton
    if not button then return end

    local visible = isHubVisible()
    if button:isVisible() ~= visible then
        button:setVisible(visible)
        sidebar:shrinkWrap()
    end
    if not visible then return end

    local buttonY = getLastButtonBottom(sidebar, button:getWidth(), button) + SIDEBAR_SPACING
    if button:getY() ~= buttonY then
        button:setY(buttonY)
        sidebar:shrinkWrap()
    end
end

local function onHubButtonClick(sidebar, button)
    if ParadiseAdminHub.TogglePanel then
        ParadiseAdminHub.TogglePanel()
    end
end

local function addHubButton(sidebar)
    if sidebar.paradiseAdminHubButton or not sidebar.chr or sidebar.chr:getPlayerNum() ~= 0 then
        return
    end

    local clientButton = sidebar.clientBtn
    if not clientButton then
        return
    end

    local buttonWidth = clientButton:getWidth()
    local buttonHeight = clientButton:getHeight()
    local button = ISButton:new(0, clientButton:getY(), buttonWidth, buttonHeight, "", sidebar, onHubButtonClick)
    button.paradiseHubIcon = getTexture(ICON_PATH)
    button:setImage(button.paradiseHubIcon)
    button:forceImageSize(buttonHeight, buttonHeight)
    button.internal = "PARADISE_ADMIN_HUB"
    button.sidebarAnchored = true
    button:initialise()
    button:instantiate()
    button:setDisplayBackground(false)
    button.borderColor = { r = 1, g = 1, b = 0.55, a = 0.35 }
    button:ignoreWidthChange()
    button:ignoreHeightChange()

    sidebar.paradiseAdminHubButton = button
    sidebar:addChild(button)
    sidebar:addMouseOverToolTipItem(button, TOOLTIP_TEXT)
    updateHubButtonPosition(sidebar)
end

if not ParadiseAdminHub.hook.ISEquippedItemInitialise then
    ParadiseAdminHub.hook.ISEquippedItemInitialise = ISEquippedItem.initialise

    function ISEquippedItem:initialise()
        ParadiseAdminHub.hook.ISEquippedItemInitialise(self)
        addHubButton(self)
    end
end

if not ParadiseAdminHub.hook.ISEquippedItemPrerender then
    ParadiseAdminHub.hook.ISEquippedItemPrerender = ISEquippedItem.prerender

    function ISEquippedItem:prerender()
        ParadiseAdminHub.hook.ISEquippedItemPrerender(self)
        updateHubButtonPosition(self)
    end
end
