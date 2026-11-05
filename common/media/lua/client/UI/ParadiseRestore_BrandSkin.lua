require "ISUI/ISUIElement"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISComboBox"

ParadiseRestore = ParadiseRestore or {}
local Brand = ParadiseRestore.Brand
if not Brand then return end

Brand.skinHook = Brand.skinHook or {}

-- Cached snapshot of the live theme. Rebuilt by Brand.repaint(); the draw hooks
-- below read only these fields so no theme lookup happens per draw call.
local S = Brand.skinMap or { rev = 0, on = true, raw = false, c = {} }
Brand.skinMap = S

-- Neutral grey bands are what we are allowed to recolour. Anything chromatic is
-- game meaning (health red, accept green) and anything near-black is a shadow.
function Brand.buildSkinMap()
	local B = Brand
	B.ensureSelection()
	local c = B.get().c
	S.rev = S.rev + 1
	S.on = B.vanilla ~= false
	S.c = c
	S.textHi = c["text.primary"]
	S.textMid = c["text.secondary"]
	S.textLo = c["text.muted"]
	S.head = c["accent.primary"]
	S.titleText = c["window.titleText"]
	S.titleBg = c["window.titleBg"]
	S.titleRule = c["window.titleRule"]
	S.border = c["window.border"]
	S.borderInner = c["window.borderInner"]
	S.alert = c["text.alert"]
	S.btnText = c["button.text"]
	S.btnOff = c["button.textDisabled"]
	S.btnBlink = c["button.blink"]
	S.surface = c["surface.base"]
	S.raised = c["surface.raised"]
	S.sel = c["accent.secondary"]
	S.wash = c["accent.glow"]
	S.div = c["divider"]
	S.frame = c["window.border"]
	S.portrait = c["frame.portrait"]
	S.portraitTint = c["frame.portraitTint"]
	S.tabActive = c["tab.activeTint"]
	S.tabIdle = c["tab.idleTint"]
end

Brand.skipType = Brand.skipType or { ISContextMenu = true, ISRadialMenu = true }

function Brand.isSkipped(obj)
	if obj.paradiseSkinSkip then return true end
	local cached = obj.brandSkip
	if cached ~= nil then return cached end
	local skip = Brand.skipType[obj.Type] == true
	local hops = 0
	local cls = obj.SuperType
	while cls and hops < 8 and not skip do
		hops = hops + 1
		skip = Brand.skipType[cls.Type] == true
		cls = cls.SuperType
	end
	obj.brandSkip = skip
	return skip
end

local function textTint(obj, v, font)
	if v >= 0.93 then
		if font == UIFont.Medium then return S.head end
		return S.textHi
	end
	if v >= 0.6 then return S.textMid end
	if obj.isButton then return S.btnOff end
	return S.textLo
end

local function rectTint(v, a)
	if v < 0.25 then return S.surface end
	if v <= 0.6 then return S.sel end
	if v < 0.85 then return S.raised end
	if a <= 0.6 then return S.wash end
	return nil
end

local function borderTint(v)
	if v < 0.25 then return nil end
	if v < 0.75 then return S.div end
	return S.frame
end

Brand.textFns = { "drawText", "drawTextRight", "drawTextCentre", "drawTextUntrimmed", "drawTextStatic", "drawTextCentreStatic", "drawTextRightStatic" }
Brand.fillFns = { "drawRect", "drawRectStatic" }
Brand.borderFns = { "drawRectBorder", "drawRectBorderStatic" }

function Brand.installBaseHooks()
	if Brand.skinHook.baseInstalled then return end
	if not ISUIElement then return end
	Brand.skinHook.baseInstalled = true
	local hooks = Brand.skinHook

	for _, name in ipairs(Brand.textFns) do
		local orig = ISUIElement[name]
		if orig then
			hooks[name] = orig
			ISUIElement[name] = function(self, str, x, y, r, g, b, a, font)
				if S.on and not S.raw and r == g and g == b and r >= 0.3 and not Brand.isSkipped(self) then
					local c = textTint(self, r, font)
					if c then
						return orig(self, str, x, y, c.r, c.g, c.b, a, font)
					end
				end
				return orig(self, str, x, y, r, g, b, a, font)
			end
		end
	end

	for _, name in ipairs(Brand.fillFns) do
		local orig = ISUIElement[name]
		if orig then
			hooks[name] = orig
			ISUIElement[name] = function(self, x, y, w, h, a, r, g, b)
				if S.on and not S.raw and r == g and g == b and not Brand.isSkipped(self) then
					local c = rectTint(r, a)
					if c then
						return orig(self, x, y, w, h, a, c.r, c.g, c.b)
					end
				end
				return orig(self, x, y, w, h, a, r, g, b)
			end
		end
	end

	for _, name in ipairs(Brand.borderFns) do
		local orig = ISUIElement[name]
		if orig then
			hooks[name] = orig
			ISUIElement[name] = function(self, x, y, w, h, a, r, g, b)
				if S.on and not S.raw and r == g and g == b and not Brand.isSkipped(self) then
					local c = borderTint(r)
					if c then
						return orig(self, x, y, w, h, a, c.r, c.g, c.b)
					end
				end
				return orig(self, x, y, w, h, a, r, g, b)
			end
		end
	end
end

-- Draw a colour exactly as given, bypassing the neutral-grey mapping (swatches).
function Brand.rawDraw(fn, ...)
	local was = S.raw
	S.raw = true
	local a, b, c, d = fn(...)
	S.raw = was
	return a, b, c, d
end

local function isNeutral(col)
	return type(col) == "table" and col.r == col.g and col.g == col.b
end

function Brand.chrome(obj, spec)
	if not obj or not spec or obj.paradiseSkinSkip then return end
	if not S.on then
		Brand.unchrome(obj)
		return
	end
	if obj.brandRev == S.rev then return end
	obj.brandOrig = obj.brandOrig or {}
	obj.brandMine = obj.brandMine or {}
	local colors = S.c
	for field, def in pairs(spec) do
		local tok, alpha, force
		local dfn
		if type(def) == "function" then
			dfn = def
		elseif type(def) == "table" then
			tok, alpha, force = def.tok, def.a, def.force
		else
			tok = def
		end
		if dfn then tok = dfn(obj) end
		local base = tok and colors[tok]
		if base then
			local cur = obj[field]
			local mine = obj.brandMine[field]
			local pristine = mine and cur and cur.r == mine.r and cur.g == mine.g and cur.b == mine.b and cur.a == mine.a
			local transparent = type(cur) == "table" and cur.a == 0
			if cur == nil or type(cur) ~= "table" or cur.r == nil or pristine or (not transparent and isNeutral(cur)) or force then
				if type(cur) == "table" and cur.r ~= nil and not obj.brandOrig[field] then
					obj.brandOrig[field] = { r = cur.r, g = cur.g, b = cur.b, a = cur.a }
				end
				local col = { r = base.r, g = base.g, b = base.b, a = alpha or base.a }
				obj[field] = col
				obj.brandMine[field] = col
			end
		end
	end
	obj.brandRev = S.rev
end

function Brand.unchrome(obj)
	if not obj or obj.brandRev == -1 then return end
	local orig = obj.brandOrig
	obj.brandRev = -1
	if not orig then return end
	for field, was in pairs(orig) do
		local cur = obj[field]
		if type(cur) == "table" and cur.r ~= nil then
			cur.r, cur.g, cur.b, cur.a = was.r, was.g, was.b, was.a
			obj.brandMine[field] = nil
		end
	end
end

Brand.windowSpec = {
	backgroundColor = function(win) return win.panel and "window.titleBg" or "window.bg" end,
	borderColor = "window.border",
	widgetTextureColor = "window.border",
}

Brand.panelSpec = {
	backgroundColor = { tok = "window.bg", a = 0 },
	borderColor = "window.borderInner",
}

Brand.chromeSpecs = {
	ISButton = {
		backgroundColor = "button.bg",
		backgroundColorMouseOver = "button.bgHover",
		borderColor = "button.border",
		textColor = "button.text",
	},
	ISComboBox = {
		backgroundColor = "button.bg",
		backgroundColorMouseOver = "button.bgHover",
		borderColor = "window.borderInner",
		textColor = "text.primary",
	},
	ISScrollingListBox = {
		backgroundColor = "surface.sunken",
		borderColor = "window.borderInner",
		textColor = { tok = "text.primary", a = 0.9 },
		selectedTextColor = { tok = "accent.primary", a = 0.9 },
		mouseOverHighlightColor = { tok = "accent.glow", a = 0.12 },
		listHeaderColor = { tok = "divider", a = 0.3 },
		selectionColor = { tok = "accent.secondary", a = 0.35, force = true },
	},
}

function Brand.applyWindowColors(win)
	Brand.chrome(win, Brand.windowSpec)
	if win.panel then
		Brand.chrome(win.panel, Brand.panelSpec)
	end
end

function Brand.applyButtonColors(btn)
	Brand.chrome(btn, Brand.chromeSpecs.ISButton)
end

function Brand.shadeText(font, alpha)
	if font == UIFont.Medium then
		return S.head
	end
	if alpha and alpha < 0.6 then
		return S.textMid
	end
	return S.textHi
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
			local c = S.c["divider"]
			return dBorder(self, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dBorder(self, x, y, w, h, a, r, g, b)
	end
	obj.drawRect = function(self, x, y, w, h, a, r, g, b)
		if r == g and g == b then
			local c = S.c["accent.primary"]
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
			local c = S.portraitTint
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
			local c = S.tabActive
			return dScaled(self, tex, x, y, w, h, a, c.r, c.g, c.b)
		elseif tex == ISTabPanel.tabUnSelected then
			local c = S.tabIdle
			return dScaled(self, tex, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dScaled(self, tex, x, y, w, h, a, r, g, b)
	end
	panel.drawRect = function(self, x, y, w, h, a, r, g, b)
		if r == 1 and g == 1 and b == 1 then
			local c = S.wash
			return dRect(self, x, y, w, h, a * 0.35, c.r, c.g, c.b)
		end
		return dRect(self, x, y, w, h, a, r, g, b)
	end
	panel.drawRectBorder = function(self, x, y, w, h, a, r, g, b)
		if r == 1 and g == 1 and b == 1 then
			local c = S.c["accent.glow"]
			return dBorder(self, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dBorder(self, x, y, w, h, a, r, g, b)
	end
	panel.drawTextCentre = function(self, text, x, y, r, g, b, a, font)
		if r == 1 and g == 1 and b == 1 then
			local active = self.activeView and self.activeView.name == text
			local c = active and S.c["tab.textActive"] or S.c["tab.text"]
			return dText(self, text, x, y, c.r, c.g, c.b, a, font)
		end
		return dText(self, text, x, y, r, g, b, a, font)
	end
	local dPre = panel.prerender
	panel.prerender = function(self)
		dPre(self)
		if not S.on then return end
		local c = S.surface
		dRect(self, 0, 0, self.width, self.height, c.a, c.r, c.g, c.b)
	end
	Brand.chrome(panel, Brand.panelSpec)
end

function Brand.skinButton(btn)
	if btn.paradiseSkinSkip then return end
	if btn.paradiseSkin then
		Brand.applyButtonColors(btn)
		return
	end
	btn.paradiseSkin = true
	Brand.applyButtonColors(btn)
	local dText = btn.drawText
	local dBorder = btn.drawRectBorder
	btn.drawText = function(self, text, x, y, r, g, b, a, font)
		if S.on and self.paradiseSkin and text == self.title then
			local c
			if not self.enable then
				c = S.c["button.textDisabled"]
			elseif self.mouseOver then
				c = S.btnBlink
			else
				c = S.btnText
			end
			return dText(self, text, x, y, c.r, c.g, c.b, a, font)
		end
		return dText(self, text, x, y, r, g, b, a, font)
	end
	btn.drawRectBorder = function(self, x, y, w, h, a, r, g, b)
		if S.on and self.paradiseSkin then
			local c = self.mouseOver and S.c["button.borderHover"] or S.c["button.border"]
			return dBorder(self, x, y, w, h, a, c.r, c.g, c.b)
		end
		return dBorder(self, x, y, w, h, a, r, g, b)
	end
end

function Brand.skinWindow(win)
	if not win.paradiseSkin then
		win.paradiseSkin = true
		local dTex = win.drawTextureScaled
		win.drawTextureScaled = function(self, tex, x, y, w, h, a, r, g, b)
			if S.on and tex ~= nil and tex == self.titlebarbkg then return end
			return dTex(self, tex, x, y, w, h, a, r, g, b)
		end
		local dText = win.drawTextCentre
		win.drawTextCentre = function(self, text, x, y, r, g, b, a, font)
			if S.on and r == 1 and g == 1 and b == 1 then
				local c = S.titleText
				return dText(self, text, x, y, c.r, c.g, c.b, a, font)
			end
			return dText(self, text, x, y, r, g, b, a, font)
		end
		local dPre = win.prerender
		win.prerender = function(self)
			dPre(self)
			if not S.on then return end
			local tbh = self:titleBarHeight()
			if self.drawFrame ~= false and tbh > 0 then
				local bg = S.titleBg
				self:drawRect(0, 0, self:getWidth(), tbh, bg.a, bg.r, bg.g, bg.b)
				local rule = S.titleRule
				self:drawRect(8, tbh - 3, self:getWidth() - 16, 1, 0.9, rule.r, rule.g, rule.b)
			end
		end
	end
	if win.panel then
		Brand.skinTabs(win.panel)
	end
	Brand.applyWindowColors(win)
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
	if not S.on then return end
	local w = win:getWidth()
	local h = win:getHeight()
	local border = S.border
	win:drawRectBorder(0, 0, w, h, border.a, border.r, border.g, border.b)
	local pl = getSpecificPlayer(win.playerNum or 0)
	if Brand.isStressed(pl) then
		local bl = S.alert
		local pu = Brand.pulse()
		win:drawRectBorder(2, 2, w - 4, h - 4, 0.20 + 0.55 * pu, bl.r, bl.g, bl.b)
	end
end

function Brand.decorateScreen(scr)
	if not S.on then return end
	local ax = scr.avatarX - 4
	local ay = scr.avatarY - 4
	local aw = scr.avatarWidth + 8
	local ah = scr.avatarHeight + 8
	local fc = S.portrait
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
	local dv = S.div
	local h = scr:getHeight()
	scr:drawRect(nameX - 6, scr.avatarY - 4, 1, math.max(0, h - scr.avatarY - 6), 0.7, dv.r, dv.g, dv.b)

	if scr.char and Brand.isStressed(scr.char) then
		local bl = S.alert
		local pu = Brand.pulse()
		scr:drawRect(nameX, h - 10, math.max(40, scr:getWidth() - nameX - 12), 2, 0.3 + 0.7 * pu, bl.r, bl.g, bl.b)
	end
end

function Brand.repaint()
	Brand.buildSkinMap()
	if Brand.notifyWatchers then Brand.notifyWatchers() end
end

function Brand.hookChrome(class, key, spec)
	if not class or not class.prerender then return end
	if Brand.skinHook[key] then return end
	local orig = class.prerender
	Brand.skinHook[key] = orig
	class.prerender = function(self)
		if not Brand.isSkipped(self) then
			Brand.chrome(self, spec)
		end
		return orig(self)
	end
end

function Brand.hookWindow()
	local hooks = Brand.skinHook
	if hooks.winCreate then return end
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

function Brand.hookAllWindows()
	if Brand.skinHook.collapsiblePre then return end
	if not ISCollapsableWindow or not ISCollapsableWindow.prerender then return end
	local orig = ISCollapsableWindow.prerender
	Brand.skinHook.collapsiblePre = orig
	ISCollapsableWindow.prerender = function(self)
		if not Brand.isSkipped(self) then
			Brand.skinWindow(self)
		end
		return orig(self)
	end
end

function Brand.hookScreen()
	local hooks = Brand.skinHook
	if hooks.scrCreate then return end
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
	if not Brand.buildSkinMap then return end
	Brand.buildSkinMap()
	Brand.installBaseHooks()
	if not ISCollapsableWindow or not ISCharacterInfoWindow or not ISCharacterScreen or not ISTabPanel then return end
	Brand.hookAllWindows()
	Brand.hookChrome(ISButton, "chromeButton", Brand.chromeSpecs.ISButton)
	Brand.hookChrome(ISComboBox, "chromeCombo", Brand.chromeSpecs.ISComboBox)
	Brand.hookChrome(ISScrollingListBox, "chromeList", Brand.chromeSpecs.ISScrollingListBox)
	Brand.hookWindow()
	Brand.hookScreen()
end
Events.OnGameStart.Remove(Brand.installSkin)
Events.OnGameStart.Add(Brand.installSkin)
Brand.installSkin()
