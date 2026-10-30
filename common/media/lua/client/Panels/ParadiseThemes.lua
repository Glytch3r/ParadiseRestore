require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISComboBox"

ParadiseThemes = ParadiseThemes or {}
local Themes = ParadiseThemes

local Brand = ParadiseRestore and ParadiseRestore.Brand
if not Brand then return end

function Themes.text(panel, text, x, y, tok)
	local r, g, b, a = Brand.col(tok)
	panel:drawText(text, x, y, r, g, b, a, UIFont.Small)
end

function Themes.styleWindow(win)
	Brand.skinWindow(win)
end

function Themes.styleList(list)
	list.backgroundColor = Brand.tbl("surface.sunken")
	list.borderColor = Brand.tbl("window.borderInner")
	list.font = UIFont.Small
end

function Themes.drawSwatch(panel, x, y, w, h, hex)
	local r, g, b, a = Brand.hexColor(hex, 1)
	panel:drawRect(x, y, w, h, 1, r, g, b)
	local br, bgc, bb = Brand.col("divider")
	panel:drawRectBorder(x, y, w, h, 1, br, bgc, bb)
end

function Themes.addContextMenu(plNum, context, worldObjs, test)
	if test then return end
	local pl = getSpecificPlayer(plNum)
	if not pl then return end
	local root = context:addOptionOnTop("Paradise Themes")
	root.iconTexture = getTexture("media/ui/Paradise/Brand/ContextIcon.png")
	local menu = ISContextMenu:getNew(context)
	context:addSubMenu(root, menu)
	local choose = menu:addOption("Choose Interface Theme", nil, function()
		if ParadiseThemes and ParadiseThemes.OpenPanel then ParadiseThemes.OpenPanel() end
	end)
	choose.iconTexture = getTexture("media/ui/Paradise/Brand/Player.png")
	if ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then
		local editor = menu:addOption("Theme Editor", nil, function()
			if ParadiseThemes and ParadiseThemes.Admin and ParadiseThemes.Admin.OpenPanel then
				ParadiseThemes.Admin.OpenPanel()
			end
		end)
		editor.iconTexture = getTexture("media/ui/Paradise/Brand/ThemeEditor.png")
	end
	if ParadiseRestore and ParadiseRestore.ContextMenuManager then
		ParadiseRestore.ContextMenuManager.registerParent("world", "Paradise Themes", context, root, menu)
	end
end
Events.OnFillWorldObjectContextMenu.Remove(Themes.addContextMenu)
Events.OnFillWorldObjectContextMenu.Add(Themes.addContextMenu)

Themes.Panel = ISCollapsableWindow:derive("ParadiseThemes.Panel")

Themes.TOKENS = {
	{ tok = "accent.primary", label = "Accent" },
	{ tok = "accent.secondary", label = "Accent dim" },
	{ tok = "accent.glow", label = "Accent glow" },
	{ tok = "window.bg", label = "Window" },
	{ tok = "window.border", label = "Window border" },
	{ tok = "window.titleBg", label = "Title bar" },
	{ tok = "window.titleText", label = "Title text" },
	{ tok = "surface.base", label = "Surface" },
	{ tok = "surface.raised", label = "Surface raised" },
	{ tok = "surface.sunken", label = "Surface sunken" },
	{ tok = "text.primary", label = "Text" },
	{ tok = "text.secondary", label = "Text dim" },
	{ tok = "text.muted", label = "Text muted" },
	{ tok = "text.alert", label = "Alert" },
	{ tok = "text.success", label = "Success" },
	{ tok = "button.bg", label = "Button" },
	{ tok = "button.text", label = "Button text" },
	{ tok = "button.border", label = "Button border" },
	{ tok = "tab.bg", label = "Tab" },
	{ tok = "tab.activeTint", label = "Tab active" },
	{ tok = "tab.idleTint", label = "Tab idle" },
	{ tok = "divider", label = "Divider" },
	{ tok = "watermark", label = "Watermark" },
	{ tok = "frame.portrait", label = "Portrait" },
}

function Themes.Panel:createChildren()
	ISCollapsableWindow.createChildren(self)
	local th = self:titleBarHeight()
	local fontHgt = getTextManager():getFontHeight(UIFont.Small)
	local btnHgt = fontHgt + 8

	self.themeCombo = ISComboBox:new(10, th + 34, 320, fontHgt + 8, self, Themes.Panel.onThemeChanged)
	self.themeCombo:initialise()
	self.themeCombo:instantiate()
	self:addChild(self.themeCombo)

	local btnY = self.height - btnHgt - 12
	self.list = ISScrollingListBox:new(10, th + 92, self.width - 20, btnY - th - 112)
	self.list:initialise()
	self.list:instantiate()
	self.list.itemheight = fontHgt + 10
	self.list.selected = 0
	self.list.joypadParent = self
	self.list.doDrawItem = Themes.Panel.drawTokenRow
	Themes.styleList(self.list)
	for i = 1, #Themes.TOKENS do
		self.list:addItem(Themes.TOKENS[i].label, Themes.TOKENS[i])
	end
	self:addChild(self.list)

	self.saveButton = ISButton:new(10, btnY, 120, btnHgt, "Save", self, Themes.Panel.onSave)
	self.defaultButton = ISButton:new(136, btnY, 120, btnHgt, "Server Default", self, Themes.Panel.onDefault)
	self.closeButton = ISButton:new(self.width - 130, btnY, 120, btnHgt, "Close", self, Themes.Panel.onClose)
	for _, btn in ipairs({ self.saveButton, self.defaultButton, self.closeButton }) do
		btn:initialise()
		btn:instantiate()
		Brand.skinButton(btn)
		self:addChild(btn)
	end

	self.icon = getTexture("media/ui/Paradise/Brand/Theme.png")
	Themes.styleWindow(self)
	self:refresh()
end

function Themes.Panel:refresh()
	if not self.list then return end
	Brand.clearPreview()
	local live = Brand.getThemeList()
	self.defs = live
	self.themeCombo:clear()
	for i = 1, #live do
		local def = live[i]
		local tag = def.mode == "preset" and ("Preset palette: " .. tostring(def.preset)) or "Custom colors"
		self.themeCombo:addOptionWithData(def.label .. "  (" .. def.key .. ")", def.key, tag)
	end
	local key = Brand.currentKey()
	self:selectKey(key or (live[1] and live[1].key), false)
end

function Themes.Panel:selectKey(key, doPreview)
	local def
	for i = 1, #self.defs do
		if self.defs[i].key == key then
			def = self.defs[i]
			break
		end
	end
	if not def then return end
	self.selectedDef = def
	if self.themeCombo then self.themeCombo:setSelectedData(def.key) end
	if doPreview then
		Brand.preview(def.key)
		Themes.styleList(self.list)
		self.status = "Previewing " .. def.label .. " - press Save to keep it."
	else
		Themes.styleList(self.list)
		self.status = def.mode == "preset" and ("Preset palette: " .. tostring(def.preset)) or "Custom colors from the server list."
	end
end

function Themes.Panel:onThemeChanged(combo)
	self:selectKey(combo:getSelectedData(), true)
end

function Themes.Panel:onSave()
	if not self.selectedDef then return end
	Brand.setSelection(self.selectedDef.key)
	Themes.styleList(self.list)
	self.status = "Saved: " .. self.selectedDef.label
end

function Themes.Panel:onDefault()
	Brand.setSelection(nil)
	local first = self.defs and self.defs[1]
	if first then
		self.selectedDef = first
		if self.themeCombo then self.themeCombo:setSelectedData(first.key) end
		self.status = "Using the server default: " .. first.label
	else
		self.status = "Using the server default."
	end
	Themes.styleList(self.list)
end

function Themes.Panel:drawTokenRow(y, item, alt)
	local token = item.item
	local c = Brand.get().c[token.tok]
	local boxH = self.itemheight - 6
	local tp = Brand.get().c["text.primary"]
	local tm = Brand.get().c["text.muted"]
	if c then
		self:drawRect(8, y + 3, 26, boxH, 1, c.r, c.g, c.b)
		local border = Brand.get().c["window.border"]
		self:drawRectBorder(8, y + 3, 26, boxH, 0.9, border.r, border.g, border.b)
		self:drawText(token.label, 42, y + 4, tp.r, tp.g, tp.b, 1, UIFont.Small)
		local hex = string.format("%02X%02X%02X", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
		if c.a < 0.999 then hex = hex .. string.format("  %d%%", math.floor(c.a * 100 + 0.5)) end
		self:drawText(hex, self.width - 100, y + 4, tm.r, tm.g, tm.b, 1, UIFont.Small)
	else
		self:drawText(token.label, 42, y + 4, tm.r, tm.g, tm.b, 0.6, UIFont.Small)
		self:drawText("--", self.width - 100, y + 4, tm.r, tm.g, tm.b, 0.6, UIFont.Small)
	end
	return y + self.itemheight
end

function Themes.Panel:render()
	ISCollapsableWindow.render(self)
	local th = self:titleBarHeight()
	Themes.text(self, "Pick a theme. The client previews it live; Save keeps it.", 34, th + 10, "text.muted")
	self:drawTextureScaled(self.icon, 10, th + 9, 18, 18, 1, 1, 1, 1)
	local def = self.selectedDef
	if def then
		local tag = def.mode == "preset" and ("Preset palette: " .. tostring(def.preset)) or "Custom colors"
		Themes.text(self, def.label .. "  -  " .. tag, 10, th + 66, "accent.primary")
	end
	if self.status then
		Themes.text(self, self.status, 10, self.height - 52, "text.primary")
	end
end

function Themes.Panel:onClose()
	self:close()
end

function Themes.Panel:close()
	Brand.clearPreview()
	Themes.ClosePanel()
end

function Themes.Panel:new(x, y, width, height)
	local panel = ISCollapsableWindow:new(x, y, width, height)
	setmetatable(panel, self)
	self.__index = self
	panel.title = "Interface Theme"
	panel.resizable = false
	return panel
end
