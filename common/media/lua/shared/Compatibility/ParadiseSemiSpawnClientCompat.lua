-- Restore Test compatibility: original Workshop source is never modified.
if not isClient() or isServer() then return end
ParadiseSemiSpawnClientCompat = ParadiseSemiSpawnClientCompat or {}
local state = ParadiseSemiSpawnClientCompat
if state.installed then return end
state.installed = true
local expected = [==[-- Guaranteed Military Vehicle Spawns at fixed coordinates
-- These vehicles will ALWAYS spawn at these locations

local function guaranteed_military_spawns_enabled()
    return not SandboxVars
        or not SandboxVars.rSemiTruck
        or SandboxVars.rSemiTruck.GuaranteedMilitarySpawns ~= false
end

local function cartrailer_spawns_enabled()
    local sandboxVars = rawget(_G, "SandboxVars")
    return not sandboxVars
        or not sandboxVars.rSemiTruck
        or sandboxVars.rSemiTruck.CarTrailerSpawns ~= false
end

local guaranteedSpawns = {
    -- Format: {vehicleType, x, y, z, direction, alwaysActive}
    -- x, y = world coordinates
    -- z = 0 for ground level
    -- direction = IsoDirections name: "N", "NE", "E", "SE", "S", "SW", "W", "NW"  (or nil for random)
    -- alwaysActive = true bypasses the sandbox toggle for that fixed spawn only

    
    {"Base.SemiTruckBox_mil", 10670, 10411, 0, "S"},-- Muldraugh Police impound
    {"Base.SemiTruckBox_mil", 11668, 9940, 0, "S"}, -- Railyard

    {"Base.SemiTrailerVan_mil", 12449, 4261, 0, "S"}, -- Louisville checkpoint
    {"Base.SemiTruck_mil", 12466, 4313, 0, "N"},       -- Louisville checkpoint

    {"Base.SemiTrailerVan_mil", 15468, 3004, 0, "S"}, -- Louisville Airport


    {"Base.SemiTrailerCartrailer", 5758,5372,0, "S", true}, -- Riverside Scrap Yard
    {"Base.SemiTrailerCartrailer", 5628,5889,0, "S", true}, -- Riverside Industrial Park

    {"Base.SemiTrailerCartrailer", 10312,9257,0, "N", true}, -- Muldraugh McCoy's Garage

    {"Base.SemiTrailerCartrailer", 852,12947,0, "W", true}, -- Irvington Speedway

    {"Base.SemiTrailerCartrailer", 12411,2769,0, "S", true}, -- Louisville Chapelmount

    {"Base.SemiTrailerCartrailer", 8251,12200,0, "E", true} -- Rosewood Gas Station
}

-- Inject additional spawns when specific map mods are active


--Secretz42 W.I.P. - add more locations as needed

if getActivatedMods():contains("\\Secretz42") then 
    -- Secretz42 map mod locations
    table.insert(guaranteedSpawns, {"Base.SemiTruck_mil",       9775, 13152,  0, "E"})
    table.insert(guaranteedSpawns, {"Base.SemiTrailerVan_mil",  10329, 12521, 0, "S"}) -- March Ridge checkpoint
end


if getActivatedMods():contains("\\RavenCreekB42") then 
    -- RavenCreekB42 map mod locations
    table.insert(guaranteedSpawns, {"Base.SemiTruck_mil",       6499, 15337,  0, "W"})
    table.insert(guaranteedSpawns, {"Base.SemiTrailerVan_mil",  6514, 15338, 0, "W"}) -- RavenCreekB42
end


-- if activeMods:contains("SomeOtherMod") then
--     table.insert(guaranteedSpawns, {"Base.SemiTruckBox_mil", 12345, 6789, 0, "W"})
-- end

Events.OnInitGlobalModData.Add(function()
    Events.LoadGridsquare.Add(function(square)
        local sx = square:getX()
        local sy = square:getY()

        for i, spawnData in ipairs(guaranteedSpawns) do
            if spawnData[2] == sx and spawnData[3] == sy then
                local vehicleType = spawnData[1]
                if vehicleType == "Base.SemiTrailerCartrailer" and not cartrailer_spawns_enabled() then
                    break
                end

                local alwaysActive = spawnData[6] == true
                if not alwaysActive and not guaranteed_military_spawns_enabled() then
                    break
                end
                local direction   = spawnData[5]
                local spawnKey    = vehicleType .. "_" .. sx .. "_" .. sy

                local modData = ModData.getOrCreate("rSemiTruck_GuaranteedSpawns")
                if not modData[spawnKey] then
                    if not square:isVehicleIntersecting() then
                        local isoDir = direction and IsoDirections.fromString(direction) or IsoDirections.getRandom()
                        local vehicle = addVehicleDebug(vehicleType, isoDir, nil, square)
                        if vehicle then
                            modData[spawnKey] = true
                            ModData.transmit("rSemiTruck_GuaranteedSpawns")
                            --print(("rSemiTruck: Spawned " .. vehicleType .. " at (" .. sx .. ", " .. sy .. ")")
                        else
                            --print(("rSemiTruck: ERROR - addVehicleDebug returned nil for " .. vehicleType)
                        end
                    end
                end
                break
            end
        end
    end)
end)
]==]
local reader
local ok, matches = pcall(function()
    reader = getModFileReader("rSemiTruck", "media/lua/server/rSemiTruck.GuaranteedSpawns_mil.lua", false)
    if not reader then return false end
    local lines, count = {}, 0
    while true do
        local line = reader:readLine()
        if line == nil then break end
        count = count + #line + 1
        if count > 32768 then return false end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n") .. "\n" == expected
end)
if reader then pcall(function() reader:close() end) end
if not ok or not matches then
    print("[ParadiseSemiSpawnClientCompat r1] SKIPPED: upstream unavailable or changed; original behavior retained")
    return
end
local coordinates = {{10670,10411},{11668,9940},{12449,4261},{12466,4313},{15468,3004},{5758,5372},{5628,5889},{10312,9257},{852,12947},{12411,2769},{8251,12200},{9775,13152},{10329,12521},{6499,15337},{6514,15338}}
local index = {}
for _, xy in ipairs(coordinates) do
    index[xy[1]] = index[xy[1]] or {}
    index[xy[1]][xy[2]] = true
end
local event = Events.LoadGridsquare
local originalAdd = event.Add
local hook
local open = true
local wrapped = 0
hook = function(callback)
    if open then
        local valid, filename = pcall(getFilenameOfClosure, callback)
        local lineOK, line = pcall(getFirstLineOfClosure, callback)
        if valid and type(filename) == "string" and lineOK and line == 71 then
            filename = string.gsub(filename, "\\", "/")
            if string.find(filename, "/mods/rSemiTruck/common/media/lua/server/rSemiTruck.GuaranteedSpawns_mil.lua", 1, true) then
                local original = callback
                callback = function(square, ...)
                    local column = index[square:getX()]
                    if column and column[square:getY()] then return original(square, ...) end
                end
                wrapped = wrapped + 1
            end
        end
    end
    return originalAdd(callback)
end
event.Add = hook
Events.OnGameStart.Add(function()
    open = false
    if event.Add == hook then event.Add = originalAdd end
    if wrapped == 1 then
        print("[ParadiseSemiSpawnClientCompat r1] ACTIVE: original handler filtered by spawn coordinates")
    else
        print("[ParadiseSemiSpawnClientCompat r1] REVIEW: wrapped=" .. tostring(wrapped) .. "; expected 1; check load order/duplicate registrations")
    end
end)
