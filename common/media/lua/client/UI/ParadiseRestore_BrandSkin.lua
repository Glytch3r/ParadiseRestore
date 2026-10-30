ParadiseRestore = ParadiseRestore or {}
local Brand = ParadiseRestore.Brand
if not Brand then return end

Brand.skinHook = Brand.skinHook or {}
Brand.skinned = Brand.skinned or {}

local function applyWindowColors(win)
	local th = Brand.get()
	win.backgroundColor = { r = th.c["window.titleBg"].r, g = th.c["window.titleBg"].g, b = th.c["window.titleBg"].b, a = 1 }
	win.borderColor = { r = th.c["window.border"].r, g = th.c["window.border"].g, b = th.c["window.border"].b, a = th.c["window.border"].a }
	win.widgetTextureColor = { r = th.c["window.border"].r, g = th.c["window.border"].g, b = th.c["window.border"].b, a = th.c["window.border"].a }
	if win.panel then
		win.panel.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
		win.panel.borderColor = { r = th.c["window.borderInner"].r, g = th.c["window.borderInner"].g, b = th.c["window.borderInner"].b, a = th.c["window.borderInner"].a }
	end
	win.brandKey = Brand.currentKey()
end

local function applyButtonColors(btn)
	local th = Brand.get()
	btn.backgroundColor = { r = th.c["button.bg"].r, g = th.c["button.bg"].g, b = th.c["button.bg"].b, a = th.c["button.bg"].a }
	btn.backgroundColorMouseOver = { r = th.c["button.bgHover"].r, g = th.c["button.bgHover"].g, b = th.c["button.bgHover"].b, a = 1 }
	btn.backgroundColorPressed = { r = th.c["button.bgPressed"].r, g = th.c["button.bgPressed"].g, b = th.c["button.bgPressed"].b, a = 1 }
	btn.borderColor = { r = th.c["button.border"].r, g = th.c["button.border"].g, b = th.c["button.border"].b, a = 1 }
	btn.textColor = { r = th.c["button.text"].r, g = th.c["button.text"].g, b = th.c["button.text"].b, a = 1 }
	btn.brandKey = Brand.currentKey()
end

function Brand.shadeText(font, alpha)
	local th = Brand.get()
	if font == UIFont.Medium then
		return th.c["accent.primary"]
	end
	if alpha and alpha < 0.6 then
		return th.c["text.secondary"]
	end
	return th.c["text.primary"]
end

function Brand.remapText(obj)
	if obj.brandText then return end
	obj.brandText = true
	local dText = obj.drawText
	local dRight = obj.drawTextRight
	local dCentre = obj.drawTextCentre
	obj.drawText = function(self, text, x, y, r, g, b, a, font)
		if r == 1 and g == 1 and b == 1 then
			local c = Brand.shadeText(font, a)
			return dText(self, text, x, y, c.r, c.g, c.b, a, font)
		end
		return dText(self, text, x, y, r, g, b, a, font)
	end
	obj.drawTextRight = function(self, text, x, y, r, g, b, a, font)
		if r == 1 and g == 1 and b == 1 then
			local c = Brand.shadeText(font, a)
			return dRight(self, text, x, y, c.r, c.g, c.b, a, font)
		end
		return dRight(self, text, x, y, r, g, b, a, font)
	end
	obj.drawTextCentre = function(self, text, x, y, r, g, b, a, font)
		if r == 1 and g == 1 and b == 1 then
			local c = Brand.shadeText(font, a)
			return dCentre(self, text, x, y, c.r, c.g, c.b, a, font)
		end
		return dCentre(self, text, x, y, r, g, b, a, font)
	end
end

function Brand.remapRects(obj)
	if obj.brandRects then return end
	obj.brandRects = true
	local dBorder = obj.drawRectBorder
	local dRect = obj.drawRect
	obj.drawRectBorder = function(self, x, y, w, h, a, r, g, b)
		if r == g and g == b then
			local c = Brand.get().c["divider"]
			return dBorder(self, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dBorder(self, x, y, w, h, a, r, g, b)
	end
	obj.drawRect = function(self, x, y, w, h, a, r, g, b)
		if r == g and g == b then
			local c = Brand.get().c["accent.primary"]
			return dRect(self, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dRect(self, x, y, w, h, a, r, g, b)
	end
end

function Brand.remapTextures(obj)
	if obj.brandTex then return end
	obj.brandTex = true
	local dScaled = obj.drawTextureScaled
	obj.drawTextureScaled = function(self, tex, x, y, w, h, a, r, g, b)
		if r == g and g == b then
			local c = Brand.get().c["frame.portraitTint"]
			return dScaled(self, tex, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dScaled(self, tex, x, y, w, h, a, r, g, b)
	end
end

function Brand.skinTabs(panel)
	if panel.paradiseTabs then return end
	panel.paradiseTabs = true
	local dScaled = panel.drawTextureScaled
	local dRect = panel.drawRect
	local dBorder = panel.drawRectBorder
	local dText = panel.drawTextCentre
	panel.drawTextureScaled = function(self, tex, x, y, w, h, a, r, g, b)
		if tex == ISTabPanel.tabSelected then
			local c = Brand.get().c["tab.activeTint"]
			return dScaled(self, tex, x, y, w, h, a, c.r, c.g, c.b)
		elseif tex == ISTabPanel.tabUnSelected then
			local c = Brand.get().c["tab.idleTint"]
			return dScaled(self, tex, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dScaled(self, tex, x, y, w, h, a, r, g, b)
	end
	panel.drawRect = function(self, x, y, w, h, a, r, g, b)
		if r == 1 and g == 1 and b == 1 then
			local c = Brand.get().c["tab.hover"]
			return dRect(self, x, y, w, h, a * 0.35, c.r, c.g, c.b)
		end
		return dRect(self, x, y, w, h, a, r, g, b)
	end
	panel.drawRectBorder = function(self, x, y, w, h, a, r, g, b)
		if r == 1 and g == 1 and b == 1 then
			local c = Brand.get().c["accent.glow"]
			return dBorder(self, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dBorder(self, x, y, w, h, a, r, g, b)
	end
	panel.drawTextCentre = function(self, text, x, y, r, g, b, a, font)
		if r == 1 and g == 1 and b == 1 then
			local active = self.activeView and self.activeView.name == text
			local c = active and Brand.get().c["tab.textActive"] or Brand.get().c["tab.text"]
			return dText(self, text, x, y, c.r, c.g, c.b, a, font)
		end
		return dText(self, text, x, y, r, g, b, a, font)
	end
	local dPre = panel.prerender
	panel.prerender = function(self)
		dPre(self)
		local c = Brand.get().c["surface.base"]
		dRect(self, 0, 0, self.width, self.height, c.a, c.r, c.g, c.b)
	end
end

function Brand.skinButton(btn)
	if btn.paradiseSkinSkip then return end
	if btn.paradiseSkin then
		applyButtonColors(btn)
		return
	end
	btn.paradiseSkin = true
	applyButtonColors(btn)
	table.insert(Brand.skinned, btn)
	local dText = btn.drawText
	local dBorder = btn.drawRectBorder
	btn.drawText = function(self, text, x, y, r, g, b, a, font)
		if self.paradiseSkin and text == self.title then
			local c
			if not self.enable then
				c = Brand.get().c["button.textDisabled"]
			elseif self.mouseOver then
				c = Brand.get().c["button.blink"]
			else
				c = Brand.get().c["button.text"]
			end
			return dText(self, text, x, y, c.r, c.g, c.b, a, font)
		end
		return dText(self, text, x, y, r, g, b, a, font)
	end
	btn.drawRectBorder = function(self, x, y, w, h, a, r, g, b)
		if self.paradiseSkin then
			local c = self.mouseOver and Brand.get().c["button.borderHover"] or Brand.get().c["button.border"]
			return dBorder(self, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dBorder(self, x, y, w, h, a, r, g, b)
	end
end

function Brand.skinWindow(win)
	if win.paradiseSkin then
		applyWindowColors(win)
		if win.panel then Brand.skinTabs(win.panel) end
		return
	end
	win.paradiseSkin = true
	win.paradiseKind = "window"
	table.insert(Brand.skinned, win)
	local dTex = win.drawTextureScaled
	win.drawTextureScaled = function(self, tex, x, y, w, h, a, r, g, b)
		if tex ~= nil and tex == self.titlebarbkg then return end
		return dTex(self, tex, x, y, w, h, a, r, g, b)
	end
	local dText = win.drawTextCentre
	win.drawTextCentre = function(self, text, x, y, r, g, b, a, font)
		if r == 1 and g == 1 and b == 1 then
			local c = Brand.get().c["window.titleText"]
			return dText(self, text, x, y, c.r, c.g, c.b, a, font)
		end
		return dText(self, text, x, y, r, g, b, a, font)
	end
	local dPre = win.prerender
	win.prerender = function(self)
		dPre(self)
		local tbh = self:titleBarHeight()
		local c = Brand.get().c["window.titleRule"]
		self:drawRect(8, tbh - 3, self:getWidth() - 16, 1, 0.9, c.r, c.g, c.b)
	end
	applyWindowColors(win)
	if win.panel then
		Brand.skinTabs(win.panel)
	end
end

function Brand.skinScreen(scr)
	if scr.paradiseSkin then return end
	scr.paradiseSkin = true
	Brand.remapText(scr)
	Brand.remapRects(scr)
	Brand.remapTextures(scr)
	if scr.hairButton then Brand.skinButton(scr.hairButton) end
	if scr.beardButton then Brand.skinButton(scr.beardButton) end
	if scr.literatureButton then
		Brand.skinButton(scr.literatureButton)
		scr.literatureButton.background = false
	end
end

function Brand.isStressed(pl)
	if not pl then return false end
	local nut = pl:getNutrition()
	if not nut then return false end
	return nut:isIncWeightLot() or nut:isDecWeight()
end

function Brand.decorateWindow(win)
	local th = Brand.get()
	local w = win:getWidth()
	local h = win:getHeight()
	local border = th.c["window.border"]
	win:drawRectBorder(0, 0, w, h, border.a, border.r, border.g, border.b)
	local pl = getSpecificPlayer(win.playerNum or 0)
	if Brand.isStressed(pl) then
		local bl = th.c["text.alert"]
		local pu = Brand.pulse()
		win:drawRectBorder(2, 2, w - 4, h - 4, 0.20 + 0.55 * pu, bl.r, bl.g, bl.b)
	end
end

function Brand.decorateScreen(scr)
	local th = Brand.get()
	local ax = scr.avatarX - 4
	local ay = scr.avatarY - 4
	local aw = scr.avatarWidth + 8
	local ah = scr.avatarHeight + 8
	local fc = th.c["frame.portrait"]
	local tick = 10
	scr:drawRectBorder(ax, ay, aw, ah, 0.9, fc.r, fc.g, fc.b)
	scr:drawRect(ax, ay, tick, 2, 1, fc.r, fc.g, fc.b)
	scr:drawRect(ax, ay, 2, tick, 1, fc.r, fc.g, fc.b)
	scr:drawRect(ax + aw - tick, ay, tick, 2, 1, fc.r, fc.g, fc.b)
	scr:drawRect(ax + aw - 2, ay, 2, tick, 1, fc.r, fc.g, fc.b)
	scr:drawRect(ax, ay + ah - 2, tick, 2, 1, fc.r, fc.g, fc.b)
	scr:drawRect(ax, ay + ah - tick, 2, tick, 1, fc.r, fc.g, fc.b)
	scr:drawRect(ax + aw - tick, ay + ah - 2, tick, 2, 1, fc.r, fc.g, fc.b)
	scr:drawRect(ax + aw - 2, ay + ah - tick, 2, tick, 1, fc.r, fc.g, fc.b)

	local nameX = scr.avatarX + scr.avatarWidth + 4 + 10
	local dv = th.c["divider"]
	local h = scr:getHeight()
	scr:drawRect(nameX - 6, scr.avatarY - 4, 1, math.max(0, h - scr.avatarY - 6), 0.7, dv.r, dv.g, dv.b)

	if scr.char and Brand.isStressed(scr.char) then
		local bl = th.c["text.alert"]
		local pu = Brand.pulse()
		scr:drawRect(nameX, h - 10, math.max(40, scr:getWidth() - nameX - 12), 2, 0.3 + 0.7 * pu, bl.r, bl.g, bl.b)
	end
end

function Brand.repaint()
	for i = 1, #Brand.skinned do
		local obj = Brand.skinned[i]
		if obj.brandKey ~= Brand.currentKey() then
			if obj.paradiseKind == "window" then
				applyWindowColors(obj)
			elseif obj.paradiseSkin then
				applyButtonColors(obj)
			end
		end
	end
	if Brand.notifyWatchers then Brand.notifyWatchers() end
end

function Brand.hookWindow()
	local hooks = Brand.skinHook
	hooks.winCreate = ISCharacterInfoWindow.createChildren
	hooks.winRender = ISCharacterInfoWindow.render
	function ISCharacterInfoWindow:createChildren()
		hooks.winCreate(self)
		Brand.skinWindow(self)
	end
	function ISCharacterInfoWindow:render()
		hooks.winRender(self)
		if self.paradiseSkin then
			Brand.decorateWindow(self)
		end
	end
end

function Brand.hookScreen()
	local hooks = Brand.skinHook
	hooks.scrCreate = ISCharacterScreen.create
	hooks.scrRender = ISCharacterScreen.render
	function ISCharacterScreen:create()
		hooks.scrCreate(self)
		Brand.skinScreen(self)
	end
	function ISCharacterScreen:render()
		hooks.scrRender(self)
		if self.paradiseSkin then
			Brand.decorateScreen(self)
		end
	end
end

function Brand.installSkin()
	if Brand.skinHook.installed then return end
	if not ISCharacterInfoWindow or not ISCharacterScreen or not ISTabPanel then return end
	Brand.skinHook.installed = true
	Brand.hookWindow()
	Brand.hookScreen()
end
Events.OnGameStart.Remove(Brand.installSkin)
Events.OnGameStart.Add(Brand.installSkin)
Brand.installSkin()
