
--ParadiseZ = ParadiseZ or {}
ParadiseClip = ParadiseClip or {}

--[[ 
    ISWorldMap.ShowWorldMap(0)
    ISFastTeleportMove.cheat = true
    pl:setBuildCheat(true)
]]

function whereami()
	local pl = getPlayer(); if not pl then return end
	local whereVar = math.floor(pl:getX()) ..', '.. math.floor(pl:getY()) ..', '.. math.floor(pl:getZ());
	Clipboard.setClipboard(whereVar);
	print('Clipboard Saved: ' ..whereVar)
	pl:Say(tostring(whereVar))
end


function cliptab(t)
    local formattedTable = ParadiseClip.printTable(t) 
    Clipboard.setClipboard(formattedTable) 
    print(formattedTable) 
    local pl = getPlayer() 
    if pl then pl:addLineChatElement(tostring('!')) end
	
	getSoundManager():playUISound("UIActivatePlayButton")
end

function clip(var)
    local pl = getPlayer()
    if not var then
        if pl then
            pl:addLineChatElement("err")
            return
        end
    end

	Clipboard.setClipboard(tostring(var))
    if pl then
        pl:addLineChatElement(tostring(var))
    end
end

function ParadiseClip.printTable(t, indent)
    indent = indent or 0
    local indentStr = string.rep("  ", indent)
    local result = ""

    if type(t) ~= "table" then
        result = result .. indentStr .. tostring(t) .. "\n"
        return result
    end

    for key, value in pairs(t) do
        if type(value) == "table" then
            result = result .. indentStr .. tostring(key) .. ":\n"
            result = result .. ParadiseClip.printTable(value, indent + 1)
        else
            result = result .. indentStr .. tostring(key) .. ": " .. tostring(value) .. "\n"
        end
    end

    return result
end

function ParadiseClip.formatTable(t, indent)
    indent = indent or 0  
    local indentation = string.rep("  ", indent)  
    local result = ""

    for key, value in pairs(t) do

        if type(key) == "number" then
            key = string.format("[%d]", key)
        else
            key = string.format("[%q]", tostring(key))
        end

        if type(value) == "table" then
            result = result .. tostring(value)..'\n' 
      
        elseif type(value) == "string" then
            result = result ..  tostring(value)..'\n'
        else
            result = result .. tostring(value)..'\n'
        end
    end

    return result
end

function ParadiseClip.clipMetaFunc(func)
    local result = ""
    local pl = getPlayer()
    local meta = getmetatable(func)
    if meta and meta.__index then
        for k, v in pairs(meta.__index) do
            result = result .. tostring(k) .."    ".. tostring(v) ..' \n';
        end
        Clipboard.setClipboard(result); print(result)
        if pl then pl:addLineChatElement(tostring(result)) end
    end
end

function ParadiseClip.clipMetaVar(var)
    local pl = getPlayer()
    local meta = getmetatable(var)
    if meta then
        local index = meta.__index
        if index then
            print(index)
            Clipboard.setClipboard(tostring(index))
            if pl then pl:addLineChatElement(tostring(index)) end
        else
            if pl then pl:addLineChatElement("err") end
        end
    else
         if pl then pl:addLineChatElement("err") end
	end
end

