ParadisePanels = ParadisePanels or {}
ParadisePanels.table = ParadisePanels.table or {}

require "Panels/ParadisePanels_table"

local function report(message)
    print("[ParadisePanels] " .. tostring(message))
end

local function isValidEntry(entry)
    return type(entry) == "table"
        and type(entry.key) == "string"
        and entry.key ~= ""
        and type(entry.getModule) == "function"
        and type(entry.getInstance) == "function"
        and type(entry.setInstance) == "function"
        and type(entry.create) == "function"
end

function ParadisePanels.Open(entry, ...)
    if entry.isAdmOnly and (not ParadiseRestore or not ParadiseRestore.isAdm or not ParadiseRestore.isAdm()) then
        return nil
    end

    local instance = entry.getInstance()
    local created = false
    if not instance then
        instance = entry.create(...)
        if not instance then return nil end
        entry.setInstance(instance)
        created = true
    end

    if created and instance.addToUIManager then instance:addToUIManager() end
    if instance.setVisible then instance:setVisible(true) end
    if instance.bringToTop then instance:bringToTop() end
    if entry.onOpen then entry.onOpen(instance, ...) end
    return instance
end

function ParadisePanels.Close(entry)
    local instance = entry.getInstance()
    if not instance then return end

    if entry.onClose then entry.onClose(instance) end
    if instance.setVisible then instance:setVisible(false) end
    if instance.removeFromUIManager then instance:removeFromUIManager() end
    entry.setInstance(nil)
end

function ParadisePanels.Toggle(entry, ...)
    if entry.getInstance() then
        ParadisePanels.Close(entry)
        return nil
    end
    return ParadisePanels.Open(entry, ...)
end

function ParadisePanels.InstallEntry(entry)
    if not isValidEntry(entry) then
        report("Invalid panel registry entry")
        return false
    end

    local module = entry.getModule()
    if type(module) ~= "table" then return false end

    module.OpenPanel = function(...) return ParadisePanels.Open(entry, ...) end
    module.ClosePanel = function() return ParadisePanels.Close(entry) end
    module.TogglePanel = function(...) return ParadisePanels.Toggle(entry, ...) end
    entry._installedModule = module
    return true
end

function ParadisePanels.Install()
    local installed = 0
    local keys = {}
    for _, entry in ipairs(ParadisePanels.table or {}) do
        if type(entry) ~= "table" or type(entry.key) ~= "string" or entry.key == "" then
            report("Panel registry entry is missing a key")
        elseif keys[entry.key] then
            report("Duplicate panel registry key: " .. entry.key)
        else
            keys[entry.key] = true
            if ParadisePanels.InstallEntry(entry) then installed = installed + 1 end
        end
    end
    return installed
end

if Events and Events.OnGameStart then
    Events.OnGameStart.Remove(ParadisePanels.Install)
    Events.OnGameStart.Add(ParadisePanels.Install)
end
