
function OpenCommandConsole()
	if not (MainScreen.instance and MainScreen.instance.inGame) then
		if not getCore():getDebug() then
			getCore():ResetLua("default", "Force")
		end
		getSoundManager():playUISound("GainExperienceLevel")
		--ISDebugMenu.OnOpenPanel()
		--local dbg = UIManager.getDebugConsole()
		local dbg = UIDebugConsole.new(20, getCore():getScreenHeight() - 265)
		UIManager.setDebugConsole(dbg)
		if not UIManager.getUI():contains(dbg) then
			UIManager.getUI():add(dbg)
		end
		UIManager.getUI():add(dbg)


		dbg:setVisible(true)
		dbg:bringToTop()
	end
end

function MainScreen:onTutorialModalClick(button)

--[[     local tutorialButton = MainScreen.instance.tutorialButton
    MainScreen.instance.tutorialButton = nil

    local joypadData = JoypadState.getMainMenuJoypad()
    if joypadData then
        joypadData.focus = MainScreen.instance
        updateJoypadFocus(joypadData)
        if button.internal == "YES" then
            MainScreen.onTutorialControllerWarn()
            return
        end
    end
    getCore():setTutorialDone(true);
    getCore():saveOptions();
    if button.internal == "YES" then
        --MainScreen.startTutorial();
    else
        getCore():setTutorialDone(true);
        getCore():saveOptions();
        --MainScreen.onMenuItemMouseDownMainMenu(tutorialButton, 0, 0)
    end
 ]]
end


--UIManager.setShowPausedMessage(false);


function MainScreen:onClickTermsOfService(button)
    local width = 600
    local height = 200
    local player = 0
    local modal = ISTermsOfServiceUI:new(self.width / 2 - width / 2, self.height / 2 - height / 2, width, height)
    modal:initialise()
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
    if player and JoypadState.players[player+1] then
        modal.prevFocus = JoypadState.players[player+1].focus
        setJoypadFocus(player, modal)
    else
        local joypadData = JoypadState.getMainMenuJoypad()
        if joypadData then
            modal.prevFocus = joypadData.focus
            joypadData.focus = modal
            updateJoypadFocus(joypadData)
        end
    end
    self.termsOfServiceDialog = modal
end


--[[ 

function ISWorldMap.ShowWorldMap(playerNum, centerX, centerY, zoom)
	if not ISWorldMap.IsAllowed() then
		return
	end
	if not ISWorldMap_instance then
		local INSET = 0
		ISWorldMap_instance = ISWorldMap:new(INSET, INSET, getCore():getScreenWidth() - INSET * 2, getCore():getScreenHeight() - INSET * 2)
		ISWorldMap_instance:initialise()
		ISWorldMap_instance:instantiate()
		ISWorldMap_instance.character = getSpecificPlayer(playerNum)
		ISWorldMap_instance.playerNum = playerNum
		ISWorldMap_instance.symbolsUI.character = getSpecificPlayer(playerNum)
		ISWorldMap_instance.symbolsUI.playerNum = playerNum
		ISWorldMap_instance.symbolsUI:checkInventory()
		ISWorldMap_instance:initDataAndStyle()
		ISWorldMap_instance:setHideUnvisitedAreas(ISWorldMap_instance.hideUnvisitedAreas)
		ISWorldMap_instance:setShowPlayers(ISWorldMap_instance.showPlayers)
		ISWorldMap_instance:setShowRemotePlayers(ISWorldMap_instance.showRemotePlayers)
		ISWorldMap_instance:setShowPlayerNames(ISWorldMap_instance.showPlayerNames)
		ISWorldMap_instance:setShowCellGrid(ISWorldMap_instance.showCellGrid)
		ISWorldMap_instance:setShowTileGrid(ISWorldMap_instance.showTileGrid)
		ISWorldMap_instance:setIsometric(ISWorldMap_instance.isometric)
		ISWorldMap_instance.mapAPI:resetView()
		if ISWorldMap_instance.character then
			ISWorldMap_instance.mapAPI:centerOn(ISWorldMap_instance.character:getX(), ISWorldMap_instance.character:getY())
			ISWorldMap_instance.mapAPI:setZoom(zoom and zoom or 18.0)
		end
		ISWorldMap_instance:restoreSettings()

		if centerX and centerY then
			ISWorldMap_instance.mapAPI:centerOn(centerX, centerY)
			ISWorldMap_instance.mapAPI:setZoom(zoom and zoom or 18.0)
		end

		ISWorldMap_instance:addToUIManager()
		ISWorldMap_instance.getJoypadFocus = true
        if ISWorldMap.shouldPause() then
            setGameSpeed(0);
        end
		for i=1,getNumActivePlayers() do
			if getSpecificPlayer(i-1) then
				getSpecificPlayer(i-1):setBlockMovement(true)
			end
		end
		return
	end

	ISWorldMap_instance.character = getSpecificPlayer(playerNum)
	ISWorldMap_instance.playerNum = playerNum
	ISWorldMap_instance.symbolsUI.character = getSpecificPlayer(playerNum)
	ISWorldMap_instance.symbolsUI.playerNum = playerNum
	ISWorldMap_instance.symbolsUI:checkInventory()
	if centerX and centerY then
		ISWorldMap_instance.mapAPI:centerOn(centerX, centerY)
		ISWorldMap_instance.mapAPI:setZoom(zoom and zoom or 18.0)
	end
	ISWorldMap_instance:setVisible(true)
	ISWorldMap_instance:addToUIManager()
	ISWorldMap_instance.getJoypadFocus = true

	if MainScreen.instance.inGame then
		for i=1,getNumActivePlayers() do
			if getSpecificPlayer(i-1) then
				getSpecificPlayer(i-1):setBlockMovement(true)
			end
		end
	else
		ISWorldMap_instance:setHideUnvisitedAreas(false)
	end
    if ISWorldMap.shouldPause() then
        setGameSpeed(0);
    end
end
 ]]
