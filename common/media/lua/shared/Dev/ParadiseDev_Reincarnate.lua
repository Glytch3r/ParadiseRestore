-- Compatibility facade for Paradise's continuous-life profiles.
-- Persistence and restoration are owned by ParadiseLifeProfiles on the server.
-- The former client XP award and shared/global admin record store are retired.
ParadiseDev = ParadiseDev or {}
ParadiseDev.Reincarnate = ParadiseDev.Reincarnate or {}
local recovery = ParadiseDev.Reincarnate
recovery.module = "ParadiseLifeProfiles"

function recovery.getUsername(pl)
    return pl and pl.getUsername and tostring(pl:getUsername()) or nil
end

function recovery.isShouldReincarnate()
    local sand = SandboxVars and SandboxVars.ParadiseZ
    return not sand or sand.isShouldReincarnate ~= false
end

function recovery.getDeathMessages()
    local sand = SandboxVars and SandboxVars.ParadiseZ
    local messages = {}
    for message in string.gmatch(tostring(sand and sand.ReincarnateDeathMessages or ""), "([^;]+)") do
        message = message:gsub("^%s+", ""):gsub("%s+$", "")
        if message ~= "" then messages[#messages + 1] = message end
    end
    if #messages == 0 then messages[1] = "THAT WAS PARADISE." end
    return messages
end

-- Existing diagnostic menus may ask for profile status, never alter XP or lives.
function recovery.addTestOptions(menu, pl)
    if not menu or not ParadiseRestore or not ParadiseRestore.isAdm(pl) then return end
    local option = menu:addOption("Life profiles: server managed", nil, function()
        local client = ParadiseDev.LifeProfilesClient
        if client then client.showStatus(pl) end
    end)
    if ISToolTip then
        local tip = ISToolTip:new()
        tip:initialise()
        tip.description = "Profiles are saved automatically. Selection is available after death."
        option.toolTip = tip
    end
end

function recovery.addTargetOptions() end
function recovery.addParadiseOptions() end

function recovery.getPlayerByUsername(username)
    if not username then return nil end
    local target = getPlayerFromUsername and getPlayerFromUsername(username) or nil
    if target then return target end
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return nil end
    username = string.lower(tostring(username))
    for index = 0, players:size() - 1 do
        local pl = players:get(index)
        local user = recovery.getUsername(pl)
        if user and string.lower(user) == username then return pl end
    end
    return nil
end

function recovery.getCagedRespawnLoc(username, player)
    local pl = player or recovery.getPlayerByUsername(username)
    local engine = ParadiseDev and ParadiseDev.Zones and ParadiseDev.Zones.Engine or nil
    if not pl or not engine or not ParadiseDev.Cage or not ParadiseDev.Cage.isCaged or not ParadiseDev.Cage.isCaged(pl) then return nil end
    local steamID = engine.playerSteamId and engine.playerSteamId(pl) or nil
    local zoneID = steamID and engine.cageAssignments and engine.cageAssignments[steamID] or nil
    local zone = zoneID and engine.zones and engine.zones[zoneID] or nil
    if not zone and engine.nearestCageZone then zone = engine.nearestCageZone(pl) end
    if not zone then return nil end
    local point = engine.getCageRebound and engine.getCageRebound(pl, zone) or nil
    if point then return point.x, point.y, point.z end
    local region = engine.nearestRegion and engine.nearestRegion(zone, pl:getX(), pl:getY()) or nil
    if not region then return nil end
    local x, y = engine.regionCenter(region)
    local z = zone.zMode == "floor" and zone.zMin or pl:getZ()
    return x, y, z
end

function recovery.getLoreEventRespawnLoc(username)
    --[[
    LoreEvents respawn condition and location resolver goes here when that system is written.
    --]]
    return nil
end

function recovery.getSafehouseRespawnLoc(username)
    local options = getServerOptions and getServerOptions() or nil
    if not username or not options or not options.getBoolean or not options:getBoolean("SafehouseAllowRespawn") then return nil end
    local houses = SafeHouse and SafeHouse.getSafehouseList and SafeHouse.getSafehouseList() or nil
    if not houses then return nil end
    for index = 0, houses:size() - 1 do
        local safehouse = houses:get(index)
        local members = safehouse and safehouse.getPlayers and safehouse:getPlayers() or nil
        local member = safehouse and safehouse.getOwner and safehouse:getOwner() == username
            or members and members.contains and members:contains(username)
        if member and safehouse.isRespawnInSafehouse and safehouse:isRespawnInSafehouse(username) then
            return safehouse:getX() + safehouse:getW() / 2, safehouse:getY() + safehouse:getH() / 2, 0
        end
    end
end

function recovery.getServerRespawnLoc()
    local options = getServerOptions and getServerOptions() or nil
    local value = options and options.getOption and options:getOption("SpawnPoint") or nil
    local sx, sy, sz = tostring(value or ""):match("^%s*([^,]+),([^,]+),([^,]+)%s*$")
    local x, y, z = tonumber(sx), tonumber(sy), tonumber(sz)
    if not x or not y or not z or x == 0 and y == 0 then return nil end
    return x, y, z
end

function recovery.getVanillaRespawnLoc()
    local regions = SpawnRegionMgr and SpawnRegionMgr.getSpawnRegions and SpawnRegionMgr.getSpawnRegions() or nil
    local region = regions and regions[1] or nil
    local points = region and region.points or nil
    local spawn = points and (points.unemployed or points[CharacterProfession and CharacterProfession.UNEMPLOYED and CharacterProfession.UNEMPLOYED:getName()]) or nil
    if not spawn or #spawn == 0 then return nil end
    local point = spawn[ZombRand(#spawn) + 1]
    local x = point.worldX and point.worldX * 300 + point.posX or point.posX
    local y = point.worldY and point.worldY * 300 + point.posY or point.posY
    return x, y, point.posZ or 0
end

function recovery.getRespawnLoc(username)
    local x, y, z = recovery.getCagedRespawnLoc(username)
    if x then return x, y, z end
    x, y, z = recovery.getLoreEventRespawnLoc(username)
    if x then return x, y, z end
    x, y, z = recovery.getSafehouseRespawnLoc(username)
    if x then return x, y, z end
    x, y, z = recovery.getServerRespawnLoc()
    if x then return x, y, z end
    return recovery.getVanillaRespawnLoc()
end
