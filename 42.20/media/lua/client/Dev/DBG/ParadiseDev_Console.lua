
function OpenCommandConsole()
	if not (MainScreen.instance and MainScreen.instance.inGame) then
		if not getCore():getDebug() then
			getCore():ResetLua("default", "Force")
		end
		getSoundManager():playUISound("GainExperienceLevel")
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

end




function MainScreen:onClickTermsOfService(button)
    local width = 600
    local height = 200
    local plNum = 0
    local modal = ISTermsOfServiceUI:new(self.width / 2 - width / 2, self.height / 2 - height / 2, width, height)
    modal:initialise()
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
    if plNum and JoypadState.players[plNum+1] then
        modal.prevFocus = JoypadState.players[plNum+1].focus
        setJoypadFocus(plNum, modal)
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
