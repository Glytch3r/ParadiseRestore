
-- client/WaveCaster_Wave.lua
WaveCaster = WaveCaster or {}


function WaveCaster.moveToXYZ(zed, x, y, z)
    zed:clearAggroList()
    zed:setTarget(nil)

    zed:getPathFindBehavior2():reset()
    zed:getPathFindBehavior2():cancel()
    zed:setPath2(nil)
	--zed:getPathFindBehavior2():pathToLocation(x, y, z)
	local sq = getCell():getOrCreateGridSquare(x, y, z)
	if not sq:TreatAsSolidFloor() and sq:getZ() == zed:getZ() then
		zed:setVariable("bPathfind", false)
		zed:setVariable("bMoving", true)
	end
end

function WaveCaster.getSpawnRandomZedInfo(fit)
    fit = fit or ''
    local maleOutfits = getAllOutfits(false)
    local femaleOutfits = getAllOutfits(true)
    local allOutfits = {}

    for i = 0, maleOutfits:size() - 1 do
        table.insert(allOutfits, maleOutfits:get(i))
    end
    for i = 0, femaleOutfits:size() - 1 do
        table.insert(allOutfits, femaleOutfits:get(i))
    end

    if not fit or fit == '' or string.lower(fit) =='none' then
        fit = allOutfits[ZombRand(#allOutfits) + 1]
    end
    local outfitExists = false
    for _, outfit in ipairs(allOutfits) do
        if outfit == fit then
            outfitExists = true
            break
        end
    end
    if not outfitExists then
        fit = allOutfits[ZombRand(#allOutfits) + 1]
    end

    if maleOutfits:contains(fit) and femaleOutfits:contains(fit) then
        return fit, 0
    elseif femaleOutfits:contains(fit) then
        return fit, 100
    else
        return fit, 0
    end
end

