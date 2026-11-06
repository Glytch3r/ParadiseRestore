SquadManager = SquadManager or {}

function SquadManager.isB41()
    return getCore():getGameVersion():getMajor() == 41
end
if SquadManager.isB41() then return end

SquadManager.module = "SquadManager"
SquadManager.storeName = "SquadManager_Data"
SquadManager.bindId = "ParadiseRestoreSquadActionCall"
SquadManager.tabTitle = "Squad"
SquadManager.tabID = 9001

SquadManager.commands = {
    create = "create",
    invite = "invite",
    respond = "respond",
    transferSeat = "transferSeat",
    kick = "kick",
    leave = "leave",
    commence = "commence",
    disband = "disband",
    chat = "chat",
    actionCall = "actionCall",
    tag = "tag",
    requestState = "requestState",
    login = "login",
    state = "state",
    none = "none",
    positions = "positions",
    chatLine = "chatLine",
    tagAdd = "tagAdd",
    tagExpire = "tagExpire",
    invitePrompt = "invitePrompt",
    inviteResolved = "inviteResolved",
    config = "config",
    departed = "departed",
}

SquadManager.defaults = {
    SquadSystemEnabled = true,
    SquadMaxMembers = 5,
    AutoLeaveDistance = 60,
    ActionCallPanelFadeDelay = 5,
    ActionCallVisualFadeDelay = 5,
    TargetTagDuration = 8,
    DisbandWhenLeaderDies = false,
    ActionCallKey = 41,
}

SquadManager.optionKeys = {
    "SquadSystemEnabled",
    "SquadMaxMembers",
    "AutoLeaveDistance",
    "ActionCallPanelFadeDelay",
    "ActionCallVisualFadeDelay",
    "TargetTagDuration",
    "DisbandWhenLeaderDies",
    "ActionCallKey",
}

SquadManager.limits = {
    SquadMaxMembers = { min = 2, max = 5 },
    AutoLeaveDistance = { min = 5, max = 1000 },
    ActionCallPanelFadeDelay = { min = 1, max = 60 },
    ActionCallVisualFadeDelay = { min = 1, max = 120 },
    TargetTagDuration = { min = 1, max = 120 },
}

SquadManager.colors = {
    squad = { r = 0.25, g = 0.80, b = 0.35 },
    leader = { r = 0.95, g = 0.75, b = 0.20 },
    zombieTag = { r = 0.20, g = 0.90, b = 0.30 },
    playerTag = { r = 0.90, g = 0.15, b = 0.15 },
}

SquadManager.actionCalls = {
    { index = 1,  label = "Cover Me",          leader = false, marker = "homing",  pin = true },
    { index = 2,  label = "Good Job",          leader = false, marker = "none" },
    { index = 3,  label = "Thanks",            leader = false, marker = "none" },
    { index = 4,  label = "All Clear",         leader = false, marker = "circle" },
    { index = 5,  label = "I'm Hit",           leader = false, marker = "homing",  pin = true, urgent = true },
    { index = 6,  label = "I'm In Position",   leader = false, marker = "circle" },
    { index = 7,  label = "Man Down",          leader = false, marker = "homing",  pin = true, urgent = true },
    { index = 8,  label = "Negative",          leader = false, marker = "none" },
    { index = 9,  label = "Roger That",        leader = false, marker = "none" },
    { index = 10, label = "Out Of Ammo",       leader = false, marker = "homing" },
    { index = 11, label = "Follow Me",         leader = true,  marker = "homing",  pin = true, rally = true },
    { index = 12, label = "Go",                leader = true,  marker = "arrow" },
    { index = 13, label = "Stick Together",    leader = true,  marker = "rally" },
    { index = 14, label = "Hold Your Position", leader = true, marker = "circle" },
    { index = 15, label = "Cease Fire",        leader = true,  marker = "none" },
    { index = 16, label = "Grab What You Can", leader = true,  marker = "circle" },
    { index = 17, label = "Stay Low",          leader = true,  marker = "none" },
    { index = 18, label = "Open Fire",         leader = true,  marker = "arrow" },
    { index = 19, label = "Fall Back",         leader = true,  marker = "arrow" },
    { index = 20, label = "Requesting Backup", leader = true,  marker = "rally" },
}

function SquadManager.actionCallByIndex(int)
    int = tonumber(int)
    if not int then return nil end
    for _, entry in ipairs(SquadManager.actionCalls) do
        if entry.index == int then return entry end
    end
    return nil
end

function SquadManager.clamp(name, value, fallback)
    local limit = SquadManager.limits[name]
    value = tonumber(value)
    if not value then return tonumber(fallback) end
    if limit then
        value = math.max(limit.min, math.min(limit.max, value))
    end
    return value
end

function SquadManager.sanitizeConfig(tab)
    local result = {}
    tab = type(tab) == "table" and tab or {}
    for _, name in ipairs(SquadManager.optionKeys) do
        local value = tab[name]
        if type(value) == "boolean" then
            result[name] = value
        else
            result[name] = SquadManager.clamp(name, value, SquadManager.defaults[name])
        end
    end
    return result
end

function SquadManager.sanitizeUser(str)
    str = tostring(str or "")
    str = str:match("^%s*(.-)%s*$") or ""
    if #str > 30 then return "" end
    return str
end

function SquadManager.seatList(squad)
    local result = {}
    if type(squad) ~= "table" or type(squad.seats) ~= "table" then return result end
    for key, user in pairs(squad.seats) do
        local seat = tonumber(key)
        if seat and user and user ~= "" then result[math.floor(seat)] = tostring(user) end
    end
    return result
end

function SquadManager.seatsOrdered(squad)
    local list = {}
    for seat, user in pairs(SquadManager.seatList(squad)) do
        list[#list + 1] = { seat = seat, user = user }
    end
    table.sort(list, function(a, b) return a.seat < b.seat end)
    return list
end

function SquadManager.setSeat(squad, seat, user)
    if type(squad) ~= "table" or type(squad.seats) ~= "table" then return end
    seat = math.floor(tonumber(seat) or 0)
    if seat <= 0 then return end
    if user == nil or user == "" then
        SquadManager.clearSeat(squad, seat)
        return
    end
    squad.seats[seat] = tostring(user)
    squad.seats[tostring(seat)] = nil
end

function SquadManager.clearSeat(squad, seat)
    if type(squad) ~= "table" or type(squad.seats) ~= "table" then return end
    seat = math.floor(tonumber(seat) or 0)
    if seat <= 0 then return end
    squad.seats[seat] = nil
    squad.seats[tostring(seat)] = nil
end

function SquadManager.seatUser(squad, seat)
    return SquadManager.seatList(squad)[math.floor(tonumber(seat) or 0)]
end

function SquadManager.seatCount(squad)
    local count = 0
    for _ in pairs(SquadManager.seatList(squad)) do count = count + 1 end
    return count
end

function SquadManager.seatOf(squad, user)
    if not user or user == "" then return 0 end
    for seat, name in pairs(SquadManager.seatList(squad)) do
        if name == user then return seat end
    end
    return 0
end

function SquadManager.isMember(squad, user)
    return SquadManager.seatOf(squad, user) > 0
end

function SquadManager.leaderUser(squad)
    local user = SquadManager.seatUser(squad, 1)
    if not user or user == "" then return nil end
    return user
end

function SquadManager.isLeader(squad, user)
    local leader = SquadManager.leaderUser(squad)
    if not leader then return false end
    return leader == user
end

function SquadManager.activeSeats(config)
    local max = SquadManager.clamp("SquadMaxMembers", config and config.SquadMaxMembers, SquadManager.defaults.SquadMaxMembers)
    local seats = {}
    for int = 1, max do seats[int] = int end
    return seats
end
