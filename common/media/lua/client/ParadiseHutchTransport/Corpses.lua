-- Isolated native corpse lifecycle composition. No events, network or world saves.
local function key(e) return tostring(e.pid)..':'..tostring(e.oid) end
local function box(n) local p=DevicePresets.new();p:addPreset('Paradise-hutch-key',n);return p:getPresetsLua()[0].frequency end
local function identity(a,e) return a and a:getAnimalID()==e.pid and a:getOnlineID()==e.oid end
return function(deps)
    deps=deps or {};local S={known={},failed={}}
    local construct=deps.construct or function(h,a) h:killAnimal(a) end
    function S.clear() S.known={};S.failed={} end
    function S.keep(a,h,e)
        local k=key(e);local v=S.known[k]
        if S.failed[k] then return 'BODY_APPLY_INCOMPLETE' end
        if e.dead~=true then
            if v then return 'BODY_LIFECYCLE_CONFLICT' end
            return 'READY',false
        end
        if v and (v.object~=a or v.hutch~=h or v.pos~=e.pos or e.kind~='inside') then
            if v.object~=a or not identity(a,e) or v.hutch:getDeadBody(box(v.pos))~=v.body or v.hutch:getAnimal(box(v.pos))~=a
                or a:getHutch()~=v.hutch or a:getData():getHutchPosition()~=v.pos then return 'BODY_IDENTITY_CONFLICT' end
            return 'READY',false,v
        end
        -- Native nest pickup UI has no corpse consumer. Preserve the exact
        -- dead animal in its authoritative nest without inventing body[-1].
        if e.kind=='nest' then
            return 'READY',false
        end
        local body=h:getDeadBody(box(e.pos))
        if v then
            if body~=v.body or h:getAnimal(box(e.pos))~=a or a:getHutch()~=h or a:getData():getHutchPosition()~=e.pos then return 'BODY_IDENTITY_CONFLICT' end
            return 'READY',true
        end
        if body~=nil then return 'UNRECOGNIZED_BODY' end
        return 'READY',false
    end
    function S.ensure(a,h,e)
        local status,keep=S.keep(a,h,e)
        if status~='READY' then return status end
        if e.dead~=true then return 'BODY_NOT_NEEDED' end
        if e.kind=='nest' then
            if not identity(a,e) or not a:isDead() or a:getHutch()~=h or a:getNestBoxIndex()~=e.pos or a:getData():getHutchPosition()~=-1 or h:getAnimalInNestBox(e.pos)~=a then return 'BODY_SOURCE_MISMATCH' end
            return 'BODY_NOT_NEEDED'
        end
        if not identity(a,e) or not a:isDead() or a:getHutch()~=h or a:getNestBoxIndex()~=-1 or a:getData():getHutchPosition()~=e.pos or h:getAnimal(box(e.pos))~=a then return 'BODY_SOURCE_MISMATCH' end
        if keep then return 'BODY_PRESERVED' end
        local k=key(e);local n=0;for _ in pairs(S.known) do n=n+1 end
        if n>=4096 then return 'BODY_LIMIT' end
        -- Record the attempt before a native constructor can run callbacks.
        S.failed[k]=true
        local ok=pcall(construct,h,a)
        local body=h:getDeadBody(box(e.pos))
        if not ok or body==nil or body:getCharacterOnlineID()~=e.oid or h:getAnimal(box(e.pos))~=a or not identity(a,e) then return 'BODY_APPLY_INCOMPLETE' end
        S.known[k]={body=body,object=a,hutch=h,pos=e.pos};S.failed[k]=nil
        return 'BODY_CREATED'
    end
    function S.retire(a,h,e)
        local k=key(e);local v=S.known[k]
        if S.failed[k] then return 'BODY_APPLY_INCOMPLETE' end
        local body=h:getDeadBody(box(e.pos))
        if v==nil then return body and 'UNRECOGNIZED_BODY' or 'BODY_ABSENT' end
        -- Native pickup/departure may already have removed both exact slots.
        -- Retiring our receipt does not destroy the body/item now held elsewhere.
        if identity(a,e) and v.object==a and v.hutch==h and v.pos==e.pos and body==nil and h:getAnimal(box(e.pos))==nil then
            S.known[k]=nil;return 'BODY_RETIRED'
        end
        if not identity(a,e) or v.object~=a or v.hutch~=h or v.pos~=e.pos or body~=v.body or body:getCharacterOnlineID()~=e.oid
            or h:getAnimal(box(e.pos))~=a or a:getHutch()~=h or a:getData():getHutchPosition()~=e.pos then return 'BODY_IDENTITY_CONFLICT' end
        -- Exact membership and body were checked before native two-map removal.
        h:removeAnimal(a)
        if h:getDeadBody(box(e.pos))~=nil or h:getAnimal(box(e.pos))~=nil or a:getHutch()~=nil then return 'BODY_APPLY_INCOMPLETE' end
        S.known[k]=nil;return 'BODY_RETIRED'
    end
    return S
end
