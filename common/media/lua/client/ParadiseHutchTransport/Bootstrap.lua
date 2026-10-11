-- Existing-Workshop prototype. No event registration and no client Java code.
-- Only materializes the exact server-supplied native animal, never a guessed ID.
return function(deps)
    deps=deps or {}
    local lookup=deps.getAnimal or getAnimal
    local findHutch=deps.getHutch or getHutch
    local S={busy={},failed={},count=0,diagnostics={}}
    local function failure(k,why)
        S.failed[k]=why
        S.diagnostics[why]=math.min((S.diagnostics[why] or 0)+1,1000000)
        error(why)
    end
    function S.create(h,item,pid,oid)
        if not h or not instanceof(h,'IsoHutch') or not instanceof(item,'AnimalInventoryItem') then error('BOOTSTRAP_ARGUMENT') end
        local clean=item:getAnimal()
        if not clean or clean:getAnimalID()~=pid or clean:getOnlineID()~=oid then error('BOOTSTRAP_SOURCE_ID') end
        if clean:getHutch()~=nil or clean:getData()==nil or clean:getBreed()==nil then error('BOOTSTRAP_SOURCE_STATE') end
        if lookup(oid)~=nil then error('BOOTSTRAP_OCCUPIED_ID') end
        local k=tostring(pid)..':'..tostring(oid)
        if S.busy[k] or S.failed[k] then error('BOOTSTRAP_REENTRY_OR_PARTIAL') end
        local sq=h:getSquare()
        if not sq or findHutch(sq:getX(),sq:getY(),sq:getZ())~=h or sq:isWaterSquare() then error('BOOTSTRAP_DESTINATION') end
        local failures=0;for _ in pairs(S.failed) do failures=failures+1 end
        if failures>=128 then error('BOOTSTRAP_PARTIAL_FAILURE_BOUND') end
        S.busy[k]=true;S.count=math.min(S.count+1,1000000)
        -- An exception during native construction can happen after world entry.
        -- Record it and forbid a blind retry. Never delete unidentified objects.
        local ok,a=pcall(function()
            if lookup(oid)~=nil then error('BOOTSTRAP_OCCUPIED_ID') end
            sq:AddWorldInventoryItem(item,0,0,0,false)
            local replica=lookup(oid)
            if not replica or replica==clean or replica:getAnimalID()~=pid or replica:getOnlineID()~=oid then error('BOOTSTRAP_RESULT_ID') end
            if replica:getData()==nil or replica:getBreed()~=clean:getBreed() or replica:getAnimalType()~=clean:getAnimalType() then error('BOOTSTRAP_RESULT_STATE') end
            if findHutch(sq:getX(),sq:getY(),sq:getZ())~=h then error('BOOTSTRAP_DESTINATION_CHANGED') end
            return replica
        end)
        S.busy[k]=nil
        if not ok then S.lastFailure=tostring(a):sub(1,512);failure(k,'BOOTSTRAP_INCOMPLETE') end
        -- Caller must perform full native hydration and exact placement in the
        -- same callback before acknowledging the snapshot. copyFrom is partial.
        return a
    end
    function S.leave() S.busy={};S.failed={};S.count=0 end
    return S
end
