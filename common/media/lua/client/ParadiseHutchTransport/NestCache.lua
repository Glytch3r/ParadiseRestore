-- Isolated cached-nest reconciliation. No callbacks/network registration.
-- The caller supplies a trusted complete current authoritative hutch snapshot.
local function integer(n,a,b) return type(n)=='number' and n>=a and n<=b and n==math.floor(n) end
return function(deps)
    deps=deps or {};local lookup=deps.getAnimal or getAnimal;local find=deps.getHutch or getHutch
    local S={epoch=nil,holds={},count=0,failed={}}
    function S.begin(epoch)
        if type(epoch)~='string' or #epoch<1 or #epoch>128 then return 'BAD_EPOCH' end
        if S.count>0 then return 'CACHE_HOLD_PENDING' end
        S.epoch=epoch;S.holds={};S.failed={};return 'SESSION_STARTED'
    end
    -- Epoch renewal preserves captured references and incomplete-mutation guards.
    function S.renew(oldEpoch,newEpoch)
        if oldEpoch~=S.epoch or type(newEpoch)~='string' or #newEpoch<1 or #newEpoch>128 or oldEpoch==newEpoch then return 'BAD_EPOCH' end
        for _,p in pairs(S.holds) do p.epoch=newEpoch end
        S.epoch=newEpoch;return 'SESSION_RENEWED'
    end
    -- Only after the actual client session has ended; never a recovery operation.
    function S.leave() S.epoch=nil;S.holds={};S.failed={};S.count=0;return 'SESSION_LEFT' end
    local function eligible(h,a,n)
        return instanceof(a,'IsoAnimal') and a:getHutch()==nil and a:getNestBoxIndex()==n
            and a:getData()~=nil and a:getData():getHutchPosition()==-1
            and lookup(a:getOnlineID())~=a and not a:isExistInTheWorld()
    end
    function S.inspect(h,s)
        if not isClient() or type(s)~='table' or s.protocol~=1 or s.epoch~=S.epoch or S.epoch==nil
            or not integer(s.rev,1,9007199254740991) or not integer(s.x,-1000000,1000000) or not integer(s.y,-1000000,1000000) or not integer(s.z,-32,32)
            or not instanceof(h,'IsoHutch') or h:isOwner() or find(s.x,s.y,s.z)~=h then return 'CACHE_CONTEXT_REJECTED' end
        if S.failed[h] then return 'CACHE_DETACH_INCOMPLETE' end
        if S.holds[h] then return 'CACHE_READY',S.holds[h] end
        local max=h:getMaxNestBox()
        if not integer(max,0,31) or h:getAnimalInside():size()>256 then return 'CACHE_BOUND' end
        local candidates,pids={},{}
        for n=0,max do
            local a=h:getAnimalInNestBox(n)
            if a and eligible(h,a,n) then
                if h:getNestBox(n):getEggsNb()>256 then return 'CACHE_BOUND' end
                candidates[#candidates+1]={a=a,n=n,pid=a:getAnimalID(),oid=a:getOnlineID()};pids[a:getAnimalID()]=true
            end
        end
        if S.count+#candidates>4096 then return 'CACHE_HOLD_BOUND' end
        -- Native removal matches persistent IDs, so inspect every matching nest
        -- before permitting it to touch any entry, including colliding IDs.
        for n=0,max do local a=h:getAnimalInNestBox(n)
            if a and pids[a:getAnimalID()] and not eligible(h,a,n) then return 'CACHE_REAL_ID_COLLISION' end
        end
        return 'CACHE_READY',{h=h,epoch=s.epoch,rev=s.rev,x=s.x,y=s.y,z=s.z,max=max,entries=candidates,detached=false}
    end
    function S.detach(p)
        if type(p)~='table' or p.epoch~=S.epoch or find(p.x,p.y,p.z)~=p.h then return 'CACHE_CONTEXT_REJECTED' end
        local h=p.h
        if S.failed[h] then return 'CACHE_DETACH_INCOMPLETE' end
        if p.detached and (S.holds[h]==p or #p.entries==0) then return 'CACHE_DETACHED' end
        if S.holds[h] then return 'CACHE_HOLD_CONFLICT' end
        if not isClient() or h:isOwner() or h:getMaxNestBox()~=p.max then return 'CACHE_CHANGED' end
        local pids,slots={},{}
        for _,e in ipairs(p.entries) do
            if h:getAnimalInNestBox(e.n)~=e.a or not eligible(h,e.a,e.n) or e.a:getAnimalID()~=e.pid or e.a:getOnlineID()~=e.oid then return 'CACHE_CHANGED' end
            pids[e.pid]=true;slots[e.n]=e.a
        end
        -- Repeat the complete native PID-removal footprint check immediately
        -- before mutation: a newly inserted real or uncaptured cache is preserved.
        for n=0,p.max do local a=h:getAnimalInNestBox(n)
            if a and pids[a:getAnimalID()] and slots[n]~=a then return 'CACHE_CHANGED' end
        end
        if S.count+#p.entries>4096 then return 'CACHE_HOLD_BOUND' end
        if #p.entries==0 then p.detached=true;return 'CACHE_DETACHED' end
        -- Capture before first native mutation. Never delete a replica or invoke
        -- removeFromWorld; retain exact references if any later stage fails.
        S.holds[h]=p;S.count=S.count+#p.entries;S.failed[h]=true
        local ok=pcall(function()
            for _,e in ipairs(p.entries) do
                if h:getAnimalInNestBox(e.n)==e.a then h:tryFindAndRemoveAnimalFromNestBox(e.a) end
            end
            for _,e in ipairs(p.entries) do if h:getAnimalInNestBox(e.n)~=nil then error('CACHE_NOT_DETACHED') end end
        end)
        if not ok then return 'CACHE_DETACH_INCOMPLETE' end
        p.detached=true;S.failed[h]=nil;return 'CACHE_DETACHED'
    end
    -- Call only after the complete authoritative snapshot has committed. It
    -- releases private display-cache references, not real animals or world data.
    function S.commit(p)
        if p and p.epoch==S.epoch and p.detached and #p.entries==0 then return 'CACHE_COMMITTED' end
        if not p or S.holds[p.h]~=p or S.failed[p.h] or not p.detached then return 'CACHE_COMMIT_REJECTED' end
        S.holds[p.h]=nil;S.count=S.count-#p.entries;return 'CACHE_COMMITTED'
    end
    return S
end
