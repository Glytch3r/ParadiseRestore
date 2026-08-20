ParadiseDev = ParadiseDev or {}
ParadiseDev.Console = ParadiseDev.Console or {}

local Console = ParadiseDev.Console

local function keepConsoleOnTop()
    local dbg = Console.instance
    if not dbg then return end
    dbg:setVisible(true)
    if dbg.setAlwaysOnTop then dbg:setAlwaysOnTop(true) end
    if dbg.bringToTop then dbg:bringToTop() end
end

local function deferConsoleToTop()
    if Console.topQueued then return end
    Console.topQueued = true
    local function onTick()
        Events.OnTick.Remove(onTick)
        Console.topQueued = false
        keepConsoleOnTop()
    end
    Events.OnTick.Add(onTick)
end

function luaReCon()
    if not getCore():getDebug() then
        getCore():ResetLua("default", "Force")
    end
end

function luaCon()

    if not getCore():getDebug() then return end

    if Console.instance and UIManager.getUI():contains(Console.instance) then
        keepConsoleOnTop()
        deferConsoleToTop()
        return Console.instance
    end
    local dbg = UIDebugConsole.new(30, getCore():getScreenHeight() - 265)
    UIManager.setDebugConsole(dbg)
    UIManager.getUI():add(dbg)
    dbg:setVisible(true)

    getSoundManager():playUISound("GainExperienceLevel")
    Console.instance = dbg
    keepConsoleOnTop()
    deferConsoleToTop()
    return dbg
end

local function openFromMainMenu(item, x, y)
    if item and item.internal == "TUTORIAL" then
        luaCon()
        return
    end
    return Console.originalMainMenuClick(item, x, y)
end

if MainScreen then
    Console.originalMainMenuClick = Console.originalMainMenuClick or MainScreen.onMenuItemMouseDownMainMenu
    MainScreen.onMenuItemMouseDownMainMenu = openFromMainMenu

    function MainScreen:onTutorialModalClick(button)
        luaCon()
    end

    function MainScreen:onClickTermsOfService(button)
        luaCon()
    end
end

function Console.onKeyPressed(key)
    if not getCore():getDebug() then return end
    if getCore():getKey("ToggleLuaConsole") == key then
        luaCon()
    end
end

Events.OnKeyPressed.Remove(Console.onKeyPressed)
Events.OnKeyPressed.Add(Console.onKeyPressed)
