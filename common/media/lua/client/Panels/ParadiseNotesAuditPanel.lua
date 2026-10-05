require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
local Panel=ISPanel:derive("ParadiseNotesAuditPanel")
local active
local function send(command,args) sendClientCommand("ParadiseNotesAudit",command,args or {}) end
function Panel:initialise()
 ISPanel.initialise(self)
 self.list=ISScrollingListBox:new(10,95,self.width-20,self.height-185)
 self.list:initialise();self.list:instantiate();self:addChild(self.list)
 self.filterEntry=ISTextEntryBox:new("",10,60,300,26);self.filterEntry:initialise();self:addChild(self.filterEntry)
 self.planEntry=ISTextEntryBox:new("",320,60,self.width-330,26);self.planEntry:initialise();self:addChild(self.planEntry)
 local labels={"Refresh / export","Previous","Next","Plan selected","Plan ALL in scope","Apply approved","Rollback approved","Close"}
 for i,label in ipairs(labels) do
  local b=ISButton:new(10+((i-1)%4)*185,self.height-80+math.floor((i-1)/4)*32,180,28,label,self,Panel.click)
  b.internal=i;b:initialise();self:addChild(b)
 end
 self.page=1;self.message="Server inventory: loaded observed floors + all globals. NOT the entire world."
end
function Panel:prerender()
 ISPanel.prerender(self);self:drawText("Notes administration — dry-run cleanup requires separate owner approval",10,10,1,1,1,1,UIFont.Small)
 self:drawText(tostring(self.message):sub(1,145),10,32,1,0.9,0.3,1,UIFont.Small)
 self:drawText("Filter: text, type or tile",10,46,0.7,0.8,0.9,1,UIFont.Small)
 self:drawText("Saved cleanup plan ID",320,46,0.7,0.8,0.9,1,UIFont.Small)
end
function Panel:click(b)
 local n=b.internal
 if n==8 then self:removeFromUIManager();active=nil;return end
 if n==1 then send("export",{page=self.page,contains=self.filterEntry:getText()})
 elseif n==2 or n==3 then self.page=math.max(1,self.page+(n==2 and -1 or 1));send("list",{page=self.page,contains=self.filterEntry:getText()})
 elseif n==4 then local row=self.list.items[self.list.selected];if row then send("plan",{id=row.item.id}) end
 elseif n==5 then send("plan",{all=true,contains=self.filterEntry:getText()})
 elseif n==6 or n==7 then local id=self.planEntry:getText();if id~="" then send(n==6 and "apply" or "rollback",{plan_id=id}) else self.message="Create a dry-run plan first, or paste its saved ID." end end
end
local function open()
 if active then active:removeFromUIManager() end
 active=Panel:new(80,80,760,480);active:initialise();active:addToUIManager();send("list",{page=1})
end
Events.OnFillWorldObjectContextMenu.Add(function(player,context,objects,test)
 if not test and ParadiseRestore.isAdm(getSpecificPlayer(player)) then context:addOption("Notes administration",nil,open) end
end)
Events.OnServerCommand.Add(function(module,command,args)
 if module~="ParadiseNotesAudit" or command~="result" then return end
 if args.ok==false and getPlayer() and HaloTextHelper then HaloTextHelper.addBadText(getPlayer(),tostring(args.message):sub(1,180)) end
 if not active then print("[ParadiseNotesAudit] "..tostring(args.message));return end
 active.message=args.message or "Response received";if args.plan_id then active.plan=args.plan_id;active.planEntry:setText(args.plan_id) end
 if args.rows then
  active.list:clear();local rows={};for _,r in pairs(args.rows) do rows[#rows+1]=r end;table.sort(rows,function(a,b)return a.id<b.id end)
  for _,r in ipairs(rows) do
   local s=r.original;local txt=s.text or s.ParadiseDevNote or s.FloorNote or ""
   active.list:addItem(r.id.." | "..tostring(txt):gsub("[\r\n]"," "):sub(1,85),r)
  end
 end
end)
