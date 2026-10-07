require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "ISUI/ISTickBox"
require "ISUI/ISScrollingListBox"
require "ISUI/ISContextMenu"
require "ISUI/ISWorldObjectContextMenu"
require "ISUI/ISInventoryPaneContextMenu"

ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.ContextMenuManager = ParadiseRestore.ContextMenuManager or {}

function ParadiseRestore.ContextMenuManager.slug(str)
    str = string.lower(tostring(str or ""))
    str = string.gsub(str, ":.*$", "")
    str = string.gsub(str, "[^%w]+", "_")
    str = string.gsub(str, "^_+", "")
    str = string.gsub(str, "_+$", "")
    return str ~= "" and str or "option"
end

function ParadiseRestore.ContextMenuManager.makeKey(kind, parts)
    local result = {ParadiseRestore.ContextMenuManager.slug(kind)}
    for _, part in ipairs(parts or {}) do
        result[#result + 1] = ParadiseRestore.ContextMenuManager.slug(part)
    end
    return table.concat(result, "/")
end

function ParadiseRestore.ContextMenuManager.newProfile()
    return {favoritesEnabled = false, hidden = {}, favorites = {}}
end

ParadiseRestore.ContextMenuManager.profile = ParadiseRestore.ContextMenuManager.profile or ParadiseRestore.ContextMenuManager.newProfile()
ParadiseRestore.ContextMenuManager.registry = ParadiseRestore.ContextMenuManager.registry or {world = {}, inventory = {}}
ParadiseRestore.ContextMenuManager.instance = ParadiseRestore.ContextMenuManager.instance or nil
-- Catalogue entries and preferences survive menu openings. Actions do not:
-- native context menus, submenus and option tables are pooled and reused.
ParadiseRestore.ContextMenuManager.openingSerial = ParadiseRestore.ContextMenuManager.openingSerial or 0

function ParadiseRestore.ContextMenuManager.beginOpening(context)
    local manager = ParadiseRestore.ContextMenuManager
    manager.openingSerial = manager.openingSerial + 1
    context.paradiseManagerOpening = {serial = manager.openingSerial, context = context,
        bindings = {world = {}, inventory = {}}, finished = {}}
    return context.paradiseManagerOpening
end

function ParadiseRestore.ContextMenuManager.getOpening(context)
    return context.paradiseManagerOpening or ParadiseRestore.ContextMenuManager.beginOpening(context)
end

function ParadiseRestore.ContextMenuManager.snapshotOption(menu, option)
    local snapshot = {name = option.name, target = option.target, onSelect = option.onSelect,
        iconTexture = option.iconTexture, checkMark = option.checkMark,
        notAvailable = option.notAvailable, toolTip = option.toolTip}
    for index = 1, 10 do snapshot['param' .. index] = option['param' .. index] end
    local subMenu = ParadiseRestore.ContextMenuManager.getSubMenu(menu, option)
    if subMenu then
        snapshot.children = {}
        for _, child in ipairs(subMenu.options or {}) do
            snapshot.children[#snapshot.children + 1] = ParadiseRestore.ContextMenuManager.snapshotOption(subMenu, child)
        end
    end
    return snapshot
end

function ParadiseRestore.ContextMenuManager.registerEntry(entry, menu, option, context, targetLabel)
    local manager = ParadiseRestore.ContextMenuManager
    -- Never put mutable native option/menu objects into the persistent catalogue.
    manager.registry[entry.kind][entry.key] = entry
    -- An opening only needs action snapshots for selected favorites. Discovering
    -- the catalogue while Favorites are disabled should not copy entire menus.
    if not manager.profile.favoritesEnabled or not manager.profile.favorites[entry.key] then return end
    local opening = manager.getOpening(context)
    local variants = opening.bindings[entry.kind][entry.key] or {}
    opening.bindings[entry.kind][entry.key] = variants
    variants[#variants + 1] = {entry = entry, opening = opening, context = context,
        targetLabel = targetLabel, snapshot = manager.snapshotOption(menu, option)}
end

function ParadiseRestore.ContextMenuManager.getProfileFilename()
    local pl = getPlayer and getPlayer() or nil
    local user = pl and pl.getUsername and pl:getUsername() or "local"
    user = string.gsub(tostring(user), "[^%w_%-]", "_")
    return "ParadiseRestore_ContextMenu_" .. user .. ".ini"
end

function ParadiseRestore.ContextMenuManager.getBackupFilename()
    return string.gsub(ParadiseRestore.ContextMenuManager.getProfileFilename(), "%.ini$", "_backup.ini")
end

function ParadiseRestore.ContextMenuManager.serializeProfile(profile)
    profile = profile or ParadiseRestore.ContextMenuManager.newProfile()
    local lines = {"favoritesEnabled=" .. tostring(profile.favoritesEnabled == true)}
    local function append(group, values)
        local keys = {}
        for key, enabled in pairs(values or {}) do
            if enabled then keys[#keys + 1] = key end
        end
        table.sort(keys)
        for _, key in ipairs(keys) do lines[#lines + 1] = group .. "=" .. key end
    end
    append("hidden", profile.hidden)
    append("favorite", profile.favorites)
    return table.concat(lines, "\n") .. "\n"
end

function ParadiseRestore.ContextMenuManager.deserializeProfile(str)
    local profile = ParadiseRestore.ContextMenuManager.newProfile()
    for line in string.gmatch(tostring(str or ""), "[^\r\n]+") do
        local name, value = string.match(line, "^([^=]+)=(.*)$")
        if name == "favoritesEnabled" then
            profile.favoritesEnabled = value == "true"
        elseif name == "hidden" and value ~= "" then
            profile.hidden[value] = true
        elseif name == "favorite" and value ~= "" then
            profile.favorites[value] = true
        end
    end
    return profile
end

function ParadiseRestore.ContextMenuManager.load()
    if not getFileReader then return end
    local reader = getFileReader(ParadiseRestore.ContextMenuManager.getProfileFilename(), true)
    if not reader then return end
    local lines = {}
    local line = reader:readLine()
    while line do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    ParadiseRestore.ContextMenuManager.profile = ParadiseRestore.ContextMenuManager.deserializeProfile(table.concat(lines, "\n"))
end

function ParadiseRestore.ContextMenuManager.save()
    if not getFileWriter then return end
    local writer = getFileWriter(ParadiseRestore.ContextMenuManager.getProfileFilename(), true, false)
    if not writer then return end
    writer:write(ParadiseRestore.ContextMenuManager.serializeProfile(ParadiseRestore.ContextMenuManager.profile))
    writer:close()
end

function ParadiseRestore.ContextMenuManager.exportBackup()
    if not getFileWriter then return end
    local writer = getFileWriter(ParadiseRestore.ContextMenuManager.getBackupFilename(), true, false)
    if not writer then return end
    writer:write(ParadiseRestore.ContextMenuManager.serializeProfile(ParadiseRestore.ContextMenuManager.profile))
    writer:close()
end

function ParadiseRestore.ContextMenuManager.importBackup()
    if not getFileReader then return false end
    local reader = getFileReader(ParadiseRestore.ContextMenuManager.getBackupFilename(), true)
    if not reader then return false end
    local lines = {}
    local line = reader:readLine()
    while line do
        lines[#lines + 1] = line
        line = reader:readLine()
    end
    reader:close()
    ParadiseRestore.ContextMenuManager.profile = ParadiseRestore.ContextMenuManager.deserializeProfile(table.concat(lines, "\n"))
    ParadiseRestore.ContextMenuManager.save()
    return true
end

function ParadiseRestore.ContextMenuManager.isShiftHeld()
    return isKeyDown and Keyboard and
        (isKeyDown(Keyboard.KEY_LSHIFT) or isKeyDown(Keyboard.KEY_RSHIFT)) or false
end

function ParadiseRestore.ContextMenuManager.isVisible(key, revealHidden)
    return revealHidden == true or ParadiseRestore.ContextMenuManager.profile.hidden[key] ~= true
end

function ParadiseRestore.ContextMenuManager.setVisible(key, visible)
    if visible then
        ParadiseRestore.ContextMenuManager.profile.hidden[key] = nil
    else
        ParadiseRestore.ContextMenuManager.profile.hidden[key] = true
    end
    ParadiseRestore.ContextMenuManager.save()
end

function ParadiseRestore.ContextMenuManager.setFavorite(key, favorite)
    ParadiseRestore.ContextMenuManager.profile.favorites[key] = favorite and true or nil
    ParadiseRestore.ContextMenuManager.save()
end

function ParadiseRestore.ContextMenuManager.removeOption(menu, option)
    if not menu or not option then return end
    for index, current in ipairs(menu.options or {}) do
        if current == option then
            table.remove(menu.options, index)
            menu.numOptions = math.max(1, (menu.numOptions or 1) - 1)
            for newIndex, remaining in ipairs(menu.options) do remaining.id = newIndex end
            if menu.calcHeight then menu:calcHeight() end
            if menu.calcWidth and menu.setWidth then menu:setWidth(menu:calcWidth()) end
            return
        end
    end
end

function ParadiseRestore.ContextMenuManager.getSubMenu(menu, option)
    if not menu or not option or not option.subOption or not menu.getSubMenu then return nil end
    return menu:getSubMenu(option.subOption)
end

function ParadiseRestore.ContextMenuManager.scan(kind, menu, parts, depth, properties, visibleDepth, rootContext, targetLabel)
    if not menu then return end
    depth = depth or 0
    visibleDepth = visibleDepth or depth
    local revealHidden = ParadiseRestore.ContextMenuManager.isShiftHeld()
    local options = {}
    for _, option in ipairs(menu.options or {}) do options[#options + 1] = option end
    for _, option in ipairs(options) do
        local isDynamic = properties and properties.dynamicLevels and properties.dynamicLevels[depth] == true
        local optionParts = {}
        for _, part in ipairs(parts or {}) do optionParts[#optionParts + 1] = part end
        if not isDynamic then optionParts[#optionParts + 1] = option.paradiseManagerKey or option.name end
        local key = ParadiseRestore.ContextMenuManager.makeKey(kind, optionParts)
        local subMenu = ParadiseRestore.ContextMenuManager.getSubMenu(menu, option)
        local childTarget = targetLabel
        if isDynamic then
            childTarget = targetLabel and (targetLabel .. " / " .. tostring(option.name)) or tostring(option.name)
        end
        if subMenu then
            ParadiseRestore.ContextMenuManager.scan(
                kind,
                subMenu,
                optionParts,
                depth + 1,
                properties,
                isDynamic and visibleDepth or visibleDepth + 1,
                rootContext,
                childTarget
            )
        end
        if not isDynamic then
            ParadiseRestore.ContextMenuManager.registerEntry({
                key = key, kind = kind,
                label = tostring(option.paradiseManagerLabel or option.name),
                depth = visibleDepth,
                parentKey = ParadiseRestore.ContextMenuManager.makeKey(kind, parts),
                hasChildren = subMenu ~= nil,
            }, menu, option, rootContext, targetLabel)
        end
        if not isDynamic and not ParadiseRestore.ContextMenuManager.isVisible(key, revealHidden) then
            ParadiseRestore.ContextMenuManager.removeOption(menu, option)
        end
    end
end

function ParadiseRestore.ContextMenuManager.registerParent(kind, key, parentMenu, rootOption, subMenu, properties)
    if kind ~= "world" and kind ~= "inventory" then return nil end
    if not parentMenu or not rootOption then return nil end
    local label = tostring(rootOption.name or key)
    local rootKey = ParadiseRestore.ContextMenuManager.makeKey(kind, {key or label})
    local bindings = ParadiseRestore.ContextMenuManager.getOpening(parentMenu).bindings[kind]
    local previous = {}
    for registeredKey in pairs(bindings) do
        if registeredKey == rootKey or string.sub(registeredKey, 1, #rootKey + 1) == rootKey .. "/" then
            previous[#previous + 1] = registeredKey
        end
    end
    for _, registeredKey in ipairs(previous) do bindings[registeredKey] = nil end
    if subMenu then
        ParadiseRestore.ContextMenuManager.scan(
            kind,
            subMenu,
            {key or label},
            1,
            properties,
            nil,
            parentMenu
        )
    end
    ParadiseRestore.ContextMenuManager.registerEntry({
        key = rootKey, kind = kind, label = label, depth = 0,
        parentKey = kind, hasChildren = subMenu ~= nil,
    }, parentMenu, rootOption, parentMenu)
    if not ParadiseRestore.ContextMenuManager.isVisible(rootKey, ParadiseRestore.ContextMenuManager.isShiftHeld()) then
        ParadiseRestore.ContextMenuManager.removeOption(parentMenu, rootOption)
    end
    return rootKey
end

function ParadiseRestore.ContextMenuManager.cloneSnapshot(sourceOption, targetMenu, binding)
    local callback = sourceOption.onSelect
    local guarded
    if callback then
        guarded = function(...)
            if not ParadiseRestore.ContextMenuManager.isCurrentEntry(binding, binding.context) then return end
            return callback(...)
        end
    end
    local option = targetMenu:addOption(
        sourceOption.name,
        sourceOption.target,
        guarded,
        sourceOption.param1,
        sourceOption.param2,
        sourceOption.param3,
        sourceOption.param4,
        sourceOption.param5,
        sourceOption.param6,
        sourceOption.param7,
        sourceOption.param8,
        sourceOption.param9,
        sourceOption.param10
    )
    option.iconTexture = sourceOption.iconTexture
    option.checkMark = sourceOption.checkMark
    option.notAvailable = sourceOption.notAvailable
    option.toolTip = sourceOption.toolTip
    if sourceOption.children then
        local targetSubMenu = ISContextMenu:getNew(targetMenu)
        targetMenu:addSubMenu(option, targetSubMenu)
        for _, child in ipairs(sourceOption.children) do
            ParadiseRestore.ContextMenuManager.cloneSnapshot(child, targetSubMenu, binding)
        end
    end
    return option
end

function ParadiseRestore.ContextMenuManager.hasFavoriteAncestor(entry)
    local parentKey = entry.parentKey
    while parentKey and parentKey ~= entry.kind do
        if ParadiseRestore.ContextMenuManager.profile.favorites[parentKey] then return true end
        parentKey = string.match(parentKey, "^(.*)/[^/]+$")
    end
    return false
end

function ParadiseRestore.ContextMenuManager.isCurrentEntry(entry, context)
    return entry ~= nil and context ~= nil and entry.context == context and
        entry.opening == context.paradiseManagerOpening
end

function ParadiseRestore.ContextMenuManager.addFavorites(kind, context)
    local profile = ParadiseRestore.ContextMenuManager.profile
    if not profile.favoritesEnabled then return end
    local opening = context.paradiseManagerOpening
    if not opening then return end
    local entries = ParadiseRestore.ContextMenuManager.getEntries(kind, true)
    local selected = {}
    for _, entry in ipairs(entries) do
        if not ParadiseRestore.ContextMenuManager.hasFavoriteAncestor(entry) then
            local variants = opening.bindings[kind][entry.key] or {}
            for _, binding in ipairs(variants) do
                if ParadiseRestore.ContextMenuManager.isCurrentEntry(binding, context) then
                    selected[#selected + 1] = {binding = binding, multiple = #variants > 1}
                end
            end
        end
    end
    if #selected == 0 then return end
    local root = context:addOption("Favorites")
    root.iconTexture = getTexture("media/ui/ContextManager/favorite_on.png")
    local menu = ISContextMenu:getNew(context)
    context:addSubMenu(root, menu)
    for _, selectedEntry in ipairs(selected) do
        local binding = selectedEntry.binding
        local option = ParadiseRestore.ContextMenuManager.cloneSnapshot(binding.snapshot, menu, binding)
        if selectedEntry.multiple and binding.targetLabel then
            option.name = binding.targetLabel .. ": " .. tostring(option.name)
        end
    end
    if menu.calcWidth and menu.setWidth then menu:setWidth(menu:calcWidth()) end
end

function ParadiseRestore.ContextMenuManager.getEntries(kind, favoritesOnly)
    local entries = {}
    for _, entry in pairs(ParadiseRestore.ContextMenuManager.registry[kind] or {}) do
        if not favoritesOnly or ParadiseRestore.ContextMenuManager.profile.favorites[entry.key] then
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(left, right)
        if left.key == right.key then return left.label < right.label end
        return left.key < right.key
    end)
    return entries
end

ParadiseRestore.ContextMenuManager.Panel = ISCollapsableWindow:derive("ParadiseRestore.ContextMenuManager.Panel")

function ParadiseRestore.ContextMenuManager.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(panel, self)
    self.__index = self
    panel.kind = "world"
    panel.favoritesOnly = false
    panel.moveWithMouse = true
    panel:setTitle("Paradise Context Menu Organizer")
    panel.backgroundColor = {r = 0.06, g = 0.07, b = 0.065, a = 0.98}
    panel.borderColor = {r = 0.65, g = 0.62, b = 0.52, a = 0.9}
    return panel
end

function ParadiseRestore.ContextMenuManager.Panel:addButton(x, y, width, title, callback)
    local button = ISButton:new(x, y, width, 28, title, self, callback)
    button:initialise()
    button:instantiate()
    button.backgroundColor = {r = 0.08, g = 0.09, b = 0.085, a = 1}
    button.backgroundColorMouseOver = {r = 0.18, g = 0.28, b = 0.16, a = 1}
    button.borderColor = {r = 0.68, g = 0.65, b = 0.56, a = 0.85}
    button.textureBackground = getTexture("media/ui/ContextManager/button.png")
    self:addChild(button)
    return button
end

function ParadiseRestore.ContextMenuManager.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.worldButton = self:addButton(12, 34, 122, "World Context", ParadiseRestore.ContextMenuManager.Panel.onWorld)
    self.inventoryButton = self:addButton(140, 34, 132, "Inventory Context", ParadiseRestore.ContextMenuManager.Panel.onInventory)
    self.favoritesButton = self:addButton(278, 34, 100, "Favorites", ParadiseRestore.ContextMenuManager.Panel.onFavorites)
    self.worldButton:setImage(getTexture("media/ui/ContextManager/world.png"))
    self.inventoryButton:setImage(getTexture("media/ui/ContextManager/inventory.png"))
    self.favoritesButton:setImage(getTexture("media/ui/ContextManager/favorite_on.png"))
    self.worldButton:forceImageSize(20, 20)
    self.inventoryButton:forceImageSize(20, 20)
    self.favoritesButton:forceImageSize(20, 20)
    self.favoritesToggle = ISTickBox:new(392, 37, 210, 24, "", self, ParadiseRestore.ContextMenuManager.Panel.onFavoritesEnabled)
    self.favoritesToggle:initialise()
    self.favoritesToggle:instantiate()
    self.favoritesToggle:addOption("Enable Favorites")
    self.favoritesToggle.selected[1] = ParadiseRestore.ContextMenuManager.profile.favoritesEnabled == true
    self:addChild(self.favoritesToggle)

    self.list = ISScrollingListBox:new(12, 72, self.width - 308, self.height - 128)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 26
    self.list.backgroundColor = {r = 0.035, g = 0.04, b = 0.038, a = 0.98}
    self.list.borderColor = {r = 0.5, g = 0.5, b = 0.45, a = 0.8}
    self.list.doDrawItem = ParadiseRestore.ContextMenuManager.Panel.drawEntry
    self.list.onMouseDown = ParadiseRestore.ContextMenuManager.Panel.onListMouseDown
    self:addChild(self.list)

    self.visibleToggle = ISTickBox:new(self.width - 280, 92, 250, 24, "", self, ParadiseRestore.ContextMenuManager.Panel.onVisible)
    self.visibleToggle:initialise()
    self.visibleToggle:instantiate()
    self.visibleToggle:addOption("Visible")
    self:addChild(self.visibleToggle)

    self.favoriteToggle = ISTickBox:new(self.width - 280, 126, 250, 24, "", self, ParadiseRestore.ContextMenuManager.Panel.onFavorite)
    self.favoriteToggle:initialise()
    self.favoriteToggle:instantiate()
    self.favoriteToggle:addOption("Favorite")
    self:addChild(self.favoriteToggle)

    self.exportButton = self:addButton(self.width - 280, 170, 120, "Export Backup", ParadiseRestore.ContextMenuManager.Panel.onExport)
    self.importButton = self:addButton(self.width - 150, 170, 120, "Import Backup", ParadiseRestore.ContextMenuManager.Panel.onImport)
    self.exportButton:setImage(getTexture("media/ui/ContextManager/export.png"))
    self.importButton:setImage(getTexture("media/ui/ContextManager/import.png"))
    self.exportButton:forceImageSize(18, 18)
    self.importButton:forceImageSize(18, 18)
    self.resetButton = self:addButton(self.width - 280, 208, 120, "Reset Item", ParadiseRestore.ContextMenuManager.Panel.onResetItem)
    self.resetAllButton = self:addButton(self.width - 150, 208, 120, "Reset All", ParadiseRestore.ContextMenuManager.Panel.onResetAll)
    self.applyButton = self:addButton(self.width - 150, self.height - 42, 120, "Apply", ParadiseRestore.ContextMenuManager.Panel.onApply)
    self.applyButton.textureBackground = getTexture("media/ui/ContextManager/button_apply.png")
    self.closeButton = self:addButton(self.width - 280, self.height - 42, 120, "Close", ParadiseRestore.ContextMenuManager.Panel.onClose)
    self:refresh()
end

function ParadiseRestore.ContextMenuManager.Panel:prerender()
    ISCollapsableWindow.prerender(self)
    self:drawText("Admin Profile: Local Cache", self.width - 280, 42, 0.78, 0.84, 0.72, 1, UIFont.Small)
    self:drawText(ParadiseRestore.ContextMenuManager.getProfileFilename(), self.width - 280, 60, 0.65, 0.65, 0.62, 1, UIFont.Small)
    self:drawText("Hold Shift while right-clicking to reveal hidden items.", 12, self.height - 38, 0.72, 0.76, 0.68, 1, UIFont.Small)
end

function ParadiseRestore.ContextMenuManager.Panel:refresh()
    if not self.list then return end
    self.list:clear()
    for _, entry in ipairs(ParadiseRestore.ContextMenuManager.getEntries(self.kind, self.favoritesOnly)) do
        self.list:addItem(entry.label, entry)
    end
    self.worldButton.textureBackground = getTexture(self.kind == "world" and not self.favoritesOnly and "media/ui/ContextManager/button_selected.png" or "media/ui/ContextManager/button.png")
    self.inventoryButton.textureBackground = getTexture(self.kind == "inventory" and not self.favoritesOnly and "media/ui/ContextManager/button_selected.png" or "media/ui/ContextManager/button.png")
    self.favoritesButton.textureBackground = getTexture(self.favoritesOnly and "media/ui/ContextManager/button_selected.png" or "media/ui/ContextManager/button.png")
    self:updateSelection()
end

function ParadiseRestore.ContextMenuManager.Panel:drawEntry(y, item, alt)
    local entry = item.item
    if self.selected == item.index then self:drawRect(0, y, self.width, self.itemheight, 0.55, 0.12, 0.24, 0.14) end
    local x = 8 + (entry.depth or 0) * 18
    local eyeTexture = ParadiseRestore.ContextMenuManager.profile.hidden[entry.key] and
        getTexture("media/ui/ContextManager/hidden.png") or
        getTexture("media/ui/ContextManager/visible.png")
    local favoriteTexture = ParadiseRestore.ContextMenuManager.profile.favorites[entry.key] and
        getTexture("media/ui/ContextManager/favorite_on.png") or
        getTexture("media/ui/ContextManager/favorite_off.png")
    self:drawTextureScaled(eyeTexture, x, y + 4, 18, 18, 1, 1, 1, 1)
    self:drawTextureScaled(favoriteTexture, x + 22, y + 4, 18, 18, 1, 1, 1, 1)
    self:drawText(entry.label, x + 46, y + 5, 0.9, 0.88, 0.8, 1, self.font)
    return y + self.itemheight
end

function ParadiseRestore.ContextMenuManager.Panel.onListMouseDown(list, x, y)
    ISScrollingListBox.onMouseDown(list, x, y)
    if list.parent and list.parent.updateSelection then list.parent:updateSelection() end
end

function ParadiseRestore.ContextMenuManager.Panel:getSelectedEntry()
    local row = self.list and self.list.items and self.list.items[self.list.selected]
    return row and row.item or nil
end

function ParadiseRestore.ContextMenuManager.Panel:updateSelection()
    local entry = self:getSelectedEntry()
    if self.visibleToggle then self.visibleToggle.selected[1] = entry and ParadiseRestore.ContextMenuManager.profile.hidden[entry.key] ~= true or false end
    if self.favoriteToggle then self.favoriteToggle.selected[1] = entry and ParadiseRestore.ContextMenuManager.profile.favorites[entry.key] == true or false end
end

function ParadiseRestore.ContextMenuManager.Panel:onWorld()
    self.kind = "world"
    self.favoritesOnly = false
    self:refresh()
end

function ParadiseRestore.ContextMenuManager.Panel:onInventory()
    self.kind = "inventory"
    self.favoritesOnly = false
    self:refresh()
end

function ParadiseRestore.ContextMenuManager.Panel:onFavorites()
    if not ParadiseRestore.ContextMenuManager.profile.favoritesEnabled then return end
    self.favoritesOnly = true
    self:refresh()
end

function ParadiseRestore.ContextMenuManager.Panel:onFavoritesEnabled(_, selected)
    ParadiseRestore.ContextMenuManager.profile.favoritesEnabled = selected == true
    ParadiseRestore.ContextMenuManager.save()
end

function ParadiseRestore.ContextMenuManager.Panel:onVisible(_, selected)
    local entry = self:getSelectedEntry()
    if not entry then return end
    ParadiseRestore.ContextMenuManager.setVisible(entry.key, selected == true)
end

function ParadiseRestore.ContextMenuManager.Panel:onFavorite(_, selected)
    local entry = self:getSelectedEntry()
    if not entry then return end
    ParadiseRestore.ContextMenuManager.setFavorite(entry.key, selected == true)
end

function ParadiseRestore.ContextMenuManager.Panel:onResetItem()
    local entry = self:getSelectedEntry()
    if not entry then return end
    ParadiseRestore.ContextMenuManager.profile.hidden[entry.key] = nil
    ParadiseRestore.ContextMenuManager.profile.favorites[entry.key] = nil
    ParadiseRestore.ContextMenuManager.save()
    self:updateSelection()
end

function ParadiseRestore.ContextMenuManager.Panel:onResetAll()
    ParadiseRestore.ContextMenuManager.profile = ParadiseRestore.ContextMenuManager.newProfile()
    ParadiseRestore.ContextMenuManager.save()
    self.favoritesToggle.selected[1] = false
    self:refresh()
end

function ParadiseRestore.ContextMenuManager.Panel:onExport()
    ParadiseRestore.ContextMenuManager.exportBackup()
end

function ParadiseRestore.ContextMenuManager.Panel:onImport()
    if ParadiseRestore.ContextMenuManager.importBackup() then
        self.favoritesToggle.selected[1] = ParadiseRestore.ContextMenuManager.profile.favoritesEnabled == true
        self:refresh()
    end
end

function ParadiseRestore.ContextMenuManager.Panel:onApply()
    ParadiseRestore.ContextMenuManager.save()
    self:close()
end

function ParadiseRestore.ContextMenuManager.Panel:onClose()
    self:close()
end

function ParadiseRestore.ContextMenuManager.Panel:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if ParadiseRestore.ContextMenuManager.instance == self then ParadiseRestore.ContextMenuManager.instance = nil end
end

function ParadiseRestore.ContextMenuManager.OpenPanel()
    if ParadiseRestore.ContextMenuManager.instance then
        ParadiseRestore.ContextMenuManager.instance:setVisible(true)
        ParadiseRestore.ContextMenuManager.instance:bringToTop()
        ParadiseRestore.ContextMenuManager.instance:refresh()
        return
    end
    local width = math.min(900, getCore():getScreenWidth() - 40)
    local height = math.min(620, getCore():getScreenHeight() - 40)
    local panel = ParadiseRestore.ContextMenuManager.Panel:new(
        math.floor((getCore():getScreenWidth() - width) / 2),
        math.floor((getCore():getScreenHeight() - height) / 2),
        width,
        height
    )
    panel:initialise()
    panel:addToUIManager()
    ParadiseRestore.ContextMenuManager.instance = panel
end

function ParadiseRestore.ContextMenuManager.addManagerOption(kind, plNum, context)
    if type(context) ~= "table" or not context.options then return end
    local opening = ParadiseRestore.ContextMenuManager.getOpening(context)
    if opening.finished[kind] then return end
    opening.finished[kind] = true
    local pl = getSpecificPlayer and getSpecificPlayer(plNum) or getPlayer()
    if not pl or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm(pl) then return end
    local count = #context.options
    ParadiseRestore.ContextMenuManager.addFavorites(kind, context)
    if ParadiseRestore.ContextMenuManager.isShiftHeld() then
        local option = context:addOption("Context Menu Manager", nil, ParadiseRestore.ContextMenuManager.OpenPanel)
        option.iconTexture = getTexture("media/ui/ContextManager/manager.png")
    end
    -- Vanilla hides an empty world menu before returning it. A favorite from a
    -- hidden parent can make it useful again after our finalization.
    if #context.options > count and context.setVisible then context:setVisible(true) end
end

function ParadiseRestore.ContextMenuManager.addWorldManager(plNum, context, worldobjects, test)
    if test then return end
    ParadiseRestore.ContextMenuManager.addManagerOption("world", plNum, context)
end

function ParadiseRestore.ContextMenuManager.addInventoryManager(plNum, context)
    ParadiseRestore.ContextMenuManager.addManagerOption("inventory", plNum, context)
end

function ParadiseRestore.ContextMenuManager.init()
    ParadiseRestore.ContextMenuManager.load()
    ParadiseRestore.ContextMenuManager.installHooks()
end

function ParadiseRestore.ContextMenuManager.installHooks()
    local manager = ParadiseRestore.ContextMenuManager
    manager.hooks = manager.hooks or {}
    local function pack(...) return {n = select('#', ...), ...} end
    local function wrap(owner, name, id, kind)
        if not owner or type(owner[name]) ~= "function" then return end
        local oldHook = manager.hooks[id]
        if oldHook and owner[name] == oldHook.wrapper then return end
        local original = owner[name]
        local wrapper
        if kind then
            wrapper = function(...)
                local arguments = pack(...)
                local results = pack(original(...))
                local isTest = kind == "world" and arguments[5]
                if not isTest then manager.addManagerOption(kind, arguments[1], results[1]) end
                return unpack(results, 1, results.n)
            end
        else
            wrapper = function(...)
                local results = pack(original(...))
                if type(results[1]) == "table" then manager.beginOpening(results[1]) end
                return unpack(results, 1, results.n)
            end
        end
        manager.hooks[id] = {wrapper = wrapper}
        owner[name] = wrapper
    end
    -- Invalidate every root opening, including another UI reusing that root.
    -- Finalize only world/inventory builders, after every OnFill handler returns.
    wrap(ISContextMenu, "get", "root")
    wrap(ISWorldObjectContextMenu, "createMenu", "world", "world")
    wrap(ISInventoryPaneContextMenu, "createMenu", "inventory", "inventory")
end

-- Release bindings retained by a previous version during Lua hot reload.
for _, entries in pairs(ParadiseRestore.ContextMenuManager.registry) do
    for _, entry in pairs(entries) do
        entry.menu, entry.option, entry.subMenu = nil, nil, nil
        entry.rootContext, entry.rootOption, entry.rootLabel = nil, nil, nil
    end
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Remove(ParadiseRestore.ContextMenuManager.init)
    Events.OnGameStart.Add(ParadiseRestore.ContextMenuManager.init)
end
if Events and Events.OnFillWorldObjectContextMenu then
    Events.OnFillWorldObjectContextMenu.Remove(ParadiseRestore.ContextMenuManager.addWorldManager)
end
if Events and Events.OnFillInventoryObjectContextMenu then
    Events.OnFillInventoryObjectContextMenu.Remove(ParadiseRestore.ContextMenuManager.addInventoryManager)
end
ParadiseRestore.ContextMenuManager.installHooks()
