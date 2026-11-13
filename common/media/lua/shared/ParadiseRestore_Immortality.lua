ParadiseRestore = ParadiseRestore or {}
ParadiseRestore.Immortality = ParadiseRestore.Immortality or {}

local Immortality = ParadiseRestore.Immortality

Immortality.MODULE = "ParadiseRestoreImmortality"
Immortality.StoreName = "ParadiseRestore_IsImmortal"
Immortality.ZoneFeature = "isSpecial"

function Immortality.isSteamMode()
    return getSteamModeActive and getSteamModeActive() or false
end

function Immortality.getUsername(pl)
    if not pl or not pl.getUsername then return nil end
    local user = pl:getUsername()
    if not user or tostring(user) == "" then return nil end
    return tostring(user)
end

function Immortality.getSteamId(pl)
    if not pl or not pl.getSteamID then return nil end
    local id = tostring(pl:getSteamID())
    if id == "" or id == "0" then return nil end
    return id
end

function Immortality.getKey(pl)
    if Immortality.isSteamMode() then return Immortality.getSteamId(pl) end
    return Immortality.getUsername(pl)
end

function Immortality.getUsernameKey(user)
    if not user or tostring(user) == "" then return nil end
    return string.lower(tostring(user))
end

function Immortality.getStore()
    if not ModData or not ModData.getOrCreate then return nil end
    local store = ModData.getOrCreate(Immortality.StoreName)
    store.players = store.players or {}
    store.names = store.names or {}
    store.pending = store.pending or {}
    store.pendingNames = store.pendingNames or {}
    return store
end

function Immortality.isImmortal(pl)
    if not pl then return false end
    local store = Immortality.getStore()
    if not store then return false end
    local key = Immortality.getKey(pl)
    local userKey = Immortality.getUsernameKey(Immortality.getUsername(pl))
    return (key and store.players[key] == true) or (userKey and store.pending[userKey] == true) or false
end

function Immortality.getZoneAt(x, y, z)
    if isClient and isClient() then
        local border = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Border or nil
        if not border or not border.getAuthorityAt then return nil end
        return border.getAuthorityAt(x, y, z, 0)
    end
    local engine = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    if not engine or not engine.getAuthority then return nil end
    return engine.getAuthority(x, y, z, 0)
end

function Immortality.isInEventZone(pl)
    if not pl then return false end
    local zone = Immortality.getZoneAt(pl:getX(), pl:getY(), pl:getZ())
    return zone ~= nil and zone.features ~= nil and zone.features[Immortality.ZoneFeature] == true
end

function Immortality.isAllowed(pl)
    if not pl then return false end
    if ParadiseRestore.isAdm and ParadiseRestore.isAdm(pl) then return true end
    return Immortality.isInEventZone(pl)
end

function Immortality.isActive(pl)
    return Immortality.isImmortal(pl) and Immortality.isAllowed(pl)
end