-- Isolated existing-Workshop capability prototype. No event registration or sending.
-- Caller supplies a trusted, atomic server snapshot pairing clean native animal
-- envelope + native save body + runtime sidecars. Ordinary Lua cannot inspect or
-- rewind the opaque buffer; binding those three is the server sender's contract.
local function integer(n,lo,hi) return type(n)=='number' and n>=lo and n<=hi and n==math.floor(n) end
local function number(n,lo,hi) return type(n)=='number' and n==n and n>=lo and n<=hi end
local function native(v,t) return v~=nil and instanceof(v,t) end
local function identity(a,pid,oid) return native(a,'IsoAnimal') and a:getAnimalID()==pid and a:getOnlineID()==oid end
local function id(s) return tostring(s.pid)..':'..tostring(s.oid) end
return function(deps)
    deps=deps or {};local lookup=deps.getAnimal or getAnimal
    -- Kahlua's ordinary tables do not implement weak-key collection. Keep the
    -- one-use mark on the two temporary transport items themselves instead of
    -- retaining every historical envelope or imposing a session-length cutoff.
    local receiptKey='ParadiseHutchHydrationReceiptR4'
    local S={epoch=nil,latest={},known={},pendingRelations={},counts={},consumed=0,receipts={},receiptIndex=0}
    local function result(code,a)
        S.counts[code]=math.min((S.counts[code] or 0)+1,1000000)
        return code,a
    end
    function S.begin(epoch)
        if type(epoch)~='string' or #epoch<1 or #epoch>128 then return result('BAD_EPOCH') end
        S.epoch=epoch;S.latest={};S.known={};S.pendingRelations={};S.consumed=0;S.receipts={};S.receiptIndex=0
        return result('SESSION_STARTED')
    end
    function S.leave()
        S.epoch=nil;S.latest={};S.known={};S.pendingRelations={};S.consumed=0;S.receipts={};S.receiptIndex=0
        return result('SESSION_LEFT')
    end
    local function validate(s)
        if type(s)~='table' or S.epoch==nil or s.epoch~=S.epoch then return 'STALE_SESSION' end
        if s.protocol~=1 or not integer(s.rev,1,9007199254740991) or not integer(s.pid,0,2147483647) or not integer(s.oid,0,32767) then return 'BAD_HEADER' end
        if not native(s.animalItem,'AnimalInventoryItem') or not native(s.bodyItem,'InventoryItem') or s.animalItem==s.bodyItem then return 'BAD_ENVELOPES' end
        if s.bodyItem:getFullType()~='Base.Animal_Item_Dummy' or s.bodyItem:getByteData()==nil then return 'BAD_BODY' end
        local clean=s.animalItem:getAnimal()
        if not identity(clean,s.pid,s.oid) then return 'BAD_ENVELOPE_ID' end
        local raw=s.bodyItem:getByteData()
        local used=(s.bodyItem:hasModData() and s.bodyItem:getModData()[receiptKey]) or (s.animalItem:hasModData() and s.animalItem:getModData()[receiptKey])
        if used then return used.status=='HYDRATED' and 'ENVELOPE_CONSUMED' or 'PREVIOUS_PARTIAL_FAILURE' end
        local k=id(s);local last=S.latest[k]
        if last==nil then local identities=0;for _ in pairs(S.latest) do identities=identities+1 end
            if identities>=4096 then return 'IDENTITY_BOUND' end
        end
        if last and s.rev<=last then return 'STALE_REVISION' end
        local a=lookup(s.oid)
        if a and not identity(a,s.pid,s.oid) then return 'IDENTITY_MISMATCH' end
        if a and S.known[k] and S.known[k]~=a then return 'IDENTITY_REUSED' end
        if clean==a then return 'ENVELOPE_IS_ORIGINAL' end
        if a and (a:getAnimalType()~=clean:getAnimalType() or a:getBreed()~=clean:getBreed()) then return 'TYPE_CHANGE_UNSUPPORTED' end
        if a and (a:getFullGenome()==clean:getFullGenome() or a:getData()==clean:getData() or a:getGeneticDisorder()==clean:getGeneticDisorder()) then return 'ENVELOPE_ALIAS' end
        local v=s.sidecar
        if type(v)~='table' or not number(v.stress,0,100) or not number(v.size,0.001,100) or not number(v.originalSize,0.001,100) or type(v.name)~='string' or #v.name>256 then return 'BAD_SIDECAR' end
        if type(v.genes)~='table' or #v.genes>128 then return 'BAD_GENES' end
        if type(v.disorders)~='table' or #v.disorders>128 then return 'BAD_DISORDERS' end
        local disorders=0
        for ix,d in pairs(v.disorders) do
            if not integer(ix,1,#v.disorders) or type(d)~='string' or #d<1 or #d>256 then return 'BAD_DISORDERS' end
            disorders=disorders+1
        end
        if disorders~=#v.disorders then return 'BAD_DISORDERS' end
        local n=0;for ix in pairs(v.genes) do if not integer(ix,1,#v.genes) then return 'BAD_GENES' end;n=n+1 end
        if n~=#v.genes or clean:getFullGenome():size()~=n then return 'GENE_SET_MISMATCH' end
        local names={}
        for _,g in ipairs(v.genes) do
            if type(g)~='table' or type(g.name)~='string' or #g.name<1 or #g.name>128 or names[g.name] or type(g.first)~='boolean' or type(g.second)~='boolean' then return 'BAD_GENE' end
            local ng=clean:getFullGenome():get(g.name)
            if ng==nil or ng:getAllele1()==nil or ng:getAllele2()==nil then return 'GENE_SET_MISMATCH' end
            names[g.name]=true
        end
        local mom=nil;local pendingMother=nil
        if v.mother~=false then
            if type(v.mother)~='table' or not integer(v.mother.pid,0,2147483647) or not integer(v.mother.oid,0,32767) or v.mother.pid==s.pid then return 'BAD_MOTHER' end
            mom=lookup(v.mother.oid)
            if not identity(mom,v.mother.pid,v.mother.oid) then
                mom=nil;pendingMother={pid=v.mother.pid,oid=v.mother.oid}
            end
            local babies=mom and mom:getBabies()
            if babies then
                if babies:size()>256 then return 'FAMILY_BOUND' end
                for i=0,babies:size()-1 do local b=babies:get(i)
                    if b~=a and b:getAnimalID()==s.pid then return 'MOTHER_CHILD_ALIAS' end
                end
            end
        elseif a and a:getMother()~=nil then return 'MOTHER_CLEAR_UNSUPPORTED' end
        if a==nil and type(deps.bootstrap)~='function' then return 'WAIT_BOOTSTRAP',{missingAnimal={pid=s.pid,oid=s.oid}} end
        return nil,{a=a,clean=clean,mom=mom,pendingMother=pendingMother,raw=raw,key=k}
    end
    -- Read-only preflight; does not even allocate item modData. It neither
    -- increments diagnostics nor returns a cached authorization for mutation.
    -- hydrate repeats this validation on the same synchronous owner thread.
    function S.validate(s)
        local ok,err,p=pcall(validate,s)
        if not ok then return 'VALIDATION_ERROR' end
        if err then return err,nil,p end
        return 'VALIDATED',p.a,p.pendingMother and {pendingMother=p.pendingMother} or nil
    end
    function S.hydrate(s)
        local ok,err,p=pcall(validate,s)
        if not ok then return result('VALIDATION_ERROR') end
        if err then return result(err) end
        -- Consumption starts before any mutation and remains recorded on failure.
        local receipt={status='APPLY_INCOMPLETE',pid=s.pid,oid=s.oid,rev=s.rev}
        s.bodyItem:getModData()[receiptKey]=receipt;s.animalItem:getModData()[receiptKey]=receipt
        S.consumed=math.min(S.consumed+1,1000000);S.receiptIndex=S.receiptIndex%128+1;S.receipts[S.receiptIndex]=receipt
        local a=p.a;local prior=nil
        local applied,why=pcall(function()
            if a==nil then
                a=deps.bootstrap(s.animalItem,s.pid,s.oid)
                if not identity(a,s.pid,s.oid) or lookup(s.oid)~=a then error('BOOTSTRAP_IDENTITY') end
            end
            receipt.original=a
            local h=a:getHutch();local nest=a:getNestBoxIndex();local position=a:getData():getHutchPosition();local preferred=a:getData():getPreferredHutchPosition()
            prior={h=h,nest=nest,position=position,preferred=preferred};receipt.phase='COPY'
            local oldMom=a:getMother()
            a:copyFrom(p.clean)
            receipt.phase='LOAD'
            a:load(p.raw,249,false)
            receipt.phase='SIDECARS'
            if not identity(a,s.pid,s.oid) or lookup(s.oid)~=a then error('BODY_IDENTITY') end
            if a:getAnimalType()~=p.clean:getAnimalType() or a:getBreed()~=p.clean:getBreed() then error('BODY_TYPE') end
            if a:getFullGenome():size()~=#s.sidecar.genes then error('BODY_GENOME') end
            for _,g in ipairs(s.sidecar.genes) do
                local ng=a:getFullGenome():get(g.name)
                if ng==nil then error('BODY_GENOME') end
                ng:getAllele1():setUsed(g.first);ng:getAllele2():setUsed(g.second)
            end
            -- This is only the bounded string metadata list; native hutch,
            -- animal and corpse maps are never cleared here.
            local disorders=a:getGeneticDisorder();disorders:clear()
            for _,d in ipairs(s.sidecar.disorders) do disorders:add(d) end
            a:setDebugStress(s.sidecar.stress)
            -- Two native forced-size calls reproduce originalSize and size exactly.
            a:getData():setSizeForced(s.sidecar.originalSize);a:getData():setSizeForced(s.sidecar.size)
            a:setCustomName(s.sidecar.name)
            if h~=nil then a:getData():setHutchPosition(position);a:getData():setPreferredHutchPosition(preferred) end
            if a:getHutch()~=h or a:getNestBoxIndex()~=nest then error('MEMBERSHIP_CHANGED') end
            if p.mom then
                if oldMom and oldMom~=p.mom then oldMom:removeBaby(a) end
                a:setMother(p.mom)
            end
            -- Native admission does not require an unloaded parent to resolve.
            -- Raw load retains the existing real reference and authoritative
            -- attach-back ID. Keep that reference until an exact parent arrives.
            if a:getMother()~=(p.mom or oldMom) then error('MOTHER_STATE') end
            S.latest[p.key]=s.rev;S.known[p.key]=a;receipt.status='HYDRATED'
            S.pendingRelations[p.key]=p.pendingMother and {a=a,pid=s.pid,oid=s.oid,mother=p.pendingMother,rev=s.rev} or nil
        end)
        if not applied then
            -- Preserve placement bookkeeping even after partial hydration. This
            -- is not a rollback of partially loaded attributes or identity.
            receipt.membershipRestored=pcall(function()
                if prior and prior.h and a:getHutch()==prior.h and a:getNestBoxIndex()==prior.nest then
                    a:getData():setHutchPosition(prior.position);a:getData():setPreferredHutchPosition(prior.preferred)
                else error('MEMBERSHIP_NOT_RESTORED') end
            end)
            return result('APPLY_INCOMPLETE',a)
        end
        return result('HYDRATED',a)
    end
    -- Optional relationship service after native replicas are available. It
    -- never creates an animal, consumes a body, rehydrates, or changes placement.
    -- Pending entries are bounded by the same 4096 admitted-identity cap.
    function S.resolveRelations()
        if S.epoch==nil then return 'STALE_SESSION',0,0 end
        local resolved=0;local pending=0
        for k,p in pairs(S.pendingRelations) do
            local a=p.a
            if S.latest[k]~=p.rev or S.known[k]~=a then
                S.pendingRelations[k]=nil
            elseif lookup(p.oid)~=a or not identity(a,p.pid,p.oid) then
                -- Do not bind a departed/recycled native object to any parent.
                S.pendingRelations[k]=nil;result('RELATION_CHILD_DEPARTED')
            elseif p.failed then
                pending=pending+1
            else
                local mom=lookup(p.mother.oid)
                if not identity(mom,p.mother.pid,p.mother.oid) then
                    pending=pending+1
                else
                    local babies=mom:getBabies();local conflict=babies and babies:size()>256
                    if babies and not conflict then for i=0,babies:size()-1 do
                        local b=babies:get(i)
                        if b~=a and b:getAnimalID()==p.pid then conflict=true end
                    end end
                    if conflict then
                        pending=pending+1;result('RELATION_FAMILY_CONFLICT')
                    else
                        -- Mark before the first native mutation. Any partial
                        -- exception requires a fresh authoritative envelope.
                        p.failed=true
                        local ok=pcall(function()
                            local old=a:getMother()
                            if old and old~=mom then old:removeBaby(a) end
                            a:setMother(mom)
                            if a:getMother()~=mom then error('RELATION_STATE') end
                        end)
                        if ok then S.pendingRelations[k]=nil;resolved=resolved+1
                        else pending=pending+1;result('RELATION_APPLY_INCOMPLETE') end
                    end
                end
            end
        end
        return pending==0 and 'RELATIONS_RESOLVED' or 'RELATIONS_PENDING',resolved,pending
    end
    function S.forgetRelation(pid,oid)
        if not integer(pid,0,2147483647) or not integer(oid,0,32767) then return 'BAD_IDENTITY' end
        S.pendingRelations[tostring(pid)..':'..tostring(oid)]=nil
        return 'RELATION_FORGOTTEN'
    end
    return S
end
