
JimsRulesSidebar = JimsRulesSidebar or {}

local SIDEBAR_SPACING = 15
local TOOLTIP_TEXT = "Server Rules (F2)"
local ICON_ON_PATH = "media/textures/JimsRulesTextIcon.png"
local ICON_OFF_PATH = "media/textures/JimsRulesTextIconOff.png"

local function overlapsSidebarColumn(child, buttonWidth)
    local childX = child:getX()
    local childRight = childX + child:getWidth()
    return childX < buttonWidth and childRight > 0
end

local function getLastButtonBottom(sidebar, buttonWidth)
    local bottom = 0
    local rulesButton = sidebar.jimsRulesButton

    for _, child in pairs(sidebar:getChildren()) do
        if child ~= rulesButton
            and child.Type == "ISButton"
            and child:isVisible()
            and child:getHeight() > 0
            and overlapsSidebarColumn(child, buttonWidth) then
            bottom = math.max(bottom, child:getBottom())
        end
    end

    return bottom
end

local function updateRulesButtonPosition(sidebar)
    local button = sidebar.jimsRulesButton
    local clientButton = sidebar.clientBtn
    if not button or not clientButton then
        return
    end

    local buttonY = getLastButtonBottom(sidebar, button:getWidth()) + SIDEBAR_SPACING
    if button:getY() ~= buttonY then
        button:setY(buttonY)
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
