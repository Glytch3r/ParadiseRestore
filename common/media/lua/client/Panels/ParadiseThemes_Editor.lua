require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "ISUI/ISComboBox"
require "ISUI/ISButton"

ParadiseThemes = ParadiseThemes or {}
local Themes = ParadiseThemes
Themes.Admin = Themes.Admin or {}
local Admin = Themes.Admin

local Brand = ParadiseRestore and ParadiseRestore.Brand
if not Brand then return end

local trim = function(s)
	return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

local isHex = function(s)
	return type(s) == "string" and string.match(s, "^%x%x%x%x%x%x$") ~= nil
end

local function copyDef(def)
	local copy = {
		key = def.key,
		label = def.label,
		align = def.align,
		mode = def.mode,
		preset = def.preset,
		accent = def.accent,
		bg = def.bg,
		text = def.text,
	}
	if copy.mode == "preset" and not copy.accent then
		local preset = Brand.presets[copy.preset]
		if preset then
			copy.accent = string.sub(preset.tokens["accent.primary"], 1, 6)
			copy.bg = string.sub(preset.tokens["surface.base"], 1, 6)
			copy.text = string.sub(preset.tokens["text.primary"], 1, 6)
		end
	end
	return copy
end

Admin.Panel = ISCollapsableWindow:derive("ParadiseThemes.Admin.Panel")

function Admin.Panel:createChildren()
	ISCollapsableWindow.createChildren(self)
	local th = self:titleBarHeight()
	local fontHgt = getTextManager():getFontHeight(UIFont.Small)
	local btnHgt = fontHgt + 6
	local listBottom = self.height - btnHgt - 44

	self.list = ISScrollingListBox:new(10, th + 26, 240, listBottom - th - 26)
	self.list:initialise()
	self.list:instantiate()
	self.list.itemheight = fontHgt + 8
	self.list.selected = 0
	self.list.joypadParent = self
	self.list.onmousedown = Admin.Panel.onListDown
	self.list.target = self
	Themes.styleList(self.list)
	self:addChild(self.list)

	self.addButton = ISButton:new(10, listBottom + 6, 74, btnHgt, "Add", self, Admin.Panel.onAdd)
	self.dupButton = ISButton:new(88, listBottom + 6, 74, btnHgt, "Duplicate", self, Admin.Panel.onDuplicate)
	self.delButton = ISButton:new(166, listBottom + 6, 74, btnHgt, "Remove", self, Admin.Panel.onRemove)
	for _, btn in ipairs({ self.addButton, self.dupButton, self.delButton }) do
		btn:initialise()
		btn:instantiate()
		Brand.skinButton(btn)
		self:addChild(btn)
	end

	local x0 = 266
	local y0 = th + 36
	self.keyEntry = self:addEntry("Key", x0, y0, 110)
	self.labelEntry = self:addEntry("Label", x0 + 124, y0, 250)

	self.alignCombo = self:addCombo("Align", x0, y0 + 46, 110)
	for _, v in ipairs({ "Heaven", "Hell", "Between" }) do self.alignCombo:addOption(v) end
	self.alignValues = { "heaven", "hell", "between" }

	self.sourceCombo = self:addCombo("Source", x0 + 124, y0 + 46, 130)
	self.sourceCombo:addOption("Preset palette")
	self.sourceCombo:addOption("Custom colors")

	self.presetCombo = self:addCombo("Preset", x0 + 268, y0 + 46, 120)
	self.presetKeys = {}
	for _, key in ipairs(Brand.presetOrder) do
		local preset = Brand.presets[key]
		self.presetCombo:addOption(preset and preset.label or key)
		self.presetKeys[#self.presetKeys + 1] = key
	end

	self.accentEntry = self:addEntry("Accent (hex)", x0, y0 + 96, 92)
	self.bgEntry = self:addEntry("Background (hex)", x0 + 124, y0 + 96, 92)
	self.textEntry = self:addEntry("Text (hex)", x0 + 248, y0 + 96, 92)

	local by = self.height - btnHgt - 12
	self.applyButton = ISButton:new(x0, by, 100, btnHgt, "Apply Draft", self, Admin.Panel.onApplyDraft)
	self.previewButton = ISButton:new(x0 + 106, by, 90, btnHgt, "Preview", self, Admin.Panel.onPreview)
	self.stopButton = ISButton:new(x0 + 202, by, 100, btnHgt, "Stop Preview", self, Admin.Panel.onStopPreview)
	self.revertButton = ISButton:new(x0 + 308, by, 80, btnHgt, "Revert", self, Admin.Panel.onRevert)
	self.publishButton = ISButton:new(x0 + 394, by, 90, btnHgt, "Publish", self, Admin.Panel.onPublish)
	for _, btn in ipairs({ self.applyButton, self.previewButton, self.stopButton, self.revertButton, self.publishButton }) do
		btn:initialise()
		btn:instantiate()
		Brand.skinButton(btn)
		self:addChild(btn)
	end

	self:refresh()
	self.icon = getTexture("media/ui/Paradise/Brand/ThemeEditor.png")
	Themes.styleWindow(self)
end

function Admin.Panel:addEntry(label, x, y, width)
	local fontHgt = getTextManager():getFontHeight(UIFont.Small)
	local entry = ISTextEntryBox:new("", x, y + 16, width, fontHgt + 6)
	entry:initialise()
	entry:instantiate()
	self:addChild(entry)
	self.labels = self.labels or {}
	table.insert(self.labels, { text = label, x = x, y = y })
	return entry
end

function Admin.Panel:addCombo(label, x, y, width)
	local fontHgt = getTextManager():getFontHeight(UIFont.Small)
	local combo = ISComboBox:new(x, y + 16, width, fontHgt + 6, self, nil)
	combo:initialise()
	combo:instantiate()
	self:addChild(combo)
	self.labels = self.labels or {}
	table.insert(self.labels, { text = label, x = x, y = y })
	return combo
end

function Admin.Panel:refresh()
	Brand.clearPreview()
	self.draft = {}
	local live = Brand.getThemeList()
	for i = 1, #live do
		self.draft[i] = copyDef(live[i])
	end
	if #self.draft == 0 then
		self.draft[1] = copyDef(Brand.parseThemeList(Brand.DEFAULT_LIST)[1])
	end
	self.selectedIndex = 1
	self:refreshList()
	self:loadFields(self.draft[1])
	self.status = "Editing the server theme list. Publish to push changes to players."
end

function Admin.Panel:refreshList()
	self.list:clear()
	for i = 1, #self.draft do
		local def = self.draft[i]
		local tag = def.mode == "preset" and ("@" .. tostring(def.preset)) or "custom"
		self.list:addItem(def.label .. "  [" .. def.key .. " | " .. tag .. "]", i)
	end
	if self.selectedIndex and self.draft[self.selectedIndex] then
		self.list.selected = self.selectedIndex
	end
end

function Admin.Panel:loadFields(def)
	if not def then return end
	self.keyEntry:setText(def.key or "")
	self.labelEntry:setText(def.label or "")
	self.accentEntry:setText(def.accent or "")
	self.bgEntry:setText(def.bg or "")
	self.textEntry:setText(def.text or "")
	for i = 1, #self.alignValues do
		if self.alignValues[i] == def.align then self.alignCombo.selected = i end
	end
	self.sourceCombo.selected = def.mode == "preset" and 1 or 2
	for i = 1, #self.presetKeys do
		if self.presetKeys[i] == def.preset then self.presetCombo.selected = i end
	end
end

function Admin.Panel:readFields()
	local align = self.alignValues[self.alignCombo.selected] or "between"
	local mode = self.sourceCombo.selected == 2 and "custom" or "preset"
	return {
		key = trim(self.keyEntry:getText()),
		label = trim(self.labelEntry:getText()),
		align = align,
		mode = mode,
		preset = self.presetKeys[self.presetCombo.selected] or Brand.presetOrder[1],
		accent = string.upper(trim(self.accentEntry:getText())),
		bg = string.upper(trim(self.bgEntry:getText())),
		text = string.upper(trim(self.textEntry:getText())),
	}
end

function Admin.Panel:applyDraft()
	if not self.selectedIndex or not self.draft[self.selectedIndex] then
		self.status = "Select a theme first."
		return false
	end
	local originalKey = self.draft[self.selectedIndex].key
	local def = self:readFields()
	local ok, err = Brand.validate(def, self.draft, originalKey)
	if not ok then
		self.status = tostring(err)
		return false
	end
	self.draft[self.selectedIndex] = def
	self:refreshList()
	self:loadFields(def)
	self.status = "Draft updated."
	return true
end

function Admin.Panel.onListDown(panel, index)
	panel.selectedIndex = index
	panel:loadFields(panel.draft[index])
end

function Admin.Panel:onAdd()
	local n = #self.draft + 1
	local key = "theme" .. tostring(n)
	while true do
		local taken = false
		for i = 1, #self.draft do
			if self.draft[i].key == key then taken = true end
		end
		if not taken then break end
		n = n + 1
		key = "theme" .. tostring(n)
	end
	self.draft[#self.draft + 1] = {
		key = key,
		label = "New Theme",
		align = "between",
		mode = "custom",
		accent = "C9A94F",
		bg = "17110A",
		text = "F0E4C6",
	}
	self.selectedIndex = #self.draft
	self:refreshList()
	self:loadFields(self.draft[self.selectedIndex])
	self.status = "Theme added to the draft."
end

function Admin.Panel:onDuplicate()
	if not self.selectedIndex or not self.draft[self.selectedIndex] then return end
	local source = self.draft[self.selectedIndex]
	local base = source.key .. "_copy"
	local key = base
	local n = 2
	while true do
		local taken = false
		for i = 1, #self.draft do
			if self.draft[i].key == key then taken = true end
		end
		if not taken then break end
		key = base .. tostring(n)
		n = n + 1
	end
	local def = copyDef(source)
	def.key = key
	def.label = source.label .. " Copy"
	self.draft[#self.draft + 1] = def
	self.selectedIndex = #self.draft
	self:refreshList()
	self:loadFields(def)
	self.status = "Theme duplicated."
end

function Admin.Panel:onRemove()
	if #self.draft <= 1 then
		self.status = "At least one theme must remain."
		return
	end
	if not self.selectedIndex then return end
	table.remove(self.draft, self.selectedIndex)
	self.selectedIndex = math.max(1, math.min(self.selectedIndex, #self.draft))
	self:refreshList()
	self:loadFields(self.draft[self.selectedIndex])
	self.status = "Theme removed from the draft."
end

function Admin.Panel:onPreview()
	local def = self:readFields()
	if not Brand.previewTheme(def) then
		self.status = "Preview needs a preset or three hex colors."
		return
	end
	self.status = "Previewing the draft on your client only."
end

function Admin.Panel:onStopPreview()
	Brand.clearPreview()
	self.status = "Preview stopped."
end

function Admin.Panel:onRevert()
	self:refresh()
end

function Admin.Panel:onPublish()
	for i = 1, #self.draft do
		for j = i + 1, #self.draft do
			if self.draft[i].key == self.draft[j].key then
				self.status = "Duplicate key: " .. tostring(self.draft[i].key)
				return
			end
		end
	end
	for i = 1, #self.draft do
		local ok, err = Brand.validate(self.draft[i], nil, nil)
		if not ok then
			self.status = "Entry " .. tostring(i) .. ": " .. tostring(err)
			return
		end
	end
	local raw = Brand.serialize(self.draft)
	local ok, err = Brand.writeSandbox(raw)
	if ok then
		self.status = "Published. Players see the new list after the sandbox sync."
	else
		self.status = "Publish failed: " .. tostring(err)
	end
end

function Admin.Panel:render()
	ISCollapsableWindow.render(self)
	local th = self:titleBarHeight()
	Themes.text(self, "Server theme list (ParadiseZ.Themes)", 34, th + 8, "text.muted")
	self:drawTextureScaled(self.icon, 10, th + 7, 18, 18, 1, 1, 1, 1)
	Themes.text(self, "Format: key:Label:align:@preset  or  key:Label:align:accent:bg:text", 266, th + 8, "text.muted")
	for i = 1, #(self.labels or {}) do
		local item = self.labels[i]
		Themes.text(self, item.text, item.x, item.y, "text.secondary")
	end
	Themes.text(self, "Preset mode ignores the three hex fields.", 266, th + 196, "text.muted")
	local accent = trim(self.accentEntry:getText())
	local bg = trim(self.bgEntry:getText())
	local text = trim(self.textEntry:getText())
	if isHex(accent) then Themes.drawSwatch(self, 362, self.accentEntry:getY() + 2, 14, 14, accent) end
	if isHex(bg) then Themes.drawSwatch(self, 486, self.bgEntry:getY() + 2, 14, 14, bg) end
	if isHex(text) then Themes.drawSwatch(self, 610, self.textEntry:getY() + 2, 14, 14, text) end
	if self.status then
		Themes.text(self, self.status, 266, th + 220, "text.primary")
	end
end

function Admin.Panel:close()
	Admin.ClosePanel()
end

function Admin.Panel:new(x, y, width, height)
	local panel = ISCollapsableWindow:new(x, y, width, height)
	setmetatable(panel, self)
	self.__index = self
	panel.title = "Theme Editor"
	panel.resizable = false
	return panel
end
