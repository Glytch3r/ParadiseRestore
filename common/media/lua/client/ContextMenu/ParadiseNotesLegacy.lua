-- Existing FloorNote data remains legacy; edits use the authenticated server path.
require "ISUI/ISTextBox"
local function request(floor,note,color,offset)
 local sq=floor:getSquare()
 sendClientCommand("ParadiseDevNotes","legacySet",{x=sq:getX(),y=sq:getY(),z=sq:getZ(),note=note,color=color,offset=offset})
end
local function prompt(player,floor,part)
 local md=floor:getModData();local c=md.FloorNoteColor or {r=1,g=1,b=1};local o=md.FloorNoteOffset or {x=0,y=0}
 local initial=part=="text" and tostring(md.FloorNote or "") or part=="color" and (c.r..","..c.g..","..c.b) or (o.x..","..o.y)
 local title=part=="text" and "Legacy note text" or part=="color" and "Color: r,g,b (each 0 to 1)" or "Display offset: x,y (each -0.49 to 0.49)"
 local modal=ISTextBox:new(0,0,340,180,title,initial,nil,function(_,button)
  if not button or button.internal~="OK" or not button.parent or not button.parent.entry then return end
  local value=button.parent.entry:getText();local note=md.FloorNote
  if part=="text" then note=value
  elseif part=="color" then local r,g,b=value:match("^%s*([^,]+),([^,]+),([^,]+)%s*$");if not tonumber(r) or not tonumber(g) or not tonumber(b) then return end;c={r=tonumber(r),g=tonumber(g),b=tonumber(b)}
  else local x,y=value:match("^%s*([^,]+),([^,]+)%s*$");if not tonumber(x) or not tonumber(y) then return end;o={x=tonumber(x),y=tonumber(y)} end
  request(floor,note,c,o)
 end,player)
 modal.maxChars=1000;modal:initialise();modal:addToUIManager()
end
Events.OnFillWorldObjectContextMenu.Add(function(player,context,objects,test)
 if test then return end
 local pl=getSpecificPlayer(player);if not pl then return end
 local admin=ParadiseRestore.isAdm(pl);local sand=SandboxVars and SandboxVars.ParadiseZnotes
 if not admin and not (sand and sand.EveryoneCanWriteNotes==true) then return end
 local seen={}
 for _,obj in ipairs(objects) do
  local sq=obj:getSquare();local floor=sq and sq:getFloor()
  if floor and not seen[floor] and floor:hasModData() then
   seen[floor]=true;local md=floor:getModData()
   if md.FloorNote and (admin or not md.FloorNoteOwner or md.FloorNoteOwner==pl:getUsername()) then
    context:addOption("Edit legacy note",player,prompt,floor,"text")
    context:addOption("Recolor legacy note",player,prompt,floor,"color")
    context:addOption("Reposition legacy note",player,prompt,floor,"offset")
    context:addOption("Delete legacy note",floor,function(f)request(f,nil)end)
   end
  end
 end
end)
