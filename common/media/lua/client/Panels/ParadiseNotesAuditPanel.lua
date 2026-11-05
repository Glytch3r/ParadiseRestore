require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"

ParadiseNotesAuditPanel = ParadiseNotesAuditPanel or {}
local Notes = ParadiseNotesAuditPanel

Notes.module = "ParadiseNotesAudit"

function Notes.send(command, args)
	if not sendClientCommand then return end
	sendClientCommand(Notes.module, command, args or {})
end

function Notes.canOpen()
	if not isClient or not isClient() then return false end
	return ParadiseRestore and ParadiseRestore.isAdm and ParadiseRestore.isAdm(getPlayer()) or false
end

function Notes.getSize()
	local width = math.min(760, getCore():getScreenWidth() - 40)
	local height = math.min(480, getCore():getScreenHeight() - 40)
	return width, height
end

Notes.Panel = ISCollapsableWindow:derive("ParadiseNotesAuditPanel.Panel")

function Notes.Panel:createChildren()
	ISCollapsableWindow.createChildren(self)
	local th = self:titleBarHeight()

	self.list = ISScrollingListBox:new(10, th + 95, self.width - 20, self.height - th - 185)
	self.list:initialise()
	self.list:instantiate()
	self:addChild(self.list)

	self.filterEntry = ISTextEntryBox:new("", 10, th + 60, 300, 26)
	self.filterEntry:initialise()
	self:addChild(self.filterEntry)

	self.planEntry = ISTextEntryBox:new("", 320, th + 60, self.width - 330, 26)
	self.planEntry:initialise()
	self:addChild(self.planEntry)

	local labels = {
		"Refresh / export",
		"Previous",
		"Next",
		"Plan selected",
		"Plan ALL in scope",
		"Apply approved",
		"Rollback approved",
		"Close",
	}
	for i, label in ipairs(labels) do
		local button = ISButton:new(10 + ((i - 1) % 4) * 185, self.height - 80 + math.floor((i - 1) / 4) * 32, 180, 28, label, self, Notes.Panel.click)
		button.internal = i
		button:initialise()
		button:instantiate()
		self:addChild(button)
	end

	self.page = 1
	self.message = "Server inventory: loaded observed floors + all globals. NOT the entire world."
end

function Notes.Panel:prerender()
	ISCollapsableWindow.prerender(self)
	if self.isCollapsed then return end
	local th = self:titleBarHeight()
	self:drawText("Dry-run cleanup requires separate owner approval", 10, th + 10, 1, 1, 1, 1, UIFont.Small)
	self:drawText(ParadiseZ.fitText(self.message, self.width - 20, UIFont.Small), 10, th + 32, 1, 0.9, 0.3, 1, UIFont.Small)
	self:drawText("Filter: text, type or tile", 10, th + 46, 0.7, 0.8, 0.9, 1, UIFont.Small)
	self:drawText("Saved cleanup plan ID", 320, th + 46, 0.7, 0.8, 0.9, 1, UIFont.Small)
end

function Notes.Panel:click(button)
	local n = button.internal
	if n == 8 then
		self:close()
		return
	end
	if n == 1 then
		Notes.send("export", { page = self.page, contains = self.filterEntry:getText() })
	elseif n == 2 or n == 3 then
		self.page = math.max(1, self.page + (n == 2 and -1 or 1))
		Notes.send("list", { page = self.page, contains = self.filterEntry:getText() })
	elseif n == 4 then
		local row = self.list.items[self.list.selected]
		if row then Notes.send("plan", { id = row.item.id }) end
	elseif n == 5 then
		Notes.send("plan", { all = true, contains = self.filterEntry:getText() })
	elseif n == 6 or n == 7 then
		local id = self.planEntry:getText()
		if id ~= "" then
			Notes.send(n == 6 and "apply" or "rollback", { plan_id = id })
		else
			self.message = "Create a dry-run plan first, or paste its saved ID."
		end
	end
end

function Notes.Panel:close()
	Notes.ClosePanel()
end

function Notes.Panel:new(x, y, width, height)
	local panel = ISCollapsableWindow:new(x, y, width, height)
	setmetatable(panel, self)
	self.__index = self
	panel.title = "Notes Administration"
	panel.resizable = false
	return panel
end

function Notes.onServerCommand(module, command, args)
	if module ~= Notes.module or command ~= "result" then return end
	if args.ok == false and getPlayer() and HaloTextHelper then
		HaloTextHelper.addBadText(getPlayer(), tostring(args.message):sub(1, 180))
	end

	local panel = Notes.instance
	if not panel then
		print("[ParadiseNotesAudit] " .. tostring(args.message))
		return
	end

	panel.message = args.message or "Response received"
	if args.plan_id then
		panel.plan = args.plan_id
		panel.planEntry:setText(args.plan_id)
	end

	if args.rows then
		panel.list:clear()
		local rows = {}
		for _, row in pairs(args.rows) do rows[#rows + 1] = row end
		table.sort(rows, function(a, b) return a.id < b.id end)
		for _, row in ipairs(rows) do
			local s = row.original
			local txt = s.text or s.ParadiseDevNote or s.FloorNote or ""
			panel.list:addItem(row.id .. " | " .. tostring(txt):gsub("[\r\n]", " "):sub(1, 85), row)
		end
	end
end
Events.OnServerCommand.Remove(Notes.onServerCommand)
Events.OnServerCommand.Add(Notes.onServerCommand)

function Notes.onOpen(panel)
	if not panel then return end
	panel.page = 1
	Notes.send("list", { page = 1 })
end
