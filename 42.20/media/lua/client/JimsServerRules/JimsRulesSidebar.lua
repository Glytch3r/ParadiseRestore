require "ISUI/ISEquippedItem"
require "ISUI/ISButton"

JimsRulesSidebar = JimsRulesSidebar or {}

local SIDEBAR_SPACING = 15
local WAR_MANAGER_SPACING = 10
local TOOLTIP_TEXT = "Server Rules (F2)"
local ICON_ON_PATH = "media/textures/JimsRulesTextIcon.png"
local ICON_OFF_PATH = "media/textures/JimsRulesTextIconOff.png"

local function isManagedButton(sidebar, child)
    return child == sidebar.jimsRulesButton
        or child == sidebar.clientBtn
        or child == sidebar.adminBtn
        or child == sidebar.warManagerBtn
end

local function overlapsSidebarColumn(child, buttonWidth)
    local childX = child:getX()
    local childRight = childX + child:getWidth()
    return childX < buttonWidth and childRight > 0
end

local function getTrailingButtons(sidebar, buttonWidth)
    local trailing = {}
    local rulesButton = sidebar.jimsRulesButton

    for _, child in pairs(sidebar:getChildren()) do
        if not isManagedButton(sidebar, child)
            and child.Type == "ISButton"
            and child:isVisible()
            and child:getHeight() > 0
            and child:getY() >= rulesButton:getY()
            and overlapsSidebarColumn(child, buttonWidth) then
            table.insert(trailing, child)
        end
    end

    table.sort(trailing, function(left, right)
        return left:getY() < right:getY()
    end)

    return trailing
end

local function updateRulesButtonPosition(sidebar)
    local button = sidebar.jimsRulesButton
    local clientButton = sidebar.clientBtn
    if not button or not clientButton then
        return
    end

    local changed = false
    if button:getY() ~= sidebar.jimsRulesButtonY then
        button:setY(sidebar.jimsRulesButtonY)
        changed = true
    end

    local nextY = button:getBottom() + SIDEBAR_SPACING
    if clientButton:getY() ~= nextY then
        clientButton:setY(nextY)
        changed = true
    end
    nextY = clientButton:getBottom() + SIDEBAR_SPACING

    for _, child in ipairs(getTrailingButtons(sidebar, button:getWidth())) do
        if child:getY() < nextY then
            child:setY(nextY)
            changed = true
        end
        nextY = child:getBottom() + SIDEBAR_SPACING
    end

    if sidebar.adminBtn then
        if sidebar.adminBtn:getY() ~= nextY then
            sidebar.adminBtn:setY(nextY)
            changed = true
        end
        nextY = sidebar.adminBtn:getBottom() + SIDEBAR_SPACING
    end

    if sidebar.warManagerBtn and sidebar.adminBtn then
        local warManagerY = sidebar.adminBtn:getY()
        if sidebar.adminBtn:isVisible() then
            warManagerY = sidebar.adminBtn:getBottom() + WAR_MANAGER_SPACING
        end

        if sidebar.warManagerBtn:getY() ~= warManagerY then
            sidebar.warManagerBtn:setY(warManagerY)
            changed = true
        end
    end

    if changed then
        sidebar:shrinkWrap()
    end
end

local function rulesButtonPrerender(button)
    if button:isMouseOver() then
        button:setImage(button.jimsRulesIconOn)
    else
        button:setImage(button.jimsRulesIconOff)
    end

    ISButton.prerender(button)
end

local function onRulesButtonClick(sidebar, button)
    if JimsRulesUI.instance then
        return
    end

    if JimsRulesClient and JimsRulesClient.requestReview then
        JimsRulesClient.requestReview()
    end
end

local function addRulesButton(sidebar)
    if sidebar.jimsRulesButton or not sidebar.chr or sidebar.chr:getPlayerNum() ~= 0 then
        return
    end

    local clientButton = sidebar.clientBtn
    if not clientButton then
        return
    end

    local buttonWidth = clientButton:getWidth()
    local buttonHeight = clientButton:getHeight()
    local buttonY = clientButton:getY()
    local button = ISButton:new(
        0,
        buttonY,
        buttonWidth,
        buttonHeight,
        "",
        sidebar,
        onRulesButtonClick
    )

    button.jimsRulesIconOn = getTexture(ICON_ON_PATH)
    button.jimsRulesIconOff = getTexture(ICON_OFF_PATH)
    button:setImage(button.jimsRulesIconOff)
    button.prerender = rulesButtonPrerender
    button:forceImageSize(buttonHeight, buttonHeight)
    button.internal = "JIMS_SERVER_RULES"
    button:initialise()
    button:instantiate()
    button:setDisplayBackground(false)
    button.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
    button:ignoreWidthChange()
    button:ignoreHeightChange()

    sidebar.jimsRulesButtonY = buttonY
    sidebar.jimsRulesButton = button
    sidebar:addChild(button)
    sidebar:addMouseOverToolTipItem(button, TOOLTIP_TEXT)
    updateRulesButtonPosition(sidebar)
end

if not ISEquippedItem.jimsRulesOriginalInitialise then
    ISEquippedItem.jimsRulesOriginalInitialise = ISEquippedItem.initialise

    function ISEquippedItem:initialise()
        ISEquippedItem.jimsRulesOriginalInitialise(self)
        addRulesButton(self)
    end
end

if not ISEquippedItem.jimsRulesOriginalPrerender then
    ISEquippedItem.jimsRulesOriginalPrerender = ISEquippedItem.prerender

    function ISEquippedItem:prerender()
        ISEquippedItem.jimsRulesOriginalPrerender(self)
        updateRulesButtonPosition(self)
    end
end
