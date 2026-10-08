-- Immutable creation clothing only. Never serialize inventory, item IDs,
-- condition, containers, mod data, or a dying body's current equipment.
ParadiseDev = ParadiseDev or {}
ParadiseDev.LifeStartingOutfit = ParadiseDev.LifeStartingOutfit or {}
local O = ParadiseDev.LifeStartingOutfit
O.VERSION = 1
O.MAX_ITEMS = 64
local fields={fullType=true,tint=true,hue=true,baseTexture=true,textureChoice=true,decal=true}
local function integer(n,lo,hi) return type(n)=="number" and n==n and n==math.floor(n) and n>=lo and n<=hi end
local function text(s,max) return type(s)=="string" and #s>0 and #s<=max end
function O.validate(outfit)
    if type(outfit)~="table" or outfit.version~=O.VERSION or type(outfit.items)~="table" then return nil,"Invalid starting outfit" end
    for key in pairs(outfit) do if key~="version" and key~="items" then return nil,"Unsupported starting outfit field" end end
    local result={version=O.VERSION,items={}}
    local count=0
    for index,item in pairs(outfit.items) do
        count=count+1
        if not integer(index,1,O.MAX_ITEMS) or type(item)~="table" then return nil,"Invalid starting clothing list" end
        for key in pairs(item) do if not fields[key] then return nil,"Unsupported starting clothing field" end end
        if not text(item.fullType,256) or not item.fullType:match("^[%w_%-]+%.[%w_%-]+$") then return nil,"Invalid starting clothing type" end
        if type(item.hue)~="number" or item.hue~=item.hue or item.hue< -1 or item.hue>1 then return nil,"Invalid starting clothing hue" end
        if not integer(item.baseTexture,-1,4096) or not integer(item.textureChoice,-1,4096) then return nil,"Invalid starting clothing texture" end
        if type(item.decal)~="string" or #item.decal>256 then return nil,"Invalid starting clothing decal" end
        local tint=item.tint
        if type(tint)~="table" then return nil,"Missing starting clothing color" end
        for key in pairs(tint) do if key~="r" and key~="g" and key~="b" then return nil,"Unsupported starting clothing color" end end
        for _,key in ipairs({"r","g","b"}) do
            local n=tint[key]
            if type(n)~="number" or n~=n or n<0 or n>1 then return nil,"Invalid starting clothing color" end
        end
        result.items[index]={fullType=item.fullType,hue=item.hue,baseTexture=item.baseTexture,textureChoice=item.textureChoice,
            decal=item.decal,tint={r=tint.r,g=tint.g,b=tint.b}}
    end
    if count~=#result.items or count>O.MAX_ITEMS then return nil,"Sparse starting clothing list" end
    for i=1,count do if not result.items[i] then return nil,"Sparse starting clothing list" end end
    return result
end

function O.basic()
    local result={version=O.VERSION,items={}}
    for _,id in ipairs({"Base.Tshirt_DefaultTEXTURE_TINT","Base.Trousers_DefaultTEXTURE_TINT","Base.Socks_Ankle","Base.Shoes_TrainerTINT"}) do
        result.items[#result.items+1]={fullType=id,tint={r=0.65,g=0.65,b=0.65},hue=0,baseTexture=0,textureChoice=0,decal=""}
    end
    return result
end

-- Pure profile/model boundary. Legacy profiles get a fixed basic outfit;
-- checkpoints and death equipment are deliberately not consulted.
function O.forProfile(outfit)
    if outfit==nil then return O.basic() end
    return O.validate(outfit)
end

function O.capture(worn)
    local result={version=O.VERSION,items={}}
    if not worn or worn:size()>O.MAX_ITEMS then return nil,"Starting clothing exceeds limit" end
    for i=0,worn:size()-1 do
        local item=worn:getItemByIndex(i)
        if item and item:IsClothing() then
            local visual,clothing=item:getVisual(),item:getClothingItem()
            if not visual or not clothing or not item:getBodyLocation() then return nil,"Starting clothing visuals unavailable" end
            -- These getters resolve native random choices before freezing them.
            local tint=visual:getTint(clothing)
            visual:getBaseTexture(clothing);visual:getTextureChoice(clothing)
            local decal=visual:getDecal(clothing) or ""
            result.items[#result.items+1]={fullType=item:getFullType(),hue=visual:getHue(clothing),tint={r=tint:getRedFloat(),g=tint:getGreenFloat(),b=tint:getBlueFloat()},
                baseTexture=visual:getBaseTexture(),textureChoice=visual:getTextureChoice(),decal=decal}
        end
    end
    return O.validate(result)
end

local function itemsFor(outfit)
    local items,locations={},{}
    for _,saved in ipairs(outfit.items) do
        local item=instanceItem(saved.fullType)
        if not item or not item:IsClothing() or not item:getBodyLocation() or not item:getVisual() or not item:getClothingItem() then
            return nil,"Starting clothing is unavailable: "..saved.fullType
        end
        local location=tostring(item:getBodyLocation())
        -- One garment per native slot; no hidden second copy in the inventory.
        if locations[location] then return nil,"Starting clothing slots conflict" end
        locations[location]=true
        local visual=item:getVisual()
        local c=saved.tint
        visual:setTint(ImmutableColor.new(c.r,c.g,c.b,1))
        visual:setHue(saved.hue)
        item:setColorRed(c.r);item:setColorGreen(c.g);item:setColorBlue(c.b)
        item:setCustomColor(true)
        visual:setBaseTexture(saved.baseTexture);visual:setTextureChoice(saved.textureChoice);visual:setDecal(saved.decal)
        items[#items+1]=item
    end
    return items
end

-- Resolve the whole plan before modifying a body/descriptor. Removed mods or
-- unavailable clothing use the approved basic fallback, never later equipment.
function O.resolve(outfit)
    local saved,err=O.forProfile(outfit)
    if not saved then return nil,err end
    local ok,items;ok,items,err=pcall(itemsFor,saved)
    if ok and items then return {outfit=saved,items=items,fallback=false} end
    local reason=ok and err or tostring(items)
    saved=O.basic();ok,items,err=pcall(itemsFor,saved)
    if not ok then return nil,tostring(items) end
    if not items then return nil,err end
    return {outfit=saved,items=items,fallback=true,reason=reason}
end

function O.dressDescriptor(desc,outfit)
    local ok,plan,err=pcall(O.resolve,outfit)
    if not ok then return nil,tostring(plan) end
    if not plan then return nil,err end
    desc:getWornItems():clear()
    for _,item in ipairs(plan.items) do desc:setWornItem(item:getBodyLocation(),item) end
    return true,plan.outfit
end
return O
