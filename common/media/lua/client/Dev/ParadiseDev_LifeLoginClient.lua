-- Login is separate from in-world reincarnation: no temporary character is
-- created merely to obtain access to the account's saved profiles.
if isServer and isServer() then return end
require "Dev/ParadiseDev_Reincarnate"
require "Dev/ParadiseDev_LifeCreationClient"
require "OptionScreens/ConnectToServer"
require "OptionScreens/MapSpawnSelect"
require "ISUI/ISPanel"
require "ISUI/ISUI3DModel"
require "ISUI/ISScrollingListBox"
ParadiseDev.LifeLoginClient=ParadiseDev.LifeLoginClient or {}
local L=ParadiseDev.LifeLoginClient
local function client()return ParadiseDev.LifeProfilesClient end
local function now()return getTimestampMs()end
local function joypad()return JoypadState.getMainMenuJoypad()end
local function enabled()return isClient() and ParadiseDev.Reincarnate.isShouldReincarnate()end
L.sequence=L.sequence or 0
local LOGIN_REPLY_SLOT=-2147483000
local function readNativeRegions()
    local ok,regions=pcall(L.nativeGetServerSpawnRegions)
    if ok and type(regions)=="table" then return regions end
end

-- Ordinary server commands are queued until a player enters the world. The
-- server uses the native loading-capable SpawnRegion packet for this one
-- connection's reply. The native accessor returns a deep copy; strip our
-- reserved slot from every public copy, without touching real spawn regions.
if not L.nativeGetServerSpawnRegions then
    L.nativeGetServerSpawnRegions=getServerSpawnRegions
    getServerSpawnRegions=function()
        local regions=readNativeRegions()
        if type(regions)=="table" then regions[LOGIN_REPLY_SLOT]=nil end
        return regions
    end
end

function L.restoreScreens()
    local saved=L.savedScreens
    if not saved then return end
    for object,methods in pairs(saved)do for name,entry in pairs(methods)do object[name]=entry.value end end
    L.savedScreens=nil
end
local function replace(object,name,value)
    L.savedScreens=L.savedScreens or {}
    L.savedScreens[object]=L.savedScreens[object] or {}
    if L.savedScreens[object][name]==nil then L.savedScreens[object][name]={value=object[name]} end
    object[name]=value
end
function L.closePanel()
    if L.panel then L.panel:removeFromUIManager();L.panel=nil end
end
function L.reset()
    L.closePanel();L.restoreScreens()
    if L.ownsState and client() then
        local c=client()
        local state=c.states[0]
        if state and state.waitPanel then state.waitPanel:removeFromUIManager()end
        c.releaseControls(0)
        c.states[0]=nil
    end
    L.ownsState=false
    L.active=false;L.pendingRequest=nil;L.accepted=nil;L.profiles=nil
    L.lastReplyPoll=nil;L.preparing=nil;L.preparationStarted=nil
end
function L.exit()
    L.reset()
    -- OnConnected runs after the server's mod/Lua reload. The new connector
    -- has no previousScreen; use the same exit as the native spawn picker.
    backToSinglePlayer()
    getCore():ResetLua("default","exitJoinServer")
end

function L.send(command,args)
    if not L.active then return false end
    L.sequence=L.sequence+1
    args=args or {}
    args.requestId=tostring(now())..":"..tostring(L.sequence)
    L.pendingRequest={command=command,args=args,sentAt=now(),startedAt=now()}
    L.transmit()
    return true
end
function L.transmit()
    local request=L.pendingRequest
    if not L.active or not request then return end
    local values={}
    for key,value in pairs(request.args)do values[#values+1]=key;values[#values+1]=value end
    -- The V overload is the native connection transport before a local player
    -- exists. Server bridge intercepts only this module and authenticates it.
    sendClientCommandV(nil,"ParadiseLifeLogin",request.command,unpack(values))
    request.sentAt=now()
end
function L.query()
    L.preparationStarted=nil;L.preparing=nil
    L.message="Checking your saved character..."
    L.send("query",{})
end

local function matchingResume(request,accepted)
    local expected=request and request.resumeSelection
    return request and request.command=="query" and expected and type(accepted)=="table"
        and type(expected.transactionId)=="string" and accepted.transactionId==expected.transactionId
        and accepted.kind==expected.kind
        and (expected.kind~="login" or accepted.bodyFingerprint==expected.bodyFingerprint)
end

function L.chooseProfile()
    if L.pendingRequest then return end
    if L.accepted then
        local accepted=L.accepted
        L.message="Refreshing your selection and safe destinations..."
        if L.send("query",{}) then
            -- Keep the prepared selection; only a matching fresh reply may resume it.
            L.pendingRequest.resumeSelection={kind=accepted.kind,transactionId=accepted.transactionId,
                bodyFingerprint=accepted.bodyFingerprint}
        end
        return
    end
    if not L.profiles or not L.profiles.canSelect then return end
    L.sequence=L.sequence+1
    L.message="Confirming your profile..."
    L.send("select",{slot=L.selected or 1,revision=L.profiles.revision,deathToken=L.profiles.deathToken,
        selectionId="login:"..tostring(now())..":"..tostring(L.sequence)})
end
function L.cancelSelection()
    if L.pendingRequest then return end
    if L.accepted and L.accepted.kind=="login" then
        L.restoreScreens();MapSpawnSelect.instance:setVisible(false)
        L.send("cancelLogin",{});L.accepted=nil;L.showPanel();L.refresh();return
    end
    local id=L.accepted and L.accepted.transactionId
    MapSpawnSelect.instance:setVisible(false)
    MainScreen.instance.charCreationProfession:setVisible(false)
    MainScreen.instance.charCreationMain:setVisible(false)
    L.restoreScreens();L.accepted=nil
    local state=client().states[0]
    if state then state.transaction=nil;state.inflight=nil;state.restored=nil end
    L.showPanel()
    if id then L.send("cancel",{transactionId=id})else L.query()end
end

function L.showPanel()
    if MapSpawnSelect.instance then MapSpawnSelect.instance:setVisible(false)end
    if L.panel then L.panel:setVisible(true);L.panel:bringToTop();return end
    local c=client()
    local sw,sh=getCore():getScreenWidth(),getCore():getScreenHeight()
    local w,h=math.min(920,sw-32),math.min(620,sh-32)
    local panel=ISPanel:new((sw-w)/2,(sh-h)/2,w,h)
    panel:initialise();panel.backgroundColor={r=.02,g=.025,b=.025,a=.98}
    panel.playerIndex=0
    panel.profileModel=ISUI3DModel:new(20,128,220,h-223)
    panel:addChild(panel.profileModel)
    panel.profileModel:setState("idle");panel.profileModel:setDirection(IsoDirections.S)
    panel.profileModel:setIsometric(false);panel.profileModel:setDoRandomExtAnimations(true)
    panel.profileModel:setAnimateWhilePaused(true);panel.profileModel:setZoom(-3)
    panel.profileDetails=ISScrollingListBox:new(255,128,w-275,h-223)
    panel.profileDetails:initialise();panel.profileDetails:instantiate();panel.profileDetails:setFont(UIFont.Small,4)
    panel.profileDetails.itemheight=getTextManager():getFontHeight(UIFont.Small)+8
    panel:addChild(panel.profileDetails)
    panel.slotButtons={}
    for i=1,3 do
        local button=ISButton:new(20+(i-1)*(w-40)/3,62,(w-46)/3,30,"Profile "..i,panel,function(_,b)
            if L.pendingRequest or L.accepted then return end
            L.selected=b.slot;L.refresh()
        end)
        button.slot=i;button:initialise();panel:addChild(button);panel.slotButtons[i]=button
    end
    panel.previous=ISButton:new(20,96,90,24,"Previous",panel,function()
        if not L.pendingRequest and not L.accepted then L.page=math.max(1,(L.page or 1)-1);L.selected=(L.page-1)*3+1;L.refresh()end
    end)
    panel.next=ISButton:new(w-110,96,90,24,"Next",panel,function()
        if not L.pendingRequest and not L.accepted then L.page=math.min(math.ceil((L.profiles.maxSlots or 3)/3),(L.page or 1)+1);L.selected=(L.page-1)*3+1;L.refresh()end
    end)
    panel.previous:initialise();panel.next:initialise();panel:addChild(panel.previous);panel:addChild(panel.next)
    panel.proceed=ISButton:new(20,h-48,(w-70)/3,28,"Continue",panel,L.chooseProfile)
    panel.retry=ISButton:new(35+(w-70)/3,h-48,(w-70)/3,28,"Retry",panel,function()
        if L.pendingRequest then L.transmit()elseif L.accepted then L.cancelSelection()else L.query()end
    end)
    panel.back=ISButton:new(50+(w-70)*2/3,h-48,(w-70)/3,28,"Back",panel,L.exit)
    for _,button in ipairs({panel.proceed,panel.retry,panel.back})do button:initialise();panel:addChild(button)end
    function panel:prerender()
        ISPanel.prerender(self)
        self:drawTextCentre("Continue your life",self.width/2,20,1,1,1,1,UIFont.Large)
        local lines=c.screenLines(L.message or "Checking your character...",UIFont.Small,self.width-40,2)
        for i,line in ipairs(lines)do self:drawTextCentre(line,self.width/2,self.height-90+(i-1)*18,.9,.85,.7,1,UIFont.Small)end
        self.proceed:setEnable(not L.pendingRequest and (L.accepted~=nil or L.profiles and L.profiles.canSelect==true) or false)
        self.proceed:setTitle(L.accepted and "Resume selection" or "Continue")
        self.retry:setTitle(L.accepted and not L.pendingRequest and "Cancel selection" or "Retry")
        for _,button in ipairs(self.slotButtons)do button:setEnable(not L.pendingRequest and not L.accepted)end
    end
    function panel:update()L.onTick()end
    panel:addToUIManager()
    -- MainScreen is a full-screen root that raises itself when clicked.
    -- Keep this separate login dialog above it while the dialog is visible.
    panel:setAlwaysOnTop(true);panel:bringToTop()
    L.panel=panel;L.refresh()
end
function L.refresh()
    local panel=L.panel
    if not panel then return end
    local c=client()
    local state=c.states[0]
    state.profiles=L.profiles;state.selected=L.selected or 1
    c.refreshDetails(panel)
    local max=L.profiles and L.profiles.maxSlots or 0
    L.page=math.max(1,math.min(math.ceil(math.max(1,max)/3),L.page or 1))
    for i,button in ipairs(panel.slotButtons)do
        local slot=(L.page-1)*3+i
        local profile=L.profiles and L.profiles.slots[slot]
        button.slot=slot;button:setVisible(slot<=max)
        button:setTitle("Profile "..slot..": "..(profile and profile.name or "Empty"))
        button.borderColor=L.selected==slot and {r=.4,g=.8,b=.65,a=1} or {r=.4,g=.4,b=.4,a=.5}
        -- Native setEnable restores its cached color on every frame.
        -- Leave first-time cache initialization to it, including the background.
        if button.borderColorEnabled then
            local color=button.borderColor
            button.borderColorEnabled={r=color.r,g=color.g,b=color.b,a=color.a}
        end
    end
    panel.previous:setVisible(max>3);panel.next:setVisible(max>3)
    panel.profileDetails:setVisible(L.profiles~=nil)
end

function L.loadExisting(accepted)
    -- A server-confirmed alive record still needs a successful native transfer.
    -- Never reinterpret a client timeout as permission to create a character.
    if not checkSavePlayerExists() then
        L.message="Your character is saved, but its download is not ready. Retry to load the same life."
        L.showPanel();return false
    end
    client().states[0].transaction=accepted
    L.closePanel();L.restoreScreens();L.active=false
    GameWindow.doRenderEvent(false);forceChangeState(LoadingQueueState.new())
    return true
end

function L.restoreCreationIntent(intent)
    local c=client()
    local profile=type(intent)=="table" and intent.profile
    if type(intent)~="table" or type(intent.id)~="string" or type(profile)~="table" or type(profile.identity)~="table" then
        L.message="The interrupted creation could not be loaded. Retry; your saved data is retained."
        L.showPanel();return
    end
    local desc=c.descriptor(profile.identity,false,profile.startingOutfit)
    MainScreen.instance.desc=desc
    getWorld():setLuaPlayerDesc(desc);getWorld():getLuaTraits():clear()
    for _,id in ipairs(profile.identity.traits or {})do
        local key=string.lower(tostring(id))
        -- This is the original first birth, not a different profile. Keep its
        -- chosen PvE trait too; unrelated account-managed statuses stay native.
        if not c.isManagedTrait(id) or key=="paradisedev:pve" or key=="pve" then
            getWorld():addLuaTrait(c.traitType(id))
        end
    end
    local gate=ParadiseDev.LifeCreationClient
    local hints=gate.hints(nil);hints.creationIntentId=intent.id
    if L.panel then L.panel:setVisible(false)end
    gate.begin(hints,function(result)
        gate.setLocation(result)
        L.closePanel();L.restoreScreens();L.active=false
        GameWindow.doRenderEvent(false);forceChangeState(LoadingQueueState.new())
    end,function()
        L.message="Your original character creation is saved. Retry to continue it."
        L.showPanel()
    end)
end

function L.chooseSpawn(id)
    if L.pendingRequest or not L.accepted then return end
    if not client().spawnOption(L.accepted,id) then
        L.message="Spawn destinations changed. Cancel this selection and choose again."
        L.showPanel();return
    end
    L.message="Confirming your spawn location..."
    if L.accepted.kind=="login" then
        L.send("chooseLogin",{bodyFingerprint=L.accepted.bodyFingerprint,policyToken=L.accepted.policyToken,spawnId=id})
    else L.send("chooseSpawn",{transactionId=L.accepted.transactionId,spawnId=id}) end
end
function L.acceptSelection(accepted)
    if type(accepted)~="table" or type(accepted.transactionId)~="string" then return end
    L.restoreScreens()
    L.accepted=accepted
    local options=accepted.spawnOptions and accepted.spawnOptions.options or {}
    if #options==0 then L.message=accepted.spawnError or "No verified safe destination is available. Retry shortly; your character is preserved.";L.showPanel();return end
    if accepted.spawnId then L.chooseSpawn(accepted.spawnId);return end
    if accepted.spawnOptions and accepted.spawnOptions.forced then
        if #options==1 then L.chooseSpawn(options[1].id)else L.message="The forced spawn location is unavailable.";L.showPanel()end
        return
    end
    local ok,regions=pcall(client().spawnRegions,accepted)
    if not ok then L.message=tostring(regions);L.showPanel();return end
    local picker=MapSpawnSelect.instance
    replace(picker,"getSpawnRegions",function()return regions end)
    replace(picker,"hasChoices",function()return true end)
    replace(picker,"clickBack",L.cancelSelection)
    replace(picker,"clickNext",function(self)
        local item=self.listbox.items[self.listbox.selected]
        local region=item and item.item and item.item.region
        if region then L.chooseSpawn(region.lifeSpawnId)end
    end)
    picker:fillList();picker.listbox.selected=1
    replace(picker.backButton,"onclick",picker.clickBack);replace(picker.nextButton,"onclick",picker.clickNext)
    local nativePrerender=picker.prerender
    replace(picker,"prerender",function(self)
        nativePrerender(self);L.onTick()
        local item=self.listbox.items[self.listbox.selected]
        self.nextButton:setEnable(not L.pendingRequest and item~=nil)
        if accepted.kind=="login" then
            local note=accepted.warning or "Choose a safe place. Your current character and belongings are preserved."
            self.nextButton.tooltip=note
            self:drawTextCentre("Continue the same character at a safe location",self.width/2,12,.9,.85,.7,1,UIFont.Small)
        end
        self.backButton:setEnable(not L.pendingRequest)
    end)
    if L.panel then L.panel:setVisible(false)end
    picker:setVisible(true,joypad())
end

function L.acceptSpawn(accepted,request)
    local old=L.accepted
    if not old or accepted.transactionId~=old.transactionId or accepted.spawnId~=request.args.spawnId
            or accepted.kind~=old.kind or not client().validSpawn(accepted.spawn) or type(accepted.spawnRegion)~="string" then return end
    L.accepted=accepted
    local c=client()
    local state=c.states[0]
    state.transaction=accepted;state.inflight=nil
    local regions=c.spawnRegions(accepted)
    local region
    for _,choice in ipairs(regions)do if choice.lifeSpawnId==accepted.spawnId then region=choice;break end end
    if not region then L.message="The selected location is unavailable.";L.showPanel();return end
    MapSpawnSelect.instance.selectedRegion=region
    MapSpawnSelect.instance:setVisible(false)
    setSpawnRegion(accepted.spawnRegion)
    getWorld():setLuaPosX(accepted.spawn.x);getWorld():setLuaPosY(accepted.spawn.y);getWorld():setLuaPosZ(accepted.spawn.z)
    if accepted.kind=="restore" then
        local desc=c.descriptor(accepted.profile.identity,false,accepted.profile.startingOutfit)
        MainScreen.instance.desc=desc
        getWorld():setLuaPlayerDesc(desc);getWorld():getLuaTraits():clear()
        for _,id in ipairs(accepted.profile.identity.traits or {})do
            local key=string.lower(tostring(id))
            if not c.isManagedTrait(id) or accepted.profile.creationRetry and (key=="paradisedev:pve" or key=="pve") then
                getWorld():addLuaTrait(c.traitType(id))
            end
        end
        local gate=ParadiseDev.LifeCreationClient
        if L.panel then L.panel:setVisible(false)end
        gate.begin(gate.hints(accepted),function(result)
            gate.setLocation(result)
            L.closePanel();L.restoreScreens();L.active=false
            GameWindow.doRenderEvent(false);forceChangeState(LoadingQueueState.new())
        end,function()L.message="Preparation cancelled. Resume or change your selection.";L.showPanel()end)
    else
        local profession=MainScreen.instance.charCreationProfession
        local original=profession.onOptionMouseDown
        replace(profession,"onOptionMouseDown",function(self,button,x,y)
            if button.internal=="BACK" then L.cancelSelection();return end
            return original(self,button,x,y)
        end)
        replace(profession.backButton,"onclick",profession.onOptionMouseDown)
        if L.panel then L.panel:setVisible(false)end
        profession:setVisible(true,joypad())
    end
end

function L.onServerCommand(module,command,args)
    if module~="ParadiseLifeLogin" or command~="result" or not L.active or type(args)~="table" then return end
    local request=L.pendingRequest
    if not request or args.requestId~=request.args.requestId then return end
    L.pendingRequest=nil
    L.message=args.message
    if args.status=="preparing" then
        L.preparationStarted=L.preparationStarted or now();L.preparing=now()
        L.profiles=nil;L.accepted=nil;L.showPanel();L.refresh();return
    end
    L.preparing=nil;L.preparationStarted=nil
    if args.status=="resume" then
        L.restoreScreens()
        if MapSpawnSelect.instance then MapSpawnSelect.instance:setVisible(false) end
        L.accepted=nil;L.loadExisting(args.accepted);return
    end
    if args.status=="relocate" then
        L.profiles=nil;L.accepted=args.accepted;L.showPanel();L.refresh()
        if L.accepted and L.accepted.spawnOptions and (not request.resumeSelection or matchingResume(request,L.accepted)) then
            L.acceptSelection(L.accepted)
        end
        return
    end
    if args.status=="new" then
        if args.creationIntent then
            L.restoreCreationIntent(args.creationIntent);return
        end
        -- The native creation route remains the authority for first characters.
        -- A fresh native lookup may also discover a late existing body here.
        L.closePanel();L.restoreScreens();L.active=false
        ParadiseDev.LifeCreationClient.install()
        L.nativeOnConnected(ConnectToServer.instance);return
    end
    if args.status=="choose" then
        L.profiles=args.profiles or L.profiles
        if args.action=="spawnAccepted" and request.command=="chooseSpawn" then
            local ok,err=pcall(L.acceptSpawn,args.accepted,request)
            if not ok then L.message=tostring(err);L.showPanel()end
            return
        end
        L.accepted=args.accepted or L.profiles and L.profiles.pending
        L.showPanel();L.refresh()
        if matchingResume(request,L.accepted) then L.acceptSelection(L.accepted)
        elseif args.action=="selectionAccepted" and request.command=="select" then L.acceptSelection(L.accepted)end
    else
        L.profiles=nil;L.accepted=nil;L.showPanel();L.refresh()
    end
end

function L.begin(connector)
    if not enabled() then L.reset();return L.nativeOnConnected(connector)end
    -- Preserve native permission denial before doing any profile UI work.
    if getDebug() and not haveAccess("ConnectWithDebug") and not isCoopHost()then return L.nativeOnConnected(connector)end
    L.reset();L.active=true;L.ownsState=true;L.selected=1;L.page=1
    ParadiseDev.LifeCreationClient.install()
    client().states[0]={selected=1,handled={},completed={}}
    connector.connecting=false;connector:setVisible(false)
    L.message="Checking your saved character...";L.showPanel();L.query()
end
function L.onTick()
    if L.active and (not L.lastReplyPoll or now()-L.lastReplyPoll>=250) then
        L.lastReplyPoll=now()
        local regions=readNativeRegions()
        local envelope=type(regions)=="table" and regions[LOGIN_REPLY_SLOT]
        if type(envelope)=="table" and envelope.protocol=="ParadiseLifeLogin" and envelope.version==2
                and type(envelope.result)=="table" then
            L.onServerCommand("ParadiseLifeLogin","result",envelope.result)
        end
    end
    if L.active and not L.pendingRequest and L.preparing and now()-L.preparing>=1000 then
        if now()-(L.preparationStarted or now())>=45000 then
            L.preparing=nil
            L.message="The saved ground could not be verified yet. Retry shortly or go Back; your character is preserved."
        else L.preparing=nil;L.send("query",{}) end
    end
    if L.active and L.pendingRequest and now()-L.pendingRequest.sentAt>=3000 then
        if now()-(L.pendingRequest.startedAt or L.pendingRequest.sentAt)>=15000 then
            L.message="The server has not answered. Retry, or go Back and check that the mod and server updates match."
        else
            L.message="Waiting for the server to verify your saved character..."
        end
        L.transmit()
    end
end
function L.onCreate()
    if L.active then L.closePanel();L.restoreScreens();L.active=false;L.pendingRequest=nil end
end
if not L.nativeOnConnected then
    L.nativeOnConnected=ConnectToServer.OnConnected
    ConnectToServer.OnConnected=L.begin
end
Events.OnServerCommand.Add(L.onServerCommand)
Events.OnTick.Add(L.onTick)
Events.OnCreatePlayer.Add(L.onCreate)
Events.OnDisconnect.Add(L.reset)
