-- Existing Paradise Workshop client runtime; prevention is the paired server
-- writer filter. These events reconcile exact originals after native delivery.
local function integer(n,a,b) return type(n)=='number' and n>=a and n<=b and n==math.floor(n) end
local function size(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
local function location(x,y,z) return tostring(x)..':'..tostring(y)..':'..tostring(z) end
return function(deps)
    local W={epoch=nil,coordinator=nil,requests={},pending={},counters={},installed=false,ready=false,needsRenewal=false}
    local events=deps.events or Events;local now=deps.now or getTimestampMs
    local lookupHutch=deps.getHutch or getHutch;local native=deps.native or instanceof
    local player=deps.player or getPlayer;local send=deps.send or sendClientCommand
    local log=deps.log or print;local connected=false;local nextHello=0;local nextObserve=0;local nextFamily=0;local nextRenewal=0;local notices={}
    local notify=deps.notify or function(message)
        local p=player();if p and HaloTextHelper and HaloTextHelper.addBadText then HaloTextHelper.addBadText(p,message) end
    end
    local transient={WAIT_HUTCH=true,WAIT_ANIMAL=true,WAIT_BOOTSTRAP=true,WAIT_MOTHER=true,STALE_SESSION=true,STALE_REVISION=true}
    local function diagnose(code)
        if type(code)~='string' or #code>80 then code='INVALID_RESULT' end
        if W.counters[code]==nil and size(W.counters)>=64 then code='OTHER' end
        local count=math.min((W.counters[code] or 0)+1,1000000);W.counters[code]=count
        if count<=3 or count%1000==0 then log('[ParadiseHutch] '..code..' count='..tostring(count)) end
        if not transient[code] and now()>=(notices[code] or 0) then
            notices[code]=now()+60000;pcall(notify,'Hutch display is temporarily unavailable. Please report this to an admin.')
        end
        if code=='IDENTITY_BOUND' or code=='IDENTITY_LIMIT' or code=='HUTCH_LIMIT' then W.needsRenewal=true end
    end
    local function transmit(command,args)
        local p=player();if p==nil then return false end
        local ok=pcall(send,p,'ParadiseHutchTransport',command,args)
        if not ok then diagnose('SEND_FAILED') end
        return ok
    end
    local function reset()
        if W.coordinator then W.coordinator.leave() end
        W.epoch=nil;W.coordinator=nil;W.requests={};W.pending={};W.ready=false;W.needsRenewal=false;nextHello=0;nextObserve=0;nextFamily=0;nextRenewal=0;notices={}
    end
    function W.connected() reset();connected=true end
    function W.disconnected() reset();connected=false end
    function W.queueHutch(object)
        if not native(object,'IsoHutch') then return end
        local square=object:getSquare();if square==nil then return end
        local h=lookupHutch(square:getX(),square:getY(),square:getZ());if h==nil then return end
        square=h:getSquare();if square==nil then return end
        local x,y,z=square:getX(),square:getY(),square:getZ()
        if not integer(x,-1000000,1000000) or not integer(y,-1000000,1000000) or not integer(z,-32,32) then diagnose('HUTCH_COORDINATE_BOUND');return end
        local k=location(x,y,z)
        if W.requests[k]==nil then
            if size(W.requests)>=256 then diagnose('REQUEST_CAPACITY');return end
            W.requests[k]={x=x,y=y,z=z,object=h,next=0}
        elseif W.requests[k].object~=h then
            W.requests[k]={x=x,y=y,z=z,object=h,next=0}
        end
    end
    function W.square(square)
        if square==nil then return end
        local objects=square:getObjects();if objects==nil then return end
        if objects:size()>512 then diagnose('SQUARE_OBJECT_BOUND');return end
        for n=0,objects:size()-1 do W.queueHutch(objects:get(n)) end
    end
    local function snapshotHeader(s)
        return type(s)=='table' and s.protocol==1 and s.epoch==W.epoch and integer(s.rev,1,9007199254740991)
            and integer(s.x,-1000000,1000000) and integer(s.y,-1000000,1000000) and integer(s.z,-32,32)
            and type(s.nonce)=='string' and #s.nonce>=1 and #s.nonce<=128 and s.hutchKey==location(s.x,s.y,s.z)
    end
    local function acknowledgeSnapshot(s)
        return transmit('ack',{protocol=1,epoch=s.epoch,rev=s.rev,nonce=s.nonce,kind='SNAPSHOT',hutchKey=s.hutchKey,oid=-1,pid=0})
    end
    local function success(s,code)
        if code=='APPLIED' or code=='DUPLICATE' then
            if acknowledgeSnapshot(s) then W.pending[s.hutchKey]=nil end
            local q=W.requests[s.hutchKey];if q then q.next=now()+30000 end
            return true
        end
        return false
    end
    function W.command(module,command,s)
        if module~='ParadiseHutchTransport' then return end
        if command=='hello' then
            if type(s)~='table' or s.protocol~=1 or type(s.epoch)~='string' or #s.epoch<1 or #s.epoch>128 then diagnose('BAD_HELLO');return end
            if W.epoch~=s.epoch then
                if W.epoch~=nil then
                    if s.previousEpoch~=W.epoch or not W.coordinator.renew then diagnose('UNEXPECTED_EPOCH');return end
                    local ok,code=pcall(W.coordinator.renew,W.epoch,s.epoch)
                    if not ok or code~='SESSION_RENEWED' then diagnose(ok and code or 'RENEW_ERROR');return end
                    W.pending={};W.needsRenewal=false
                else
                    W.coordinator=deps.coordinator()
                    local code=W.coordinator.begin(s.epoch);if code~='SESSION_STARTED' then diagnose(code);W.coordinator=nil;return end
                end
                W.epoch=s.epoch;for _,q in pairs(W.requests) do q.next=0 end
            end
            connected=true;nextHello=now()+30000
            W.ready=transmit('ready',{protocol=1,epoch=W.epoch});if not W.ready then nextHello=0 end
            return
        end
        if W.coordinator==nil or type(s)~='table' or s.epoch~=W.epoch then diagnose('STALE_SESSION');return end
        if command=='snapshot' then
            if not snapshotHeader(s) then diagnose('BAD_SNAPSHOT_HEADER');return end
            if W.pending[s.hutchKey]==nil and size(W.pending)>=256 then diagnose('PENDING_CAPACITY');return end
            local old=W.pending[s.hutchKey]
            if old and old.rev>s.rev then diagnose('STALE_REVISION');return end
            if old and old.rev==s.rev and old.nonce~=s.nonce then diagnose('TICKET_CONFLICT');return end
            local ok,code=pcall(W.coordinator.offer,s)
            if not ok then diagnose('RECEIVER_ERROR');return end
            if success(s,code) then return end
            diagnose(code)
            -- Coordinator privately owns the bounded payload; retain only its
            -- immutable acknowledgement header while waiting for world loading.
            local work=W.coordinator.work[s.hutchKey]
            if work and work.snapshot.epoch==s.epoch and work.snapshot.rev==s.rev then
                W.pending[s.hutchKey]={protocol=1,epoch=s.epoch,rev=s.rev,nonce=s.nonce,hutchKey=s.hutchKey,x=s.x,y=s.y,z=s.z,next=now()+1000}
            end
        elseif command=='retire' then
            local ok,code,ack=pcall(W.coordinator.retire,s)
            if ok and (code=='RETIRED' or code=='RETIREMENT_DUPLICATE') then transmit('ack',ack)
            else diagnose(ok and code or 'RETIREMENT_ERROR') end
        elseif command=='status' then
            local allowed={snapshot_too_large=true,snapshot_pending=true,snapshot_unavailable=true,renewal_pending=true}
            if s.protocol==1 and allowed[s.code] then diagnose(s.code) end
        end
    end
    function W.tick()
        if not connected then return end
        local time=now()
        if W.epoch==nil then
            if time>=nextHello then transmit('hello',{protocol=1});nextHello=time+5000 end
            return
        end
        if not W.ready then
            if time>=nextHello then W.ready=transmit('ready',{protocol=1,epoch=W.epoch});nextHello=time+5000 end
            return
        end
        if W.needsRenewal and time>=nextRenewal then
            transmit('renew',{protocol=1,epoch=W.epoch});nextRenewal=time+30000
        end
        if time>=nextObserve then
            nextObserve=time+250
            local ok,code=pcall(W.coordinator.observe)
            if not ok or code~='OBSERVED' then diagnose(ok and code or 'OBSERVE_ERROR') end
        end
        if time>=nextFamily then
            nextFamily=time+1000
            local ok,code=pcall(W.coordinator.resolveRelations)
            if not ok then diagnose('FAMILY_ERROR') elseif code~='RELATIONS_RESOLVED' and code~='RELATIONS_PENDING' then diagnose(code) end
        end
        local n=0
        for k,s in pairs(W.pending) do if time>=s.next and n<4 then
            n=n+1;s.next=time+1000
            local ok,code=pcall(W.coordinator.reconcile,k)
            if ok then success(s,code) else diagnose('RECONCILE_ERROR') end
        end end
        n=0
        for k,q in pairs(W.requests) do
            if lookupHutch(q.x,q.y,q.z)~=q.object then W.requests[k]=nil
            elseif time>=q.next and n<4 then
                n=n+1;q.next=time+5000
                transmit('request',{protocol=1,epoch=W.epoch,x=q.x,y=q.y,z=q.z})
            end
        end
    end
    function W.install()
        if W.installed then return 'ALREADY_INSTALLED' end
        for _,e in ipairs({'OnConnected','OnDisconnect','OnServerCommand','LoadGridsquare','OnObjectAdded','OnTick'}) do
            if events[e]==nil or type(events[e].Add)~='function' then diagnose('EVENT_UNAVAILABLE');return 'EVENT_UNAVAILABLE' end
        end
        events.OnConnected.Add(W.connected);events.OnDisconnect.Add(W.disconnected);events.OnServerCommand.Add(W.command)
        events.LoadGridsquare.Add(W.square);events.OnObjectAdded.Add(W.queueHutch);events.OnTick.Add(W.tick)
        W.installed=true;connected=true;return 'INSTALLED'
    end
    return W
end
