ParadisePOIBuilder = ParadisePOIBuilder or {}
ParadisePOIBuilder.Cursor = ParadisePOIBuilder.Cursor or {}
if ParadisePOIBuilder.isB41() then return end

local P = ParadisePOIBuilder
local K = P.Cursor

if not K.install then
    K.install = function()
        local Cursor = ISDestroyCursor
        if not Cursor or not Cursor.canDestroy then return end
        K.canDestroyHook = K.canDestroyHook or Cursor.canDestroy
        if not K.canDestroy then
            K.canDestroy = function(cursor, obj)
                if P.isSledgeProof(obj) then return false end
                return K.canDestroyHook(cursor, obj)
            end
        end
        if Cursor.canDestroy ~= K.canDestroy then
            Cursor.canDestroy = K.canDestroy
        end
    end
end
K.install()
Events.OnGameStart.Remove(K.install)
Events.OnGameStart.Add(K.install)
