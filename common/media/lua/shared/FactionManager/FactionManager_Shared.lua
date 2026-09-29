FactionManager = FactionManager or {}

function FactionManager.isB41()
    return getCore():getGameVersion():getMajor() == 41
end
if FactionManager.isB41() then return end

FactionManager.module = "FactionManager"
FactionManager.storeName = "FactionManager_Data"
FactionManager.states = { active = true, inactive = true, deleted = true }
FactionManager.statePaths = {
    active = "FactionManager/active",
    inactive = "FactionManager/inactive",
    deleted = "FactionManager/deleted",
}
FactionManager.commands = {
    request = "request",
    mutate = "mutate",
    state = "state",
    perform = "perform",
    login = "login",
}

function FactionManager.trim(str)
    if type(str) ~= "string" then return "" end
    return str:match("^%s*(.-)%s*$") or ""
end

function FactionManager.safeName(str)
    str = FactionManager.trim(str)
    if str == "" then return "unknown" end
    return str:gsub("[^%w_%-]", function(sym)
        return string.format("%%%02X", string.byte(sym))
    end)
end

function FactionManager.copyTab(tab)
    local result = {}
    if type(tab) ~= "table" then return result end
    for key, value in pairs(tab) do result[key] = value end
    return result
end

function FactionManager.listHas(tab, str)
    if type(tab) ~= "table" then return false end
    for _, value in ipairs(tab) do
        if value == str then return true end
    end
    return false
end

function FactionManager.removeListValue(tab, str)
    if type(tab) ~= "table" then return end
    for int = #tab, 1, -1 do
        if tab[int] == str then table.remove(tab, int) end
    end
end

function FactionManager.getFactionByName(str)
    str = FactionManager.trim(str)
    if str == "" or not Faction or not Faction.getFaction then return nil end
    return Faction.getFaction(str)
end

function FactionManager.getMemberCount(faction)
    if not faction then return 0 end
    local players = faction:getPlayers()
    return (players and players:size() or 0) + 1
end
