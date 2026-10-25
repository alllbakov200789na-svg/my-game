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
-- INJECT SERVER MODULES

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
