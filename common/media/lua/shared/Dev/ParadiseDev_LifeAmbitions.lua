-- Versioned Lifestyle progress only. Never accepts inventory, traits or account data.
ParadiseDev = ParadiseDev or {}
ParadiseDev.LifeAmbitions = ParadiseDev.LifeAmbitions or {}
local A = ParadiseDev.LifeAmbitions
A.VERSION = 1
A.MAX_BYTES = 65536
local ids = {}
for _,id in ipairs({"LSBladeMaster","LSTerminator","LSMasterPainter","LSJuryRigger","LSBrushmaster",
    "LSGrimeFighter","LSElDorado","LSCommando","LSTheProfessional","LSLordDeath","LSUnstoppable",
    "LSGoodEating","LSRockstar","LSExplorer","LSWanderer","LSLumberjack","LSKnockdown","LSPlushies",
    "LSDietOfGods","LSLucky"}) do ids[id]=true end
local flags = {}
for _,key in ipairs({"isHidden","isPassive","disable","resetF","reqHas","reqNotHas","isActive","completed",
    "reset","forceReset","offBhv","offbhv","delayUnlock","ateRecent","clearBP","resetAdm","doUnlock","custom"}) do flags[key]=true end
local numbers = {ogXP=true,oldXP=true,ogKills=true,ogEnd=true,ogFireKR=true,ogHth=true,
    newWeight=true,ogX=true,ogY=true,countdown=true,recentKills=true,cd=true}
local strings = {name=true,cat=true,texture=true,_paradiseRestoreKey=true}
local bodyParts = {}
for _,key in ipairs({"Hand_L","Hand_R","ForeArm_L","ForeArm_R","UpperArm_L","UpperArm_R","Torso_Upper",
    "Torso_Lower","Head","Neck","Groin","UpperLeg_L","UpperLeg_R","LowerLeg_L","LowerLeg_R","Foot_L","Foot_R"}) do bodyParts[key]=true end
local injuries = {}
for _,key in ipairs({"Bite","Bleeding","Burn","Cut","DeepWound","Fracture","Scratch"}) do injuries[key.."ogTime"]=true end
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<=1000000000000 end
local function text(v) return type(v)=="string" and #v<=128 and not v:find("%z") end
local function need(ok) if not ok then error("Invalid or unsupported Lifestyle ambition snapshot") end end

function A.validate(payload)
    local ok,result = pcall(function()
        need(type(payload)=="table" and payload.version==A.VERSION and type(payload.ambitions)=="table")
        for key in pairs(payload) do need(key=="version" or key=="ambitions") end
        local bytes,nodes,seen=0,0,{}
        local function charge(key,value)
            nodes=nodes+1; bytes=bytes+24+(type(key)=="string" and #key*4 or 8)+(type(value)=="string" and #value*4 or 8)
            need(nodes<=4096 and bytes<=A.MAX_BYTES)
        end
        local function enter(value)
            need(type(value)=="table" and not seen[value]); seen[value]=true
        end
        local function flat(value,kind)
            enter(value)
            local out={}
            for key,item in pairs(value) do
                charge(key,item)
                if kind=="explored" then need(text(key) and type(item)=="boolean")
                elseif kind=="credit" then need(type(key)=="string" and key:match("^goal[1-6]progress$") and finite(item) and item>=0)
                elseif kind=="injury" then
                    need((type(key)=="number" and key==math.floor(key) and key>=1 and key<=6 and type(item)=="boolean") or
                        (injuries[key] and finite(item) and item>=0))
                else need(type(key)=="number" and key==math.floor(key) and key>=1 and key<=256 and text(item)) end
                out[key]=item
            end
            return out
        end
        enter(payload.ambitions)
        local ambitions={}
        for id,value in pairs(payload.ambitions) do
            charge(id,value);need(ids[id])
            if value==false then ambitions[id]=false
            else
                enter(value)
                local out={}
                for key,item in pairs(value) do
                    charge(key,item);need(type(key)=="string")
                    if flags[key] then need(type(item)=="boolean");out[key]=item
                    elseif strings[key] then need(text(item) and (key~="name" or item==id));out[key]=item
                    elseif numbers[key] then
                        need(finite(item) or item==false)
                        if key=="newWeight" and item~=false then need(item==math.floor(item) and item>=1 and item<=2147483647) end
                        out[key]=item
                    elseif key:match("^goal[1-6]$") then need((finite(item) and item>=0) or text(item));out[key]=item
                    elseif key:match("^goal[1-6]progress$") then need(finite(item) or type(item)=="boolean");out[key]=item
                    elseif key=="explored" and id=="LSExplorer" then out[key]=flat(item,"explored")
                    elseif key=="exclusive" then out[key]=flat(item,"strings")
                    elseif key=="_paradiseCredit" then out[key]=flat(item,"credit")
                    elseif bodyParts[key] and id=="LSUnstoppable" then out[key]=flat(item,"injury")
                    elseif key=="plushyList" and id=="LSPlushies" then
                        enter(item);out[key]={}
                        for index,list in pairs(item) do
                            charge(index,list);need(type(index)=="number" and index==math.floor(index) and index>=1 and index<=6)
                            out[key][index]=flat(list,"strings")
                        end
                    -- Obsolete native square references are not earned progress.
                    elseif key~="ogSqr" then error("Unsupported Lifestyle ambition field: "..key) end
                end
                ambitions[id]=out
            end
        end
        return {version=A.VERSION,ambitions=ambitions}
    end)
    if ok then return result end
    return nil,tostring(result)
end

function A.capture(pl)
    if not pl or not pl.getModData then return nil,"Player unavailable" end
    local value=pl:getModData().Ambitions
    if value==nil then return nil end
    return A.validate({version=A.VERSION,ambitions=value})
end

-- Skill loss is independent of ambition credit. Rebase derived counters once
-- against the destination XP/kills, and retain historical goals without items.
function A.forRestore(ambitions,skills,kills,restoreKey)
    if ambitions==nil then return nil end
    local payload,err=A.validate({version=A.VERSION,ambitions=ambitions})
    if not payload then return nil,err end
    local out=payload.ambitions
    local blade=out.LSBladeMaster
    if blade and not blade.completed then
        local progress=math.max(0,tonumber(blade.goal1progress) or 0)
        blade.ogXP=(skills.SmallBlade or 0)+(skills.LongBlade or 0)-progress
        blade.oldXP=false
        -- Do not rebase against a client that has not received native XP yet.
        -- Keep credit visible while that separate native replication catches up.
        blade._paradiseCredit=blade._paradiseCredit or {}
        blade._paradiseCredit.goal1progress=progress
    end
    local terminator=out.LSTerminator
    if terminator then
        if not terminator.completed then terminator.ogKills=kills-math.max(0,tonumber(terminator.goal1progress) or 0) end
        terminator.ogEnd=nil;terminator.ogHth=nil;terminator.ogFireKR=nil
    end
    for _,id in ipairs({"LSRockstar","LSElDorado"}) do
        local entry=out[id]
        if entry and not entry.completed then
            entry._paradiseCredit=entry._paradiseCredit or {}
            for i=1,(id=="LSRockstar" and 1 or 3) do
                local key="goal"..i.."progress"
                if finite(entry[key]) then entry._paradiseCredit[key]=math.max(0,entry[key],entry._paradiseCredit[key] or 0) end
            end
        end
    end
    local wanderer=out.LSWanderer
    if wanderer then
        wanderer.ogX=nil;wanderer.ogY=nil;wanderer.ogSqr=nil
        wanderer.newWeight=nil;wanderer._paradiseRestoreKey=restoreKey
    end
    local unstoppable=out.LSUnstoppable
    if unstoppable then for key in pairs(bodyParts) do unstoppable[key]=nil end;unstoppable.clearBP=nil end
    -- Conditions belong to the replacement body; earned counters remain exact.
    if out.LSDietOfGods then out.LSDietOfGods.ateRecent=false end
    return out
end
return A
