require "ISUI/ISPanelJoypad"
require "ISUI/ISRichTextPanel"
require "ISUI/ISTickBox"
require "ISUI/ISButton"

JimsRulesUI = ISPanelJoypad:derive("JimsRulesUI")

local COLOR = {
    overlay = { r = 0.015, g = 0.015, b = 0.018, a = 0.84 },
    card = { r = 0.055, g = 0.052, b = 0.052, a = 0.98 },
    cardInset = { r = 0.025, g = 0.024, b = 0.024, a = 0.78 },
    border = { r = 0.28, g = 0.27, b = 0.25, a = 1.00 },
    accent = { r = 0.72, g = 0.16, b = 0.13, a = 1.00 },
    accentSoft = { r = 0.45, g = 0.11, b = 0.09, a = 0.42 },
    title = { r = 0.92, g = 0.90, b = 0.84, a = 1.00 },
    text = { r = 0.72, g = 0.71, b = 0.67, a = 1.00 },
    muted = { r = 0.47, g = 0.46, b = 0.43, a = 1.00 },
    error = { r = 0.92, g = 0.30, b = 0.24, a = 1.00 }
}

local function escapeRichText(value)
    local escaped = tostring(value or "")
    escaped = escaped:gsub("<", "&lt;")
    escaped = escaped:gsub(">", "&gt;")
    return escaped
end

local function formatRules(rawRules)
    local output = {
        "<TEXT> <RGB:0.76,0.75,0.71>"
    }
    local firstContentLine = true
    local pendingBlankLine = false
    local previousLineType = nil

    for rawLine in (tostring(rawRules or "") .. "\n"):gmatch("(.-)\n") do
        local line = rawLine:gsub("\r$", "")
        local subHeading = line:match("^%s*###%s+(.+)$")
        local ruleHeading = line:match("^%s*##%s+(.+)$")
        local sectionHeading = line:match("^%s*#%s+(.+)$")
        local bullet = line:match("^%s*[-*]%s+(.+)$")
        local isBlank = line:match("^%s*$") ~= nil

        if isBlank then
            pendingBlankLine = not firstContentLine
        else
            local currentLineType = "body"
            if sectionHeading then
                currentLineType = "section"
            elseif ruleHeading then
                currentLineType = "rule"
            elseif subHeading then
                currentLineType = "subheading"
            elseif bullet then
                currentLineType = "bullet"
            end

            if not firstContentLine then
                local needsGap = false

                if currentLineType == "section" then
                    needsGap = true
                elseif currentLineType == "rule" and previousLineType ~= "section" then
                    needsGap = true
                elseif currentLineType == "subheading" then
                    needsGap = true
                elseif currentLineType == "body"
                    and pendingBlankLine
                    and previousLineType ~= "section"
                    and previousLineType ~= "rule"
                    and previousLineType ~= "subheading" then
                    needsGap = true
                end

                if needsGap then
                    table.insert(output, "<LINE>")
                end
            end

            if subHeading then
                table.insert(output, "<TEXT>")
                table.insert(output, "<SIZE:medium>")
                table.insert(output, "<RGB:0.67,0.62,0.52>")
                table.insert(output, escapeRichText(subHeading))
                table.insert(output, "<LINE>")
                table.insert(output, "<SIZE:small>")
                table.insert(output, "<RGB:0.76,0.75,0.71>")
            elseif ruleHeading then
                table.insert(output, "<H2>")
                table.insert(output, "<RGB:0.90,0.88,0.82>")
                table.insert(output, escapeRichText(ruleHeading))
                table.insert(output, "<LINE>")
                table.insert(output, "<TEXT>")
                table.insert(output, "<RGB:0.76,0.75,0.71>")
            elseif sectionHeading then
                table.insert(output, "<H2>")
                table.insert(output, "<RGB:0.82,0.24,0.19>")
                table.insert(output, escapeRichText(string.upper(sectionHeading)))
                table.insert(output, "<LINE>")
                table.insert(output, "<TEXT>")
                table.insert(output, "<RGB:0.76,0.75,0.71>")
            elseif bullet then
                table.insert(output, "<INDENT:18>")
                table.insert(output, "- " .. escapeRichText(bullet))
                table.insert(output, "<LINE>")
                table.insert(output, "<INDENT:0>")
            else
                table.insert(output, escapeRichText(line))
                table.insert(output, "<LINE>")
            end

            firstContentLine = false
            pendingBlankLine = false
            previousLineType = currentLineType
        end
    end

    return table.concat(output, " ")
end

function JimsRulesUI:initialise()
    ISPanelJoypad.initialise(self)
end

function JimsRulesUI:calculateCardLayout()
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()

    self.cardWidth = math.floor(math.min(860, math.max(620, screenWidth * 0.68)))
    self.cardHeight = math.floor(math.min(760, math.max(500, screenHeight * 0.84)))
    self.cardX = math.floor((screenWidth - self.cardWidth) / 2)
    self.cardY = math.floor((screenHeight - self.cardHeight) / 2)
    self.headerHeight = 124
    self.footerHeight = 104
    self.padding = 30
end

function JimsRulesUI:createChildren()
    ISPanelJoypad.createChildren(self)
    self:calculateCardLayout()

    local rulesX = self.cardX + self.padding
    local rulesY = self.cardY + self.headerHeight
    local rulesWidth = self.cardWidth - (self.padding * 2)
    local rulesHeight = self.cardHeight - self.headerHeight - self.footerHeight

    self.rulesPanel = ISRichTextPanel:new(rulesX, rulesY, rulesWidth, rulesHeight)
    self.rulesPanel:initialise()
    self.rulesPanel:instantiate()
    self.rulesPanel.background = true
    self.rulesPanel.backgroundColor = {
        r = COLOR.cardInset.r,
        g = COLOR.cardInset.g,
        b = COLOR.cardInset.b,
        a = COLOR.cardInset.a
    }
    self.rulesPanel.borderColor = { r = 0.17, g = 0.16, b = 0.15, a = 1.0 }
    self.rulesPanel.autosetheight = false
    self.rulesPanel.clip = true
    self.rulesPanel:setMargins(22, 18, 28, 18)
    self.rulesPanel:setText(formatRules(self.rawRules))
    self.rulesPanel:paginate()
    self.rulesPanel:addScrollBars()
    self:addChild(self.rulesPanel)

    local footerY = self.cardY + self.cardHeight - self.footerHeight
    local tickHeight = math.max(24, getTextManager():getFontHeight(UIFont.Small) + 4)
    self.agreement = ISTickBox:new(
        self.cardX + self.padding,
        footerY + 47,
        self.cardWidth - 300,
        tickHeight,
        "agreement",
        self,
        JimsRulesUI.onAgreementChanged
    )
    self.agreement:initialise()
    self.agreement:instantiate()
    self.agreement:addOption("I have read and agree to the server rules.")
    self.agreement.choicesColor = {
        r = COLOR.text.r,
        g = COLOR.text.g,
        b = COLOR.text.b,
        a = COLOR.text.a
    }
    self:addChild(self.agreement)

    self.acceptButton = ISButton:new(
        self.cardX + self.cardWidth - self.padding - 220,
        footerY + 43,
        220,
        38,
        "ACCEPT AND ENTER",
        self,
        JimsRulesUI.onAccept
    )
    self.acceptButton:initialise()
    self.acceptButton:instantiate()
    self.acceptButton:setBackgroundRGBA(0.36, 0.07, 0.055, 1.0)
    self.acceptButton:setBackgroundColorMouseOverRGBA(0.66, 0.14, 0.10, 1.0)
    self.acceptButton:setBorderRGBA(COLOR.accent.r, COLOR.accent.g, COLOR.accent.b, 1.0)
    self.acceptButton:setEnable(false)
    self:addChild(self.acceptButton)

    if self.reviewOnly then
        self.agreement:setVisible(false)
        self.acceptButton:setTitle("CLOSE")
        self.acceptButton:setEnable(true)
    end

    self.joypadIndex = 1
    self.joypadIndexY = 1
    self:insertNewLineOfButtons(self.agreement)
    self:insertNewLineOfButtons(self.acceptButton)
end

function JimsRulesUI:applyLayout()
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    self:setWidth(screenWidth)
    self:setHeight(screenHeight)
    self:calculateCardLayout()

    local rulesX = self.cardX + self.padding
    local rulesY = self.cardY + self.headerHeight
    local rulesWidth = self.cardWidth - (self.padding * 2)
    local rulesHeight = self.cardHeight - self.headerHeight - self.footerHeight

    self.rulesPanel:setX(rulesX)
    self.rulesPanel:setY(rulesY)
    self.rulesPanel:setWidth(rulesWidth)
    self.rulesPanel:setHeight(rulesHeight)
    self.rulesPanel.textDirty = true
    self.rulesPanel:updateScrollbars()

    local footerY = self.cardY + self.cardHeight - self.footerHeight
    self.agreement:setX(self.cardX + self.padding)
    self.agreement:setY(footerY + 47)
    self.agreement:setWidth(self.cardWidth - 300)

    self.acceptButton:setX(self.cardX + self.cardWidth - self.padding - 220)
    self.acceptButton:setY(footerY + 43)
end

function JimsRulesUI:onAgreementChanged(index, selected)
    if not self.awaitingServer then
        self.acceptButton:setEnable(selected == true)
    end
end

function JimsRulesUI:onAccept(button)
    if self.reviewOnly then
        self:destroy()
        return
    end

    if self.awaitingServer or not self.agreement:isSelected(1) then
        return
    end

    self.awaitingServer = true
    self.errorMessage = nil
    self.acceptButton:setTitle("SAVING...")
    self.acceptButton:setEnable(false)
    sendClientCommand(
        self.player,
        JimsServerRules.MODULE,
        JimsServerRules.COMMAND_ACCEPT,
        {}
    )
end

function JimsRulesUI:showError(message)
    self.awaitingServer = false
    self.errorMessage = tostring(message or "An unknown server error occurred.")
    self.acceptButton:setTitle("TRY AGAIN")
    self.acceptButton:setEnable(self.agreement:isSelected(1))
end

function JimsRulesUI:prerender()
    self:drawRect(
        0,
        0,
        self.width,
        self.height,
        COLOR.overlay.a,
        COLOR.overlay.r,
        COLOR.overlay.g,
        COLOR.overlay.b
    )

    self:drawRect(
        self.cardX,
        self.cardY,
        self.cardWidth,
        self.cardHeight,
        COLOR.card.a,
        COLOR.card.r,
        COLOR.card.g,
        COLOR.card.b
    )
    self:drawRectBorder(
        self.cardX,
        self.cardY,
        self.cardWidth,
        self.cardHeight,
        COLOR.border.a,
        COLOR.border.r,
        COLOR.border.g,
        COLOR.border.b
    )
    self:drawRect(
        self.cardX,
        self.cardY,
        self.cardWidth,
        4,
        COLOR.accent.a,
        COLOR.accent.r,
        COLOR.accent.g,
        COLOR.accent.b
    )
    self:drawRect(
        self.cardX + self.padding + 104,
        self.cardY + 70,
        72,
        2,
        COLOR.accent.a,
        COLOR.accent.r,
        COLOR.accent.g,
        COLOR.accent.b
    )

    local portraitX = self.cardX + self.padding
    local portraitY = self.cardY + 16
    local portraitSize = 82

    self:drawRect(
        portraitX - 2,
        portraitY - 2,
        portraitSize + 4,
        portraitSize + 4,
        1.0,
        COLOR.accentSoft.r,
        COLOR.accentSoft.g,
        COLOR.accentSoft.b
    )
    self:drawRectBorder(
        portraitX - 2,
        portraitY - 2,
        portraitSize + 4,
        portraitSize + 4,
        1.0,
        COLOR.accent.r,
        COLOR.accent.g,
        COLOR.accent.b
    )

    if self.headerPortrait then
        self:drawTextureScaled(
            self.headerPortrait,
            portraitX,
            portraitY,
            portraitSize,
            portraitSize,
            1.0,
            1.0,
            1.0,
            1.0
        )
    end

    self:drawText(
        self.title,
        self.cardX + self.padding + 104,
        self.cardY + 24,
        COLOR.title.r,
        COLOR.title.g,
        COLOR.title.b,
        COLOR.title.a,
        UIFont.Large
    )
    self:drawText(
        self.subtitle,
        self.cardX + self.padding + 104,
        self.cardY + 78,
        COLOR.muted.r,
        COLOR.muted.g,
        COLOR.muted.b,
        COLOR.muted.a,
        UIFont.Small
    )
    self:drawTextRight(
        "SERVER REGULATIONS",
        self.cardX + self.cardWidth - self.padding,
        self.cardY + 31,
        COLOR.accent.r,
        COLOR.accent.g,
        COLOR.accent.b,
        1.0,
        UIFont.Small
    )

    local footerY = self.cardY + self.cardHeight - self.footerHeight
    self:drawRect(
        self.cardX + self.padding,
        footerY + 18,
        self.cardWidth - (self.padding * 2),
        1,
        0.75,
        COLOR.border.r,
        COLOR.border.g,
        COLOR.border.b
    )

    if self.errorMessage then
        self:drawText(
            self.errorMessage,
            self.cardX + self.padding,
            footerY + 24,
            COLOR.error.r,
            COLOR.error.g,
            COLOR.error.b,
            COLOR.error.a,
            UIFont.Small
        )
    else
        local footerMessage = "Scroll to review the complete document, then confirm your agreement."
        if self.reviewOnly then
            footerMessage = "Review the current server rules."
        end

        self:drawText(
            footerMessage,
            self.cardX + self.padding,
            footerY + 24,
            COLOR.muted.r,
            COLOR.muted.g,
            COLOR.muted.b,
            COLOR.muted.a,
            UIFont.Small
        )
    end
end

function JimsRulesUI:update()
    ISPanelJoypad.update(self)

    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    if self.width ~= screenWidth or self.height ~= screenHeight then
        self:applyLayout()
    end

    self:bringToTop()
end

function JimsRulesUI:onMouseDown(x, y)
    return true
end

function JimsRulesUI:onMouseWheel(delta)
    return true
end

function JimsRulesUI:onConsumeKeyPress(key)
    return key == Keyboard.KEY_ESCAPE
end

function JimsRulesUI:onConsumeKeyRepeat(key)
    return key == Keyboard.KEY_ESCAPE
end

function JimsRulesUI:onConsumeKeyRelease(key)
    return key == Keyboard.KEY_ESCAPE
end

function JimsRulesUI:onKeyPress(key)
    return key == Keyboard.KEY_ESCAPE
end

function JimsRulesUI:onKeyRepeat(key)
    return key == Keyboard.KEY_ESCAPE
end

function JimsRulesUI:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then
        if self.reviewOnly then
            self:destroy()
        end
        return true
    end

    return false
end

function JimsRulesUI:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:restoreJoypadFocus(joypadData)
end

function JimsRulesUI:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
end

function JimsRulesUI:onJoypadDown(button, joypadData)
    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end

function JimsRulesUI:destroy()
    if self.playerNumber and JoypadState.players[self.playerNumber + 1] then
        setJoypadFocus(self.playerNumber, self.previousJoypadFocus)
    end

    self:setVisible(false)
    self:removeFromUIManager()

    if JimsRulesUI.instance == self then
        JimsRulesUI.instance = nil
    end
end

function JimsRulesUI.show(playerNumber, player, title, subtitle, rawRules, reviewOnly)
    if JimsRulesUI.instance then
        JimsRulesUI.instance:destroy()
    end

    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    local ui = JimsRulesUI:new(
        0,
        0,
        screenWidth,
        screenHeight,
        playerNumber,
        player,
        title,
        subtitle,
        rawRules,
        reviewOnly
    )
    ui:initialise()
    ui:addToUIManager()
    ui:setAlwaysOnTop(true)
    ui:setWantKeyEvents(true)
    ui:setForceCursorVisible(true)

    if JoypadState.players[playerNumber + 1] then
        ui.previousJoypadFocus = JoypadState.players[playerNumber + 1].focus
        setJoypadFocus(playerNumber, ui)
    end

    JimsRulesUI.instance = ui
    return ui
end

function JimsRulesUI:new(x, y, width, height, playerNumber, player, title, subtitle, rawRules, reviewOnly)
    local object = ISPanelJoypad.new(self, x, y, width, height)
    object.background = false
    object.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    object.anchorLeft = true
    object.anchorRight = true
    object.anchorTop = true
    object.anchorBottom = true
    object.alwaysOnTop = true
    object.wantKeyEvents = true
    object.wantMouseEvents = true
    object.forceCursorVisible = true
    object.playerNumber = playerNumber
    object.player = player
    object.title = tostring(title or "JIM'S PARADISE")
    object.subtitle = tostring(subtitle or "Read the rules below before entering the world.")
    object.rawRules = tostring(rawRules or "")
    object.reviewOnly = reviewOnly == true
    object.headerPortrait = getTexture("media/textures/JimsRulesPortrait.png")
    object.awaitingServer = false
    object.errorMessage = nil
    return object
end
