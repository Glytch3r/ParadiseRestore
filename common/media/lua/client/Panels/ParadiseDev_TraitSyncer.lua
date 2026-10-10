ParadiseDev = ParadiseDev or {}
ParadiseDev.TraitSyncer = ParadiseDev.TraitSyncer or {}
local Syncer = ParadiseDev.TraitSyncer

local function tooltip(option,message)
    if not ISToolTip or not ISToolTip.new then return end
    if not option.toolTip or type(option.toolTip)=="string" then
        option.toolTip=ISToolTip:new();option.toolTip:initialise()
    end
    option.toolTip.description=message
end

if LuaEventManager and LuaEventManager.AddEvent then
    LuaEventManager.AddEvent("OnTraitsSync")
end

Syncer.StoreName = "ParadiseDev_TraitSyncer"
Syncer.Traits = {
    "ParadiseDev:TheRangeStaff",
    "ParadiseDev:Caged",
    "ParadiseDev:InjuredPvP",
    "ParadiseDev:PvE",
}
Syncer.window = nil
Syncer.entries = {}
Syncer.cageEntries = nil
Syncer.lastSync = 0
Syncer.lastStateRevision = -1
Syncer.lastOwnerRevision = -1
Syncer.ownerPvE = nil

-- Apply only a live, server-confirmed PvE assignment. This trait has no XP
-- boosts; mutating its native collection must never call the admin SyncXp API.
function Syncer.applyConfirmedPvE(player, enabled)
    if not player or type(enabled) ~= "boolean" or not player.getCharacterTraits then return false end
    local trait = ParadiseDev.getTrait and ParadiseDev.getTrait("ParadiseDev:PvE")
    local traits = player:getCharacterTraits()
    if not trait or not traits or not player.hasTrait then return false end
    if player:hasTrait(trait) ~= enabled then
        if enabled then traits:add(trait) else traits:remove(trait) end
        if player == (getPlayer and getPlayer()) and triggerEvent then
            Syncer.lastOwner, Syncer.lastOwnerPvE = player, enabled
            triggerEvent("OnTraitsSync", "ParadiseDev:PvE", enabled)
        end
    end
    return player:hasTrait(trait) == enabled
end

function Syncer.refreshTraitsUI()
    local ui = ISPlayerStatsUI and ISPlayerStatsUI.instance
    if not ui or not ui.loadTraits or not ui.char or not ui.char.getCharacterTraits then return end
    if ui.getIsVisible and not ui:getIsVisible() then return end
    local traits = ui.char:getCharacterTraits()
    local known = traits and traits:getKnownTraits()
    if not known then return end
    local ids = {}
    for i = 0, known:size() - 1 do ids[#ids + 1] = tostring(known:get(i)) end
    table.sort(ids)
    local fingerprint = table.concat(ids, "\n")
    -- Vanilla loadTraits destroys and recreates every icon, initially hidden.
    -- Calling it on each one-second owner sync makes an unchanged list blink.
    -- Watch the inspected player, including dynamic/native trait changes.
    if ui.paradiseTraitsPlayer == ui.char and ui.paradiseTraitsFingerprint == fingerprint then return end
    ui:loadTraits()
    ui.paradiseTraitsPlayer, ui.paradiseTraitsFingerprint = ui.char, fingerprint
end

function Syncer.getStore()
    return ModData.get(Syncer.StoreName) or ModData.getOrCreate(Syncer.StoreName)
end

function Syncer.has(player, traitId)
    return player and ParadiseDev.hasTrait and ParadiseDev.hasTrait(player, traitId) or false
end

function Syncer.setLocal(player, traitId, enabled)
    -- Native server trait packets own PvE state in multiplayer. Sending SyncXp
    -- from an ordinary owner's client is not the synchronization path.
    if traitId == "ParadiseDev:PvE" and isClient and isClient() then return false end
    if not player or not player.getCharacterTraits then return false end
    if Syncer.has(player, traitId) == enabled then return false end
    local changed = ParadiseDev.setTrait(traitId, enabled, player)
    if not changed then return false end
    if triggerEvent then triggerEvent("OnTraitsSync", traitId, enabled == true) end
    return true
end

function Syncer.syncPlayer(player)
    if not player or not player.getUsername then return end
    local username = tostring(player:getUsername())
    local store = Syncer.getStore()
    local record = store.players and store.players[username] or nil
    if type(record) ~= "table" then record = {} end
    for _, traitId in ipairs(Syncer.Traits) do
        if traitId ~= "ParadiseDev:Caged" and traitId~="ParadiseDev:PvE" and record[traitId] ~= nil then
            Syncer.setLocal(player, traitId, record[traitId] == true)
        end
    end
    Syncer.refreshTraitsUI()
end

function Syncer.requestSet(username, traitId, enabled, context)
    if traitId=="ParadiseDev:PvE" then
        if type(context)~="table" or not Syncer.stateAt or getTimestampMs()-Syncer.stateAt>5000 then
            Syncer.requestState();return false
        end
    end
    if traitId == "ParadiseDev:Caged" then
        local cage = ParadiseDev.Cage
        if not cage then return end
        local entry = cage.getEntry and cage.getEntry(username) or nil
        if entry and entry.key and cage.requestKeySet then
            return cage.requestKeySet(entry.key, username, enabled == true)
        end
        if cage.requestSet then return cage.requestSet(username, enabled == true) end
        return
    end
    if sendClientCommand then
        sendClientCommand("ParadiseDevTraitSyncer", "set", {
            username = tostring(username), trait = traitId, enabled = enabled == true, context=context,
        })
    end
end

function Syncer.isTargetTrait(target, traitId)
    if traitId == "ParadiseDev:Caged" and ParadiseDev.Cage and ParadiseDev.Cage.isTargetCaged then
        return ParadiseDev.Cage.isTargetCaged(target)
    end
    local username = target and (target.username or (target.getUsername and target:getUsername())) or nil
    if username then
        for _, entry in ipairs(Syncer.entries or {}) do
            if string.lower(tostring(entry.username or "")) == string.lower(tostring(username)) then
                return entry.traits and entry.traits[traitId] == true or false
            end
        end
    end
    return Syncer.has(target, traitId)
end

function Syncer.setTarget(_, target, traitId, enabled)
    if not target or not target.getUsername then return end
    if traitId == "ParadiseDev:Caged" and ParadiseDev.Cage and ParadiseDev.Cage.requestSet then
        ParadiseDev.Cage.requestSet(target:getUsername(), enabled)
        return
    end
    Syncer.requestSet(target:getUsername(), traitId, enabled)
end

function Syncer.addTargetMenu(menu, target)
    if not menu or not target or not target.getUsername then return end
    local root = menu:addOption("Trait Syncer")
    local submenu = ISContextMenu:getNew(menu)
    menu:addSubMenu(root, submenu)
    for _, traitId in ipairs(Syncer.Traits) do
        if traitId=="ParadiseDev:PvE" then Syncer.bindPvEMenu(submenu,target)
        else
            local enabled = Syncer.isTargetTrait(target, traitId)
            local option = submenu:addOption((enabled and "Remove " or "Add ") .. traitId, nil, Syncer.setTarget, target, traitId, not enabled)
            tooltip(option,"Account trait state: " .. (enabled and "TRUE" or "FALSE"))
        end
    end
end

Syncer.Panel = ISCollapsableWindow:derive("ParadiseDev.TraitSyncer.Panel")
function Syncer.Panel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + 10
    self.info = ISLabel:new(12, top, 18, "Trait assignments", 0.85, 0.9, 1, 1, UIFont.Small, true)
    self.info:initialise(); self.info:instantiate(); self:addChild(self.info)
    self.usernameEntry = ISTextEntryBox:new("", 84, top + 24, self.width - 222, 24)
    self.usernameEntry:initialise(); self.usernameEntry:instantiate(); self:addChild(self.usernameEntry)
    self.addButton = ISButton:new(self.width - 128, top + 24, 116, 24, "Add", self, Syncer.Panel.onClick)
    self.addButton.internal = "ADD"; self.addButton:initialise(); self.addButton:instantiate(); self:addChild(self.addButton)
    self.list = ISScrollingListBox:new(12, top + 54, self.width - 24, self.height - top - 108)
    self.list:initialise(); self.list:instantiate(); self.list.itemheight = 22; self.list.font = UIFont.Small; self.list.drawBorder = true; self:addChild(self.list)
    self.refreshButton = ISButton:new(self.width - 122, self.height - 42, 110, 26, "Refresh", self, Syncer.Panel.onClick)
    self.refreshButton.internal = "REFRESH"; self.refreshButton:initialise(); self.refreshButton:instantiate(); self:addChild(self.refreshButton)
    self.trueButton = ISButton:new(12, self.height - 42, 110, 26, "Set TRUE", self, Syncer.Panel.onClick)
    self.trueButton.internal = "TRUE"; self.trueButton:initialise(); self.trueButton:instantiate(); self:addChild(self.trueButton)
    self.falseButton = ISButton:new(128, self.height - 42, 110, 26, "Set FALSE", self, Syncer.Panel.onClick)
    self.falseButton.internal = "FALSE"; self.falseButton:initialise(); self.falseButton:instantiate(); self:addChild(self.falseButton)
    Syncer.refreshPanel()
end
function Syncer.Panel:onClick(button)
    if button.internal == "REFRESH" then Syncer.requestState(); return end
    local username = self.usernameEntry and self.usernameEntry:getText() or ""
    if button.internal == "ADD" and username ~= "" then
        Syncer.requestSet(username, Syncer.Traits[1], true); self.usernameEntry:setText("")
        return
    end
    if button.internal == "TRUE" or button.internal == "FALSE" then
        local item = self.list.items[self.list.selected]
        local entry = item and item.item or nil
        if entry then Syncer.requestSet(entry.username, entry.trait, button.internal == "TRUE",entry.context) end
    end
end
function Syncer.Panel:new(x, y, width, height)
    local panel = ISCollapsableWindow:new(x, y, width, height); setmetatable(panel, self); self.__index = self
    panel.title = "ParadiseZ Trait Syncer"; panel.resizable = true; return panel
end
function Syncer.Panel:close()
    ParadiseDev.TraitSyncer.ClosePanel()
end
function Syncer.ClosePanel()
    local panel=Syncer.window
    Syncer.window=nil
    if panel then panel:setVisible(false);panel:removeFromUIManager() end
end
function Syncer.OpenPanel()
    local player=getPlayer and getPlayer()
    if not ParadiseRestore or not ParadiseRestore.isAdm(player) then return end
    if not Syncer.window then
        local width,height=640,420
        local core=getCore()
        local panel=Syncer.Panel:new((core:getScreenWidth()-width)/2,(core:getScreenHeight()-height)/2,width,height)
        Syncer.window=panel
        panel:initialise();panel:addToUIManager()
    end
    Syncer.window:setVisible(true)
    Syncer.requestState()
end
function Syncer.refreshPanel()
    if not Syncer.window or not Syncer.window.list then return end
    local list=Syncer.window.list
    local selected=list.items[list.selected]
    selected=selected and selected.item
    list:clear()
    local cageEntries = Syncer.cageEntries
    local cages, seen, entries = {}, {}, {}
    for _, entry in ipairs(cageEntries or {}) do
        cages[string.lower(tostring(entry.username or ""))] = entry
    end
    for _, entry in ipairs(Syncer.entries) do
        entries[#entries + 1] = entry
        seen[string.lower(tostring(entry.username or ""))] = true
    end
    for _, entry in ipairs(cageEntries or {}) do
        if not seen[string.lower(tostring(entry.username or ""))] then
            entries[#entries + 1] = {username = entry.username, cageOnly = true}
            seen[string.lower(tostring(entry.username or ""))] = true
        end
    end
    for _, entry in ipairs(entries) do
        for _, traitId in ipairs(Syncer.Traits) do
            if (not entry.cageOnly or traitId == "ParadiseDev:Caged") and (traitId~="ParadiseDev:PvE" or entry.context and entry.context.scope=="legacy-body") then
                local enabled = entry.traits and entry.traits[traitId] == true
                if traitId == "ParadiseDev:Caged" and cageEntries ~= nil then
                    local cageEntry = cages[string.lower(tostring(entry.username or ""))]
                    enabled = cageEntry and cageEntry.isCaged == true or false
                end
                Syncer.window.list:addItem(tostring(entry.username) .. " | " .. traitId .. " | " .. (enabled and "TRUE" or "FALSE"), {
                    username = entry.username, trait = traitId, enabled = enabled,context=entry.context,
                })
            end
        end
    end
    for _,entry in ipairs(Syncer.profiles or {}) do
        local context=entry.context
        if type(context)=="table" then
            local status=context.ready and (context.pve and "TRUE" or "FALSE") or "NEEDS ASSIGNMENT"
            Syncer.window.list:addItem(tostring(entry.username).." | Profile "..tostring(entry.slot).." "..tostring(entry.name).." | PvE | "..status,
                {username=entry.username,trait="ParadiseDev:PvE",context=context,enabled=context.pve})
        end
    end
    -- A refreshed roster must not move an administrator's selection onto a
    -- different account or a new profile reusing the same numbered slot.
    list.selected=0
    if selected then
        local selectedId=selected.context and selected.context.profileId
        for i,item in ipairs(list.items) do
            local current=item.item
            if current.username==selected.username and current.trait==selected.trait
                and (current.context and current.context.profileId)==selectedId then list.selected=i;break end
        end
    end
end
local function clock() return getTimestampMs and getTimestampMs() or 0 end
local function owner() return getPlayer and getPlayer() end
local function administrator() return ParadiseRestore and ParadiseRestore.isAdm(owner()) end
local function user(pl) return pl and pl.getUsername and tostring(pl:getUsername()) end
local function samePlayer(pl)
    return pl and user(pl) and getPlayerFromUsername and getPlayerFromUsername(user(pl))==pl
end
local function contextValid(c)
    return type(c)=="table" and type(c.contextId)=="string" and type(c.bodyKey)=="string"
        and type(c.pveRevision)=="number" and type(c.pve)=="boolean"
end
Syncer.CACHE_MS=5000
Syncer.profiles={};Syncer.observed={};Syncer.menuRows={};Syncer.requests={}
Syncer.nonceSequence=Syncer.nonceSequence or 0
local function nonce(prefix)
    Syncer.nonceSequence=Syncer.nonceSequence+1
    return prefix..":"..tostring(clock())..":"..tostring(Syncer.nonceSequence)
end
function Syncer.requestState()
    Syncer.requestMenuState(true)
    if ParadiseDev.Cage and ParadiseDev.Cage.requestState then ParadiseDev.Cage.requestState() end
end
function Syncer.requestMenuState(force)
    if not administrator() or not sendClientCommand then return false end
    local now=clock()
    if not force and Syncer.lastMenuRequest and now>=Syncer.lastMenuRequest and now-Syncer.lastMenuRequest<1000 then return false end
    Syncer.lastMenuRequest=now
    local id=nonce("admin");local targets={}
    local players=getOnlinePlayers and getOnlinePlayers()
    if players then for i=0,players:size()-1 do local pl=players:get(i);if user(pl) then targets[string.lower(user(pl))]=pl end end end
    for _,row in ipairs(Syncer.menuRows) do if samePlayer(row.player) then targets[string.lower(user(row.player))]=row.player end end
    for key,request in pairs(Syncer.requests) do if now-request.at>Syncer.CACHE_MS then Syncer.requests[key]=nil end end
    Syncer.requests[id]={at=now,targets=targets,owner=owner()}
    sendClientCommand("ParadiseDevTraitSyncer","list",{requestId=id})
    return true
end
function Syncer.getTargetPvEState(target)
    if not administrator() or not samePlayer(target) or (target.isDead and target:isDead()) then return false,false end
    local record=Syncer.observed[string.lower(user(target))]
    local now=clock()
    if not record or record.player~=target or now<record.at or now-record.at>Syncer.CACHE_MS then return false,false end
    local c=record.context
    if not contextValid(c) or c.onlineId~=target:getOnlineID() then return false,false end
    return c.pve,c.ready==true,c
end
local function attached(row)
    for _,option in pairs(row.menu.options or {}) do if option==row.option and option.paradisePvERow==row then return true end end
    return false
end
function Syncer.retryMenu(row)
    if row.valid and not row.valid() then return end
    row.started=clock();row.attempts=0;row.context=nil
    Syncer.observed[string.lower(user(row.player) or "")]=nil
    Syncer.updateMenus(true)
end
function Syncer.chooseMenu(row)
    if row.valid and not row.valid() then return end
    local _,known,context=Syncer.getTargetPvEState(row.player)
    if not known or not row.context or context.contextId~=row.context.contextId
        or context.pveRevision~=row.context.pveRevision then
        Syncer.retryMenu(row);return
    end
    Syncer.requestSet(user(row.player),"ParadiseDev:PvE",row.enabled,row.context)
end
function Syncer.reviewMenu(row)
    if row.valid and not row.valid() then return end
    Syncer.OpenPanel()
end
function Syncer.updateMenus(force)
    local now=clock()
    if not force and Syncer.menuTick and now>=Syncer.menuTick and now-Syncer.menuTick<250 then return end
    Syncer.menuTick=now
    for i=#Syncer.menuRows,1,-1 do
        local row=Syncer.menuRows[i]
        local option=row.option
        if not attached(row) or row.valid and not row.valid() or not administrator() or now-row.started>60000 then table.remove(Syncer.menuRows,i)
        else
            local pve,known,context=Syncer.getTargetPvEState(row.player)
            local name=user(row.player) or "player"
            local visible=not row.menu.getIsVisible or row.menu:getIsVisible()
            local previousName=option.name
            option.target=row;option.param1=nil
            if known then
                option.name=(pve and "Disable PvE: " or "Enable PvE: ")..name
                row.context=context;row.enabled=not pve
                option.notAvailable=false;option.onSelect=Syncer.chooseMenu
                row.wasKnown=true
                tooltip(option,context.scope=="legacy-body" and "Changes this existing character only. Other profiles keep their own PvE setting."
                    or "Changes this profile only. Other profiles keep their own PvE setting. Zone eligibility is checked again after the change.")
            elseif context and not context.ready then
                option.name="PvE needs profile review: "..name
                option.notAvailable=false;option.onSelect=Syncer.reviewMenu;row.context=nil
                tooltip(option,(context.reason or "This profile's older PvE records disagree.").." Open Trait Syncer, select the profile, and choose Set TRUE or Set FALSE.")
            elseif not samePlayer(row.player) or (row.player.isDead and row.player:isDead()) then
                option.name="PvE target unavailable: "..name
                option.notAvailable=true;option.onSelect=nil;row.context=nil
                tooltip(option,"This character has died, disconnected, or changed. Open a new menu for the current character.")
            else
                if row.wasKnown then row.started=now;row.attempts=0;row.wasKnown=nil end
                local waiting=now-row.started<5000 and row.attempts<3
                option.name=(waiting and "PvE status loading: " or "PvE unavailable - retry: ")..name
                option.notAvailable=waiting;option.onSelect=not waiting and Syncer.retryMenu or nil;row.context=nil
                tooltip(option,waiting and "Waiting for this character's current server-confirmed profile status."
                    or "The server did not return a current profile status. Click to retry; no trait change has been sent.")
                if waiting and (visible or force) and Syncer.requestMenuState() then row.attempts=row.attempts+1 end
            end
            if option.name~=previousName and row.menu.calcWidth and row.menu.setWidth then row.menu:setWidth(row.menu:calcWidth()) end
        end
    end
end
function Syncer.bindPvEMenu(menu,target)
    local option=menu:addOption("PvE status loading: "..tostring(user(target) or "player"))
    local row={menu=menu,option=option,player=target,started=clock(),attempts=0}
    option.paradisePvERow=row;option.notAvailable=true
    Syncer.menuRows[#Syncer.menuRows+1]=row
    -- Menus are pooled by vanilla; bound retention and verify option identity.
    while #Syncer.menuRows>32 do table.remove(Syncer.menuRows,1) end
    Syncer.updateMenus(true)
    return option
end
function Syncer.requestOwner(player)
    if not player or not sendClientCommand then return end
    local now=clock();local request=Syncer.ownerRequest
    if request and request.player==player and now>=request.at and now-request.at<1000 then return end
    local id=nonce("owner")
    Syncer.ownerRequest={player=player,id=id,at=now};Syncer.ownerPvE=nil
    sendClientCommand("ParadiseDevTraitSyncer","owner",{requestId=id})
end
function Syncer.onServerCommand(module, command, args)
    if module=="ParadiseDevCage" and command=="state" then
        Syncer.cageEntries=type(args)=="table" and type(args.entries)=="table" and args.entries or {}
        Syncer.refreshPanel();return
    end
    if module~="ParadiseDevTraitSyncer" or type(args)~="table" then return end
    if command=="state" and type(args.entries)=="table" then
        if type(args.requestId)~="string" then return end
        local request=Syncer.requests[args.requestId]
        Syncer.requests[args.requestId]=nil
        local revision=tonumber(args.revision);local now=clock()
        if not administrator() or not request or request.owner~=owner() or now<request.at or now-request.at>Syncer.CACHE_MS
            or not revision or revision<Syncer.lastStateRevision then return end
        Syncer.lastStateRevision=revision;Syncer.entries=args.entries;Syncer.profiles=args.profiles or {};Syncer.stateAt=now
        Syncer.observed={}
        for _,entry in ipairs(args.entries) do
            local name=string.lower(tostring(entry.username or ""));local pl=request.targets[name];local context=entry.context
            if samePlayer(pl) and contextValid(context) and context.onlineId==pl:getOnlineID() then
                Syncer.observed[name]={player=pl,context=context,at=now}
                if context.ready and pl~=owner() then Syncer.applyConfirmedPvE(pl,context.pve) end
            end
        end
        Syncer.refreshPanel();Syncer.refreshTraitsUI();Syncer.updateMenus(true)
    elseif command=="invalidate" then
        Syncer.observed={};Syncer.stateAt=nil
        if Syncer.window or #Syncer.menuRows>0 then Syncer.requestMenuState() end
        Syncer.updateMenus(true)
    elseif command=="pve" then
        local player=owner();local request=Syncer.ownerRequest;local c=args.context;local revision=tonumber(args.revision)
        if not request or request.player~=player or args.requestId~=request.id or not contextValid(c)
            or not c.ready or c.onlineId~=player:getOnlineID() or not revision or revision<Syncer.lastOwnerRevision then return end
        Syncer.lastOwnerRevision=revision
        Syncer.ownerPvE={player=player,enabled=c.pve,context=c,at=clock()}
        Syncer.applyConfirmedPvE(player,c.pve);Syncer.refreshTraitsUI()
    elseif command=="result" and type(args.message)=="string" then
        local player=owner();if administrator() and player and player.setHaloNote then player:setHaloNote(args.message) end
    elseif command=="error" and type(args.message)=="string" then
        Syncer.observed={};Syncer.stateAt=nil
        local player=owner();if player and player.setHaloNote then player:setHaloNote(args.message) end
        Syncer.updateMenus(true)
    end
end
function Syncer.onPlayerUpdate(player)
    if not player or player~=owner() then return end
    local now=clock()
    if now>=Syncer.lastSync and now-Syncer.lastSync<1000 then return end
    Syncer.lastSync=now
    local receipt=Syncer.ownerPvE
    if not receipt or receipt.player~=player or now<receipt.at or now-receipt.at>5000 then Syncer.requestOwner(player)
    else Syncer.applyConfirmedPvE(player,receipt.enabled) end
    Syncer.syncPlayer(player)
    local pve=Syncer.has(player,"ParadiseDev:PvE")
    if Syncer.lastOwner~=player or Syncer.lastOwnerPvE~=pve then
        Syncer.lastOwner,Syncer.lastOwnerPvE=player,pve
        if triggerEvent then triggerEvent("OnTraitsSync","ParadiseDev:PvE",pve) end
    end
end
function Syncer.onConnected()
    Syncer.entries={};Syncer.profiles={};Syncer.observed={};Syncer.requests={};Syncer.menuRows={};Syncer.lastMenuRequest=nil
    Syncer.lastStateRevision=-1;Syncer.lastOwnerRevision=-1;Syncer.ownerPvE=nil;Syncer.ownerRequest=nil;Syncer.stateAt=nil
    if administrator() then Syncer.requestMenuState() end
end
Events.OnConnected.Remove(Syncer.onConnected)
Events.OnConnected.Add(Syncer.onConnected)
Events.OnServerCommand.Add(Syncer.onServerCommand)
Events.OnPlayerUpdate.Add(Syncer.onPlayerUpdate)
function Syncer.menuTickUpdate() Syncer.updateMenus(false) end
Events.OnTick.Add(Syncer.menuTickUpdate)
