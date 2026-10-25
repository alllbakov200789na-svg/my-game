-- Run: node tools/test-bundle.mjs && luau tests/movement.generated.lua
-- Deterministic engine-boundary tests; these do not simulate Roblox physics/networking.
local V=require("../src/Server/Services/VerticalMotion")
local A=require("../src/Shared/AbilityDefinitions")
local time=0
local os={clock=function() return time end,time=function() return 0 end}
local warn=function() end
local Vector3={}
local mt={}
function Vector3.new(x,y,z) return setmetatable({X=x,Y=y,Z=z},mt) end
function mt.__index(v,k)
 if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end
 if k=="Unit" then return Vector3.new(v.X/v.Magnitude,v.Y/v.Magnitude,v.Z/v.Magnitude) end
end
function mt.__add(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function mt.__sub(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
function mt.__mul(a,b) return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
Vector3.zero=Vector3.new(0,0,0)
local CFrame={new=function(pos) return {Position=pos} end,lookAt=function(pos) return {Position=pos} end}
local RaycastParams={new=function() return {} end}
local Enum={RaycastFilterType={Exclude="Exclude"}}
local staticPart={Anchored=true,IsA=function() return false end}
local workspace={Gravity=196.2,GameplayEffects={},GetServerTimeNow=function() return time end}
local groundY=0
local groundTest=function() return true end
function workspace:Raycast(origin,dir,params)
 assert(params.RespectCanCollide and params.CollisionGroup=="Default")
 if groundY and groundTest(origin) and origin.Y>=groundY and origin.Y+dir.Y<=groundY then
  return {Instance=staticPart,Position=Vector3.new(origin.X,groundY,origin.Z)}
 end
 return nil
end
function workspace:Blockcast() return nil end
local deferred={}
local task={spawn=function(fn) table.insert(deferred,fn) end,wait=function() end}
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
local Damage=(function()
local S={}
function S:Init(ctx) self.C=ctx end
function S:Apply(attacker,target,amount,origin,knock)
 local C=self.C
 if not C.RoundService:IsCombat() or not attacker or not attacker.Alive or not target.Alive then return 0 end
 if attacker.Team==target.Team or not target.Participant then return 0 end
 if not C.U.finite(amount) or amount<=0 then return 0 end
 local h=C.U.humanoid(target.Model); local root=C.U.root(target.Model)
 if not h or not root or h.Health<=0 or os.clock()<(target.ShieldUntil or 0) then return 0 end
 local multiplier=1-(target.Definition.Defense or 0)
 if target.Team=="Curses" then multiplier=multiplier*(1+0.08*(C.MapService.Seals or 0)) end
 local damage=math.min(h.Health,amount*multiplier)
 target.LastAttacker=attacker; target.LastHitAt=os.clock()
 h:TakeDamage(damage)
 attacker.Damage=(attacker.Damage or 0)+damage; attacker.Ultimate=math.min(100,(attacker.Ultimate or 0)+damage*0.12)
 attacker.Actions=(attacker.Actions or 0)+1
 if attacker.Player then C.QuestService:Progress(attacker.Player,"Damage",math.floor(damage)) end
 if knock and origin then
  local v=root.Position-origin; if v.Magnitude>0.1 then
   local velocity=v.Unit*knock+Vector3.new(0,12,0)
   C.AntiExploitService:AuthorizeImpulse(target,velocity,1.3); root.AssemblyLinearVelocity=velocity
  end
 end
 C.Remotes.Effect:FireAllClients("Hit",root.Position,{255,240,220},3,target.Model)
 if h.Health<=0 then C.CharacterService:Die(target) end
 return damage
end
function S:Heal(a,target,amount)
 if not a.Alive or not target.Alive or a.Team~=target.Team or not target.Participant then return 0 end
 local h=self.C.U.humanoid(target.Model); if not h then return 0 end
 local healed=math.min(amount,h.MaxHealth-h.Health); h.Health=h.Health+healed
 if target~=a and healed>0 then
  a.Healed=(a.Healed or 0)+healed; a.Actions=a.Actions+1; a.Ultimate=math.min(100,a.Ultimate+healed*0.2)
  if a.Player then self.C.QuestService:Progress(a.Player,"Help",1) end
 end
 return healed
end
return S

end)()


local count=0
local function check(name,fn)
 local ok,err=pcall(fn); assert(ok,"FAIL "..name..": "..tostring(err))
 count=count+1; print("PASS "..name)
end
local function equal(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function finite(n) return n==n and math.abs(n)<1e7 end
local function fixture(y)
 time=0; groundY=0; staticPart.Anchored=true; workspace.Gravity=196.2; deferred={}
 groundTest=function() return true end
 local root={Position=Vector3.new(0,y or 3,0),Size=Vector3.new(2,2,1),CollisionGroup="Default",AssemblyLinearVelocity=Vector3.zero}
 local h={UseJumpPower=true,JumpPower=50,JumpHeight=7.2,HipHeight=2,Health=500,MaxHealth=500}
 function h:TakeDamage(n) self.Health=self.Health-n end
 local model={Parent=true}; function model:Destroy() self.Parent=nil end
 local p={UserId=1}
 local a={Player=p,Alive=true,Participant=true,Model=model,Definition={SprintSpeed=30,UltimateAbility="UnlimitedVoid",Defense=0},
  Abilities={"Teleport","CursedDash","ShadowDash","Blue"},Energy=100,Ultimate=100,Cooldowns={},StunUntil=0,UsedAbilities={},Team="Sorcerers"}
 local c={U={root=function(m) return m.Root end,humanoid=function(m) return m.Humanoid end,
  finite=finite,vector=function(v) return finite(v.X) and finite(v.Y) and finite(v.Z) end},
  AntiExploitService=Guard,Abilities=A,CharacterService={ByPlayer={[p]=a}},
  Config={ArenaRadius=200},RoundService={Token=1,IsCombat=function() return true end},
  QuestService={Progress=function() end},Remotes={Effect={FireAllClients=function() end}},
  DestructionService={Blast=function() end},MapService={Seals=0}}
 model.Root=root; model.Humanoid=h
 c.CombatService={Area=function() end,Targets=function() return {} end,Visible=function() return true end,
  Ray=function(_,origin) return {Position=Vector3.new(origin.X,groundY or 0,origin.Z)} end}
 Guard:Init(c); Ability:Init(c); Damage:Init(c)
 Guard:ResetMotion(a,root.Position)
 local function step(t,pos)
  time=t; root.Position=pos; root.CFrame=nil; Guard:Step(a,0.25)
  return root.CFrame~=nil
 end
 return a,root,h,c,step
end

check("standing, sprinting and stairs keep a valid baseline",function()
 local a,root,h,c,step=fixture()
 for i=1,16 do
  groundY=i*0.5
  assert(not step(i*0.25,Vector3.new(i*6,groundY+3,0)))
 end
 equal(#Guard.Audit,0); equal(Guard.Motion[a.Player].Pos.X,96)
end)
check("normal repeated jumps, both jump settings and low gravity",function()
 for _,g in ipairs({196.2,60}) do for _,usePower in ipairs({true,false}) do
  local a,root,h,c,step=fixture(); workspace.Gravity=g; h.UseJumpPower=usePower
  Guard:ResetMotion(a,root.Position)
  local speed=Guard:JumpSpeed(a); local flight=2*speed/g
  local t=0
  for _=1,5 do
   step(t,Vector3.new(0,3,0))
   for j=1,8 do
    local age=flight*j/8
    assert(not step(t+age,Vector3.new(0,3+math.max(0,speed*age-g*age*age/2),0)))
   end
   t=t+flight+0.25
  end
  equal(#Guard.Audit,0)
 end end
end)
check("long fall, destroyed support, wall slide and server stall",function()
 local a,root,h,c,step=fixture(1003); groundY=1000
 step(0.25,root.Position); groundY=nil
 for _,age in ipairs({0.25,0.5,1.5,2.5,3}) do
  assert(not step(0.25+age,Vector3.new(0,1003-196.2*age*age/2,0)))
 end
 equal(#Guard.Audit,0)
 a,root,h,c,step=fixture(1003); groundY=nil
 for i=1,30 do assert(not step(i*0.25,Vector3.new(0,1003-i*2,0))) end
 equal(#Guard.Audit,0)
end)
check("batched replication and a single bad sample recover without a flag",function()
 local a,root,h,c,step=fixture()
 step(0.25,Vector3.new(0,3,0)); step(0.5,Vector3.new(0,3,0))
 step(0.75,Vector3.new(0,9,0)); step(1,Vector3.new(0,3,0))
 assert(not step(1.25,Vector3.new(0,500,0)))
 assert(not step(1.5,Vector3.new(0,3,0))); equal(#Guard.Audit,0)
 equal(Guard.Motion[a.Player].SuspectAt,nil)
end)
check("vertical teleport up/down requires confirmation and preserves safe position",function()
 for _,y in ipairs({503,-497}) do
  local a,root,h,c,step=fixture(); step(0.25,root.Position)
  assert(not step(0.5,Vector3.new(0,y,0))); assert(not step(0.75,Vector3.new(0,y,0)))
  equal(Guard.Motion[a.Player].Pos.Y,3)
  assert(step(1,Vector3.new(0,y,0))); equal(root.CFrame.Position.Y,3)
  equal(root.AssemblyLinearVelocity.Magnitude,0); equal(#Guard.Audit,1)
 end
end)
check("slow ascent and hovering are rejected even with forged velocity and grace",function()
 for _,rise in ipairs({0,1}) do
  local a,root,h,c,step=fixture(30); groundY=nil; a.MotionGrace=10000
  root.AssemblyLinearVelocity=Vector3.new(0,10000,0)
  local corrected=false
  for i=1,24 do if step(i*0.25,Vector3.new(0,30+i*rise,0)) then corrected=true; break end end
  assert(corrected); equal(#Guard.Audit,1)
 end
end)
check("client-owned support cannot authorize hovering",function()
 local a,root,h,c,step=fixture(30); staticPart.Anchored=false; groundY=27
 local corrected=false
 for i=1,20 do if step(i*0.25,root.Position) then corrected=true; break end end
 assert(corrected)
end)
check("ledge support is accepted but a teleport onto a roof is rejected",function()
 local a,root,h,c,step=fixture()
 groundTest=function(origin) return origin.X>0.5 end
 for i=1,20 do assert(not step(i*0.25,root.Position)) end
 equal(#Guard.Audit,0)
 a,root,h,c,step=fixture(); step(0.25,root.Position)
 groundY=30
 step(0.5,Vector3.new(0,33,0)); step(0.75,Vector3.new(0,33,0))
 assert(step(1,Vector3.new(0,33,0))); equal(root.CFrame.Position.Y,3)
end)
check("horizontal guard still rejects unauthorized displacement",function()
 local a,root,h,c,step=fixture()
 assert(step(0.25,Vector3.new(500,3,0))); equal(Guard.Audit[1].Reason,"movement")
end)
check("Teleport and both dash techniques reset to the server destination",function()
 for _,id in ipairs({"Teleport","CursedDash","ShadowDash"}) do
  local a,root,h,c,step=fixture(); groundY=2
  Ability:Cast(a.Player,id,Vector3.new(1,0,0))
  local destination=root.CFrame.Position
  equal(destination.X,A[id].Range); equal(destination.Y,5.2)
  equal(Guard.Motion[a.Player].Pos.Y,destination.Y)
  assert(not step(0.25,destination)); equal(#Guard.Audit,0)
  step(0.5,destination+Vector3.new(0,500,0)); step(0.75,destination+Vector3.new(0,500,0))
  assert(step(1,destination+Vector3.new(0,500,0)))
 end
end)
check("server impulses permit upward/downward arcs but not arbitrary teleport",function()
 for _,velocity in ipairs({77,-65,48,-48}) do
  local a,root,h,c,step=fixture(1003); groundY=nil
  Guard:AuthorizeImpulse(a,Vector3.new(65,velocity,0),1.3)
  for i=1,8 do
   local t=i*0.25
   assert(not step(t,Vector3.new(65*math.min(t,1.25),1003+velocity*t-196.2*t*t/2,0)))
  end
  equal(#Guard.Audit,0)
 end
 local a,root,h,c,step=fixture(); Guard:AuthorizeImpulse(a,Vector3.new(0,77,0),1.3)
 step(0.25,Vector3.new(0,500,0)); step(0.5,Vector3.new(0,500,0))
 assert(step(0.75,Vector3.new(0,500,0)))
end)
check("DamageService knockback and Blue register their exact server impulse",function()
 local a,root,h,c,step=fixture()
 local attacker={Alive=true,Team="Curses"}
 Damage:Apply(attacker,a,10,Vector3.new(0,-10,0),65)
 equal(Guard.Motion[a.Player].Vertical.Up,77); equal(root.AssemblyLinearVelocity.Y,77)
 a,root,h,c,step=fixture()
 local target={Player={UserId=2},Model={Root={Position=Vector3.new(0,10,0)},Humanoid=h},Definition=a.Definition}
 Guard:ResetMotion(target,target.Model.Root.Position)
 c.CombatService.Targets=function() return {target} end
 Ability:Cast(a.Player,"Blue",Vector3.new(1,0,0))
 local velocity=target.Model.Root.AssemblyLinearVelocity
 assert(velocity.Y<0); equal(Guard.Motion[target.Player].Vertical.Down,-velocity.Y)
end)
check("both domains keep their ticks and do not grant movement exemptions",function()
 for _,id in ipairs({"UnlimitedVoid","MalevolentShrine"}) do
  local a,root,h,c,step=fixture(); local hits=0; local stun=nil
  a.Definition.UltimateAbility=id
  c.CombatService.Area=function(_,actor,center,radius,damage,knock,duration) hits=hits+1; stun=duration end
  local baseline=Guard.Motion[a.Player]
  Ability:Cast(a.Player,id,Vector3.new(1,0,0)); equal(#deferred,1); deferred[1]()
  equal(hits,6); equal(a.Ultimate,0); equal(Guard.Motion[a.Player],baseline)
  equal(stun,id=="UnlimitedVoid" and 0.65 or nil)
 end
end)
check("respawn replaces history, removal clears it, dead/NPC actors are skipped",function()
 local a,root,h,c,step=fixture(); step(0.25,Vector3.new(0,500,0))
 a.Model={Root=root,Humanoid=h}; root.Position=Vector3.new(0,100,0)
 Guard:ResetMotion(a,root.Position); equal(Guard.Motion[a.Player].SuspectAt,nil)
 equal(Guard.Motion[a.Player].SafePos.Y,100)
 a.Alive=false; assert(not step(1,Vector3.new(0,500,0)))
 Guard:Remove(a.Player); equal(Guard.Motion[a.Player],nil)
 a.Player=nil; a.Alive=true; Guard:Step(a,0.25); equal(next(Guard.Motion),nil)
end)
check("non-finite positions still destroy invalid actors",function()
 local a,root,h,c,step=fixture(); step(0.25,Vector3.new(0,0/0,0))
 equal(a.Alive,false); equal(a.Model.Parent,nil)
end)
print("MOVEMENT TEST GROUPS PASSED: "..count)
