require "ISUI/ISPanelJoypad"
WaveCaster = WaveCaster or {}
WaveCasterPanel = ISCollapsableWindow:derive("WaveCasterPanel");
WaveCaster.midColor = { r = 1.00, g = 0.48, b = 0.45 }
WaveCaster.pickedColor = { r = 0.65, g = 0.84, b = 0.94 }
if DebugContextMenu and DebugContextMenu.onHordeManager then
	function DebugContextMenu.onHordeManager(sq, pl)
		if not getCore():getDebug() then return end
		WaveCaster.panel(true)
	end
end
if AdminContextMenu and AdminContextMenu.onHordeManager then
	function AdminContextMenu.onHordeManager(sq, pl)
		local pl = getPlayer()
		if not pl then return end
		if not (isAdmin() or string.lower(pl:getAccessLevel()) == "admin") then return end
		WaveCaster.panel(true)
	end
end
-----------------------            ---------------------------
function WaveCasterPanel:render()
    ISCollapsableWindow.render(self)

	local mCol = WaveCaster.midColor
	local pCol = WaveCaster.pickedColor


	self:drawRect(195, 10, 160, 80, 0.4, 0, 0, 0)
	self:drawText(
		"\nPicked Square\nX:  "..tostring(self.selectX) .. "\nY:  " .. tostring(self.selectY) .. "\nZ:  " .. tostring(self.selectZ),
		208, 8, pCol.r, pCol.g, pCol.b, 1, UIFont.Small)
    if self.castMidX and self.castMidY then
        self:drawText(
            "\nCast Point\nX:  "..tostring(self.castMidX) .. "\nY:  " .. tostring(self.castMidY),
            293, 8, mCol.r, mCol.g, mCol.b,	 1, UIFont.Small)
    end
    local castEvent = self:getCastEvent()
    local state = "Empty"
	--[[ if castEvent and castEvent.Countdown > 0 ]]
    if castEvent and castEvent.Waves and #castEvent.Waves > 0 then
        if castEvent.Countdown and castEvent.Countdown > 0 then
            state = "Active"
        else
			if #castEvent.Waves <= 0 then 
				state = "Empty"
			else
				state = "Ready"
			end
        end
    end
    self:drawText(
        "STATE:  \n[  ".. state .."  ]",
        10,
        330,
        1,1,1,1,
        UIFont.Small
    )
    self:drawText(
        "NEXT WAVE:  \n[ " .. tostring(castEvent and castEvent.Countdown or 0)..' ]',
        130,
        330,
        1,1,1,1,
        UIFont.Small
    )
    self:drawText(
        "WAVES:  \n[ " .. tostring(castEvent and #castEvent.Waves or 0)..' ]',
        250,
        330,
        1,1,1,1,
        UIFont.Small
    )
--[[ 	local sqStr = "Picked Square: " .. self.selectX .. "," .. self.selectY .. "," .. self.selectZ--.. "  |   Cast Point: " .. self.castMidX .. "," ..  self.castMidY
	self:drawText(tostring(sqStr), 25, 15, 1, 1, 1, 1, self.font); ]]
end

function WaveCasterPanel:new(x, y, width, height, character, sq)

	width = width or 900;
	height = height or 400;

	local o = ISCollapsableWindow.new(self, x, y, width, height);
	o.plNum = character:getPlayerNum()
	if y == 0 then
		o.y = getPlayerScreenTop(plNum) + (getPlayerScreenHeight(o.plNum) - height) / 2
		o:setY(o.y)
	end
	if x == 0 then
		o.x = getPlayerScreenLeft(o.plNum) + (getPlayerScreenWidth(o.plNum) - width) / 2
		o:setX(o.x)
	end
	o.width = width;
	o.height = height;
	o.chr = character;
	o.moveWithMouse = true;
	o.title = 'Wave  Caster  Panel'
	sq = sq or character:getSquare()
	o.castMidX, o.castMidY = WaveCaster.getBldgMidXY(sq:getX(), sq:getY());
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
    o.backgroundColor = { r = 0.47, g = 0.27, b = 0.14 , a=0.4}
	o.selectX = sq:getX();
	o.selectY = sq:getY();
	o.selectZ = sq:getZ();
	if o.castMidX and o.castMidY then
		local midSq = getCell():getOrCreateGridSquare(o.castMidX, o.castMidY, 0)
		if midSq then
			o:addMarker(midSq, 1);
		end
	end
	o:addPickMarker(sq);
	return o;
end
function WaveCasterPanel:createChildren()
	local btnWid = 100
	local btnHgt = 25
	local padBottom = 0
	local y = 90
	local f = 0.8
	local leftWidth = 420

	local mCol = WaveCaster.midColor
	local pCol = WaveCaster.pickedColor

	ISCollapsableWindow.createChildren(self)
	local labelY =100
	self.zombiesNbrLabel = ISLabel:new(10, labelY, 10, "Zombies Number" ,1,1,1,1,UIFont.Small, true);
	self:addChild(self.zombiesNbrLabel);
	self.zombiesNbr = ISTextEntryBox:new("1", self.zombiesNbrLabel.x, labelY + 15, 100, 20);
	self.zombiesNbr:initialise();
	self.zombiesNbr:instantiate();
	self.zombiesNbr:setOnlyNumbers(true);
	self:addChild(self.zombiesNbr);
	
	self.radiusLbl = ISLabel:new(130, labelY, 10, "Wave Radius" ,1,1,1,1,UIFont.Small, true);
	self:addChild(self.radiusLbl);
	y=y+25
	
	self.radius = ISTextEntryBox:new("1", self.radiusLbl.x, labelY + 15, 100, 20);
	self.radius:initialise();
	self.radius:instantiate();
	self.radius:setOnlyNumbers(true);
	self.radius.backgroundColor.r = mCol.r
	self.radius.backgroundColor.g = mCol.g
	self.radius.backgroundColor.b = mCol.b

	self:addChild(self.radius);
	y=y+30
--**
	self.outfitLbl = ISLabel:new(250, labelY, 10, "Zombies Outfit" ,1,1,1,1,UIFont.Small, true);
	self:addChild(self.outfitLbl);
	self.outfitLbl.backgroundColor.r = mCol.r
	self.outfitLbl.backgroundColor.g = mCol.g
	self.outfitLbl.backgroundColor.b = mCol.b
	--**
	self.outfit = ISComboBox:new(self.outfitLbl.x, labelY + 15, 160, 20)
	self.outfit.textColor = {r=1, g=0, b=0, a=1};
	self.outfit.backgroundColor = {r=0, g=0, b=0, a=1};
	self.outfit.backgroundColorMouseOver = {r=0.4, g=0.4, b=0.4, a=1};
	self.outfit.borderColor = {r=0.3, g=0.3, b=0.3, a=1};
	self.outfit.font = UIFont.Small

	self.outfit:initialise()
	self:addChild(self.outfit)

	self.maleOutfits = getAllOutfits(false);
	self.femaleOutfits = getAllOutfits(true);
	self.outfit:addOptionWithData("None", nil);
	self.outfit.textColor = {r=0, g=1, b=0, a=0.7};
	for i=0, self.maleOutfits:size()-1 do
		local text = "";
		if not self.femaleOutfits:contains(self.maleOutfits:get(i)) then
			text = " - Male Only";
		end
		self.outfit:addOptionWithData(self.maleOutfits:get(i) .. text, self.maleOutfits:get(i));
	end
	for i=0, self.femaleOutfits:size()-1 do
		if not self.maleOutfits:contains(self.femaleOutfits:get(i)) then
			self.outfit:addOptionWithData(self.femaleOutfits:get(i) .. " - Female only", self.femaleOutfits:get(i));
		end
	end
	
	
	self.leftBoolOptions = ISTickBox:new(10, y, 110, 20, "", self, WaveCasterPanel.onBoolOptionsChangeLeft);
	self.leftBoolOptions:initialise()
	self.leftBoolOptions.choicesColor = {r=0, g=1, b=0.6, a=1};
	self:addChild(self.leftBoolOptions)
	self.leftBoolOptions:addOption("KnockedDown");
	self.leftBoolOptions:addOption("Crawler");
	self.rightBoolOptions = ISTickBox:new(130, y, 110, 20, "", self, WaveCasterPanel.onBoolOptionsChangeRight);
	self.rightBoolOptions:initialise()
	self:addChild(self.rightBoolOptions)
	self.rightBoolOptions.choicesColor = {r=0, g=1, b=0.6, a=1};
	self.rightBoolOptions:addOption("FakeDead");
	self.rightBoolOptions:addOption("FallOnFront");
	_,self.healthSliderTitle = ISDebugUtils.addLabel(self,"Health",250,y,"Health", UIFont.Small, true);
	_,self.healthSliderLabel = ISDebugUtils.addLabel(self,"Health",300,y,"1", UIFont.Small, false);
	_,self.healthSlider = ISDebugUtils.addSlider(self, "Health", 250, y+18, 140, 20, WaveCasterPanel.onSliderChange)
	self.healthSlider.pretext = "Health: ";
	self.healthSlider.valueLabel = self.healthSliderLabel;
	self.healthSlider:setValues(0, 2, 0.1, 0.1, true);
	self.healthSlider.currentValue = 1.0;
	
	y = y + self.leftBoolOptions:getHeight() + 10
	self.pickNewSq = ISButton:new(35, 30, btnWid+25, btnHgt+25, "Pick Cast Point", self, WaveCasterPanel.onSelectNewSquare);
	self.pickNewSq.anchorTop = false
	self.pickNewSq.anchorBottom = true
	self.pickNewSq:initialise();
	self.pickNewSq:instantiate();
	self.pickNewSq.backgroundColor = {r=pCol.r, g=pCol.g, b=pCol.b, a=0.6};
	self.pickNewSq.borderColor = {r=pCol.r, g=pCol.g, b=pCol.b, a=0.6};
	self:addChild(self.pickNewSq);



--[[ 
	self.pickNewSq = ISButton:new(5, 20, btnWid, btnHgt, "Pick Cast Point", self, WaveCasterPanel.onSelectNewSquare);
	self.pickNewSq.anchorTop = false
	self.pickNewSq.anchorBottom = true
	self.pickNewSq:initialise();
	self.pickNewSq:instantiate();
	self.pickNewSq = {r=0.2, g=3.2, b=0.2, a=0.4};
	self.pickNewSq.borderColor = {r=1, g=1, b=1, a=0.4};
	self:addChild(self.pickNewSq);
 ]]
	self.add = ISButton:new(10, y, btnWid*f, btnHgt, "Spawn", self, WaveCasterPanel.onSpawn);
	self.add.anchorTop = false
	self.add.anchorBottom = true
	self.add:initialise();
	self.add:instantiate();
	self.add.borderColor = {r=0, g=1, b=0, a=0.1};
	self.add.backgroundColorMouseOver.r = 0
	self.add.backgroundColorMouseOver.g = 1
	self.add.backgroundColorMouseOver.b = 0
	self.add.backgroundColorMouseOver.a = 1
	self:addChild(self.add);
	self.add.enable = false
	self.removezombies = ISButton:new(self.add.x + (btnWid*f) + 5, self.add.y, btnWid, btnHgt, "Remove zombies", self, WaveCasterPanel.onRemoveZombies);
	self.removezombies.anchorTop = false
	self.removezombies.anchorBottom = true
	self.removezombies:initialise();
	self.removezombies:instantiate();
	self.removezombies.borderColor = {r=1, g=1, b=1, a=0.4};
	self:addChild(self.removezombies);
	--self.removezombies.enable = false
	self.clearbodies = ISButton:new(self.removezombies.x + btnWid + 5, self.add.y, btnWid, btnHgt, "Remove bodies", self, WaveCasterPanel.onRemoveBodies);
	self.clearbodies.anchorTop = false
	self.clearbodies.anchorBottom = true
	self.clearbodies:initialise();
	self.clearbodies:instantiate();
	self.clearbodies.borderColor = {r=1, g=1, b=1, a=0.4};
	self:addChild(self.clearbodies);
	--self.clearbodies.enable = false
	self.queue = ISButton:new(self.clearbodies.x + btnWid + 5, self.add.y, btnWid*f, btnHgt, "Add Queue", self, WaveCasterPanel.onQueue);
	y = self.add.y + btnHgt + 15
	_,self.castRadiusSliderTitle = ISDebugUtils.addLabel(self,"CastRadius",10,y,"Cast Radius", UIFont.Small, true);
	self.castRadiusSliderTitle.r = mCol.r
	self.castRadiusSliderTitle.g = mCol.g
	self.castRadiusSliderTitle.b = mCol.b
	_,self.castRadiusSliderLabel = ISDebugUtils.addLabel(self,"CastRadiusVal",165,y,"1", UIFont.Small, false);
	_,self.castRadiusSlider = ISDebugUtils.addSlider(self, "castradius", 10, y+18, 150, 20, WaveCasterPanel.onSliderChange)
	self.castRadiusSlider.pretext = "Cast Radius: ";
	self.castRadiusSlider.valueLabel = self.castRadiusSliderLabel;
	self.castRadiusSlider:setValues(0, 100, 1, 1, true);
	self.castRadiusSlider.currentValue = 1;



	_,self.delaySliderTitle = ISDebugUtils.addLabel(self,"Delay",180,y,"Delay", UIFont.Small, true);
	_,self.delaySliderLabel = ISDebugUtils.addLabel(self,"DelayVal",335,y,"5", UIFont.Small, false);
	_,self.delaySlider = ISDebugUtils.addSlider(self, "delay", 180, y+18, 150, 20, WaveCasterPanel.onSliderChange)
	self.delaySlider.pretext = "Delay: ";
	self.delaySlider.valueLabel = self.delaySliderLabel;
	self.delaySlider:setValues(0, 120, 1, 1, true);
	self.delaySlider.currentValue = 5;
	self.waveListTitle = ISLabel:new(leftWidth + 20, 20, 20, "Wave List" ,1,1,1,1,UIFont.Large, true);
	self:addChild(self.waveListTitle);
	self.waveList = ISScrollingListBox:new(leftWidth + 10, 45+25, self.width - leftWidth - 20, self.height - 45 - 80)
	self.waveList:initialise()
	self.waveList:instantiate()
	self.waveList.itemheight = 25
	self.waveList.font = UIFont.Medium
	self.waveList.drawBorder = true
	self.waveList:addColumn("#", 0)
	self.waveList:addColumn("Outfit", 35)
	self.waveList:addColumn("Count", 170)
	self.waveList:addColumn("Radius", 240)
	self.waveList:addColumn("Delay", 310)
	self.waveList:addColumn("Mid Square", 360)
	self.waveList:addColumn("Flags", 500)
	self.waveList.doDrawItem = function(box, y, item, alt)
		return self:drawWaveItem(y, item, alt)
	end
	self.waveList:setOnMouseDownFunction(self, WaveCasterPanel.onWaveListClick)
	self:addChild(self.waveList)
	self.castWave = ISButton:new(leftWidth + 10, self.height - 50, btnWid, btnHgt, "Cast Wave", self, WaveCasterPanel.onCast);
	self.castWave.anchorTop = false
	self.castWave.anchorBottom = true
	self.castWave:initialise();
	self.castWave:instantiate();
	self.castWave.borderColor = {r=1, g=1, b=1, a=0.1};
	self.castWave.enable = false
	self.castWave.tooltip = 'Forces the first wave to trigger by setting the countdown timer to 0'
	self:addChild(self.castWave);
	self.queue = ISButton:new(self.castWave.x + btnWid + 5, self.height - 50, btnWid*f, btnHgt, "Add Queue", self, WaveCasterPanel.onQueue);
	self.queue.anchorTop = false
	self.queue.anchorBottom = true
	self.queue:initialise();
	self.queue:instantiate();
	self.queue.borderColor = {r=1, g=0, b=0, a=0.2};
	self.queue.tooltip = 'Add a wave to the queue list based on your settings'

	self:addChild(self.queue);
	self.removeWave = ISButton:new(self.queue.x + (btnWid*f) + 5, self.height - 50, btnWid, btnHgt, "Remove Wave", self, WaveCasterPanel.onRemoveWave);
	self.removeWave.anchorTop = false
	self.removeWave.anchorBottom = true
	self.removeWave:initialise();
	self.removeWave:instantiate();
	self.removeWave.borderColor = {r=1, g=0, b=0, a=0.4};
	self.removeWave.enable = false
	self.removeWave.tooltip = 'Remove selected wave entry'

	self:addChild(self.removeWave);
	self.closeButton2 = ISButton:new(self.removeWave.x + btnWid + 5, self.height - 50, 80, btnHgt, "Close", self, WaveCasterPanel.close);
	self.closeButton2.anchorTop = false
	self.closeButton2.anchorBottom = true
	self.closeButton2:initialise();
	self.closeButton2:instantiate();
	self.closeButton2.borderColor = {r=1, g=0, b=0, a=0.1};
	self.closeButton2.background = {r=0.1, g=0.1, b=0.1, a=1};
	self:addChild(self.closeButton2);
end
------------------------            ---------------------------
function WaveCasterPanel:onSpawn()
	local count = self:getZombiesNumber()
	local radius = self:getRadius()
	local outfit = self:getOutfit()
	local femaleChance = nil
	local knockedDown = false
	local crawler = false
	local isFallOnFront = false
	local isFakeDead = false
	if self.maleOutfits:contains(outfit) and not self.femaleOutfits:contains(outfit) then
		femaleChance = 0
	end
	if self.femaleOutfits:contains(outfit) and not self.maleOutfits:contains(outfit) then
		femaleChance = 100
	end
	if self.leftBoolOptions.selected[1] then
		knockedDown = true
	end
	if self.leftBoolOptions.selected[2] then
		crawler = true
	end
	if self.rightBoolOptions.selected[1] then
		isFakeDead = true
	end
	if self.rightBoolOptions.selected[2] then
		isFallOnFront = true
	end
	local health = self.healthSlider:getCurrentValue()
	--local castRadius = WaveCasterPanel:getCastRadius()
	local castRadius = self:getCastRadius()
	if not (self.selectX and self.selectY) then return end
	if isClient() then
		SendCommandToServer(string.format("/createhorde2 -x %d -y %d -z %d -count %d -radius %d -crawler %s -isFallOnFront %s -isFakeDead %s -knockedDown %s -health %s -outfit %s ",
		self.selectX, self.selectY, self.selectZ, count, radius, tostring(crawler), tostring(isFallOnFront), 
		tostring(isFakeDead), tostring(knockedDown), tostring(health), outfit or ""))
		return
	end
	for i=1,count do
		local x = ZombRand(self.selectX - castRadius, self.selectX + castRadius + 1)
		local y = ZombRand(self.selectY - castRadius, self.selectY + castRadius + 1)
		addZombiesInOutfit(x, y, self.selectZ, 1, outfit, femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, health)
	end
end
-----------------------            ---------------------------
function WaveCasterPanel:onCast()
	local castEvent = self:getCastEvent()
	if not castEvent then return end
	if not castEvent.Waves or #castEvent.Waves == 0 then return end
	castEvent.Countdown = 0
	WaveCaster.processWave(castEvent)
	WaveCaster.saveData(WaveCaster.Data)
	self:refreshWaveList()
end
-----------------------            ---------------------------
function WaveCasterPanel:onBoolOptionsChangeLeft(index, selected)
	if index == 1 then
		if not selected then
			self.leftBoolOptions.selected[2] = false
			self.rightBoolOptions.selected[1] = false
		end
	end
	if index == 2 then
		self.leftBoolOptions.selected[1] = selected
		if selected then
			self.rightBoolOptions.selected[2] = true
		end
	end
end
function WaveCasterPanel:onBoolOptionsChangeRight(index, selected)
	if index == 1 then
		self.leftBoolOptions.selected[1] = selected
	end
	if index == 2 then
		if not selected then
			self.leftBoolOptions.selected[2] = false
		end
	end
end
------------------------            ---------------------------
function WaveCasterPanel:onSliderChange(_newval, _slider)
	if _slider.valueLabel then
		_slider.valueLabel:setName(ISDebugUtils.printval(_newval,3));
	end
end
function WaveCasterPanel:onRadSliderChange(_newval, _slider)
	if _slider.valueLabel then
		_slider.valueLabel:setName(ISDebugUtils.printval(_newval,3));
	end
end
function WaveCasterPanel:getCastRadius()
	return tonumber(self.castRadiusSlider:getCurrentValue())
end
function WaveCasterPanel:getRadius()
	local radius = self.radius:getInternalText();
	return (tonumber(radius) or 1) - 1;
end
function WaveCasterPanel:getZombiesNumber()
	local nbr = self.zombiesNbr:getInternalText();
	return tonumber(nbr) or 1;
end
function WaveCasterPanel:getOutfit()
	return self.outfit.options[self.outfit.selected].data;
end
-----------------------            ---------------------------
function WaveCasterPanel:getEventKey()
	if not (self.castMidX and self.castMidY) then return end
	return string.format("%d_%d", self.castMidX, self.castMidY)
end
function WaveCasterPanel:getCastEvent()
	if not WaveCaster.Data then return end
	WaveCaster.Data.events = WaveCaster.Data.events or {}
	local key = self:getEventKey()
	if not key then return end
	return WaveCaster.Data.events[key]
end
-----------------------            ---------------------------

function WaveCasterPanel:onQueue()
	local key = self:getEventKey()
	if not key then return end
	local count = self:getZombiesNumber()
	local radius = self:getRadius()
	local outfit = self:getOutfit()
	local femaleChance = nil
	local knockedDown = false
	local crawler = false
	local isFallOnFront = false
	local isFakeDead = false
	if self.maleOutfits:contains(outfit) and not self.femaleOutfits:contains(outfit) then
		femaleChance = 0
	end
	if self.femaleOutfits:contains(outfit) and not self.maleOutfits:contains(outfit) then
		femaleChance = 100
	end
	if self.leftBoolOptions.selected[1] then
		knockedDown = true
	end
	if self.leftBoolOptions.selected[2] then
		crawler = true
	end
	if self.rightBoolOptions.selected[1] then
		isFakeDead = true
	end
	if self.rightBoolOptions.selected[2] then
		isFallOnFront = true
	end
	local health = self.healthSlider:getCurrentValue()
	local delay = self.delaySlider:getCurrentValue()
	local castRadius = self.castRadiusSlider:getCurrentValue()
	WaveCaster.Data.events = WaveCaster.Data.events or {}
	local castEvent = WaveCaster.Data.events[key]
	if not castEvent then
		castEvent = {
			CastX = self.castMidX,
			CastY = self.castMidY,
						CastZ = 0,
			Countdown = 0,
			Waves = {},
		}
		WaveCaster.Data.events[key] = castEvent
	end
	castEvent.Waves = castEvent.Waves or {}
	local wave = {
		Delay = delay,
		CastRadius = castRadius,
		WaveX = self.selectX,
		WaveY = self.selectY,
		WaveZ = self.selectZ,
		ZData = {
			count = count,
			radius = radius,
			outfit = outfit,
			femaleChance = femaleChance,
			crawler = crawler,
			isFallOnFront = isFallOnFront,
			isFakeDead = isFakeDead,
			knockedDown = knockedDown,
			health = health,
		}
	}
	table.insert(castEvent.Waves, wave)
	if #castEvent.Waves == 1 then
		castEvent.Countdown = wave.Delay
	end
	WaveCaster.saveData(WaveCaster.Data)
	self:refreshWaveList()
end
-----------------------            ---------------------------
function WaveCasterPanel:refreshWaveList()
    self.waveList:clear()
    local castEvent = self:getCastEvent()
    if not castEvent or not castEvent.Waves then return end
    for i, wave in ipairs(castEvent.Waves) do
        local flags = {}
        if wave.ZData.knockedDown then table.insert(flags, "KD") end
        if wave.ZData.crawler then table.insert(flags, "CR") end
        if wave.ZData.isFakeDead then table.insert(flags, "FD") end
        if wave.ZData.isFallOnFront then table.insert(flags, "FF") end
        self.waveList:addItem("", {
            Number = i,
            Outfit = wave.ZData.outfit or "None",
            Count = wave.ZData.count,
            Radius = wave.CastRadius,
            Delay = wave.Delay,
			WaveX = wave.WaveX,
			WaveY = wave.WaveY,
			WaveZ = wave.WaveZ,
            MidSq = string.format("%d,%d", self.castMidX or 0, self.castMidY or 0),
            Flags = table.concat(flags, ","),
            Wave = wave,
        })
    end
end
function WaveCasterPanel:drawWaveItem(y, item, alt)
    local data = item.item
    if self.waveList.selected == item.index then
        self.waveList:drawRect(0, y, self.waveList.width, self.waveList.itemheight, 0.3, 0.3, 0.15, 0.0)
    elseif alt then
        self.waveList:drawRect(0, y, self.waveList.width, self.waveList.itemheight, 0.1, 1, 1, 1)
    end
    self.waveList:drawText("#"..tostring(data.Number), 5, y + 2, 1,1,1,1, UIFont.Small)
    self.waveList:drawText(tostring(data.Outfit), 35, y + 2, 1,1,1,1, UIFont.Small)
    self.waveList:drawText(tostring(data.Count), 170, y + 2, 1,1,1,1, UIFont.Small)
    self.waveList:drawText(tostring(data.Radius), 240, y + 2, 1,1,1,1, UIFont.Small)
    self.waveList:drawText(tostring(data.Delay), 310, y + 2, 1,1,1,1, UIFont.Small)
    self.waveList:drawText(tostring(data.MidSq), 360, y + 2, 1,1,1,1, UIFont.Small)
    self.waveList:drawText(tostring(data.Flags), 500, y + 2, 1,1,1,1, UIFont.Small)
    return y + self.waveList.itemheight
end
function WaveCasterPanel:onWaveListClick(item)
    if not item then return end
    local wave = item.Wave
    if not wave then return end
    self.zombiesNbr:setText(tostring(wave.ZData.count))
    self.healthSlider:setCurrentValue(wave.ZData.health)
    self.radius:setText(tostring(wave.ZData.radius))
    self.castRadiusSlider:setCurrentValue(wave.CastRadius)
    self.delaySlider:setCurrentValue(wave.Delay)
    self.leftBoolOptions.selected[1] = wave.ZData.knockedDown
    self.leftBoolOptions.selected[2] = wave.ZData.crawler
    self.rightBoolOptions.selected[1] = wave.ZData.isFakeDead
    self.rightBoolOptions.selected[2] = wave.ZData.isFallOnFront
    self.removeWave.enable = true
end
function WaveCasterPanel:prerender()
	ISCollapsableWindow.prerender(self)
	local castRadius = self.castRadiusSlider:getCurrentValue()
	local castRadius = self.castRadiusSlider:getCurrentValue()
	if self.marker and self.marker:getSize() ~= castRadius then
		self.marker:setSize(castRadius)
	end
	local castEvent = self:getCastEvent()
	local hasWaves = castEvent and castEvent.Waves and #castEvent.Waves > 0
	self.queue.enable = (self.castMidX ~= nil and self.castMidY ~= nil)
	self.add.enable = (self.selectX ~= nil and self.selectY ~= nil)
	self.castWave.enable = hasWaves and true or false
	self.removeWave.enable = hasWaves and true or false
end

function WaveCasterPanel:onSelectNewSquare()
	self.cursor = ISSelectCursor:new(self.chr, self, self.onSquareSelected)
	getCell():setDrag(self.cursor, self.chr:getPlayerNum())
end
-----------------------            ---------------------------
function WaveCasterPanel:onSquareSelected(sq)
	self.cursor = nil;
	self:removeMarker();
	self.selectX = sq:getX();
	self.selectY = sq:getY();
	self.selectZ = sq:getZ();
	self.castMidX, self.castMidY = WaveCaster.getBldgMidXY(sq:getX(), sq:getY());
	if self.castMidX and self.castMidY then
		local midSq = getCell():getOrCreateGridSquare(self.castMidX, self.castMidY, 0)
		if midSq then
			self:addMarker(midSq, self.castRadiusSlider:getCurrentValue());
		end
	end
	self:addPickMarker(sq);
	self:refreshWaveList()
end
function WaveCasterPanel:refreshData()
    self:refreshWaveList()
end
-----------------------            ---------------------------
function WaveCasterPanel:addMarker(sq, rad)	
	local mCol = WaveCaster.midColor	
	WaveCaster.PanelMarker =  getWorldMarkers():addGridSquareMarker(sq, mCol.r, mCol.g, mCol.b, true, rad);
	self.marker = WaveCaster.PanelMarker
	self.marker:setScaleCircleTexture(true);
end
function WaveCasterPanel:addPickMarker(sq)
	local pCol = WaveCaster.pickedColor
	self.pickMarker = getWorldMarkers():addGridSquareMarker(sq, pCol.r, pCol.g, pCol.b, true, 0.5);
end

-----------------------    remove*        ---------------------------

function WaveCasterPanel:removeMarker()
	if self.marker then
		self.marker:remove();
		self.marker = nil;
	end
	if self.pickMarker then
		self.pickMarker:remove()
		self.pickMarker = nil
	end
end

function WaveCasterPanel:onRemoveWave()
	local castEvent = self:getCastEvent()
	if not castEvent or not castEvent.Waves then return end
	local index = self.waveList.selected
	if not index or index < 1 or index > #castEvent.Waves then return end
	table.remove(castEvent.Waves, index)
	if castEvent.Waves[1] then
		castEvent.Countdown = castEvent.Waves[1].Delay
	else
		castEvent.Countdown = 0
	end
	WaveCaster.saveData(WaveCaster.Data)
	self:refreshWaveList()
end
--#A5D6F0

function WaveCasterPanel:onRemoveBodies()
	--local radius = self:getRadius() + 1
	local radius = self:getCastRadius() + 1

	if isClient() then
		SendCommandToServer(string.format("/removezombies -x %d -y %d -z %d -radius %d -clear true", self.selectX, self.selectY, self.selectZ, radius))
	else
		local cell = getCell()
		for x = self.selectX - radius, self.selectX + radius+1 do
			for y = self.selectY - radius, self.selectY + radius+1 do
				if IsoUtils.DistanceTo(self.selectX, self.selectY, x+0.5, y+0.5) <= radius then
					local sq = cell:getGridSquare(x, y, self.selectZ)
					local bodies = {}
					for i=0, sq:getStaticMovingObjects():size()-1 do
						if instanceof(sq:getStaticMovingObjects():get(i), "IsoDeadBody") then
							table.insert(bodies, sq:getStaticMovingObjects():get(i))
						end
					end
					for i, body in ipairs(bodies) do
						sq:removeCorpse(body, false);
					end
				end
			end
		end
	end
end

function WaveCasterPanel:onRemoveZombies()
	--local radius = self:getRadius() + 1
	local radius = self:getCastRadius() + 1

	if not (self.selectX and self.selectY) then return end
	if isClient() then
		SendCommandToServer(string.format("/removezombies -x %d -y %d -z %d -radius %d", self.selectX, self.selectY, self.selectZ, radius))
		return
	end
	for x=self.selectX-radius, self.selectX + radius do
		for y=self.selectY-radius, self.selectY + radius do
			local sq = getCell():getGridSquare(x,y,self.selectZ);
			if sq then
				for i=sq:getMovingObjects():size(),1,-1 do
					local testZed = sq:getMovingObjects():get(i-1);
					if instanceof(testZed, "IsoZombie") then
						testZed:removeFromWorld();
						testZed:removeFromSquare();
					end
				end
			end
		end
	end
end
-----------------------            ---------------------------
function WaveCasterPanel:close()
    if self.childEditor then
        if self.childEditor.onCancel then
            self.childEditor:onCancel()
        else
            self.childEditor:close()
        end
        self.childEditor = nil
    end
    self:removeMarker();
    self:setVisible(false)
    self:removeFromUIManager()
end
function WaveCaster.panel(activate)
    activate = activate or true
    if WaveCasterPanel.instance then
        WaveCasterPanel.instance:close()
        WaveCasterPanel.instance = nil
    end
    if activate then
        local pl = getPlayer() 
        local sq = pl:getSquare()
        if not pl or not sq then return end
        local width = 900;
        local height = 400;
        local x = (getCore():getScreenWidth() - width) / 2 - 300
        local y = (getCore():getScreenHeight() - height) / 2
        local editor = WaveCasterPanel:new(x, y, width, height, pl, sq )
        editor:initialise()
        editor:addToUIManager()
		WaveCasterPanel.instance = editor
    end
end
--[[ 
WaveCaster.panel(true)
 ]]