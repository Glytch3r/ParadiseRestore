-- Small Lifestyle compatibility hooks. Progress restoration never calls doComplete
-- or grants inventory. Normal Lifestyle action and completion handlers remain.
if isServer and isServer() then return end
require "Dev/ParadiseDev_LifeAmbitions"
ParadiseDev.LifeAmbitionsClient = ParadiseDev.LifeAmbitionsClient or {}
local C=ParadiseDev.LifeAmbitionsClient
C.wrappers=C.wrappers or {}
C.weights=C.weights or setmetatable({}, {__mode="k"})
C.pendingXP=C.pendingXP or setmetatable({}, {__mode="k"})
C.incompleteWanderer=C.incompleteWanderer or setmetatable({}, {__mode="k"})
local function finite(v) return type(v)=="number" and v==v and v>-math.huge and v<math.huge end
local function retained(ambt)
    for key,value in pairs(ambt._paradiseCredit or {}) do
        if finite(value) and (not finite(ambt[key]) or ambt[key]<value) then ambt[key]=value end
    end
end
local function progressWrapper(original,name)
    return function(pl,ambt)
        retained(ambt)
        if name=="LSBladeMaster" and C.pendingXP[pl] then return end
        local result=original(pl,ambt)
        -- Music level and currently carried money can legitimately be lower
        -- after death; retained ambition credit does not recreate those items.
        retained(ambt)
        return result
    end
end
local function wandererWrapper(original)
    return function(pl,ambt)
        if not ambt.completed then
            C.incompleteWanderer[pl]=ambt
            return original(pl,ambt)
        end
        -- Let upstream remove its old walking listener, without replaying its
        -- process-local additive carry-weight reward on login/profile switch.
        original(pl,{completed=false,isActive=false})
        if C.pendingXP[pl] then return end
        local ok,movement=pcall(require,"Helper/MovementUtil")
        if ok and movement and movement.setRunning then movement.setRunning(ambt.isActive==true) end
        if CharacterTrait and CharacterTrait.OUTDOORSMAN and not pl:hasTrait(CharacterTrait.OUTDOORSMAN) then
            sendClientCommand(pl,"LS","ChangeTrait",{"OUTDOORSMAN","add"})
        end
        local key=ambt._paradiseRestoreKey or tostring(pl:getModData().ParadiseLifeProfileCharacterKey or "native")
        local state=C.weights[pl]
        local saved=finite(ambt.newWeight) and ambt.newWeight or nil
        if not state or state.key~=key or (saved and state.target~=saved) then
            -- A pre-existing completed ambition without a receipt cannot prove
            -- whether an older version awarded its carry bonus. Never guess
            -- another additive reward during an ordinary reconnect.
            local newlyCompleted=C.incompleteWanderer[pl]==ambt
            state={key=key,target=saved or pl:getMaxWeightBase()+(newlyCompleted and 1 or 0),applied=saved~=nil or not newlyCompleted}
            C.weights[pl]=state
        end
        ambt.newWeight=state.target
        if pl:getMaxWeightBase()==state.target then state.applied=true end
        if not state.applied then
            local now=getTimestampMs and getTimestampMs() or 0
            if not state.sentAt or now-state.sentAt>=5000 then
                state.sentAt=now
                if isClient and isClient() then sendClientCommand(pl,"LS","ChangeMaxWeight",{state.target})
                else pl:setMaxWeightBase(state.target);state.applied=true end
            end
        end
    end
end
function C.install()
    local manager=LSAmbtMng
    if not manager then return false end
    for _,name in ipairs({"LSBladeMaster","LSRockstar","LSElDorado","LSWanderer"}) do
        local original=manager[name]
        if type(original)=="function" and original~=C.wrappers[name] then
            local wrapped=(name=="LSWanderer" and wandererWrapper or progressWrapper)(original,name)
            C.wrappers[name]=wrapped;manager[name]=wrapped
        end
    end
    return true
end
function C.onRestored(pl)
    C.install()
    C.pendingXP[pl]=true
    -- Upstream reconciles its custom definitions on the next normal update.
    -- No ambition completion/effect handler is invoked by this callback.
    if LSAmbtMng then LSAmbtMng.LSCheckCustomAmbts=false end
end
function C.onXPReady(pl) C.pendingXP[pl]=nil end
local function onCreate() C.install() end
if Events then
    if Events.OnGameStart then Events.OnGameStart.Add(C.install) end
    if Events.OnCreatePlayer then Events.OnCreatePlayer.Add(onCreate) end
end
return C
