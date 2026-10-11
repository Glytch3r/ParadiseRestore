-- Local composition prototype only. No event wiring, packet registration or send.
-- Both native location-1 producers must be excluded before first use.
-- Requires a trusted server source and strictly increasing global revisions.
local function integer(v,a,b) return type(v)=='number' and v>=a and v<=b and v==math.floor(v) end
local function key(e) return tostring(e.pid)..':'..tostring(e.oid) end
local function place(s) return tostring(s.x)..':'..tostring(s.y)..':'..tostring(s.z) end
local function box(n) local p=DevicePresets.new();p:addPreset('Paradise-hutch-key',n);return p:getPresetsLua()[0].frequency end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
return function(makeMembership,makeHydration,deps)
    deps=deps or {};local lookup=deps.getAnimal or getAnimal;local hutch=deps.getHutch or getHutch
    local bodyPlan={}
    local M=makeMembership({getAnimal=lookup,getHutch=hutch,canRetireBody=function(h,pos,body)
        for _,v in pairs(bodyPlan) do if v.hutch==h and v.pos==pos and v.body==body then return true end end
        return false
    end})
    local currentDestination=nil
    local bootstrap=deps.bootstrap
    if deps.bootstrapAtHutch then bootstrap=function(item,pid,oid)
        if currentDestination==nil then error('BOOTSTRAP_WITHOUT_DESTINATION') end
        return deps.bootstrapAtHutch(currentDestination,item,pid,oid)
    end end
    local H=makeHydration({getAnimal=lookup,bootstrap=bootstrap})
    local bodies=deps.makeCorpses and deps.makeCorpses(deps.corpseDependencies)
    local caches=deps.makeCache and deps.makeCache({getAnimal=lookup,getHutch=hutch})
    -- Reuse the frozen schema validator, stopping before all native placement.
    local V=makeMembership({getAnimal=function() return nil end,getHutch=function() return nil end})
    local C={epoch=nil,known={},work={},last={},retired={},receipts={},failedDelete={},counts={}}
    local function result(status) C.counts[status]=math.min((C.counts[status] or 0)+1,1000000);return status end
    function C.begin(epoch)
        if C.epoch~=nil and epoch==C.epoch then return result('SESSION_UNCHANGED') end
        if caches and caches.begin(epoch)~='SESSION_STARTED' then return result('CACHE_HOLD_PENDING') end
        if M.begin(epoch)~='SESSION_STARTED' or H.begin(epoch)~='SESSION_STARTED' or V.begin(epoch)~='SESSION_STARTED' then return result('BAD_EPOCH') end
        if bodies then bodies.clear() end
        C.epoch=epoch;C.known={};C.work={};C.last={};C.retired={};C.receipts={};C.failedDelete={};return result('SESSION_STARTED')
    end
    function C.leave()
        M.leave();H.leave();V.leave();if bodies then bodies.clear() end;if caches then caches.leave() end;C.epoch=nil;C.known={};C.work={};C.last={};C.retired={};C.receipts={};C.failedDelete={};return result('SESSION_LEFT')
    end
    -- Authenticated server renewal resets finite protocol history without
    -- deleting animals, replacing originals, or discarding exact corpse receipts.
    function C.renew(oldEpoch,newEpoch)
        if oldEpoch~=C.epoch or C.epoch==nil or type(newEpoch)~='string' or #newEpoch<1 or #newEpoch>128 or newEpoch==oldEpoch then return result('BAD_RENEWAL') end
        local observed=C.observe();if observed~='OBSERVED' then return observed end
        if caches and caches.renew(oldEpoch,newEpoch)~='SESSION_RENEWED' then return result('CACHE_RENEWAL_FAILED') end
        local kept={}
        for k,v in pairs(C.known) do if v.state=='adopted' then kept[k]=v end end
        M.begin(newEpoch);H.begin(newEpoch);V.begin(newEpoch)
        for k,v in pairs(kept) do
            v.rev=0;M.known[k]={object=v.object,owner=v.owner,rev=0};M.observed[v.owner]=v.hutch
            H.known[k]=v.object;H.latest[k]=0
        end
        C.known=kept;C.work={};C.last={};C.retired={};C.receipts={};C.epoch=newEpoch
        return result('SESSION_RENEWED')
    end
    local function exact(v)
        if v.kind=='inside' then return v.hutch:getAnimal(box(v.pos))==v.object end
        return v.hutch:getAnimalInNestBox(v.pos)==v.object
    end
    local function retireReference(v)
        local old=v.hutch;local a=v.object
        if a:getHutch()~=nil and a:getHutch()~=old then return false end
        if old:getAnimal(box(-1))~=nil or old:getDeadBody(box(-1))~=nil then return false end
        if bodies and v.kind=='inside' then
            local status=bodies.retire(a,old,v)
            if status~='BODY_ABSENT' and status~='BODY_RETIRED' then return false end
        end
        if v.kind=='inside' then
            local map=old:getAnimalInside()
            if map:get(box(v.pos))==a and not map:remove(box(v.pos),a) then return false end
        elseif old:getAnimalInNestBox(v.pos)==a then
            -- Native cleanup compares persistent IDs; reject another real alias.
            for n=0,old:getMaxNestBox() do local b=old:getAnimalInNestBox(n)
                if b and b~=a and b:getAnimalID()==a:getAnimalID() then return false end
            end
            old:tryFindAndRemoveAnimalFromNestBox(a)
        end
        -- Native removeAnimal uses its saved slot. Retire that slot first and
        -- use a verified vacant sentinel so a delayed departure cannot remove
        -- another real animal later occupying the old slot.
        if a:getHutch()==old then a:getData():setHutchPosition(-1);old:removeAnimal(a) end
        return true
    end
    local function retire(k,v,state)
        if not retireReference(v) then return 'RETIREMENT_CONFLICT' end
        C.retired[k]=math.max(C.retired[k] or 0,v.rev);C.work[v.owner]=nil;M.pending[v.owner]=nil
        if H.forgetRelation then H.forgetRelation(v.pid,v.oid) end
        v.state=state
        if state=='unloaded' then M.known[k]=nil;H.known[k]=nil
        elseif M.known[k] then M.known[k].owner=false end
        return nil
    end
    -- Called before applying/retrying snapshots. It never restores cached state.
    function C.observe()
        if C.epoch==nil then return result('NO_SESSION') end
        for k,v in pairs(C.known) do if v.state=='adopted' then
            local a=lookup(v.oid);local member=exact(v)
            local oldCurrent=hutch(v.x,v.y,v.z)==v.hutch
            local status
            if a==v.object and (a:getHutch()~=v.hutch or not member) then
                status=retire(k,v,'departed')
            elseif a==nil and not member then status=retire(k,v,'deleted')
            elseif not oldCurrent then status=retire(k,v,'unloaded')
            elseif a~=v.object then return result(a and 'IDENTITY_REUSED' or 'WAIT_NATIVE_REGISTRY') end
            if status then return result(status) end
        end end
        return result('OBSERVED')
    end
    -- Acknowledgement is returned only after exact membership is retired.
    -- The caller must send it on the same authenticated connection/session.
    function C.retire(t)
        if type(t)~='table' or C.epoch==nil or t.epoch~=C.epoch then return result('STALE_SESSION') end
        if t.protocol~=1 or not integer(t.rev,1,9007199254740991) or not integer(t.pid,0,2147483647) or not integer(t.oid,0,32767)
            or type(t.nonce)~='string' or #t.nonce<1 or #t.nonce>128
            or (t.reason~='exit' and t.reason~='delete' and t.reason~='unload') then return result('BAD_RETIREMENT') end
        local k=key(t);local v=C.known[k];local prior=C.receipts[k]
        if C.failedDelete[k] then return result('DELETE_INCOMPLETE') end
        if v and v.rev>t.rev then return result('STALE_RETIREMENT') end
        if prior and prior.rev>t.rev then return result('STALE_RETIREMENT') end
        if prior and prior.rev==t.rev and (prior.nonce~=t.nonce or prior.reason~=t.reason) then return result('RETIREMENT_CONFLICT') end
        if not prior and count(C.receipts)+count(C.failedDelete)>=4096 then return result('IDENTITY_LIMIT') end
        local a=lookup(t.oid)
        if a and (a:getAnimalID()~=t.pid or a:getOnlineID()~=t.oid) then return result('IDENTITY_MISMATCH') end
        if v and a and a~=v.object then return result('IDENTITY_REUSED') end
        if v then
            if not bodies and (v.object:isDead() or v.hutch:getDeadBody(box(v.pos))~=nil) then return result('DEAD_LIFECYCLE_UNSUPPORTED') end
            if not retireReference(v) then return result('RETIREMENT_CONFLICT') end
            v.state='retired';v.rev=t.rev
        elseif a and a:getHutch()~=nil then return result('UNKNOWN_MEMBERSHIP') end
        for w,p in pairs(C.work) do if p.snapshot.rev<=t.rev then
            for _,e in ipairs(p.snapshot.entries) do if key(e)==k then C.work[w]=nil;M.pending[w]=nil;break end end
        end end
        C.retired[k]=math.max(C.retired[k] or 0,t.rev);H.latest[k]=math.max(H.latest[k] or 0,t.rev)
        if H.forgetRelation then H.forgetRelation(t.pid,t.oid) end
        if M.known[k] then M.known[k].owner=false;M.known[k].rev=t.rev end
        if t.reason=='delete' and a~=nil then
            -- The native delete packet is a one-shot event. Remove the exact
            -- authenticated original here rather than queueing a bare online ID.
            if lookup(t.oid)~=a then return result('IDENTITY_CHANGED_DURING_HANDOFF') end
            local ok=pcall(function() a:remove() end)
            if not ok or lookup(t.oid)~=nil then C.failedDelete[k]=true;return result('DELETE_INCOMPLETE') end
            if v then v.state='deleted' end
        end
        C.receipts[k]={rev=t.rev,nonce=t.nonce,reason=t.reason}
        local ack={protocol=1,epoch=t.epoch,rev=t.rev,pid=t.pid,oid=t.oid,reason=t.reason,nonce=t.nonce,kind='RETIREMENT',hutchKey=''}
        return result(prior and prior.rev==t.rev and 'RETIREMENT_DUPLICATE' or 'RETIRED'),ack
    end
    local function copyHydration(s)
        if type(s)~='table' or type(s.sidecar)~='table' or type(s.sidecar.genes)~='table' or type(s.sidecar.disorders)~='table' then return nil end
        local v=s.sidecar;local genes,disorders={},{};local size=0
        for n,g in pairs(v.genes) do size=size+1;if size>128 or type(g)~='table' then return nil end;genes[n]={name=g.name,first=g.first,second=g.second} end
        size=0;for n,d in pairs(v.disorders) do size=size+1;if size>128 then return nil end;disorders[n]=d end
        local mom=v.mother
        if type(mom)=='table' then mom={pid=mom.pid,oid=mom.oid} end
        return {protocol=s.protocol,epoch=s.epoch,rev=s.rev,pid=s.pid,oid=s.oid,animalItem=s.animalItem,bodyItem=s.bodyItem,
            sidecar={stress=v.stress,size=v.size,originalSize=v.originalSize,name=v.name,mother=mom,genes=genes,disorders=disorders}}
    end
    function C.offer(s)
        if C.epoch==nil then return result('NO_SESSION') end
        local valid=V.offer(s)
        if valid~='WAIT_ANIMAL' and valid~='WAIT_HUTCH' and valid~='APPLIED' then return result(valid) end
        local w=place(s);local signature={}
        for _,e in ipairs(s.entries) do signature[#signature+1]=key(e)..':'..e.kind..':'..tostring(e.pos)..':'..tostring(e.preferred)..':'..tostring(e.dead==true) end
        signature=table.concat(signature,';')
        local previous=C.last[w]
        if not previous and count(C.last)>=256 then return result('HUTCH_LIMIT') end
        if previous and s.rev<previous.rev then return result('STALE_REVISION') end
        if previous and s.rev==previous.rev then return result(signature==previous.signature and 'DUPLICATE' or 'REVISION_CONFLICT') end
        local observed=C.observe();if observed~='OBSERVED' then return observed end
        if not C.work[w] and count(C.work)>=256 then return result('HUTCH_LIMIT') end
        local pending=C.work[w]
        if pending and s.rev<pending.snapshot.rev then return result('STALE_REVISION') end
        if pending and s.rev==pending.snapshot.rev then
            if signature~=pending.signature then return result('REVISION_CONFLICT') end
            return C.reconcile(w)
        end
        local copy={protocol=s.protocol,epoch=s.epoch,rev=s.rev,x=s.x,y=s.y,z=s.z,entries={}}
        for _,e in ipairs(s.entries) do
            local k=key(e)
            if C.retired[k] and s.rev<=C.retired[k] then return result('RETIRED_REVISION') end
            if e.dead==true and not bodies then return result('DEAD_LIFECYCLE_UNSUPPORTED') end
            local q=copyHydration(e.hydration)
            if not q or q.protocol~=1 or q.epoch~=s.epoch or q.rev~=s.rev or q.pid~=e.pid or q.oid~=e.oid then return result('ENVELOPE_BINDING') end
            copy.entries[#copy.entries+1]={pid=e.pid,oid=e.oid,pos=e.pos,preferred=e.preferred,kind=e.kind,dead=e.dead==true,hydration=q}
        end
        C.work[w]={snapshot=copy,signature=signature,hydrated={}}
        return C.reconcile(w)
    end
    function C.reconcile(w)
        local observed=C.observe();if observed~='OBSERVED' then return observed end
        local work=C.work[w];if not work then return result('NO_PENDING') end
        local s=work.snapshot;local destination=hutch(s.x,s.y,s.z)
        if destination==nil then return result('WAIT_HUTCH') end
        bodyPlan={}
        if bodies then for _,e in ipairs(s.entries) do
            local ready,keep,moving=bodies.keep(lookup(e.oid),destination,e)
            if ready~='READY' then return result(ready) end
            e.keepBody=keep
            if moving then bodyPlan[key(e)]=moving end
        end end
        if H.validate then for _,e in ipairs(s.entries) do if not work.hydrated[key(e)] then
            local ready=H.validate(e.hydration)
            if ready~='VALIDATED' then return result(ready) end
            if e.hydration.animalItem:getAnimal():isDead()~=e.dead then return result('DEAD_ENVELOPE_MISMATCH') end
        end end end
        if caches then
            local ready,plan=caches.inspect(destination,s)
            if ready~='CACHE_READY' then return result(ready) end
            local detached=caches.detach(plan)
            if detached~='CACHE_DETACHED' then return result(detached) end
            work.cachePlan=plan
        end
        if M.validate then
            local ready=M.validate(s)
            if ready~='VALIDATED' and ready~='WAIT_ANIMAL' then return result(ready) end
        end
        -- Every member and serialized body is validated before relocating any
        -- exact corpse membership. The original animal remains registered.
        if bodies then for k,v in pairs(bodyPlan) do
            local moved=bodies.retire(v.object,v.hutch,{pid=v.object:getAnimalID(),oid=v.object:getOnlineID(),pos=v.pos})
            if moved~='BODY_RETIRED' then return result(moved) end
            if C.known[k] then C.known[k].state='relocating' end
        end end
        bodyPlan={}
        if bodies then
            local wanted={};for _,e in ipairs(s.entries) do wanted[key(e)]=true end
            for k,v in pairs(C.known) do if v.owner==w and v.state=='adopted' and not wanted[k] and v.rev<=s.rev then
                if not retireReference(v) then return result('RETIREMENT_CONFLICT') end
                v.state='departed';v.rev=s.rev;C.retired[k]=s.rev
                if H.forgetRelation then H.forgetRelation(v.pid,v.oid) end
            end end
        end
        for _,e in ipairs(s.entries) do
            local k=key(e)
            if C.retired[k] and s.rev<=C.retired[k] then C.work[w]=nil;return result('RETIRED_REVISION') end
            if not work.hydrated[k] then
                currentDestination=destination
                local ok,status,a=pcall(H.hydrate,e.hydration)
                currentDestination=nil
                if not ok then return result('APPLY_INCOMPLETE') end
                if status~='HYDRATED' then return result(status) end
                work.hydrated[k]=a
            elseif lookup(e.oid)~=work.hydrated[k] then return result('IDENTITY_CHANGED_DURING_HANDOFF') end
        end
        local status=M.offer(s)
        if status~='APPLIED' then return result(status) end
        if bodies then for _,e in ipairs(s.entries) do
            local bodyStatus=bodies.ensure(lookup(e.oid),destination,e)
            if bodyStatus~='BODY_CREATED' and bodyStatus~='BODY_PRESERVED' and bodyStatus~='BODY_NOT_NEEDED' then return result(bodyStatus) end
        end end
        if caches and caches.commit(work.cachePlan)~='CACHE_COMMITTED' then return result('CACHE_COMMIT_REJECTED') end
        local wanted={}
        for _,e in ipairs(s.entries) do
            local k=key(e);wanted[k]=true
            C.known[k]={object=lookup(e.oid),oid=e.oid,pid=e.pid,owner=w,rev=s.rev,state='adopted',hutch=destination,kind=e.kind,pos=e.pos,dead=e.dead,x=s.x,y=s.y,z=s.z}
        end
        for k,v in pairs(C.known) do if v.owner==w and not wanted[k] and v.rev<=s.rev then
            v.state='departed';v.rev=s.rev;C.retired[k]=s.rev
            if H.forgetRelation then H.forgetRelation(v.pid,v.oid) end
        end end
        C.last[w]={rev=s.rev,signature=work.signature};C.work[w]=nil
        return result('APPLIED')
    end
    function C.resolveRelations()
        if H.resolveRelations then return H.resolveRelations() end
        return 'RELATIONS_RESOLVED',0,0
    end
    return C
end
