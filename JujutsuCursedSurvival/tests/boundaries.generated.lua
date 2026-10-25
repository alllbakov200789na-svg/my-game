local U=require("../src/Shared/Utility")
local Config=require("../src/Shared/Config")
local A=require("../src/Shared/AbilityDefinitions")
local warnings={}; local warn=function(...) table.insert(warnings,{...}) end
local workspace={GetServerTimeNow=function() return os.clock() end}
local task={wait=function() end,spawn=function() end,delay=function() end}
local game={GetService=function(_,name) return {} end}
local Vector3={}
local mt={}
function Vector3.new(x,y,z)
 local v=setmetatable({X=x,Y=y,Z=z},mt); v.Magnitude=math.sqrt(x*x+y*y+z*z); return v
end
function mt.__index(v,k) if k=="Unit" then return Vector3.new(v.X/v.Magnitude,v.Y/v.Magnitude,v.Z/v.Magnitude) end end
function mt.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
local CFrame={lookAt=function() return {} end}
local count=0
local function check(name,fn) local ok,err=pcall(fn); if not ok then error("FAIL "..name..": "..tostring(err)) end; count=count+1; print("PASS "..name) end
local function equal(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local Data=(function()
local DS=game:GetService("DataStoreService")
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local S={}
local function fresh()
 return {SchemaVersion=1,Coins=0,Level=1,XP=0,TotalWins=0,TotalMatches=0,Eliminations=0,SorcererWins=0,CurseWins=0,
 OwnedCosmetics={},EquippedCosmetics="",DailyRewardTimestamp=0,QuestProgress={},RolePity=0,
 ProcessedPurchaseReceipts={},Loadouts={},Settings={},Entitlements={}}
end
function S:Init(ctx)
 self.C=ctx; self.Profiles={}; self.Session=game.JobId~="" and game.JobId or Http:GenerateGUID(false)
 self.Memory=Run:IsStudio(); if not self.Memory then self.Store=DS:GetDataStore(ctx.Config.DataStoreName) end
 task.spawn(function() while not self.Closing do task.wait(ctx.Config.AutosaveSeconds)
  for p in pairs(self.Profiles) do task.spawn(function() self:Save(p,false) end) end
 end end)
end
function S:Load(p)
 local profile={Data=fresh(),Busy=false,Valid=true,Persistent=not self.Memory}
 if not self.Memory then
  local ok,result
  for attempt=1,4 do
   ok,result=pcall(function() return self.Store:UpdateAsync("u_"..p.UserId,function(old)
    old=old or {Data=fresh()}
    if old.Lease and old.Lease.Session~=self.Session and old.Lease.Expires>os.time() then return nil end
    old.Lease={Session=self.Session,Expires=os.time()+self.C.Config.LeaseSeconds}; return old
   end) end)
   if ok and result then break end; task.wait(attempt*1.5)
  end
  if not ok or not result then p:Kick("Данные временно недоступны или открыты на другом сервере. Повторите вход позже."); return false end
  for k,v in pairs(fresh()) do if result.Data[k]==nil then result.Data[k]=v end end
  profile.Data=result.Data
 end
 self.Profiles[p]=profile
 p:SetAttribute("DataMode",self.Memory and "STUDIO · прогресс не сохраняется" or "Облачное сохранение")
 return true
end
function S:Get(p) local f=self.Profiles[p]; return f and f.Valid and f.Data end
function S:Acquire(p)
 local f=self.Profiles[p]; if not f then return end
 local deadline=os.clock()+20
 while f.Busy and f.Valid and os.clock()<deadline do task.wait(0.05) end
 if not f.Valid or f.Busy then return end; f.Busy=true; return f
end
function S:Mutate(p,fn)
 local f=self:Acquire(p); if not f then return false end
 local ok,result=pcall(fn,f.Data); f.Busy=false
 if not ok then warn("Profile mutation:",result); return false end
 return true,result
end
function S:Persist(p,f,data,release)
 local ok,result
 for attempt=1,3 do
  ok,result=pcall(function() return self.Store:UpdateAsync("u_"..p.UserId,function(old)
   if not old or not old.Lease or old.Lease.Session~=self.Session then return nil end
   return {Data=data,Lease=not release and {Session=self.Session,Expires=os.time()+self.C.Config.LeaseSeconds} or nil}
  end) end)
  if ok and result then return true end
  task.wait(attempt)
 end
 -- Fail closed. Never overwrite an uncertain purchase with an older in-memory snapshot.
 f.Valid=false; warn("Profile persistence failed",p.UserId,tostring(result))
 if p.Parent then p:Kick("Сохранение временно недоступно. Сессия закрыта для защиты данных; войдите позже.") end
 return false
end
function S:Save(p,release)
 local f=self:Acquire(p); if not f then if release then self.Profiles[p]=nil end; return false end
 local ok=true
 if f.Persistent then ok=self:Persist(p,f,self.C.U.copy(f.Data),release) end
 f.Busy=false
 if release then f.Valid=false; self.Profiles[p]=nil end
 return ok
end
function S:Receipt(p,purchaseId,product)
 local f=self:Acquire(p); if not f or not f.Persistent then if f then f.Busy=false end; return false end
 if f.Data.ProcessedPurchaseReceipts[purchaseId] then f.Busy=false; return true end
 local nextData=self.C.U.copy(f.Data)
 nextData.Coins=nextData.Coins+(product.Coins or 0)
 for _,id in ipairs(product.Cosmetics or {}) do nextData.OwnedCosmetics[id]=true end
 nextData.ProcessedPurchaseReceipts[purchaseId]=os.time()
 local ok=self:Persist(p,f,nextData,false)
 if ok then f.Data=nextData end
 f.Busy=false; return ok
end
function S:Public(p)
 local d=self:Get(p); if not d then return nil end
 local out={}
 for _,k in ipairs({"Coins","Level","XP","TotalWins","TotalMatches","Eliminations","SorcererWins","CurseWins","OwnedCosmetics","EquippedCosmetics","DailyRewardTimestamp","QuestProgress","Loadouts","Settings","Entitlements"}) do out[k]=self.C.U.copy(d[k]) end
 return out
end
return S

end)()
local Guard=(function()
local VerticalMotion=require("../src/Server/Services/VerticalMotion")
local S={}
function S:Init(ctx) self.C=ctx; self.Buckets={}; self.Log={}; self.Motion={}; self.Audit={} end
function S:Flag(p,reason)
 local now=os.clock(); local key=p.UserId..":"..reason
 if self.Log[key] and now-self.Log[key]<10 then return end
 self.Log[key]=now; warn("[Guard]",p.UserId,reason)
 if #self.Audit>=100 then table.remove(self.Audit,1) end
 table.insert(self.Audit,{User=p.UserId,Reason=reason,Time=os.time()})
end
function S:Allow(p,channel,rate,burst)
 self.Audit=self.Audit or {}
 local key=p.UserId..":"..channel; local now=os.clock(); local b=self.Buckets[key] or {At=now,Tokens=burst}
 b.Tokens=math.min(burst,b.Tokens+(now-b.At)*rate); b.At=now; self.Buckets[key]=b
 if b.Tokens<1 then self:Flag(p,"rate:"..channel); return false end
 b.Tokens=b.Tokens-1; return true
end
function S:JumpSpeed(a)
 local h=self.C.U.humanoid(a.Model)
 if not h then return 50 end
 return h.UseJumpPower and h.JumpPower or math.sqrt(2*math.max(0,workspace.Gravity)*h.JumpHeight)
end
function S:Grounded(a,root)
 local h=self.C.U.humanoid(a.Model); if not h then return false end
 local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude
 rp.FilterDescendantsInstances={a.Model,workspace.GameplayEffects}; rp.RespectCanCollide=true
 rp.CollisionGroup=root.CollisionGroup
 local down=Vector3.new(0,-(h.HipHeight+root.Size.Y/2+1),0)
 local x=root.Size.X/2; local z=root.Size.Z/2
 -- Footprint probes also recognize a character standing at the edge of a ledge.
 for _,offset in ipairs({Vector3.zero,Vector3.new(x,0,z),Vector3.new(-x,0,z),Vector3.new(x,0,-z),Vector3.new(-x,0,-z)}) do
  local hit=workspace:Raycast(root.Position+offset,down,rp)
  -- Current maps have static ground. Client-owned debris/characters cannot certify a landing.
  if hit and (hit.Instance:IsA("Terrain") or hit.Instance.Anchored) then return true end
 end
 return false
end
-- Call only with a position computed by server gameplay code, immediately after teleport/spawn.
function S:ResetMotion(a,pos)
 if not a.Player then return end
 local now=os.clock()
 self.Motion[a.Player]={Model=a.Model,Pos=pos,SafePos=pos,At=now,
  Vertical=VerticalMotion.new(pos.Y,now,self:JumpSpeed(a))}
end
-- Authorize the exact server-written impulse, not the client's AssemblyLinearVelocity.
function S:AuthorizeImpulse(a,velocity,duration)
 if not a.Player then return end
 local old=self.Motion[a.Player]; if not old or old.Model~=a.Model then return end
 local now=os.clock()
 old.Vertical=VerticalMotion.new(old.Pos.Y,now,self:JumpSpeed(a),velocity.Y)
 old.ImpulseUntil=now+duration
 old.ImpulseSpeed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
end
function S:Step(a,_dt)
 if not a.Player or not a.Alive then return end
 local root=self.C.U.root(a.Model); if not root then return end
 local now=os.clock(); local pos=root.Position
 if not self.C.U.vector(pos) then a.Alive=false; a.Model:Destroy(); return end
 local old=self.Motion[a.Player]
 if not old or old.Model~=a.Model then self:ResetMotion(a,pos); return end
 local dt=math.max(0,now-old.At)
 local grounded=self:Grounded(a,root)
 local delta=Vector3.new(pos.X-old.Pos.X,0,pos.Z-old.Pos.Z).Magnitude
 local verticalOK,nextVertical=VerticalMotion.check(old.Vertical,pos.Y,now,grounded,
  self:JumpSpeed(a),workspace.Gravity,a.Definition.SprintSpeed*2,delta)
 do
  local speed=a.Definition.SprintSpeed+12
  if now<(old.ImpulseUntil or 0) then speed=math.max(speed,old.ImpulseSpeed) end
  if delta>math.max(18,speed*dt*2.5) then
   root.CFrame=CFrame.new(old.SafePos); root.AssemblyLinearVelocity=Vector3.zero
   self:ResetMotion(a,old.SafePos)
   self:Flag(a.Player,"movement"); return
  end
 end
 if not verticalOK then
  old.SuspectAt=old.SuspectAt or now; old.SuspectCount=(old.SuspectCount or 0)+1
  -- Freeze the accepted baseline; a suspect position must not become the next allowance.
  if old.SuspectCount>=3 and now-old.SuspectAt>=0.5 then
   root.CFrame=CFrame.new(old.SafePos); root.AssemblyLinearVelocity=Vector3.zero
   self:ResetMotion(a,old.SafePos); self:Flag(a.Player,"vertical movement")
  end
  return
 end
 old.Pos=pos; old.At=now; old.Vertical=nextVertical
 old.SuspectAt=nil; old.SuspectCount=nil
 if grounded then old.SafePos=pos end
end
function S:Remove(p)
 self.Motion[p]=nil
 for k in pairs(self.Buckets) do if string.sub(k,1,#tostring(p.UserId)+1)==p.UserId..":" then self.Buckets[k]=nil end end
 for k in pairs(self.Log) do if string.sub(k,1,#tostring(p.UserId)+1)==p.UserId..":" then self.Log[k]=nil end end
end
return S

end)()
local Ability=(function()
local S={}
function S:Init(ctx) self.C=ctx; self.Tasks={} end
function S:Valid(a,token) return a.Alive and a.Model.Parent and self.C.RoundService.Token==token and self.C.RoundService:IsCombat() end
function S:Cast(p,id,direction)
 local C=self.C
 if type(id)~="string" or #id>32 or not C.AntiExploitService:Allow(p,"Cast",7,10) then return end
 local a=C.CharacterService.ByPlayer[p]; local def=C.Abilities[id]
 if not a or not a.Participant or not a.Alive or not C.RoundService:IsCombat() or not def then return end
 if id~="Basic" and id~="Heavy" and id~=a.Definition.UltimateAbility and not table.find(a.Abilities,id) then C.AntiExploitService:Flag(p,"ability ownership"); return end
 if not C.U.vector(direction) or direction.Magnitude<0.5 or direction.Magnitude>1.5 then C.AntiExploitService:Flag(p,"invalid aim"); return end
 direction=direction.Unit
 local root=C.U.root(a.Model); if not root then return end
 local now=os.clock()
 if now<a.StunUntil or now<(a.CastUntil or 0) or now<(a.Cooldowns[id] or 0) or a.Energy<def.Cost then return end
 local ultimate=id==a.Definition.UltimateAbility
 if ultimate and a.Ultimate<100 then return end
 -- Reserve resources synchronously, before creating any deferred effect.
 a.Cooldowns[id]=now+def.Cooldown; a.CastUntil=now+math.min(def.Duration,0.45); a.Energy=a.Energy-def.Cost
 if ultimate then a.Ultimate=0 end
 if not a.UsedAbilities[id] then a.UsedAbilities[id]=true; C.QuestService:Progress(p,"Abilities",1) end
 local token=C.RoundService.Token; local origin=root.Position
 local facing=Vector3.new(direction.X,0,direction.Z)
 if facing.Magnitude>0.05 then root.CFrame=CFrame.lookAt(origin,origin+facing.Unit) end
 C.Remotes.Effect:FireAllClients("Cast",origin,def.Color,def.Radius,a.Model,id)
 local function area(center,damage,radius,knock,stun)
  if not self:Valid(a,token) then return end
  C.CombatService:Area(a,center,radius or def.Radius,damage,knock,stun)
 end
 if def.Kind=="Melee" then
  local power=id=="Basic" and a.Definition.AttackPower or def.Damage
  for _,b in ipairs(C.CombatService:Targets(a,def.Range)) do
   local br=C.U.root(b.Model); local v=br.Position-origin
   if v.Magnitude>0 and v.Unit:Dot(direction)>0.25 and C.CombatService:Visible(origin,b,{a.Model}) then C.DamageService:Apply(a,b,power,origin,id=="Heavy" and 45 or 15) end
  end
  C.DestructionService:Blast(origin+direction*5,7,power)
 elseif def.Kind=="Projectile" then
  task.spawn(function()
   local position=origin+direction*3; local traveled=0; local speed=115; local step=0.05
   while self:Valid(a,token) and traveled<def.Range do
    local segment=direction*math.min(speed*step,def.Range-traveled)
    local hit=C.CombatService:Ray(position,segment,{a.Model,workspace.GameplayEffects})
    local nextPos=hit and hit.Position or position+segment
    C.Remotes.Effect:FireAllClients("Projectile",nextPos,def.Color,def.Radius,nil,id,position)
    if hit then
     local impact=nextPos-direction*0.35
     area(impact,def.Damage,nil,25,id=="IceSpear" and 1.2 or nil)
     C.DestructionService:Blast(impact,def.Radius,def.Damage); break
    end
    position=nextPos; traveled=traveled+segment.Magnitude; task.wait(step)
   end
  end)
 elseif def.Kind=="Push" or def.Kind=="Pull" or def.Kind=="Stun" then
  local hit=C.CombatService:Ray(origin,direction*def.Range,{a.Model})
  local center=hit and hit.Position-direction*0.5 or origin+direction*math.min(def.Range,20)
  area(center,def.Damage,def.Radius,def.Kind=="Push" and 65 or nil,def.Kind=="Stun" and def.Duration or nil)
  if def.Kind=="Pull" then
   for _,b in ipairs(C.CombatService:Targets(a,def.Range+def.Radius)) do
    local br=C.U.root(b.Model); local delta=center-br.Position
    if delta.Magnitude<def.Radius and delta.Magnitude>1 and C.CombatService:Visible(center,b,{a.Model}) then
     local velocity=delta.Unit*48; C.AntiExploitService:AuthorizeImpulse(b,velocity,1)
     br.AssemblyLinearVelocity=velocity
    end
   end
  end
  C.Remotes.Effect:FireAllClients("Burst",center,def.Color,def.Radius)
  C.DestructionService:Blast(center,def.Radius,def.Damage)
 elseif def.Kind=="Shield" then
  a.ShieldUntil=now+def.Duration; a.Model:SetAttribute("ShieldUntil",workspace:GetServerTimeNow()+def.Duration)
 elseif def.Kind=="HealSelf" then C.DamageService:Heal(a,a,def.Damage)
 elseif def.Kind=="Heal" then
  for _,b in pairs(C.CharacterService.Actors) do
   local br=C.U.root(b.Model)
   if br and (br.Position-origin).Magnitude<=def.Range and C.CombatService:Visible(origin,b,{a.Model}) then C.DamageService:Heal(a,b,def.Damage) end
  end
 elseif def.Kind=="Teleport" or def.Kind=="Dash" then
  local flat=Vector3.new(direction.X,0,direction.Z); if flat.Magnitude<0.1 then return end; flat=flat.Unit
  -- Blockcast checks character width; ground and arena bounds are independently validated.
  local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances={a.Model,workspace.GameplayEffects}
  local hit=workspace:Blockcast(root.CFrame,Vector3.new(3,4,3),flat*def.Range,rp)
  local length=hit and math.max(0,hit.Distance-2) or def.Range
  local pos=origin+flat*length; local ground=C.CombatService:Ray(pos+Vector3.new(0,3,0),Vector3.new(0,-16,0),{a.Model})
  if ground and math.abs(pos.X)<C.Config.ArenaRadius and math.abs(pos.Z)<C.Config.ArenaRadius then
   pos=Vector3.new(pos.X,ground.Position.Y+3.2,pos.Z)
   root.CFrame=CFrame.lookAt(pos,pos+flat); root.AssemblyLinearVelocity=Vector3.zero
   C.AntiExploitService:ResetMotion(a,pos)
   if def.Kind=="Dash" then area(pos,def.Damage,nil,35) end
  end
 elseif def.Kind=="Domain" then
  C.Remotes.Effect:FireAllClients("Domain",origin,def.Color,def.Radius,a.Model,id)
  task.spawn(function()
   for _=1,math.floor(def.Duration) do
    if not self:Valid(a,token) then break end
    area(origin,def.Damage,nil,nil,id=="UnlimitedVoid" and 0.65 or nil)
    C.DestructionService:Blast(origin,def.Radius,20); task.wait(1)
   end
  end)
 elseif def.Kind=="Trap" then
  local hit=C.CombatService:Ray(origin,direction*def.Range,{a.Model})
  local center=hit and hit.Position-direction or origin+direction*def.Range
  local ground=C.CombatService:Ray(center+Vector3.new(0,6,0),Vector3.new(0,-30,0),{a.Model})
  if ground then center=ground.Position+Vector3.new(0,0.3,0) end
  C.Remotes.Effect:FireAllClients("Trap",center,def.Color,def.Radius,nil,id,def.Duration)
  task.spawn(function()
   local finish=os.clock()+def.Duration
   while self:Valid(a,token) and os.clock()<finish do
    if C.CombatService:Area(a,center+Vector3.new(0,2,0),def.Radius,def.Damage,0,2)>0 then break end
    task.wait(0.25)
   end
  end)
 elseif def.Kind=="Summon" then C.NPCService:Summon(a,def,token) end
end
return S

end)()
local Round=(function()
local Players=game:GetService("Players")
local S={}
local nextStates={
 WaitingForPlayers={Intermission=true},Intermission={VotingOrSelection=true,WaitingForPlayers=true},
 VotingOrSelection={Loading=true,WaitingForPlayers=true},Loading={Intro=true,Cleanup=true},Intro={InProgress=true,Cleanup=true},
 InProgress={SuddenDeath=true,Results=true,Cleanup=true},SuddenDeath={Results=true,Cleanup=true},
 Results={Cleanup=true},Cleanup={WaitingForPlayers=true},
}
function S:Init(ctx)
 self.C=ctx; self.State="WaitingForPlayers"; self.Token=0; self.RoundId=0; self.PlayerCount=0; self.Deadline=0; self.TeamWins={Sorcerers=0,Curses=0}
end
function S:IsCombat() return self.State=="InProgress" or self.State=="SuddenDeath" end
function S:Transition(state,seconds)
 if state==self.State then return false end
 assert(nextStates[self.State] and nextStates[self.State][state],"Illegal transition "..self.State.." -> "..state)
 self.State=state; self.Deadline=workspace:GetServerTimeNow()+(seconds or 0); self:Broadcast(); return true
end
function S:EligiblePlayers()
 local list={}; for _,p in ipairs(Players:GetPlayers()) do if self.C.PlayerDataService:Get(p) and p:GetAttribute("Ready") then table.insert(list,p) end end
 return list
end
function S:Broadcast()
 local C=self.C; local alive=0
 for _,a in pairs(C.CharacterService.Actors) do if a.Player and a.Alive and a.Participant then alive=alive+1 end end
 local mode=self.Mode and C.Modes[self.Mode]
 C.Remotes.State:FireAllClients({State=self.State,Deadline=self.Deadline,Mode=mode and mode.Name or "CURSED SURVIVAL",
 ModeId=self.Mode,Objective=mode and mode.Objective or "Ожидание игроков. Один игрок запускает тренировку с NPC.",
 Map=self.MapName,Seals=C.MapService.Seals,Alive=alive,Wave=C.NPCService.Wave,NPCs=C.NPCService:Count(),
 RoundId=self.RoundId,TeamWins=self.TeamWins,Revealed=self.Revealed,Training=self.PlayerCount==1})
end
function S:Countdown(seconds,abortEmpty)
 local untilTime=os.clock()+seconds
 while os.clock()<untilTime and not self.Closing do
  if abortEmpty and #self:EligiblePlayers()==0 then return false end
  self:Broadcast(); task.wait(math.min(0.5,math.max(0,untilTime-os.clock())))
 end
 return not self.Closing
end
function S:RevealCarrier()
 local C=self.C; local a=self.Carrier and C.CharacterService.ByPlayer[self.Carrier]
 if not a or not a.Alive or not self.Carrier.Parent then
  local candidates={}; for p,b in pairs(C.CharacterService.ByPlayer) do if b.Participant and b.Alive and p.Parent then table.insert(candidates,p) end end
  if #candidates<2 then self.ForcedResult={"Sorcerers","Носитель исчез; оставшиеся маги спасены"}; return end
  self.Carrier=candidates[C.Rng:NextInteger(1,#candidates)]
 end
 if C.CharacterService:Transform(self.Carrier) then
  self.Revealed=true
  local b=C.CharacterService.ByPlayer[self.Carrier]
  C.Remotes.Role:FireClient(self.Carrier,{Name=b.Definition.DisplayName,Role=b.Role,Team=b.Team,Abilities=b.Abilities,Ultimate=b.Definition.UltimateAbility})
  C.Remotes.Effect:FireAllClients("Scare",C.U.root(b.Model).Position,{255,60,90},20,b.Model)
 end
end
function S:RunOne()
 local C=self.C
 while #self:EligiblePlayers()==0 and not self.Closing do self:Broadcast(); task.wait(1) end
 if self.Closing then return end
 self:Transition("Intermission",C.Config.Intermission)
 if not self:Countdown(C.Config.Intermission,true) then self:Transition("WaitingForPlayers"); return end
 self:Transition("VotingOrSelection",C.Config.SelectionSeconds)
 if not self:Countdown(C.Config.SelectionSeconds,true) then self:Transition("WaitingForPlayers"); return end
 local players=self:EligiblePlayers(); if #players==0 then self:Transition("WaitingForPlayers"); return end
 self.PlayerCount=#players; local modes=C.ModeService:Eligible(#players); self.Mode=modes[C.Rng:NextInteger(1,#modes)]
 local map=C.Maps[C.Rng:NextInteger(1,#C.Maps)]; self.MapName=map.Name
 self.Token=self.Token+1; self.RoundId=self.RoundId+1; self.Revealed=false; self.ForcedResult=nil
 self:Transition("Loading",0); C.MapService:Load(map.Id,self.Mode)
 local roles,carrier=C.RoleService:Assign(players,self.Mode,C.Rng); self.Carrier=carrier
 -- Solo practice uses a durable hero and reduced rewards.
 if #players==1 then roles[players[1]]={Role="Gojo",Team="Sorcerers",Abilities=table.clone(C.Characters.Gojo.AbilitySet)} end
 local index=0
 for _,p in ipairs(players) do
  if p.Parent then
   index=index+1; local r=roles[p]; local cf=C.MapService:Spawn(index,r.Team)
   -- Pathfinding yields; the player can leave while a safe point is being selected.
   if not p.Parent then continue end
   local a=C.CharacterService:Spawn(p,r.Role,r.Team,r.Abilities,cf,true)
   C.Remotes.Role:FireClient(p,{Name=a.Definition.DisplayName,Role=a.Role,Team=a.Team,Abilities=a.Abilities,Ultimate=a.Definition.UltimateAbility})
  end
 end
 self:Transition("Intro",C.Config.IntroSeconds); self:Countdown(C.Config.IntroSeconds)
 self.StartedAt=os.clock(); self:Transition("InProgress",C.Config.RoundSeconds)
 local winner,reason
 while not winner and not self.Closing do
  if self.Mode=="Betrayal" and not self.Revealed and os.clock()-self.StartedAt>=60 then self:RevealCarrier() end
  if self.ForcedResult then winner,reason=table.unpack(self.ForcedResult)
  else
   local expired=workspace:GetServerTimeNow()>=self.Deadline
   winner,reason=C.ModeService.Decide(self.Mode,C.ModeService:Snapshot(),expired)
   if winner=="Draw" and expired and self.State=="InProgress" and self.Mode=="Clash" then
    winner=nil; self:Transition("SuddenDeath",C.Config.SuddenDeathSeconds)
   end
  end
  self:Broadcast(); if not winner then task.wait(0.5) end
 end
 if self.Closing then return end
 self:Transition("Results",C.Config.ResultsSeconds); self.Token=self.Token+1
 if self.TeamWins[winner] then self.TeamWins[winner]=self.TeamWins[winner]+1 end
 C.RewardService:Award(self.RoundId,winner,reason); self:Countdown(C.Config.ResultsSeconds)
 self:Cleanup()
end
function S:Cleanup()
 if self.State~="Cleanup" then self:Transition("Cleanup") end
 self.Token=self.Token+1; self.C.NPCService:Cleanup()
 for _,p in ipairs(Players:GetPlayers()) do if self.C.PlayerDataService:Get(p) then self.C.CharacterService:Lobby(p) end end
 self.C.MapService:Cleanup(); workspace.GameplayEffects:ClearAllChildren()
 self.Mode=nil; self.MapName=nil; self.Carrier=nil; self.PlayerCount=0; self:Transition("WaitingForPlayers")
end
function S:Start()
 task.spawn(function()
  while not self.Closing do
   local ok,err=xpcall(function() self:RunOne() end,debug.traceback)
   if not ok then
    warn("Round recovery",err)
    self.Token=self.Token+1; self.State="Cleanup"; self.C.NPCService:Cleanup(); self.C.MapService:Cleanup()
    for _,p in ipairs(Players:GetPlayers()) do if self.C.PlayerDataService:Get(p) then pcall(function() self.C.CharacterService:Lobby(p) end) end end
    self.State="WaitingForPlayers"; self.Mode=nil; self.MapName=nil; task.wait(3)
   end
  end
 end)
end
return S

end)()

check("T14 receipt atomicity and duplicate delivery",function()
 local p={UserId=1,Parent=true,Kick=function(self,msg) self.Kicked=msg end}
 local initial={Coins=20,OwnedCosmetics={},ProcessedPurchaseReceipts={}}
 local stored={Data=U.copy(initial),Lease={Session="server-a",Expires=os.time()+180}}
 local writes=0
 Data.C={U=U,Config=Config}; Data.Session="server-a"; Data.Profiles={[p]={Data=initial,Valid=true,Persistent=true,Busy=false}}
 Data.Store={UpdateAsync=function(_,_,fn) local value=fn(U.copy(stored)); if value then stored=value; writes=writes+1 end; return value end}
 assert(Data:Receipt(p,"receipt-1",{Coins=500,Cosmetics={"Azure"}})); equal(stored.Data.Coins,520); assert(stored.Data.OwnedCosmetics.Azure)
 equal(Data:Get(p).Coins,520); assert(Data:Receipt(p,"receipt-1",{Coins=500})); equal(writes,1); equal(stored.Data.Coins,520)
 Data.Profiles[p]={Data=U.copy(stored.Data),Valid=true,Persistent=true,Busy=false}
 assert(Data:Receipt(p,"receipt-1",{Coins=500})); equal(Data:Get(p).Coins,520); equal(writes,1)
end)
check("T14 ambiguous commit retry never grants twice",function()
 local p={UserId=2,Parent=true,Kick=function() end}; local initial={Coins=0,OwnedCosmetics={},ProcessedPurchaseReceipts={}}
 local stored={Data=U.copy(initial),Lease={Session="server-a",Expires=os.time()+180}}; local first=true
 Data.Profiles={[p]={Data=initial,Valid=true,Persistent=true,Busy=false}}
 Data.Store={UpdateAsync=function(_,_,fn) local v=fn(U.copy(stored)); if v then stored=v end; if first then first=false; error("response lost AFTER commit") end; return v end}
 assert(Data:Receipt(p,"r-ambiguous",{Coins=500})); equal(stored.Data.Coins,500); equal(Data:Get(p).Coins,500)
end)
check("DataStore failure closes profile and prevents stale save",function()
 local p={UserId=3,Parent=true,Kick=function(self) self.Kicked=true end}
 local f={Data={Coins=10,OwnedCosmetics={},ProcessedPurchaseReceipts={}},Valid=true,Persistent=true,Busy=false}; Data.Profiles={[p]=f}
 local requests=0; Data.Store={UpdateAsync=function() requests=requests+1; error("outage") end}
 assert(not Data:Receipt(p,"r-fail",{Coins=500})); equal(requests,3); assert(p.Kicked); assert(not f.Valid); equal(f.Data.Coins,10)
 assert(not Data:Save(p,false)); equal(requests,3)
end)
check("Foreign session cannot be overwritten",function()
 local p={UserId=4,Parent=true,Kick=function() end}; local stored={Data={Coins=999},Lease={Session="other",Expires=os.time()+180}}
 Data.Profiles={[p]={Data={Coins=1},Valid=true,Persistent=true,Busy=false}}
 Data.Store={UpdateAsync=function(_,_,fn) local v=fn(U.copy(stored)); if v then stored=v end; return v end}
 assert(not Data:Save(p,false)); equal(stored.Data.Coins,999)
end)
check("Studio rejects real purchase receipts",function()
 local p={UserId=5};Data.Profiles={[p]={Data={Coins=0},Valid=true,Persistent=false,Busy=false}}
 assert(not Data:Receipt(p,"studio",{Coins=500}));equal(Data:Get(p).Coins,0)
end)
check("Remote token bucket limits bursts",function()
 Guard:Init({}); local p={UserId=6}
 for _=1,10 do assert(Guard:Allow(p,"Cast",0,10)) end
 for _=1,100 do assert(not Guard:Allow(p,"Cast",0,10)) end
 equal(#Guard.Audit,1); Guard:Remove(p); equal(next(Guard.Buckets),nil)
end)
check("T07 cooldown, role ownership, spectator and finite direction checks",function()
 local p={UserId=7};local healed=0;local events=0
 local root={Position=Vector3.new(0,3,0)}
 local actor={Alive=true,Participant=true,Role="Sukuna",Team="Curses",Model={},Energy=100,Ultimate=100,Abilities={"Regeneration"},Cooldowns={},StunUntil=0,UsedAbilities={},Definition={UltimateAbility="MalevolentShrine",AttackPower=26}}
 local c={Abilities=A,CharacterService={ByPlayer={[p]=actor}},AntiExploitService={Allow=function() return true end,Flag=function() end},RoundService={IsCombat=function() return true end,Token=1},
 U={vector=function(v) return type(v)=="table" and U.finite(v.X) and U.finite(v.Y) and U.finite(v.Z) end,root=function() return root end},QuestService={Progress=function() end},
 Remotes={Effect={FireAllClients=function() events=events+1 end}},DamageService={Heal=function() healed=healed+1 end}}
 Ability:Init(c);local dir=Vector3.new(0,0,-1)
 Ability:Cast(p,"Regeneration",dir);equal(healed,1);equal(actor.Energy,65)
 Ability:Cast(p,"Regeneration",dir);equal(healed,1);equal(actor.Energy,65)
 actor.CastUntil=0;actor.Cooldowns={};actor.Participant=false;Ability:Cast(p,"Regeneration",dir);equal(healed,1)
 actor.Participant=true;Ability:Cast(p,"Infinity",dir);equal(healed,1);equal(actor.Energy,65)
 Ability:Cast(p,"Regeneration",Vector3.new(0/0,0,0));equal(healed,1)
 actor.Energy=0;Ability:Cast(p,"Regeneration",dir);equal(healed,1)
end)
check("T08 ultimate needs full charge and consumes it once",function()
 local p={UserId=8};local root={Position=Vector3.new(0,3,0)}
 local a={Alive=true,Participant=true,Model={},Energy=100,Ultimate=99,Abilities={},Cooldowns={},StunUntil=0,UsedAbilities={},Definition={UltimateAbility="MalevolentShrine"}}
 local c={Abilities=A,CharacterService={ByPlayer={[p]=a}},AntiExploitService={Allow=function() return true end},RoundService={IsCombat=function() return true end,Token=1},
 U={vector=function() return true end,root=function() return root end},QuestService={Progress=function() end},Remotes={Effect={FireAllClients=function() end}}}
 Ability:Init(c);local dir=Vector3.new(0,0,-1)
 Ability:Cast(p,"MalevolentShrine",dir);equal(a.Energy,100);equal(a.Ultimate,99)
 a.Ultimate=100;Ability:Cast(p,"MalevolentShrine",dir);equal(a.Energy,60);equal(a.Ultimate,0)
 Ability:Cast(p,"MalevolentShrine",dir);equal(a.Energy,60)
end)
check("Round transitions reject duplicates and illegal edges",function()
 Round.State="WaitingForPlayers";Round.Broadcast=function() end
 assert(Round:Transition("Intermission",20));assert(not Round:Transition("Intermission",20))
 local ok=pcall(function() Round:Transition("Results",10) end);assert(not ok)
 for _,s in ipairs({"VotingOrSelection","Loading","Intro","InProgress","SuddenDeath","Results","Cleanup","WaitingForPlayers"}) do assert(Round:Transition(s,1)) end
end)
check("Disconnect during yielding spawn search does not create a departed character",function()
 local leaving={Parent=true}; local staying={Parent=true}; local players={leaving,staying}
 local spawned,notified=0,0
 local roles={}
 for _,p in ipairs(players) do roles[p]={Role="Sorcerer",Team="Sorcerers",Abilities={}} end
 local c={Config=Config,Maps={{Id="test",Name="test"}},Rng={NextInteger=function() return 1 end},
  ModeService={Eligible=function() return {"Hunt"} end},RoleService={Assign=function() return roles end},
  MapService={Load=function() end,Spawn=function(_,index) if index==1 then leaving.Parent=nil end; return "safe" end},
  CharacterService={Spawn=function(_,p,role,team,abilities,cf)
   assert(p==staying and p.Parent and cf=="safe"); spawned=spawned+1
   return {Role=role,Team=team,Abilities=abilities,Definition={DisplayName="test"}}
  end},Remotes={Role={FireClient=function(_,p) assert(p==staying); notified=notified+1 end}}}
 local round=setmetatable({},{__index=Round}); round:Init(c); round.Closing=false
 round.EligiblePlayers=function() return players end; round.Broadcast=function() end
 round.Countdown=function(self) if self.State=="Intro" then self.Closing=true end; return true end
 round:RunOne(); equal(spawned,1); equal(notified,1)
end)
print("BOUNDARY TEST GROUPS PASSED: "..count)
