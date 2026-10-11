-- Existing Workshop shared integration. Keep the native constructor/parameter
-- names intact because NetTimedAction serializes its named arguments.
require "TimedActions/Animals/ISHutchGrabCorpseAction"
if ParadiseHutchCorpseGuard then return ParadiseHutchCorpseGuard end
local G={refused=0}
local originalValid=ISHutchGrabCorpseAction.isValid
local originalComplete=ISHutchGrabCorpseAction.complete
local function refuse()
    G.refused=math.min(G.refused+1,1000000)
    if G.refused<=3 or G.refused%1000==0 then print('[ParadiseHutch] stale corpse action refused') end
    return false
end
local function exact(action)
    if action==nil or action.paradiseCorpseAttempted or action.hutch==nil or action.animal==nil or action.corpse==nil then return false end
    local body=action.hutch:getDeadBody(action.index)
    return body~=nil and action.hutch:getAnimal(action.index)==action.animal
        and action.animal:getHutch()==action.hutch
        and action.animal:getData():getHutchPosition()==action.index
        and body:getCharacterOnlineID()==action.animal:getOnlineID()
        and body:getItem()==action.corpse
end
function ISHutchGrabCorpseAction:isValid()
    if not exact(self) then return refuse() end
    return originalValid(self)
end
function ISHutchGrabCorpseAction:complete()
    if not exact(self) then return refuse() end
    -- Never repeat a potentially partial inventory grant after an exception.
    self.paradiseCorpseAttempted=true
    return originalComplete(self)
end
G.exact=exact
ParadiseHutchCorpseGuard=G
return G
