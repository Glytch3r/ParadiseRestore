require "ISUI/ISPanelJoypad"
WaveCaster = WaveCaster or {}
WaveCasterPanel = ISCollapsableWindow:derive("WaveCasterPanel");
WaveCaster.midColor = { r = 1.00, g = 0.48, b = 0.45 }
WaveCaster.pickedColor = { r = 0.65, g = 0.84, b = 0.94 }
WaveCaster.ZedSkins = { "F_ZedBody01_level1", "F_ZedBody01_level2", "F_ZedBody01_level3", "F_ZedBody01", "F_ZedBody02_level1", "F_ZedBody02_level2", "F_ZedBody02_level3", "F_ZedBody02", "F_ZedBody03_level1", "F_ZedBody03_level2", "F_ZedBody03_level3", "F_ZedBody03", "F_ZedBody04_level1", "F_ZedBody04_level2", "F_ZedBody04_level3", "F_ZedBody04", "M_ZedBody01_level1", "M_ZedBody01_level2", "M_ZedBody01_level3", "M_ZedBody01", "M_ZedBody02_level1", "M_ZedBody02_level2", "M_ZedBody02_level3", "M_ZedBody02", "M_ZedBody03_level1", "M_ZedBody03_level2", "M_ZedBody03_level3", "M_ZedBody03", "M_ZedBody04_level1", "M_ZedBody04_level2", "M_ZedBody04_level3", "M_ZedBody04" }
WaveCaster.HumanSkins = { "FemaleBody01", "FemaleBody02", "FemaleBody03", "FemaleBody04", "FemaleBody05", "MaleBody01", "MaleBody01a", "MaleBody02", "MaleBody02a", "MaleBody03", "MaleBody03a", "MaleBody04", "MaleBody04a", "MaleBody05", "MaleBody05a" }
WaveCaster.SkeletonSkins = { "Skeleton_Mannequin", "Skeleton", "SkeletonBurned", "SkeletonMuscle", "F_Mannequin_White", "F_Mannequin_Black", "M_Mannequin_Black", "M_Mannequin_White", "Male_Scarecrow" }
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
        450,
        710,
        1,1,1,1,
        UIFont.Small
    )
    self:drawText(
        "NEXT WAVE:  \n[ " .. tostring(castEvent and castEvent.Countdown or 0)..' ]',
        600,
        710,
        1,1,1,1,
        UIFont.Small
    )
    self:drawText(
        "WAVES:  \n[ " .. tostring(castEvent and #castEvent.Waves or 0)..' ]',
        750,
        710,
        1,1,1,1,
        UIFont.Small
    )
--[[ 	local sqStr = "Picked Square: " .. self.selectX .. "," .. self.selectY .. "," .. self.selectZ--.. "  |   Cast Point: " .. self.castMidX .. "," ..  self.castMidY
	self:drawText(tostring(sqStr), 25, 15, 1, 1, 1, 1, self.font); ]]
end

function WaveCasterPanel:new(x, y, width, height, character, sq)

	width = width or 1020;
	height = height or 860;

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
	o.castX, o.castY = sq:getX(), sq:getY();
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
    o.backgroundColor = { r = 0.47, g = 0.27, b = 0.14 , a=0.4}
	o.selectX = sq:getX();
	o.selectY = sq:getY();
	o.selectZ = sq:getZ();
	if o.castX and o.castY then
		local castSq = getCell():getOrCreateGridSquare(o.castX, o.castY, o.selectZ)
		if castSq then
			--o:addMarker(castSq, 1);
		end
	end
	o:addPickMarker(sq);
	return o;
end
function WaveCasterPanel:createChildren()
	local btnWid = 100
	local btnHgt = 25
	local padBottom = 0
	local y = 365
	local f = 0.8
	local leftWidth = 420

	local mCol = WaveCaster.midColor
	local pCol = WaveCaster.pickedColor

	ISCollapsableWindow.createChildren(self)
	local labelY =112
	self.zombiesNbrLabel = ISLabel:new(130, labelY, 10, "Zombies Number" ,1,1,1,1,UIFont.Small, true);
	self:addChild(self.zombiesNbrLabel);
	self.zombiesNbr = ISTextEntryBox:new("1", self.zombiesNbrLabel.x, labelY + 15, 100, 20);
	self.zombiesNbr:initialise();
	self.zombiesNbr:instantiate();
	self.zombiesNbr:setOnlyNumbers(true);
	self:addChild(self.zombiesNbr);
	
	self.radiusLbl = ISLabel:new(315, 50, 10, "Wave Radius" ,1,1,1,1,UIFont.Small, true);
	self:addChild(self.radiusLbl);
	
	self.radius = ISTextEntryBox:new("1", self.radiusLbl.x, 66, 100, 20);
	self.radius:initialise();
	self.radius:instantiate();
	self.radius:setOnlyNumbers(true);
	self.radius.backgroundColor.r = mCol.r
	self.radius.backgroundColor.g = mCol.g
	self.radius.backgroundColor.b = mCol.b

	self:addChild(self.radius);
--**
	self.outfitLbl = ISLabel:new(254, labelY, 10, "Zombies Outfit" ,1,1,1,1,UIFont.Small, true);
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
	self.skinLabel = ISLabel:new(254, 158, 10, "Skin Texture", 1, 1, 1, 1, UIFont.Small, true)
	self.skinLabel:initialise()
	self:addChild(self.skinLabel)
	self.skin = ISComboBox:new(254, 175, 160, 20)
	self.skin:initialise()
	self:addChild(self.skin)
	self.humanizeOption = ISTickBox:new(254, 202, 95, 20, "", self, WaveCasterPanel.onSkinOptionsChanged)
	self.humanizeOption:initialise()
	self.humanizeOption.choicesColor = {r=0, g=1, b=0.6, a=1}
	self.humanizeOption:addOption("Humanize")
	self:addChild(self.humanizeOption)
	self.randomAnyOption = ISTickBox:new(344, 202, 95, 20, "", self, WaveCasterPanel.onSkinOptionsChanged)
	self.randomAnyOption:initialise()
	self.randomAnyOption.choicesColor = {r=0, g=1, b=0.6, a=1}
	self.randomAnyOption:addOption("Random Any")
	self:addChild(self.randomAnyOption)
	self.copyVisualOption = ISTickBox:new(254, 227, 160, 20, "", self, nil)
	self.copyVisualOption:initialise()
	self.copyVisualOption.choicesColor = {r=0, g=1, b=0.6, a=1}
	self.copyVisualOption:addOption("Copy Player Visual")
	self:addChild(self.copyVisualOption)
	self:refreshSkinOptions()
	
	
	self.turnDeltaLabel = ISLabel:new(40, 198, 10, "Turn Delta", 1, 1, 1, 1, UIFont.Small, true);
	self:addChild(self.turnDeltaLabel)
	self.turnDelta = ISTextEntryBox:new("1", 40, 215, 82, 20);
	self.turnDelta:initialise();
	self.turnDelta:instantiate();
	self.turnDelta:setOnlyNumbers(true);
	self:addChild(self.turnDelta);
	self.spawnDelayLabel = ISLabel:new(130, 198, 10, "Spawn Delay", 1, 1, 1, 1, UIFont.Small, true);
	self:addChild(self.spawnDelayLabel)
	self.spawnDelay = ISTextEntryBox:new("5", 130, 215, 82, 20);
	self.spawnDelay:initialise();
	self.spawnDelay:instantiate();
	self.spawnDelay:setOnlyNumbers(true);
	self:addChild(self.spawnDelay);
	self.walkTypeLabel = ISLabel:new(40, 245, 10, "Walktype", 1, 1, 1, 1, UIFont.Small, true);
	self:addChild(self.walkTypeLabel)
	self.walkType = ISComboBox:new(40, 262, 80, 20)
	self.walkType:initialise()
	self:addChild(self.walkType)
	for _, walkType in ipairs({ "slow1", "slow2", "slow3", "1", "2", "3", "4", "5", "sprint1", "sprint2", "sprint3", "sprint4", "sprint5" }) do
		self.walkType:addOptionWithData(walkType, walkType)
	end
	self.walkType:setSelected(4)
	self.voiceLabel = ISLabel:new(130, 245, 10, "Voice", 1, 1, 1, 1, UIFont.Small, true)
	self.voiceLabel:initialise()
	self:addChild(self.voiceLabel)
	self.voice = ISComboBox:new(130, 262, 80, 20)
	self.voice:initialise()
	self.voice:addOptionWithData("Random", nil)
	self.voice:addOptionWithData("1", 1)
	self.voice:addOptionWithData("2", 2)
	self.voice:addOptionWithData("3", 3)
	self.voice:setSelected(1)
	self:addChild(self.voice)
	self.zombieStats = {}
	for _, stat in ipairs({
		{ key = "strength", label = "Strength", x = 40, y = 290, options = { { "Default", nil }, { "Weak", 1 }, { "Normal", 3 }, { "Superhuman", 5 } } },
		{ key = "cognition", label = "Cognition", x = 130, y = 290, options = { { "Default", nil }, { "Cannot Open", 0 }, { "Can Open", 1 } } },
		{ key = "memory", label = "Memory", x = 220, y = 290, options = { { "Default", nil }, { "Long", 1250 }, { "Normal", 800 }, { "Short", 500 }, { "None", 25 } } },
		{ key = "sight", label = "Sight", x = 310, y = 290, options = { { "Default", nil }, { "Eagle", 1 }, { "Normal", 2 }, { "Poor", 3 } } },
		{ key = "hearing", label = "Hearing", x = 40, y = 335, options = { { "Default", nil }, { "Pinpoint", 1 }, { "Normal", 2 }, { "Poor", 3 } } },
	}) do
		local label = ISLabel:new(stat.x, stat.y, 10, stat.label, 1, 1, 1, 1, UIFont.Small, true)
		label:initialise()
		self:addChild(label)
		local combo = ISComboBox:new(stat.x, stat.y + 17, 80, 20)
		combo:initialise()
		for _, option in ipairs(stat.options) do combo:addOptionWithData(option[1], option[2]) end
		combo:setSelected(1)
		self:addChild(combo)
		self.zombieStats[stat.key] = combo
	end

	y = 410
	self.leftBoolOptions = ISTickBox:new(40, y, 180, 20, "", self, WaveCasterPanel.onBoolOptionsChangeLeft);
	self.leftBoolOptions:initialise()
	self.leftBoolOptions.choicesColor = {r=0, g=1, b=0.6, a=1};
	self:addChild(self.leftBoolOptions)
	self.leftBoolOptions:addOption("KnockedDown");
	self.leftBoolOptions:addOption("Crawler");
	self.rightBoolOptions = ISTickBox:new(254, y, 180, 20, "", self, WaveCasterPanel.onBoolOptionsChangeRight);
	self.rightBoolOptions:initialise()
	self:addChild(self.rightBoolOptions)
	self.rightBoolOptions.choicesColor = {r=0, g=1, b=0.6, a=1};
	self.rightBoolOptions:addOption("FakeDead");
	self.rightBoolOptions:addOption("FallOnFront");
	self.vanillaBoolOptions = ISTickBox:new(40, y + 55, 180, 20, "", self, nil);
	self.vanillaBoolOptions:initialise()
	self.vanillaBoolOptions.choicesColor = {r=0, g=1, b=0.6, a=1};
	self:addChild(self.vanillaBoolOptions)
	self.vanillaBoolOptions:addOption("Invulnerable");
	self.vanillaBoolOptions:addOption("Sitting");
	self.vanillaBoolOptions:addOption("On Fire");
	self.leftExtraBoolOptions = ISTickBox:new(40, y + 165, 180, 20, "", self, WaveCasterPanel.onSkinOptionsChanged);
	self.leftExtraBoolOptions:initialise()
	self.leftExtraBoolOptions.choicesColor = {r=0, g=1, b=0.6, a=1};
	self:addChild(self.leftExtraBoolOptions)
	self.leftExtraBoolOptions:addOption("Skeleton");
	self.leftExtraBoolOptions:addOption("Force Eating");
	self.leftExtraBoolOptions:addOption("Always Knocked Down");
	self.leftExtraBoolOptions:addOption("Can Walk");
	self.leftExtraBoolOptions:addOption("Crawl Under Vehicle");
	self.leftExtraBoolOptions:addOption("Sit Against Wall");
	self.extraBoolOptions = ISTickBox:new(254, y + 55, 180, 20, "", self, WaveCasterPanel.onExtraBoolOptionsChange);
	self.extraBoolOptions:initialise()
	self.extraBoolOptions.choicesColor = {r=0, g=1, b=0.6, a=1};
	self:addChild(self.extraBoolOptions)
	self.extraBoolOptions:addOption("Immortal Tutorial");
	self.extraBoolOptions:addOption("Useless");
	self.extraBoolOptions:addOption("Random Blood/Dirt/Holes");
	self.extraBoolOptions:addOption("Knife Death");
	self.extraBoolOptions:addOption("No Teeth");
	self.extraBoolOptions:addOption("Jaw Stab Attach");
	self.extraBoolOptions:addOption("Only Jaw Stab");
	self.stateBoolOptions = ISTickBox:new(254, y + 225, 180, 20, "", self, nil)
	self.stateBoolOptions:initialise()
	self.stateBoolOptions.choicesColor = {r=0, g=1, b=0.6, a=1}
	self:addChild(self.stateBoolOptions)
	self.stateBoolOptions:addOption("Inactive")
	self.stateBoolOptions:addOption("Reanimated Player")
	self.stateBoolOptions:addOption("Scratch")
	self.stateBoolOptions:addOption("Laceration")
	self.stateBoolOptions:addOption("Keep It Real")
	self.healthLabel = ISLabel:new(55, labelY, 10, "Health", 1, 1, 1, 1, UIFont.Small, true)
	self.healthLabel:initialise()
	self:addChild(self.healthLabel)
	self.health = ISTextEntryBox:new("1", 55, labelY + 15, 80, 20)
	self.health:initialise()
	self.health:instantiate()
	self.health:setOnlyNumbers(true)
	self:addChild(self.health)
	
	self.pickNewSq = ISButton:new(35, 30, btnWid+25, btnHgt+25, "Pick Cast Point", self, WaveCasterPanel.onSelectNewSquare);
	self.pickNewSq.anchorTop = false
	self.pickNewSq.anchorBottom = true
	self.pickNewSq:initialise();
	self.pickNewSq:instantiate();
	self.pickNewSq.backgroundColor = {r=pCol.r, g=pCol.g, b=pCol.b, a=0.6};
	self.pickNewSq.borderColor = {r=pCol.r, g=pCol.g, b=pCol.b, a=0.6};
	self:addChild(self.pickNewSq);
	self.pickWalkTarget = ISButton:new(35, 85, btnWid+25, 20, "Pick Target Square", self, WaveCasterPanel.onSelectWalkTarget)
	self.pickWalkTarget:initialise()
	self.pickWalkTarget:instantiate()
	self.pickWalkTarget.backgroundColor = {r=pCol.r, g=pCol.g, b=pCol.b, a=0.6}
	self.pickWalkTarget.borderColor = {r=pCol.r, g=pCol.g, b=pCol.b, a=0.6}
	self:addChild(self.pickWalkTarget)
	self.walkTargetLabel = ISLabel:new(195, 100, 10, "Target Square: None", pCol.r, pCol.g, pCol.b, 1, UIFont.Small, true)
	self.walkTargetLabel:initialise()
	self:addChild(self.walkTargetLabel)
	self.pickedSquareLabel = ISLabel:new(195, 30, 10, "Cast Point", pCol.r, pCol.g, pCol.b, 1, UIFont.Small, true)
	self.pickedSquareLabel:initialise()
	self:addChild(self.pickedSquareLabel)
	for _, entry in ipairs({
		{ name = "X", value = self.selectX, y = 47 },
		{ name = "Y", value = self.selectY, y = 64 },
		{ name = "Z", value = self.selectZ, y = 81 },
	}) do
		local label = ISLabel:new(195, entry.y, 10, entry.name .. ":", pCol.r, pCol.g, pCol.b, 1, UIFont.Small, true)
		label:initialise()
		self:addChild(label)
		local input = ISTextEntryBox:new(tostring(entry.value), 215, entry.y - 2, 80, 18)
		input:initialise()
		input:instantiate()
		self:addChild(input)
		if entry.name == "X" then self.selectXEntry = input end
		if entry.name == "Y" then self.selectYEntry = input end
		if entry.name == "Z" then self.selectZEntry = input end
	end



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
	self.add = ISButton:new(40, 760, btnWid*f, btnHgt, "Cast Now", self, WaveCasterPanel.onSpawn);
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
	self.waveListTitle = ISLabel:new(leftWidth + 20, 28, 20, "Wave List" ,1,1,1,1,UIFont.Large, true);
	self:addChild(self.waveListTitle);
	self.waveList = ISScrollingListBox:new(leftWidth + 10, 75, self.width - leftWidth - 20, self.height - 230)
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
	self.waveList:addColumn("Cast Point", 360)
	self.waveList:addColumn("Target", 455)
	self.waveList.doDrawItem = function(box, y, item, alt)
		return self:drawWaveItem(y, item, alt)
	end
	self.waveList:setOnMouseDownFunction(self, WaveCasterPanel.onWaveListClick)
	self:addChild(self.waveList)
	self.castWave = ISButton:new(40, 790, btnWid, btnHgt, "Cast Wave", self, WaveCasterPanel.onCast);
	self.castWave.anchorTop = false
	self.castWave.anchorBottom = true
	self.castWave:initialise();
	self.castWave:instantiate();
	self.castWave.borderColor = {r=1, g=1, b=1, a=0.1};
	self.castWave.enable = false
	self.castWave.tooltip = 'Forces the first wave to trigger by setting the countdown timer to 0'
	self:addChild(self.castWave);
	self.removeZombies = ISButton:new(40, 760, btnWid, btnHgt, getText("IGUI_SpawnHorde_RemoveZombies"), self, WaveCasterPanel.onRemoveZombies);
	self.removeZombies.anchorTop = false
	self.removeZombies.anchorBottom = true
	self.removeZombies:initialise();
	self.removeZombies:instantiate();
	self.removeZombies.borderColor = {r=1, g=1, b=1, a=0.1};
	self.removeZombies.tooltip = 'Hold Shift to remove all loaded zombies.'
	self:addChild(self.removeZombies);
	self.removeBodies = ISButton:new(40, 730, btnWid, btnHgt, getText("IGUI_SpawnHorde_RemoveBodies"), self, WaveCasterPanel.onRemoveBodies);
	self.removeBodies.anchorTop = false
	self.removeBodies.anchorBottom = true
	self.removeBodies:initialise();
	self.removeBodies:instantiate();
	self.removeBodies.borderColor = {r=1, g=1, b=1, a=0.1};
	self.removeBodies.tooltip = 'Remove corpses within the Cast Point radius.'
	self:addChild(self.removeBodies);
	self.queue = ISButton:new(253, 760, btnWid*f, btnHgt, "Add Queue", self, WaveCasterPanel.onQueue);
	self.queue.anchorTop = false
	self.queue.anchorBottom = true
	self.queue:initialise();
	self.queue:instantiate();
	self.queue.borderColor = {r=1, g=0, b=0, a=0.2};
	self.queue.tooltip = 'Add a wave to the queue list based on your settings'

	self:addChild(self.queue);
	self.removeWave = ISButton:new(253, 790, btnWid, btnHgt, "Remove Wave", self, WaveCasterPanel.onRemoveWave);
	self.removeWave.anchorTop = false
	self.removeWave.anchorBottom = true
	self.removeWave:initialise();
	self.removeWave:instantiate();
	self.removeWave.borderColor = {r=1, g=0, b=0, a=0.4};
	self.removeWave.enable = false
	self.removeWave.tooltip = 'Remove selected wave entry'

	self:addChild(self.removeWave);
end
------------------------            ---------------------------
function WaveCasterPanel:onSpawn()
	if not self:applyTypedSquare() then return end
	local zd = self:getZData()
	local count = zd.count
	local radius = zd.radius
	local outfit = zd.outfit
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
	local health = zd.health
	--local castRadius = WaveCasterPanel:getCastRadius()
	local castRadius = self:getCastRadius()
	if not (self.selectX and self.selectY) then return end
	if isClient() then
		sendClientCommand("WaveCaster", "Spawn", { x = self.selectX, y = self.selectY, z = self.selectZ, zedData = zd, femaleChance = femaleChance })
		return
	end
	for i=1,count do
		local x = ZombRand(self.selectX - castRadius, self.selectX + castRadius + 1)
		local y = ZombRand(self.selectY - castRadius, self.selectY + castRadius + 1)
		local zeds = addZombiesInOutfit(x, y, self.selectZ, 1, outfit, femaleChance, crawler, isFallOnFront, isFakeDead, knockedDown, zd.isInvulnerable, zd.isSitting, health, zd.isRecordingAnims, zd.heightOffset, false, zd.onFire)
		for j = 0, zeds:size() - 1 do
			WaveCaster.applyZedData(zeds:get(j), zd, self.selectX, self.selectY)
		end
	end
end
-----------------------            ---------------------------
function WaveCasterPanel:onCast()
	if not self:applyTypedSquare() then return end
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
		self.walkType.enable = not selected
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
	return self:getRadius()
end
function WaveCasterPanel:getRadius()
	local radius = self.radius:getInternalText();
	return (tonumber(radius) or 1) - 1;
end
function WaveCasterPanel:getZombiesNumber()
	local nbr = self.zombiesNbr:getInternalText();
	return tonumber(nbr) or 1;
end
function WaveCasterPanel:onExtraBoolOptionsChange(index, selected)
	if index == 4 and selected then
		self.rightBoolOptions.selected[1] = true
	end
end
function WaveCasterPanel:getHealth()
	return tonumber(self.health:getInternalText()) or 1
end
function WaveCasterPanel:getOutfit()
	return self.outfit.options[self.outfit.selected].data;
end
function WaveCasterPanel:getWalkType()
	local option = self.walkType.options[self.walkType.selected]
	return option and option.data or "1"
end
function WaveCasterPanel:setWalkType(value)
	value = tostring(value or "1")
	for index, option in ipairs(self.walkType.options) do
		if option.data == value then
			self.walkType:setSelected(index)
			return
		end
	end
	self.walkType:setSelected(4)
end
function WaveCasterPanel:onSkinOptionsChanged()
	if self.humanizeOption.selected[1] then self.randomAnyOption.selected[1] = false end
	self:refreshSkinOptions()
end
function WaveCasterPanel:refreshSkinOptions(selectedSkin)
	selectedSkin = selectedSkin or (self.skin.options[self.skin.selected] and self.skin.options[self.skin.selected].data) or "Random Zed"
	self.skin:clear()
	if not (self.humanizeOption and self.humanizeOption.selected[1]) then
		self.skin:addOptionWithData("Random Zed", "Random Zed")
		for _, skin in ipairs(WaveCaster.ZedSkins) do self.skin:addOptionWithData(skin, skin) end
	end
	if self.leftExtraBoolOptions and self.leftExtraBoolOptions.selected[1] then
		self.skin:addOptionWithData("Random Skeleton", "Random Skeleton")
		for _, skin in ipairs(WaveCaster.SkeletonSkins) do self.skin:addOptionWithData(skin, skin) end
	end
	if self.humanizeOption and self.humanizeOption.selected[1] then
		self.skin:addOptionWithData("Random Human", "Random Human")
		for _, skin in ipairs(WaveCaster.HumanSkins) do self.skin:addOptionWithData(skin, skin) end
	end
	if self.randomAnyOption and self.randomAnyOption.selected[1] and not (self.humanizeOption and self.humanizeOption.selected[1]) then self.skin:addOptionWithData("Random Any", "Random Any") end
	for index, option in ipairs(self.skin.options) do
		if option.data == selectedSkin then self.skin:setSelected(index); return end
	end
	self.skin:setSelected(1)
end
function WaveCasterPanel:getSkin()
	local option = self.skin.options[self.skin.selected]
	return option and option.data or "Random Zed"
end
function WaveCasterPanel:getStatValue(key)
	local combo = self.zombieStats[key]
	local option = combo and combo.options[combo.selected]
	return option and option.data or nil
end
function WaveCasterPanel:setStatValue(key, value)
	local combo = self.zombieStats[key]
	if not combo then return end
	for index, option in ipairs(combo.options) do
		if option.data == value then combo:setSelected(index); return end
	end
	combo:setSelected(1)
end
function WaveCasterPanel:getVoice()
	local option = self.voice.options[self.voice.selected]
	return option and option.data or nil
end
function WaveCasterPanel:getZData()
	return {
		count = self:getZombiesNumber(), radius = self:getRadius(), outfit = self:getOutfit(), health = self:getHealth(), skin = self:getSkin(),
		knockedDown = self.leftBoolOptions.selected[1] or false, crawler = self.leftBoolOptions.selected[2] or false,
		isFakeDead = self.rightBoolOptions.selected[1] or self.extraBoolOptions.selected[4] or false, isFallOnFront = self.rightBoolOptions.selected[2] or false,
		isInvulnerable = self.vanillaBoolOptions.selected[1] or false, isSitting = self.vanillaBoolOptions.selected[2] or false,
		isRecordingAnims = false, heightOffset = 0,
		onFire = self.vanillaBoolOptions.selected[3] or false,
		walkType = self.leftBoolOptions.selected[2] and "" or self:getWalkType(), turnDelta = tonumber(self.turnDelta:getInternalText()),
		immortalTutorialZombie = self.extraBoolOptions.selected[1] or false, randomOutfit = false, humanize = self.humanizeOption.selected[1] or false, copyVisual = self.copyVisualOption.selected[1] or false,
		useless = self.extraBoolOptions.selected[2] or false, randomBloodDirtHoles = self.extraBoolOptions.selected[3] or false,
		knifeDeath = self.extraBoolOptions.selected[4] or false, noTeeth = self.extraBoolOptions.selected[5] or false,
		jawStabAttach = self.extraBoolOptions.selected[6] or false, onlyJawStab = self.extraBoolOptions.selected[7] or false,
		forceEatingAnimation = self.leftExtraBoolOptions.selected[2] or false,
		alwaysKnockedDown = self.leftExtraBoolOptions.selected[3] or false, canWalk = self.leftExtraBoolOptions.selected[4] or false,
		canCrawlUnderVehicle = self.leftExtraBoolOptions.selected[5] or false, sitAgainstWall = self.leftExtraBoolOptions.selected[6] or false,
		skeleton = self.leftExtraBoolOptions.selected[1] or false, inactive = self.stateBoolOptions.selected[1] or false,
		reanimatedPlayer = self.stateBoolOptions.selected[2] or false, scratch = self.stateBoolOptions.selected[3] or false,
		laceration = self.stateBoolOptions.selected[4] or false, keepItReal = self.stateBoolOptions.selected[5] or false,
		strength = self:getStatValue("strength"), cognition = self:getStatValue("cognition"), memory = self:getStatValue("memory"),
		sight = self:getStatValue("sight"), hearing = self:getStatValue("hearing"), voice = self:getVoice(),
		walkTargetX = self.walkTargetX, walkTargetY = self.walkTargetY, walkTargetZ = self.walkTargetZ,
		becomeCrawler = false,
	}
end
-----------------------            ---------------------------
function WaveCasterPanel:getEventKey()
	if not (self.castX and self.castY) then return end
	return string.format("%d_%d", self.castX, self.castY)
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
	if not self:applyTypedSquare() then return end
	local key = self:getEventKey()
	if not key then return end
	local zd = self:getZData()
	local count = zd.count
	local radius = zd.radius
	local outfit = zd.outfit
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
	local health = self:getHealth()
	local delay = tonumber(self.spawnDelay:getInternalText()) or 5
	local castRadius = self:getCastRadius()
	WaveCaster.Data.events = WaveCaster.Data.events or {}
	local castEvent = WaveCaster.Data.events[key]
	if not castEvent then
		castEvent = {
			CastX = self.castX,
			CastY = self.castY,
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
		ZData = zd
	}
	wave.ZData.femaleChance = femaleChance
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
			CastPoint = string.format("%d,%d,%d", wave.WaveX or 0, wave.WaveY or 0, wave.WaveZ or 0),
			Target = wave.ZData.walkTargetX and string.format("%d,%d,%d", wave.ZData.walkTargetX, wave.ZData.walkTargetY, wave.ZData.walkTargetZ) or "None",
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
	self.waveList:drawText(tostring(data.CastPoint), 360, y + 2, 1,1,1,1, UIFont.Small)
	self.waveList:drawText(tostring(data.Target), 455, y + 2, 1,1,1,1, UIFont.Small)
    return y + self.waveList.itemheight
end
function WaveCasterPanel:onWaveListClick(item)
    if not item then return end
    local wave = item.Wave
    if not wave then return end
    self.zombiesNbr:setText(tostring(wave.ZData.count))
	self.health:setText(tostring(wave.ZData.health or 1))
	self.radius:setText(tostring((wave.CastRadius or wave.ZData.radius or 0) + 1))
	self.spawnDelay:setText(tostring(wave.Delay or 5))
    self.leftBoolOptions.selected[1] = wave.ZData.knockedDown
    self.leftBoolOptions.selected[2] = wave.ZData.crawler
	self.rightBoolOptions.selected[1] = wave.ZData.isFakeDead or wave.ZData.knifeDeath or false
	self.rightBoolOptions.selected[2] = wave.ZData.isFallOnFront
	self.vanillaBoolOptions.selected[1] = wave.ZData.isInvulnerable or false
	self.vanillaBoolOptions.selected[2] = wave.ZData.isSitting or false
	self.vanillaBoolOptions.selected[3] = wave.ZData.onFire or false
	self:setWalkType(wave.ZData.walkType)
	self.walkType.enable = not self.leftBoolOptions.selected[2]
	self.turnDelta:setText(tostring(wave.ZData.turnDelta or 1))
	self.extraBoolOptions.selected[1] = wave.ZData.immortalTutorialZombie or false
	self.extraBoolOptions.selected[2] = wave.ZData.useless or false
	self.extraBoolOptions.selected[3] = wave.ZData.randomBloodDirtHoles or false
	self.extraBoolOptions.selected[4] = wave.ZData.knifeDeath or false
	self.extraBoolOptions.selected[5] = wave.ZData.noTeeth or false
	self.extraBoolOptions.selected[6] = wave.ZData.jawStabAttach or false
	self.extraBoolOptions.selected[7] = wave.ZData.onlyJawStab or false
	self.leftExtraBoolOptions.selected[1] = wave.ZData.skeleton or (wave.ZData.skin and string.find(wave.ZData.skin, "Skeleton") ~= nil) or false
	self.leftExtraBoolOptions.selected[2] = wave.ZData.forceEatingAnimation or false
	self.leftExtraBoolOptions.selected[3] = wave.ZData.alwaysKnockedDown or false
	self.leftExtraBoolOptions.selected[4] = wave.ZData.canWalk or false
	self.leftExtraBoolOptions.selected[5] = wave.ZData.canCrawlUnderVehicle or false
	self.leftExtraBoolOptions.selected[6] = wave.ZData.sitAgainstWall or false
	self.humanizeOption.selected[1] = wave.ZData.humanize or (wave.ZData.skin and (wave.ZData.skin == "Random Human" or string.find(wave.ZData.skin, "Body") ~= nil and string.find(wave.ZData.skin, "Zed") == nil)) or false
	self.randomAnyOption.selected[1] = wave.ZData.skin == "Random Any"
	self.copyVisualOption.selected[1] = wave.ZData.copyVisual or false
	self.stateBoolOptions.selected[1] = wave.ZData.inactive or false
	self.stateBoolOptions.selected[2] = wave.ZData.reanimatedPlayer or false
	self.stateBoolOptions.selected[3] = wave.ZData.scratch or false
	self.stateBoolOptions.selected[4] = wave.ZData.laceration or false
	self.stateBoolOptions.selected[5] = wave.ZData.keepItReal or false
	self:setStatValue("strength", wave.ZData.strength)
	self:setStatValue("cognition", wave.ZData.cognition)
	self:setStatValue("memory", wave.ZData.memory)
	self:setStatValue("sight", wave.ZData.sight)
	self:setStatValue("hearing", wave.ZData.hearing)
	for index, option in ipairs(self.voice.options) do
		if option.data == wave.ZData.voice then self.voice:setSelected(index); break end
	end
	self.walkTargetX, self.walkTargetY, self.walkTargetZ = wave.ZData.walkTargetX, wave.ZData.walkTargetY, wave.ZData.walkTargetZ
	self:updateWalkTargetLabel()
	self:refreshSkinOptions(wave.ZData.skin)
	self.removeWave.enable = true
end
function WaveCasterPanel:prerender()
	ISCollapsableWindow.prerender(self)
	self.isShiftDown = Keyboard.isKeyDown(Keyboard.KEY_LSHIFT) or Keyboard.isKeyDown(Keyboard.KEY_RSHIFT)
	if self.isShiftDown then
		self.removeZombies:setTitle(getText("IGUI_SpawnHorde_RemoveAllZombies"))
		local color = getCore():getBadHighlitedColor()
		self.removeZombies:setBackgroundColorMouseOverRGBA(color:getR(), color:getG(), color:getB(), 1)
	else
		self.removeZombies:setTitle(getText("IGUI_SpawnHorde_RemoveZombies"))
		self.removeZombies:setBackgroundColorMouseOverRGBA(0.3, 0.3, 0.3, 1)
	end
	local castRadius = self:getCastRadius()
	if self.marker and self.marker:getSize() ~= castRadius then
		self.marker:setSize(castRadius)
	end
	local castEvent = self:getCastEvent()
	local hasWaves = castEvent and castEvent.Waves and #castEvent.Waves > 0
	self.queue.enable = (self.selectX ~= nil and self.selectY ~= nil)
	self.add.enable = (self.selectX ~= nil and self.selectY ~= nil)
	self.castWave.enable = hasWaves and true or false
	self.removeWave.enable = hasWaves and true or false
	self.removeZombies.enable = (self.selectX ~= nil and self.selectY ~= nil)
	self.removeBodies.enable = (self.selectX ~= nil and self.selectY ~= nil)
end

function WaveCasterPanel:onSelectNewSquare()
	self.cursor = ISSelectCursor:new(self.chr, self, self.onSquareSelected)
	self.cursor.skipWalk2 = true
	getCell():setDrag(self.cursor, self.chr:getPlayerNum())
end
function WaveCasterPanel:onSelectWalkTarget()
	self.cursor = ISSelectCursor:new(self.chr, self, self.onWalkTargetSelected)
	self.cursor.skipWalk2 = true
	getCell():setDrag(self.cursor, self.chr:getPlayerNum())
end
function WaveCasterPanel:updateWalkTargetLabel()
	local text = "Target Square: None"
	if self.walkTargetX ~= nil and self.walkTargetY ~= nil and self.walkTargetZ ~= nil then
		text = string.format("Target Square: %d, %d, %d", self.walkTargetX, self.walkTargetY, self.walkTargetZ)
	end
	self.walkTargetLabel:setName(text)
end
function WaveCasterPanel:onWalkTargetSelected(sq)
	self.cursor = nil
	self.walkTargetX, self.walkTargetY, self.walkTargetZ = sq:getX(), sq:getY(), sq:getZ()
	self:updateWalkTargetLabel()
end
-----------------------            ---------------------------
function WaveCasterPanel:applyTypedSquare()
	local x = tonumber(self.selectXEntry:getInternalText())
	local y = tonumber(self.selectYEntry:getInternalText())
	local z = tonumber(self.selectZEntry:getInternalText())
	if not x or not y or not z then return false end
	x = math.floor(x)
	y = math.floor(y)
	z = math.floor(z)
	self:removeMarker()
	self.selectX = x
	self.selectY = y
	self.selectZ = z
	self.castX = x
	self.castY = y
	self:refreshWaveList()
	return true
end
function WaveCasterPanel:onSquareSelected(sq)
	self.cursor = nil;
	self:removeMarker();
	self.selectX = sq:getX();
	self.selectY = sq:getY();
	self.selectZ = sq:getZ();
	self.selectXEntry:setText(tostring(self.selectX))
	self.selectYEntry:setText(tostring(self.selectY))
	self.selectZEntry:setText(tostring(self.selectZ))
	self.castX, self.castY = sq:getX(), sq:getY();
	if self.castX and self.castY then
		local castSq = getCell():getOrCreateGridSquare(self.castX, self.castY, self.selectZ)
		if castSq then
			--self:addMarker(castSq, self.castRadiusSlider:getCurrentValue());
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
	if not self:applyTypedSquare() then return end
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
	if not self:applyTypedSquare() then return end
	local radius = self:getCastRadius() + 1

	if not (self.selectX and self.selectY) then return end
	if isClient() then
		if self.isShiftDown then
			AdminContextMenu.OnRemoveAllZombiesClient()
			return
		end
		SendCommandToServer(string.format("/removezombies -x %d -y %d -z %d -radius %d", self.selectX, self.selectY, self.selectZ, radius))
		return
	end
	if self.isShiftDown then
		DebugContextMenu.OnRemoveAllZombies()
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
		local width = 1020;
		local height = 860;
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
