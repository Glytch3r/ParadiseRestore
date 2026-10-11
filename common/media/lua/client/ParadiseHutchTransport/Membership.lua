-- Isolated protocol prototype. No events are registered and no packets are sent.
-- Requires BOTH native location-1 writers to be prevented before first hydration.
-- Call synchronously on the game-owning thread, never while a chunk is unloading.
local function box(n)
    local p=DevicePresets.new(); p:addPreset('Paradise-hutch-key',n)
    local k=p:getPresetsLua()[0].frequency
    if type(k)~='userdata' then error('Integer adapter unavailable') end
    return k
end
local function integer(n,lo,hi) return type(n)=='number' and n>=lo and n<=hi and n==math.floor(n) end
local function key(e) return tostring(e.pid)..':'..tostring(e.oid) end
local function where(s) return tostring(s.x)..':'..tostring(s.y)..':'..tostring(s.z) end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function exactNest(h,a,wanted)
    if h:getAnimalInNestBox(wanted)~=nil then return false,'OCCUPIED' end
    local blockers,removed={},{}
    local target=h:getNestBox(wanted)
    local ok,result=pcall(function()
        for n=0,wanted-1 do
            if h:getAnimalInNestBox(n)==nil then
                local b=h:getNestBox(n); blockers[#blockers+1]={b=b,count=b:getEggsNb()}
                while b:getEggsNb()<10 do b:addEgg(nil) end
            end
        end
        while target:getEggsNb()>=10 do removed[#removed+1]={value=target:removeEgg(target:getEggsNb()-1)} end
        return h:addAnimalInNestBox(a)
    end)
    local restored=pcall(function()
        for n=#blockers,1,-1 do
            local b=blockers[n]
            while b.b:getEggsNb()>b.count do b.b:removeEgg(b.b:getEggsNb()-1) end
        end
        for n=#removed,1,-1 do target:addEgg(removed[n].value) end
    end)
    if not restored then return false,'EGG_RESTORE_ERROR' end
    if not ok then return false,'NATIVE_ERROR' end
    return result,result and 'PLACED' or 'NATIVE_REFUSED'
end

return function(deps)
    deps=deps or {}
    local animalLookup=deps.getAnimal or getAnimal
    local hutchLookup=deps.getHutch or getHutch
    local S={epoch=nil,pending={},observed={},known={},revisions={},counts={}}
    local function result(status)
        S.counts[status]=math.min((S.counts[status] or 0)+1,1000000)
        return status
    end
    function S.begin(epoch)
        if type(epoch)~='string' or #epoch<1 or #epoch>128 then return result('BAD_EPOCH') end
        S.epoch=epoch;S.pending={};S.observed={};S.known={};S.revisions={}
        return result('SESSION_STARTED')
    end
    function S.leave()
        S.epoch=nil;S.pending={};S.observed={};S.known={};S.revisions={}
        return result('SESSION_LEFT')
    end
    local function validate(s)
        if type(s)~='table' or s.protocol~=1 or s.epoch~=S.epoch or S.epoch==nil then return 'STALE_SESSION' end
        if not integer(s.rev,1,9007199254740991) or not integer(s.x,-1000000,1000000) or not integer(s.y,-1000000,1000000) or not integer(s.z,-32,32) then return 'BAD_SNAPSHOT' end
        if type(s.entries)~='table' or #s.entries>128 then return 'BAD_SNAPSHOT' end
        local length=#s.entries
        for k in pairs(s.entries) do if not integer(k,1,length) then return 'BAD_ENTRY_INDEX' end end
        if count(s.entries)~=length then return 'BAD_ENTRY_INDEX' end
        local ids,pids,oids,positions={},{},{},{}
        for n,e in ipairs(s.entries) do
            if type(e)~='table' or not integer(e.pid,0,2147483647) or not integer(e.oid,0,32767) or not integer(e.pos,0,255) or not integer(e.preferred,-1,255) or (e.kind~='inside' and e.kind~='nest') then return 'BAD_ENTRY' end
            local k=key(e);local p=e.kind..':'..tostring(e.pos)
            if ids[k] or pids[e.pid] or oids[e.oid] or positions[p] then return 'DUPLICATE_ENTRY' end
            ids[k]=true;pids[e.pid]=true;oids[e.oid]=true;positions[p]=true
        end
    end
    function S.offer(s)
        local invalid=validate(s);if invalid then return result(invalid) end
        local w=where(s)
        if not S.pending[w] and count(S.pending)>=256 then return result('HUTCH_LIMIT') end
        if S.revisions[w] and s.rev<S.revisions[w] then return result('STALE_REVISION') end
        if S.pending[w] and s.rev<S.pending[w].rev then return result('STALE_REVISION') end
        -- Snapshot is privately copied; caller mutation cannot alter validated data.
        local copy={protocol=1,epoch=s.epoch,rev=s.rev,x=s.x,y=s.y,z=s.z,entries={}}
        for _,e in ipairs(s.entries) do copy.entries[#copy.entries+1]={pid=e.pid,oid=e.oid,pos=e.pos,preferred=e.preferred,kind=e.kind,keepBody=e.keepBody==true} end
        local parts={};for _,e in ipairs(copy.entries) do parts[#parts+1]=key(e)..':'..e.kind..':'..tostring(e.pos)..':'..tostring(e.preferred) end
        copy.signature=table.concat(parts,';')
        if S.pending[w] and s.rev==S.pending[w].rev and copy.signature~=S.pending[w].signature then return result('REVISION_CONFLICT') end
        S.pending[w]=copy
        return S.reconcile(w,S.validationOnly)
    end
    -- Isolated coordinator extension: execute the same complete native-state
    -- validation, stopping before placement or commit and restoring local caches.
    function S.validate(s)
        local pending,observed=S.pending,S.observed
        local staged,seen={},{}
        for k,v in pairs(pending) do staged[k]=v end
        for k,v in pairs(observed) do seen[k]=v end
        S.pending=staged;S.observed=seen;S.validationOnly=true
        local ok,status=pcall(S.offer,s)
        S.validationOnly=false;S.pending=pending;S.observed=observed
        if not ok then return result('VALIDATION_ERROR') end
        return status
    end
    function S.reconcile(w,validateOnly)
        if S.epoch==nil then return result('NO_SESSION') end
        local s=S.pending[w];if not s then return result('NO_SNAPSHOT') end
        local h=hutchLookup(s.x,s.y,s.z);if h==nil then return result('WAIT_HUTCH') end
        if not instanceof(h,'IsoHutch') then return result('HUTCH_TYPE_MISMATCH') end
        local max=h:getMaxAnimals();local maxNest=h:getMaxNestBox()
        if not integer(max,1,256) or not integer(maxNest,0,31) then return result('UNSUPPORTED_HUTCH') end
        S.observed[w]=h
        local wanted,objects,entries,detach,retained={}, {}, {}, {}, {}
        for _,e in ipairs(s.entries) do
            local k=key(e);local prior=S.known[k]
            if prior and prior.rev>s.rev then return result('STALE_ANIMAL_REVISION') end
            local a=animalLookup(e.oid)
            if a==nil then return result('WAIT_ANIMAL') end
            if not instanceof(a,'IsoAnimal') then return result('ANIMAL_TYPE_MISMATCH') end
            if a:getAnimalID()~=e.pid or a:getOnlineID()~=e.oid then return result('IDENTITY_MISMATCH') end
            if prior and prior.object~=a then return result('IDENTITY_REUSED') end
            if prior and prior.rev==s.rev and prior.owner and prior.owner~=w then return result('OWNER_REVISION_CONFLICT') end
            if a:getData()==nil or (e.kind=='inside' and e.pos>=max) or (e.kind=='nest' and e.pos>maxNest) then return result('BAD_PLACEMENT') end
            wanted[k]=true;objects[a]=true;entries[a]=e
            if e.keepBody then
                if e.kind~='inside' or a:getHutch()~=h or a:getData():getHutchPosition()~=e.pos or a:getNestBoxIndex()~=-1 or h:getAnimal(box(e.pos))~=a or h:getDeadBody(box(e.pos))==nil then return result('BODY_KEEP_MISMATCH') end
                retained[a]=true
            else detach[a]=true end
        end
        local newIdentities=0;for k in pairs(wanted) do if not S.known[k] then newIdentities=newIdentities+1 end end
        if count(S.known)+newIdentities>4096 then return result('IDENTITY_LIMIT') end
        -- A full snapshot can retire only identities previously adopted here.
        for k,v in pairs(S.known) do
            if v.owner==w and v.rev<=s.rev and not wanted[k] then detach[v.object]=true end
        end
        -- Resolve an animal's actual hutch even if it was not observed earlier.
        local hutches,seen={},{}
        local function addHutch(v)
            if v~=nil and not seen[v] then seen[v]=true;hutches[#hutches+1]=v end
        end
        addHutch(h)
        for _,v in pairs(S.observed) do addHutch(v) end
        for a in pairs(detach) do addHutch(a:getHutch()) end
        local removals={}
        local nestReferences=0
        for _,v in ipairs(hutches) do
            if v:getAnimalInside():size()>256 or v:getMaxNestBox()>31 then return result('SCAN_LIMIT') end
            if v:getAnimal(box(-1))~=nil or v:getDeadBody(box(-1))~=nil then return result('SENTINEL_OCCUPIED') end
            local map=v:getAnimalInside();local keys=ArrayList.new(map:keySet())
            if map:containsValue(nil) then return result('PREEXISTING_NULL') end
            for n=0,keys:size()-1 do
                local slot=keys:get(n)
                if not integer(slot,0,255) then return result('UNKNOWN_MAP_KEY') end
                local k=box(slot);local a=map:get(k)
                if a==nil then return result('UNKNOWN_MAP_KEY') end
                if detach[a] then removals[#removals+1]={map=map,key=k,object=a}
                elseif retained[a] and v~=h then return result('BODY_ALIAS')
                elseif v==h and not retained[a] then return result('UNRECOGNIZED_OCCUPANT') end
            end
            for n=0,v:getMaxNestBox() do
                local a=v:getAnimalInNestBox(n)
                if v:getNestBox(n):getEggsNb()>256 then return result('EGG_LIMIT') end
                if a~=nil then
                    -- Native removal compares persistent IDs; reject aliases first.
                    for d in pairs(detach) do if a~=d and a:getAnimalID()==d:getAnimalID() then return result('PERSISTENT_ID_COLLISION') end end
                    if v==h and not detach[a] then return result('UNRECOGNIZED_OCCUPANT') end
                    if detach[a] then nestReferences=nestReferences+1 end
                end
            end
        end
        -- Native inside placement must never enter its random fallback loop.
        for a,e in pairs(entries) do
            if e.kind=='inside' then
                local body=h:getDeadBody(box(e.pos))
                if body~=nil and not retained[a] and not (deps.canRetireBody and deps.canRetireBody(h,e.pos,body)) then return result('DEAD_BODY_COLLISION') end
                for b,f in pairs(entries) do if f.kind=='nest' and f.preferred==e.pos then return result('PREFERRED_POSITION_COLLISION') end end
            end
        end
        local function commit()
            for k,v in pairs(S.known) do
                if v.owner==w and v.rev<=s.rev and not wanted[k] then v.owner=false;v.rev=s.rev end
            end
            for _,e in ipairs(s.entries) do S.known[key(e)]={object=animalLookup(e.oid),owner=w,rev=s.rev} end
            S.revisions[w]=s.rev
        end
        local exact=true;local insideCount,nestCount=0,0
        for a,e in pairs(entries) do
            if a:getHutch()~=h or a:getData():getPreferredHutchPosition()~=(e.kind=='inside' and e.pos or e.preferred) then exact=false end
            if e.kind=='inside' then
                if not retained[a] then insideCount=insideCount+1 end
                if h:getAnimal(box(e.pos))~=a or a:getData():getHutchPosition()~=e.pos or a:getNestBoxIndex()~=-1 then exact=false end
            else
                nestCount=nestCount+1
                if h:getAnimalInNestBox(e.pos)~=a or a:getNestBoxIndex()~=e.pos or a:getData():getHutchPosition()~=-1 then exact=false end
            end
        end
        for a in pairs(detach) do if not entries[a] and a:getHutch()~=nil then exact=false end end
        if #removals~=insideCount or nestReferences~=nestCount then exact=false end
        if exact then if validateOnly then return result('VALIDATED') end;commit();return result('APPLIED') end
        if validateOnly then return result('VALIDATED') end
        -- Phase two begins only after every destination and identity is resolved.
        local ok,failure=pcall(function()
            for _,r in ipairs(removals) do
                if not r.map:remove(r.key,r.object) then error('IDENTITY_CHANGED_DURING_APPLY') end
            end
            for a in pairs(detach) do
                for _,v in ipairs(hutches) do v:tryFindAndRemoveAnimalFromNestBox(a) end
                a:getData():setHutchPosition(-1)
                local old=a:getHutch();if old~=nil then old:removeAnimal(a) end
            end
            -- All objects are detached before any reattachment; swaps are safe.
            for _,e in ipairs(s.entries) do
                local a=animalLookup(e.oid)
                if not retained[a] then
                a:getData():setPreferredHutchPosition(e.kind=='inside' and e.pos or e.preferred)
                local placed,why
                if e.kind=='inside' then placed=h:addAnimalInside(a,false)
                else placed,why=exactNest(h,a,e.pos) end
                if not placed then error(why or 'NATIVE_REFUSED') end
                if (e.kind=='inside' and h:getAnimal(box(e.pos))~=a) or (e.kind=='nest' and h:getAnimalInNestBox(e.pos)~=a) then error('PLACEMENT_MISMATCH') end
                end
            end
        end)
        if not ok then return result('APPLY_INCOMPLETE') end
        commit()
        return result('APPLIED')
    end
    return S
end
