-- Server-authoritative notes. Requires notes-audit-test-r1.jar; fails closed without durable IO.
local N = ParadiseDev.Notes
local A = { seen = {}, last = setmetatable({}, {__mode="k"}), module = "ParadiseNotesAudit", maxRows = 1000 }
ParadiseNotesAudit = A
local fields = {
 ordinary = {"ParadiseDevNote", "ParadiseDevNoteColor", "ParadiseDevNoteOffset", "ParadiseDevNoteOwner", "ParadiseDevNoteAudit"},
 legacy = {"FloorNote", "FloorNoteColor", "FloorNoteOffset", "FloorNoteOwner", "FloorNoteAudit"}
}
local function io(op, a, b)
 if not ParadiseNotesIO then error("Note audit bridge is unavailable; change refused") end
 return ParadiseNotesIO(op, a, b)
end
local function clone(v, depth)
 depth = depth or 0
 if depth > 12 then error("Note value nesting exceeds limit") end
 if type(v) ~= "table" then return v end
 local out, count = {}, 0
 for k, x in pairs(v) do count = count + 1; if count > 100 then error("Note value is oversized") end; out[k] = clone(x, depth + 1) end
 return out
end
local function same(a, b) return io("equal", a or {}, b or {}) end
local function now() return getTimestampMs() end
local function reply(pl, data) if pl then sendServerCommand(pl, A.module, "result", data) end end
local function actor(pl)
 if not pl or not pl.getUsername then error("Authenticated player required") end
 return { username = tostring(pl:getUsername()), steamid = io("steam", pl), position = {x=pl:getX(),y=pl:getY(),z=pl:getZ()} }
end
local function coord(args)
 local out = {}
 for _, k in ipairs({"x","y","z"}) do
  local v = args[k]
  if type(v) ~= "number" or v ~= v or math.abs(v) > 10000000 or v ~= math.floor(v) then error("Invalid target tile") end
  out[k] = v
 end
 return out
end
local function key(t, kind) return kind .. ":" .. t.x .. ":" .. t.y .. ":" .. t.z end
local function globalNotes()
 local s = ModData.get(N.globalStore)
 return s and s.notes or {}
end
local function snapshot(t, kind)
 if kind == "global" then return clone(globalNotes()[N.globalKey(t)]) end
 if not fields[kind] then error("Unknown note type") end
 local flr = N.getFloor(t)
 if not flr then error("Target is not loaded; no world files were scanned or changed") end
 local md = flr:getModData(); local f = fields[kind]; local out = {}
 for _, k in ipairs(f) do out[k] = clone(md[k]) end
 return out
end
local function text(s, kind) if not s then return nil end; if kind == "global" then return s.text end; return s[fields[kind][1]] end
local function metadata(s,kind) if not s then return nil end; if kind=="global" then return s.audit end; return s[fields[kind][5]] end
local function ownership(s,kind) if not s then return nil end; if kind=="global" then return s.owner end; return s[fields[kind][4]] end
local function appearance(s,kind,part) if kind=="global" then return s[part] end; return s[fields[kind][part=="color" and 2 or 3]] end
local function removed(s,kind)
 if kind~="global" or not s then return nil end
 local out=clone(s)
 for _,k in ipairs({"x","y","z","text","color","offset","owner","audit"}) do out[k]=nil end
 for _ in pairs(out) do return out end
 return nil
end
local function put(t,kind,s)
 if kind == "global" then N.getGlobalStore().notes[N.globalKey(t)] = clone(s); return end
 local flr = N.getFloor(t); if not flr then error("Target unloaded") end
 local md = flr:getModData()
 for _, k in ipairs(fields[kind]) do md[k] = s and clone(s[k]) or nil end
end
local function sync(t,kind)
 if kind == "global" then ModData.transmit(N.globalStore) else local flr=N.getFloor(t); if flr then flr:transmitModData() end end
end
local function reject(pl,command,reason)
 local id=io("id");local ms=now()
 io("write",id..".rejected.json",{event_id=id,status="rejected",utc=io("utc",ms),epoch_ms=ms,action=command,actor=actor(pl),reason=reason})
 reply(pl,{ok=false,message=reason})
end
function A.rejectGeneric(pl,command)
 local reason="Global notes are protected. Use Notes administration or the note context menu."
 local ok,err=pcall(function() reject(pl,command,reason) end)
 if not ok then print("[ParadiseNotesAudit] REJECTION LOG FAILURE "..tostring(err));reply(pl,{ok=false,message=reason}) end
end
local function applied(pl,t,kind,before,after,action,origin,plan,eventId)
 if same(before,after) then return false end
 local id=eventId or io("id");local ms=now()
 local creator=metadata(after,kind) or metadata(before,kind)
 if not creator and text(before,kind) then creator={provenance="first_observed_existing",first_observed_ms=ms,recorded_owner=ownership(before,kind)} end
 local record={event_id=id,utc=io("utc",ms),epoch_ms=ms,action=action,origin=origin,actor=actor(pl),target=t,note_type=kind,
  before=before or {},after=after or {},creator=creator,plan_id=plan,status="prepared"}
 -- Write-ahead evidence is durable before mutation; applied is a separate durable outcome.
 io("write",id..".prepared.json",record)
 local ok,err=pcall(function()
  put(t,kind,after);record.status="applied";record.prepared_epoch_ms=ms
  record.epoch_ms=now();record.utc=io("utc",record.epoch_ms)
  io("write",id..".applied.json",record)
 end)
 if not ok then
  local restored,restoreError=pcall(function() put(t,kind,before) end)
  record.status=restored and "failed_restored" or "recovery_required";record.error=tostring(err);record.restore_error=tostring(restoreError)
  pcall(function() io("write",id..".failed.json",record) end)
  print("[ParadiseNotesAudit] CHANGE FAILURE "..id.." "..record.status)
  error("Audit/mutation failed; event "..id.." requires review")
 end
 A.seen[key(t,kind)]={target=t,kind=kind}
 local sent,sendError=pcall(function() sync(t,kind) end)
 if not sent then print("[ParadiseNotesAudit] SYNC FAILURE "..id.." "..tostring(sendError)) end
 return id
end
local function allowed(pl,before,kind)
 if not N.canWriteNotes(pl) then return false end
 if kind=="global" then return N.isAdmin(pl) end
 local owner=ownership(before,kind)
 return not owner or N.isAdmin(pl) or tostring(owner)==N.getUsername(pl)
end
local function bounded(v,lo,hi,default)
 if v==nil then return default end
 if type(v)~="number" or v~=v or v<lo or v>hi then error("Invalid color/offset") end
 return v
end
local function request(pl,args,kind)
 local t=coord(args);local before=snapshot(t,kind)
 if kind=="global" and not N.getFloor(t) then return reject(pl,"globalSet","Target is not loaded") end
 if not allowed(pl,before,kind) then return reject(pl,kind.."Set","Notes disabled or actor lacks permission") end
 if args.note~=nil and (type(args.note)~="string" or #args.note>1000) then return reject(pl,kind.."Set","Text exceeds limit") end
 local value=N.normalizeNote(args.note);local after=removed(before,kind)
 if value then
  local oldcolor=kind=="global" and before and before.color or before and before[fields[kind] and fields[kind][2]]
  local oldoffset=kind=="global" and before and before.offset or before and before[fields[kind] and fields[kind][3]]
  local c=args.color or oldcolor or (kind=="legacy" and {r=1,g=1,b=1} or {});local o=args.offset or oldoffset or {}
  if type(c)~="table" or type(o)~="table" then error("Invalid appearance") end
  c={r=bounded(c.r,0,1,1),g=bounded(c.g,0,1,0.85),b=bounded(c.b,0,1,0.2)}
  o={x=bounded(o.x,-0.49,0.49,0),y=bounded(o.y,-0.49,0.49,0)}
  local existing=text(before,kind);local owner=ownership(before,kind)
  local meta=clone(metadata(before,kind))
  if not meta then
   meta={first_observed_ms=now(),provenance=existing and "first_observed_existing" or "created"}
   if not existing then local a=actor(pl);meta.creator_username=a.username;meta.creator_steamid=a.steamid;meta.created_ms=now();owner=a.username
   elseif owner then meta.recorded_owner=tostring(owner) end
  end
  -- Never assign the first editor as creator of an existing ownerless note.
  if kind=="global" then after=clone(before or {});after.x=t.x;after.y=t.y;after.z=t.z;after.text=value;after.color=c;after.offset=o;after.owner=owner;after.audit=meta
  else after={};local f=fields[kind];after[f[1]]=value;after[f[2]]=c;after[f[3]]=o;after[f[4]]=owner;after[f[5]]=meta end
  -- Equal retries must not become edits merely because old notes gain metadata.
  if existing==value and same(oldcolor or N.normalizeColor(nil),c) and same(oldoffset or N.normalizeOffset(nil),o) then return end
 end
 local action=not value and "delete" or not text(before,kind) and "create" or "edit"
 if action=="edit" and text(before,kind)==value then
  local bc=appearance(before,kind,"color")
  local ac=appearance(after,kind,"color")
  local bo=appearance(before,kind,"offset")
  local ao=appearance(after,kind,"offset")
  action=not same(bc,ac) and (not same(bo,ao) and "recolor_reposition" or "recolor") or "reposition"
 end
 local id=applied(pl,t,kind,before,after,action,N.isAdmin(pl) and "admin" or "gameplay")
 reply(pl,{ok=true,event_id=id or "unchanged",message=id and action.." recorded" or "Unchanged"})
end
function A.observe(sq)
 local flr=sq and sq:getFloor();if not flr or not flr:hasModData() then return end
 local md=flr:getModData();local t={x=sq:getX(),y=sq:getY(),z=sq:getZ()}
 for kind,f in pairs(fields) do if md[f[1]]~=nil then A.seen[key(t,kind)]={target=t,kind=kind} end end
end
function A.inventory(filter)
 if filter~=nil and (type(filter)~="string" or #filter>200) then error("Invalid inventory filter") end
 local entries={};local found={}
 for k,r in pairs(A.seen) do
  local ok,s=pcall(function() return snapshot(r.target,r.kind) end)
  if ok and text(s,r.kind) then entries[#entries+1]={id=k,target=r.target,kind=r.kind,original=s,loaded=true};found[k]=true end
 end
 for _,s in pairs(globalNotes()) do
  if type(s)=="table" and s.text then local t=coord(s);entries[#entries+1]={id=key(t,"global"),target=t,kind="global",original=clone(s),loaded=N.getFloor(t)~=nil} end
 end
 table.sort(entries,function(a,b)return a.id<b.id end)
 if filter and filter~="" then
  local selected={};filter=string.lower(filter)
  for _,r in ipairs(entries) do if string.find(string.lower(r.id.." "..tostring(text(r.original,r.kind))),filter,1,true) then selected[#selected+1]=r end end
  entries=selected
 end
 return entries
end
local function plan(pl,args)
 local rows=A.inventory(args.contains);local selected={};local count=0
 for _,r in ipairs(rows) do if args.all==true or args.id==r.id then count=count+1;r.removal_event_id=io("id");selected[tostring(count)]=r end end
 if count==0 then error("No notes in scope") end
 if count>A.maxRows then error("Plan exceeds 1000 notes; filter scope and create smaller approved batches") end
 local id=io("id");local p={plan_id=id,created_ms=now(),actor=actor(pl),scope="observed currently loaded floor notes plus all persisted global notes; NOT entire saved world",filter=args.contains or "",count=count,rows=selected}
 io("write",id..".plan.json",p)
 reply(pl,{ok=true,message="DRY RUN: "..count.." notes. Owner approval required. Plan "..id,plan_id=id})
end
local function cleanup(pl,args,rollback)
 local id=args.plan_id;if type(id)~="string" or not id:match("^[%w%-]+$") or #id~=36 then error("Invalid plan ID") end
 local p=io("read",id..".plan.json");if not p or p.plan_id~=id then error("Missing plan") end
 local approval=io("read",id..(rollback and ".rollback-approval.json" or ".approval.json"))
 if not approval or approval.plan_id~=id or approval.approved~=true then error("Separate owner approval file required") end
 if approval.plan_sha256~=io("sha256",id..".plan.json") then error("Approved manifest hash does not match") end
 local phase=rollback and "rollback" or "cleanup"
 -- Preflight the full manifest before the first mutation; later IO failures can still leave a partial plan.
 for _,r in pairs(p.rows) do
  local current=snapshot(r.target,r.kind);local receipt=io("read",r.removal_event_id..".applied.json")
  if rollback then
   if receipt and not same(current,receipt.after) and not same(current,r.original) then error("Rollback conflict at "..r.id) end
  elseif receipt then
   if not same(current,receipt.after) then error("Cleanup replay conflict at "..r.id) end
  elseif not same(current,r.original) then error("Cleanup conflict at "..r.id) end
 end
 for index,r in pairs(p.rows) do
  local current=snapshot(r.target,r.kind)
  -- The plan preassigns the deletion event ID: no crash window between deletion and receipt.
  local receipt=io("read",r.removal_event_id..".applied.json")
  if rollback then
   if receipt then
    if same(current,receipt.after) then applied(pl,r.target,r.kind,current,r.original,"restore","cleanup",id)
    elseif not same(current,r.original) then error("Rollback conflict at "..r.id) end
   end
  elseif receipt then
   if not same(current,receipt.after) then error("Note changed after cleanup; create a new plan") end
  elseif same(current,r.original) then
   if io("read",r.removal_event_id..".prepared.json") then error("Interrupted deletion requires journal review: "..r.removal_event_id) end
   applied(pl,r.target,r.kind,current,removed(current,r.kind),"delete","cleanup",id,r.removal_event_id)
  else error("Cleanup conflict at "..r.id) end
 end
 reply(pl,{ok=true,message=phase.." finished; individual durable events reference "..id})
end
function A.command(module,command,pl,args)
 if module~=N.module and module~=A.module then return end
 args=type(args)=="table" and args or {}
 local ok,err=pcall(function()
  actor(pl)
  local who=pl;local stamp=now()
  if A.last[who] and stamp-A.last[who]<100 then reply(pl,{ok=false,message="Rate limited; no change applied"});return end
  A.last[who]=stamp
  if module==N.module then
   if command=="set" then return request(pl,args,"ordinary") end
   if command=="globalSet" then return request(pl,args,"global") end
   if command=="legacySet" then return request(pl,args,"legacy") end
   if command=="setFontSize" then
    if not N.canWriteNotes(pl) or not N.isFontSize(args.size) then return reject(pl,command,"Notes disabled or invalid font") end
    local store=N.getGlobalStore();local old=store.fontSize;if old==args.size then return end
    local id=io("id");local ms=now();local rec={event_id=id,epoch_ms=ms,utc=io("utc",ms),actor=actor(pl),action="font_size",note_type="global_display_setting",origin=N.isAdmin(pl) and "admin" or "gameplay",before={size=old},after={size=args.size},status="prepared"}
    io("write",id..".prepared.json",rec);store.fontSize=args.size;rec.status="applied"
    local saved,why=pcall(function()io("write",id..".applied.json",rec)end)
    if not saved then store.fontSize=old;error(why) end
    ModData.transmit(N.globalStore);return
   end
   return
  end
  if not N.isAdmin(pl) then return reject(pl,command,"Administrator permission required") end
  if command=="list" or command=="export" then
   local rows=A.inventory(args.contains);local id
   if command=="export" then
    if #rows>A.maxRows then error("Export exceeds 1000 notes; narrow the filter. Paging remains available.") end
    id=io("id");io("write",id..".inventory.json",{export_id=id,epoch_ms=now(),filter=args.contains or "",scope="Loaded observed ordinary/legacy notes + all global notes; not entire saved world",rows=rows})
   end
   local page=math.max(1,math.floor(tonumber(args.page) or 1));local result={}
   for i=(page-1)*25+1,math.min(page*25,#rows) do result[tostring(i)]=rows[i] end
   reply(pl,{ok=true,rows=result,page=page,total=#rows,export_id=id,message="Loaded observed floors + all globals. "..(id and "Export "..id or "Read-only inventory")})
  elseif command=="plan" then plan(pl,args)
  elseif command=="apply" then cleanup(pl,args,false)
  elseif command=="rollback" then cleanup(pl,args,true) end
 end)
 if not ok then print("[ParadiseNotesAudit] REQUEST FAILURE "..tostring(err));pcall(function()reject(pl,command,tostring(err))end);reply(pl,{ok=false,message=tostring(err)}) end
end
N.onClientCommand=A.command
-- Internal legacy helpers cannot silently bypass the audited command path.
N.setNote=function() error("Use authenticated ParadiseDevNotes command") end
N.setFontSize=function() error("Use authenticated ParadiseDevNotes command") end
N.setGlobal=function() error("Use authenticated ParadiseDevNotes command") end
Events.LoadGridsquare.Add(A.observe)
