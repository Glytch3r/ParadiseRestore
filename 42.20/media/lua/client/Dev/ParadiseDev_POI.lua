ParadisePOI = ParadisePOI or {}
Paradise_POI_Manager = ISPanel:derive("Paradise_POI_Manager")
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
ParadisePOI.refreshDelay = 1000
ParadisePOI.pendingRefresh = false
ParadisePOI.lastRefresh = 0
ParadisePOI.liveCoordinateDelay = 250

ParadisePOI.data = ParadisePOI.data or {}

function ParadisePOI.openPanel()
    if not ParadiseDev.isAdm() then return end
    if ParadisePOI.instance then
        ParadisePOI.instance:setVisible(true)
        ParadisePOI.instance:bringToTop()
        ParadisePOI.instance:addToUIManager()
        ParadisePOI.requestSync()
        return
    end

    local width = 960
    local height = 430
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)

    local panel = Paradise_POI_Manager:new(x, y, width, height)
    panel:initialise()
    panel:addToUIManager()

    ParadisePOI.instance = panel
    ParadisePOI.requestSync()
end

function ParadisePOI.closePanel()
    if ParadisePOI.instance then
        ParadisePOI.instance:close()
    end
end

function ParadisePOI.requestSync()
    if isClient() then
        sendClientCommand(getPlayer(), "ParadisePOI", "requestSync", {})
    else
        ParadisePOI.data = ModData.getOrCreate("ParadisePOI_Data")
        if ParadisePOI.instance then
            ParadisePOI.instance:refreshPOIList()
        end
    end
end

function ParadisePOI.OnServerCommand(module, command, args)
    if module ~= "ParadisePOI" then return end

    if command == "sync" then
        ParadisePOI.data = args.data or {}
        ParadisePOI.pendingRefresh = true
    end
end

Events.OnServerCommand.Add(ParadisePOI.OnServerCommand)
Events.OnTick.Add(function()
    if not ParadisePOI.pendingRefresh or not ParadisePOI.instance then return end
    local now = getTimestampMs and getTimestampMs() or (os.time() * 1000)
    if now - ParadisePOI.lastRefresh < ParadisePOI.refreshDelay then return end
    ParadisePOI.pendingRefresh = false
    ParadisePOI.lastRefresh = now
    ParadisePOI.instance:refreshPOIList()
end)

function Paradise_POI_Manager:new(x, y, width, height)
    local o = ISPanel.new(self, x, y, width, height)
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.borderColor = {r=0.35, g=0.35, b=0.35, a=1}
    o.moveWithMouse = true
    return o
end

function Paradise_POI_Manager:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if ParadisePOI and ParadisePOI.instance then
        ParadisePOI.instance = nil
    end
end

function Paradise_POI_Manager:initialise()
    ISPanel.initialise(self)
    self.anchorLeft = true
    self.anchorRight = false
    self.anchorTop = true
    self.anchorBottom = false
    self.drawBackground = true
    self.drawBorder = true
    self.resizable = false
end

function Paradise_POI_Manager:createChildren()
    ISPanel.createChildren(self)

    self.titleLabel = ISLabel:new(16, 10, 20, "Paradise POI Manager", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self:addChild(self.titleLabel)

    self.keyLabel = ISLabel:new(16, 35, 20, "POI Label", 1, 1, 1, 1, UIFont.Small, true)
    self.keyLabel:initialise()
    self:addChild(self.keyLabel)

    self.key = ISTextEntryBox:new("", 16, 55, 232, 25)
    self.key:initialise()
    self.key:instantiate()
    self.key.onTextChange = Paradise_POI_Manager.onEntryChanged
    self.key.target = self
    self:addChild(self.key)

    self.xLabel = ISLabel:new(16, 90, 20, "X:", 1, 1, 1, 1, UIFont.Small, true)
    self.xLabel:initialise()
    self:addChild(self.xLabel)

    self.coordX = ISTextEntryBox:new("0", 40, 85, 208, 25)
    self.coordX:initialise()
    self.coordX:instantiate()
    self.coordX.onTextChange = Paradise_POI_Manager.onEntryChanged
    self.coordX.target = self
    self:addChild(self.coordX)

    self.yLabel = ISLabel:new(16, 120, 20, "Y:", 1, 1, 1, 1, UIFont.Small, true)
    self.yLabel:initialise()
    self:addChild(self.yLabel)

    self.coordY = ISTextEntryBox:new("0", 40, 115, 208, 25)
    self.coordY:initialise()
    self.coordY:instantiate()
    self.coordY.onTextChange = Paradise_POI_Manager.onEntryChanged
    self.coordY.target = self
    self:addChild(self.coordY)

    self.zLabel = ISLabel:new(16, 150, 20, "Z:", 1, 1, 1, 1, UIFont.Small, true)
    self.zLabel:initialise()
    self:addChild(self.zLabel)

    self.coordZ = ISTextEntryBox:new("0", 40, 145, 208, 25)
    self.coordZ:initialise()
    self.coordZ:instantiate()
    self.coordZ.onTextChange = Paradise_POI_Manager.onEntryChanged
    self.coordZ.target = self
    self:addChild(self.coordZ)

    self.valueLabel = ISLabel:new(16, 180, 20, "Description", 1, 1, 1, 1, UIFont.Small, true)
    self.valueLabel:initialise()
    self:addChild(self.valueLabel)

    self.descriptionBox = ISTextEntryBox:new("", 16, 200, 232, 80)
    self.descriptionBox:initialise()
    self.descriptionBox:instantiate()
    self.descriptionBox:setMultipleLine(true)
    self.descriptionBox.onTextChange = Paradise_POI_Manager.onEntryChanged
    self.descriptionBox.target = self
    self:addChild(self.descriptionBox)

    self.listHeaders = {
        { text = "Label", x = 275 },
        { text = "X", x = 470 },
        { text = "Y", x = 550 },
        { text = "Z", x = 630 },
        { text = "Description", x = 710 },
    }
    for _, header in ipairs(self.listHeaders) do
        local label = ISLabel:new(header.x, 35, 18, header.text, 1, 1, 1, 1, UIFont.Small, true)
        label:initialise()
        self:addChild(label)
    end

    self.poiList = ISScrollingListBox:new(270, 55, 674, 255)
    self.poiList:initialise()
    self.poiList:instantiate()
    self.poiList.itemheight = 40
    self.poiList.font = UIFont.Small
    self.poiList.selected = 0
    self.poiList.onmousedown = self.onSelectPOI
    self.poiList.doDrawItem = Paradise_POI_Manager.doDrawItem
    self.poiList.target = self
    self.poiList.drawBorder = true
    self.poiList.borderColor = { r = 0.35, g = 1, b = 0.45, a = 0.9 }
    self:addChild(self.poiList)

    self.btnUpdateCoord = ISButton:new(16, 290, 232, 25, "Update Coordinate", self, self.onButtonClick)
    self.btnUpdateCoord.internal = "UPDATE_COORD"
    self.btnUpdateCoord:initialise()
    self.btnUpdateCoord:instantiate()
    self:addChild(self.btnUpdateCoord)

    self.btnTPCoord = ISButton:new(16, 320, 232, 25, "TP to Coordinates", self, self.onButtonClick)
    self.btnTPCoord.internal = "TP_COORD"
    self.btnTPCoord:initialise()
    self.btnTPCoord:instantiate()
    self:addChild(self.btnTPCoord)

    self.btnZPlus = ISButton:new(280, 310, 120, 25, "Z +", self, self.onButtonClick)
    self.btnZPlus.internal = "Z_PLUS"
    self.btnZPlus:initialise()
    self.btnZPlus:instantiate()
    self:addChild(self.btnZPlus)

    self.btnZZero = ISButton:new(280, 340, 120, 25, "Z 0", self, self.onButtonClick)
    self.btnZZero.internal = "Z_ZERO"
    self.btnZZero:initialise()
    self.btnZZero:instantiate()
    self:addChild(self.btnZZero)

    self.btnZMinus = ISButton:new(280, 370, 120, 25, "Z -", self, self.onButtonClick)
    self.btnZMinus.internal = "Z_MINUS"
    self.btnZMinus:initialise()
    self.btnZMinus:instantiate()
    self:addChild(self.btnZMinus)

    self.btnSave = ISButton:new(430, 310, 120, 25, "Save", self, self.onButtonClick)
    self.btnSave.internal = "SAVE"
    self.btnSave:initialise()
    self.btnSave:instantiate()
    self:addChild(self.btnSave)

    self.btnDelete = ISButton:new(560, 310, 120, 25, "Delete", self, self.onButtonClick)
    self.btnDelete.internal = "DELETE"
    self.btnDelete:initialise()
    self.btnDelete:instantiate()
    self:addChild(self.btnDelete)

    self.btnTPPOI = ISButton:new(430, 340, 250, 25, "TP to POI", self, self.onButtonClick)
    self.btnTPPOI.internal = "TP_POI"
    self.btnTPPOI:initialise()
    self.btnTPPOI:instantiate()
    self:addChild(self.btnTPPOI)

    self.btnUnstuck = ISButton:new(430, 370, 120, 25, "Unstuck", self, self.onButtonClick)
    self.btnUnstuck.internal = "UNSTUCK"
    self.btnUnstuck:initialise()
    self.btnUnstuck:instantiate()
    self:addChild(self.btnUnstuck)

    self.btnExit = ISButton:new(560, 370, 120, 25, "Exit", self, self.onButtonClick)
    self.btnExit.internal = "EXIT"
    self.btnExit:initialise()
    self.btnExit:instantiate()
    self:addChild(self.btnExit)

    self.liveCoords = ISLabel:new(16, 385, 20, "Square: X 0  Y 0  Z 0", 0.2, 1, 0.2, 1, UIFont.Small, true)
    self.liveCoords:initialise()
    self:addChild(self.liveCoords)

    self:refreshPOIList()
    self:updateButtonStates()
end

function Paradise_POI_Manager:doDrawItem(y, item, alt)
    local list = self
    if y + list:getYScroll() + list.itemheight < 0 or y + list:getYScroll() >= list.height then
        return y + list.itemheight
    end
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), list.itemheight, 0.25, 0.75, 0.35, 0.45)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), list.itemheight, 0.13, 0.30, 0.32, 0.32)
    end
    list:drawRectBorder(0, y, list:getWidth(), list.itemheight, 0.45, 1, 0.35, 0.45)

    local d = item.item or {}
    local textY = y + 2
    local columnX = { 5, 200, 280, 360, 440 }
    list:drawText(tostring(item.text or ""), columnX[1], textY, 1, 1, 1, 1, list.font)
    list:drawText(tostring(d.x or 0), columnX[2], textY, 0.8, 0.8, 0.8, 1, list.font)
    list:drawText(tostring(d.y or 0), columnX[3], textY, 0.8, 0.8, 0.8, 1, list.font)
    list:drawText(tostring(d.z or 0), columnX[4], textY, 0.8, 0.8, 0.8, 1, list.font)
    list:drawText(tostring(d.desc or ""), columnX[5], textY, 0.7, 0.7, 0.7, 1, list.font)

    return y + self.itemheight
end

function Paradise_POI_Manager:refreshPOIList()
    local selectedLabel = self.key and self.key:getText() or nil
    self.poiList:clear()
    local data = ParadisePOI.data or {}

    for label, item in pairs(data) do
        self.poiList:addItem(label, item)
    end
    if selectedLabel and data[selectedLabel] then
        for index, item in ipairs(self.poiList.items) do
            if item.text == selectedLabel then
                self.poiList.selected = index
                break
            end
        end
    end
    if self.poiList.selected > #self.poiList.items then self.poiList.selected = 0 end
    self:updateButtonStates()
end

function Paradise_POI_Manager:onSelectPOI(item)
    if not item then
        self.poiList.selected = 0
        self:updateButtonStates()
        return
    end
    local data = item.item or item
    self.key:setText(item.text or "")
    self.coordX:setText(tostring(data.x or 0))
    self.coordY:setText(tostring(data.y or 0))
    self.coordZ:setText(tostring(data.z or 0))
    self.descriptionBox:setText(data.desc or "")
    self:updateButtonStates()
end

function Paradise_POI_Manager:onEntryChanged()
    local target = self.target or self
    if target.updateButtonStates then target:updateButtonStates() end
end

function Paradise_POI_Manager:updateButtonStates()
    if not self.btnTPCoord then return end
    local x = tonumber(self.coordX:getText())
    local y = tonumber(self.coordY:getText())
    local label = tostring(self.key:getText() or ""):gsub("^%s*(.-)%s*$", "%1")
    local selected = self.poiList.selected and self.poiList.selected > 0 and self.poiList.items[self.poiList.selected]
    local hasCoordinates = x and y and x ~= 0 and y ~= 0
    self.btnTPCoord.enable = hasCoordinates == true
    self.btnSave.enable = hasCoordinates == true and label ~= ""
    self.btnTPPOI.enable = selected ~= nil
    self.btnDelete.enable = selected ~= nil
end

function Paradise_POI_Manager:onButtonClick(button)
    local player = getSpecificPlayer(0)
    if not player then return end

    if button.internal == "UPDATE_COORD" then
        self.coordX:setText(tostring(math.floor(player:getX())))
        self.coordY:setText(tostring(math.floor(player:getY())))
        self.coordZ:setText(tostring(math.floor(player:getZ())))
        self:updateButtonStates()


        --self.coordZ:setText(tostring((tonumber(self.coordZ:getText()) or 0) + 1))
        --self:updateButtonStates()

    elseif button.internal == "Z_PLUS" then
        local x = tonumber(self.coordX:getText())
        local y = tonumber(self.coordY:getText())
        local z = tonumber(self.coordZ:getText()) or 0
        if x and y then
            z = z + 1
            sendClientCommand(player, ParadiseDev.TP.module, "teleportWithVehicle", {
                x = x,
                y = y,
                z = z
            })
            self.coordZ:setText(tostring(z))
        end
    elseif button.internal == "Z_ZERO" then
        local x = tonumber(self.coordX:getText())
        local y = tonumber(self.coordY:getText())
        if x and y then
            sendClientCommand(player, ParadiseDev.TP.module, "teleportWithVehicle", {
                x = x,
                y = y,
                z = 0
            })
            self.coordZ:setText("0")
        end
    elseif button.internal == "Z_MINUS" then
        local x = tonumber(self.coordX:getText())
        local y = tonumber(self.coordY:getText())
        local z = tonumber(self.coordZ:getText()) or 0
        if x and y then
            z = z - 1
            sendClientCommand(player, ParadiseDev.TP.module, "teleportWithVehicle", {
                x = x,
                y = y,
                z = z
            })
            self.coordZ:setText(tostring(z))
        end
    elseif button.internal == "TP_COORD" then
        local x = tonumber(self.coordX:getText())
        local y = tonumber(self.coordY:getText())
        local z = tonumber(self.coordZ:getText()) or 0
        if x and y then
            sendClientCommand(player, ParadiseDev.TP.module, "teleportWithVehicle", {
                x = x,
                y = y,
                z = z
            })
        end
    elseif button.internal == "SAVE" then
        local label = tostring(self.key:getText() or ""):gsub("^%s*(.-)%s*$", "%1")
        if label and label ~= "" then
            local args = {
                label = label,
                x = tonumber(self.coordX:getText()) or 0,
                y = tonumber(self.coordY:getText()) or 0,
                z = tonumber(self.coordZ:getText()) or 0,
                desc = self.descriptionBox:getText()
            }
            sendClientCommand(player, "ParadisePOI", "save", args)
        end

    elseif button.internal == "DELETE" then
        local selectedIndex = self.poiList.selected
        if selectedIndex and selectedIndex > 0 then
            local item = self.poiList.items[selectedIndex]
            if item then
                sendClientCommand(player, "ParadisePOI", "delete", {label = item.text})
                self.poiList.selected = 0
                self:updateButtonStates()
            end
        end

    elseif button.internal == "TP_POI" then
        local selectedIndex = self.poiList.selected
        if selectedIndex and selectedIndex > 0 then
            local item = self.poiList.items[selectedIndex]
            if item and item.item then
                sendClientCommand(player, ParadiseDev.TP.module, "teleportWithVehicle", {
                    x = item.item.x,
                    y = item.item.y,
                    z = item.item.z
                })
            end
        end

    elseif button.internal == "UNSTUCK" then
        if ParadiseDev.reboundCountdown then
            ParadiseDev.reboundCountdown(true)
        end
--[[         if ParadiseDev.TP and ParadiseDev.TP.rebound then
            ParadiseDev.TP.rebound(player)
        end
 ]]
    elseif button.internal == "EXIT" then
        self:close()
    end
end

function Paradise_POI_Manager:prerender()
    ISPanel.prerender(self)
    local now = getTimestampMs and getTimestampMs() or (os.time() * 1000)
    if now - (self.lastLiveCoordinateUpdate or 0) < ParadisePOI.liveCoordinateDelay then return end
    self.lastLiveCoordinateUpdate = now
    local player = getSpecificPlayer(0)
    if player and self.liveCoords then
        local square = player:getSquare()
        local x = square and square:getX() or math.floor(player:getX())
        local y = square and square:getY() or math.floor(player:getY())
        local z = square and square:getZ() or math.floor(player:getZ())
        self.liveCoords:setName(string.format("%d , %d , %d", x, y, z))
    end
end

function Paradise_POI_Manager:render()
    ISPanel.render(self)
end
