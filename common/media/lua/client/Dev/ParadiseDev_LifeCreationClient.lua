-- Keep recoverable preparation in the menu, before native creation's deadline.
if isServer and isServer() then return end
require "ISUI/ISPanel"
require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
ParadiseDev=ParadiseDev or {}
ParadiseDev.LifeCreationClient=ParadiseDev.LifeCreationClient or {}
local G=ParadiseDev.LifeCreationClient
G.sequence=G.sequence or 0
G.nativeRegions=G.nativeRegions or getServerSpawnRegions
local SLOT=-2147483000
local function now()return getTimestampMs()end
local function copy(t)local r={};for k,v in pairs(t or {})do r[k]=v end;return r end
local function validPoint(p)
    if type(p)~="table" then return false end
    for _,k in ipairs({"x","y","z"})do
        if type(p[k])~="number" or p[k]~=p[k] or math.abs(p[k])>10000000 then return false end
    end
    return p.z==math.floor(p.z) and p.z>=-32 and p.z<=31
end
local function send(command,args)
    local values={}
    for k,v in pairs(args)do values[#values+1]=k;values[#values+1]=v end
    sendClientCommandV(nil,"ParadiseLifeLogin",command,unpack(values))
end
function G.close()
    if G.panel then
        local panel=G.panel
        panel:removeFromUIManager();G.panel=nil
        if panel.creationJoypad and panel.creationJoypad.focus==panel then
            panel.creationJoypad.focus=panel.previousFocus
            updateJoypadFocus(panel.creationJoypad)
        end
    end
    G.pending=nil
end
function G.cancel()
    local p=G.pending
    if not p then return end
    G.close()
    -- The request identity prevents a delayed cancel from clearing a newer lease.
    send("cancelCreate",{requestId=p.args.requestId,creationRequestId=p.args.requestId})
    if p.cancel then p.cancel()end
end
function G.transmit()
    local p=G.pending
    if not p then return end
    p.sentAt=now();send("prepareCreate",p.args)
end
function G.retry()
    local p=G.pending
    if not p then return end
    G.sequence=G.sequence+1
    p.args.requestId="birth:"..tostring(now())..":"..tostring(G.sequence)
    p.lastReply=nil;p.answered=false;p.retryAt=nil;G.transmit()
end
function G.onResult(args)
    local p=G.pending
    if not p or type(args)~="table" or args.requestId~=p.args.requestId then return false end
    if args.status=="creationReady" then
        if not validPoint(args.creationLocation) or type(args.spawnRegion)~="string"
                or (p.args.transactionId and args.transactionId~=p.args.transactionId)
                or (p.args.creationIntentId and args.creationIntentId~=p.args.creationIntentId) then
            p.message="The server returned an incomplete location. Retry or go Back.";p.retryAt=nil;return true
        end
        -- Remove the pending operation before invoking code that starts native loading.
        -- Replayed mailbox packets and double clicks cannot invoke it twice.
        G.close()
        p.proceed(args)
        return true
    end
    p.message=args.message or "Your destination is not ready. Retry or go Back to change the selection."
    p.retryAt=args.status=="creationPending" and now()+1000 or nil
    p.answered=true
    return true
end
function G.tick()
    local p=G.pending
    if not p then return end
    if not p.polledAt or now()-p.polledAt>=250 then
        p.polledAt=now()
        local login=ParadiseDev.LifeLoginClient
        local read=login and login.nativeGetServerSpawnRegions or G.nativeRegions
        local ok,regions=pcall(read)
        local envelope=ok and type(regions)=="table" and regions[SLOT]
        if type(envelope)=="table" and envelope.protocol=="ParadiseLifeLogin" and envelope.version==2 then
            -- Consume each mailbox response once. Re-reading a pending answer must
            -- not push the next retry forward forever.
            local result=envelope.result
            local signature=type(result)=="table" and tostring(result.requestId)..":"..tostring(result.replySequence)
            if signature and signature~=p.lastReply then
                p.lastReply=signature;G.onResult(result)
            end
        end
    end
    if G.pending~=p then return end
    if p.retryAt and now()>=p.retryAt then
        G.retry()
    elseif not p.answered and now()-(p.sentAt or 0)>=3000 then
        p.message="Waiting for the server to prepare your destination. Your profile is preserved."
        G.transmit()
    end
end
function G.begin(args,proceed,cancel)
    if G.pending then return false end
    G.sequence=G.sequence+1
    args=copy(args);args.requestId="birth:"..tostring(now())..":"..tostring(G.sequence)
    G.pending={args=args,proceed=proceed,cancel=cancel,message="Preparing a safe place for your character..."}
    local sw,sh=getCore():getScreenWidth(),getCore():getScreenHeight()
    local w,h=math.min(660,sw-32),190
    local panel=ISPanelJoypad:new((sw-w)/2,(sh-h)/2,w,h)
    panel:initialise();panel.backgroundColor={r=.02,g=.025,b=.025,a=1}
    function panel:prerender()
        ISPanelJoypad.prerender(self)
        self:drawTextCentre("Preparing your character",self.width/2,18,1,1,1,1,UIFont.Medium)
        local message=G.pending and G.pending.message or ""
        local c=ParadiseDev.LifeProfilesClient
        local lines=c and c.screenLines and c.screenLines(message,UIFont.Small,self.width-32,3) or {message}
        for i,line in ipairs(lines)do self:drawTextCentre(line,self.width/2,50+(i-1)*18,.9,.85,.7,1,UIFont.Small)end
    end
    function panel:update()G.tick()end
    local retry=ISButton:new(16,h-44,(w-48)/2,28,"Retry",panel,function()
        G.retry()
    end)
    local back=ISButton:new(32+(w-48)/2,h-44,(w-48)/2,28,"Back",panel,G.cancel)
    retry:initialise();back:initialise();panel:addChild(retry);panel:addChild(back)
    function panel:onGainJoypadFocus()
        self:setISButtonForA(retry);self:setISButtonForB(back)
    end
    function panel:onJoypadDown(button)
        if button==Joypad.AButton then G.retry()
        elseif button==Joypad.BButton then G.cancel()end
    end
    panel:setAlwaysOnTop(true);panel:addToUIManager();G.panel=panel
    local jd=JoypadState.getMainMenuJoypad() or CoopCharacterCreation and CoopCharacterCreation.getJoypad and CoopCharacterCreation.getJoypad()
    if jd then panel.creationJoypad=jd;panel.previousFocus=jd.focus;panel:setVisible(true,jd)end
    G.transmit();return true
end
function G.setLocation(result)
    local p=result.creationLocation
    setSpawnRegion(result.spawnRegion)
    getWorld():setLuaPosX(p.x);getWorld():setLuaPosY(p.y);getWorld():setLuaPosZ(p.z)
end
function G.hints(accepted,creation)
    local desc=MainScreen.instance.desc
    local args={transactionId=accepted and accepted.transactionId,
        creationIntentId=accepted and accepted.creationIntentId,
        regionName=accepted and accepted.spawnRegion,
        profession=desc and tostring(desc:getCharacterProfession()) or "base:unemployed",pveHint=false}
    local picker=creation and creation.mapSpawnSelect or MapSpawnSelect.instance
    local region=picker and picker.selectedRegion
    args.regionName=args.regionName or region and (region.lifeRegionName or region.name)
    if accepted and accepted.kind=="restore" then
        args.pveHint=accepted.profile and accepted.profile.pve==true
        args.profession=accepted.profile and accepted.profile.identity and accepted.profile.identity.profession or args.profession
    elseif creation then
        for _,row in ipairs(creation.charCreationProfession.listboxTraitSelected.items or {})do
            local id=string.lower(tostring(row.item:getType()))
            if id=="paradisedev:pve" or id=="pve" then args.pveHint=true end
        end
    else
        local traits=getWorld():getLuaTraits()
        for i=0,traits:size()-1 do
            local id=string.lower(tostring(traits:get(i)))
            if id=="paradisedev:pve" or id=="pve" then args.pveHint=true end
        end
    end
    return args
end
function G.install()
    if CharacterCreationMain and not G.nativeMainOption then
        G.nativeMainOption=CharacterCreationMain.onOptionMouseDown
        CharacterCreationMain.onOptionMouseDown=function(self,button,x,y)
            local r=ParadiseDev.Reincarnate
            if not button or button.internal~="NEXT" or not isClient() or not r or not r.isShouldReincarnate() then
                return G.nativeMainOption(self,button,x,y)
            end
            if G.pending then return end
            local c=ParadiseDev.LifeProfilesClient
            local s=c and c.states[0]
            local accepted=s and s.transaction
            self:initPlayer()
            self:setVisible(false)
            G.begin(G.hints(accepted),function(result)
                G.setLocation(result)
                local login=ParadiseDev.LifeLoginClient
                if login then login.closePanel();login.restoreScreens();login.active=false end
                return G.nativeMainOption(self,button,x,y)
            end,function()self:setVisible(true,JoypadState.getMainMenuJoypad())end)
        end
    end
    if MainScreen and MainScreen.instance and MainScreen.instance.charCreationMain and G.nativeMainOption then
        local main=MainScreen.instance.charCreationMain
        if main.playButton then main.playButton.onclick=CharacterCreationMain.onOptionMouseDown end
    end
    if CoopCharacterCreation and not G.nativeCoopAccept then
        G.nativeCoopAccept=CoopCharacterCreation.accept
        CoopCharacterCreation.accept=function(self)
            local r=ParadiseDev.Reincarnate
            if self.playerIndex~=0 or not isClient() or not r or not r.isShouldReincarnate() then return G.nativeCoopAccept(self)end
            if G.pending then return end
            local c=ParadiseDev.LifeProfilesClient
            local s=c and c.states[self.playerIndex]
            local accepted=s and s.transaction
            self:initPlayer()
            self.charCreationMain:setVisible(false)
            G.begin(G.hints(accepted,self),function(result)
                if CoopCharacterCreation.instance~=self then return end
                G.setLocation(result)
                local p=result.creationLocation
                self.mapSpawnSelect.selectedRegion={name=result.spawnRegion,
                    points={unemployed={{posX=p.x,posY=p.y,posZ=p.z}}}}
                return G.nativeCoopAccept(self)
            end,function()
                if CoopCharacterCreation.instance==self then self.charCreationMain:setVisible(true,self.joypadData)end
            end)
        end
    end
end
Events.OnTick.Add(G.tick)
Events.OnDisconnect.Add(G.close)
if Events.OnGameStart then Events.OnGameStart.Add(G.install)end
return G
