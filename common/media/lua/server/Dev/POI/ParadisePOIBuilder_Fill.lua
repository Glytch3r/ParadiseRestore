ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.Fill = ParadisePOIBuilder.Fill or {}
if ParadisePOIBuilder.isB41() then return end

local P = ParadisePOIBuilder
local F = P.Fill

F.sheetSet = F.sheetSet or nil

function F.sheets()
    if F.sheetSet then return F.sheetSet end
    local set = {}
    local all = getWorld():getTileImageNames()
    if all then
        for i = 0, all:size() - 1 do
            local full = all:get(i)
            if full then
                local sheet = luautils.split(full, ".")[1]
                if sheet then set[sheet] = true end
            end
        end
    end
    F.sheetSet = set
    return set
end

function F.checkObjectEntry(entry)
    if P.parseBlood(entry) then return nil end
    local sheet = entry:match("^(.+)_%d+$")
    if not sheet or not F.sheets()[sheet] then
        return tostring(entry) .. " is not a known tile. Pick tiles from the sheet list."
    end
    return nil
end

function F.checkItemEntry(entry)
    if not ScriptManager.instance:getItem(entry) then
        return tostring(entry) .. " is not a known item. Pick items from the item browser."
    end
    return nil
end

function F.placeObject(job, unit)
    if not P.rollHit(job.payload.percent) then return "skip" end
    local sq = getCell():getOrCreateGridSquare(unit.x, unit.y, unit.z)
    if not sq then return "skip" end
    local entry = P.pickEntry(job.payload.entries)
    local blood = P.parseBlood(entry)
    if blood then
        addBloodSplat(sq, blood)
        return nil
    end
    local obj = IsoObject.new(sq, entry)
    sq:AddTileObject(obj)
    obj:transmitCompleteItemToClients()
    return nil
end

function F.placeItem(job, unit)
    if not P.rollHit(job.payload.percent) then return "skip" end
    local sq = getCell():getOrCreateGridSquare(unit.x, unit.y, unit.z)
    if not sq then return "skip" end
    local entry = P.pickEntry(job.payload.entries)
    for i = 1, job.payload.count do
        local item = instanceItem(entry)
        if item then
            sq:AddWorldInventoryItem(item, ZombRand(100) / 100, ZombRand(100) / 100, 0)
        end
    end
    return nil
end