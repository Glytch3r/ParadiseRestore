ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.Wall = ParadisePOIBuilder.Wall or {}
if ParadisePOIBuilder.isB41() then return end

require "TimedActions/ISDestroyStuffAction"

local P = ParadisePOIBuilder
local W = P.Wall

function W.applyProps(obj, props)
    obj:setMaxHealth(props.hp)
    obj:setHealth(props.hp)
    obj:setName(P.WALL_NAME)
    obj:setBreakSound(P.WALL_BREAK_SOUND)
    obj:setCanBarricade(false)
    obj:setIsDismantable(false)
    obj:setIsThumpable(not props.indestructible)
    obj:setIsHoppable(props.climb)
    obj:getModData().ParadisePOIBuilder = {
        sledge = props.sledge,
        indestructible = props.indestructible,
        climb = props.climb,
    }
end

function W.place(job, unit)
    local sq = getCell():getGridSquare(unit.x, unit.y, unit.z)
    if not sq then return "skip" end
    if sq:getWall(unit.north) then return "skip" end
    local sprName = unit.north and job.payload.northSprite or job.payload.westSprite
    local obj = IsoThumpable.new(getCell(), sq, sprName, unit.north, nil)
    W.applyProps(obj, job.payload)
    sq:AddSpecialObject(obj)
    sq:RecalcAllWithNeighbours(true)
    obj:transmitCompleteItemToClients()
    return true
end

W.destroyHook = W.destroyHook or ISDestroyStuffAction.complete

function W.onDestroyComplete(act)
    if P.isSledgeProof(act and act.item) then return false end
    return W.destroyHook(act)
end
if ISDestroyStuffAction.complete ~= W.onDestroyComplete then
    ISDestroyStuffAction.complete = W.onDestroyComplete
end
