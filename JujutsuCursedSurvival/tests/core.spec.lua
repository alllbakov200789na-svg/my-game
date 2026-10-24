local Mode=require("../src/Server/Services/ModeService")
local Role=require("../src/Server/Services/RoleService")
local Damage=require("../src/Server/Services/DamageService")
local U=require("../src/Shared/Utility")
local A=require("../src/Shared/AbilityDefinitions")
local Modes=require("../src/Shared/RoundDefinitions")
local Config=require("../src/Shared/Config")
local passed=0
local function check(name,fn)
 local ok,err=pcall(fn); if not ok then error("FAIL "..name..": "..tostring(err)) end
 passed=passed+1; print("PASS "..name)
end
local function equal(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local seed=1031
local rng={}
function rng:NextNumber() seed=(seed*48271)%2147483647; return seed/2147483647 end
function rng:NextInteger(a,b) return a+math.floor(self:NextNumber()*(b-a+1)) end
local data={}
local dataService={}
function dataService:Get(p) return data[p] end
function dataService:Mutate(p,fn) fn(data[p]); return true end
local chars={Gojo={AbilitySet={"Blue","Red"}},Sukuna={AbilitySet={"Cleave"}},Curse={AbilitySet={"Dismantle"}}}
local C={U=U,Abilities=A,Modes=Modes,Characters=chars,PlayerDataService=dataService}
Role:Init(C); Mode:Init(C)
local function players(n)
 local out={}; data={}
 for i=1,n do local p={UserId=i}; table.insert(out,p); data[p]={RolePity=i%5} end
 return out
end
check("T03 role counts for 15 players in all five modes",function()
 for mode in pairs(Modes) do
  local ps=players(15); local roles,carrier=Role:Assign(ps,mode,rng); local totals={Sorcerers=0,Curses=0}; local count=0
  for _,r in pairs(roles) do count=count+1; totals[r.Team]=totals[r.Team]+1 end
  equal(count,15)
  if mode=="Hunt" then equal(totals.Curses,1) end
  if mode=="Clash" then assert(math.abs(totals.Sorcerers-totals.Curses)<=1) end
  if mode=="Invasion" then equal(totals.Curses,2) end
  if mode=="Betrayal" then assert(carrier); equal(totals.Curses,0); equal(roles[carrier].Role,"Sorcerer") end
 end
end)
check("T04 eligible modes for 0..15 players",function()
 for n=0,15 do
  for _,id in ipairs(Mode:Eligible(n)) do assert(n>=Modes[id].MinPlayers) end
 end
 equal(#Mode:Eligible(0),0); equal(#Mode:Eligible(1),1); equal(Mode:Eligible(1)[1],"Survival")
end)
check("T05 1000 random compatible pairs",function()
 local seen={}
 for _=1,1000 do local pair=Role:Abilities(rng); equal(#pair,2); assert(pair[1]~=pair[2]); assert(not(A.Incompatible[pair[1]] and A.Incompatible[pair[1]][pair[2]])); seen[pair[1]]=true; seen[pair[2]]=true end
 for _,id in ipairs(A.Pool) do assert(seen[id]) end
end)
check("Role pity reset and increment",function()
 local ps=players(8); local before={}; for p,d in pairs(data) do before[p]=d.RolePity end
 local roles=Role:Assign(ps,"Hunt",rng)
 for p,r in pairs(roles) do equal(data[p].RolePity,r.Special and 0 or before[p]+1) end
end)
check("Every technique has real effect metadata",function()
 local kinds={Melee=true,Pull=true,Push=true,Shield=true,Teleport=true,Projectile=true,Domain=true,Dash=true,HealSelf=true,Summon=true,Stun=true,Heal=true,Trap=true}
 local n=0
 for id,a in pairs(A) do if type(a)=="table" and a.Id then n=n+1; assert(kinds[a.Kind],id); assert(a.Cost>=0 and a.Cooldown>0); assert(a.Color and #a.Color==3,id) end end
 equal(n,26)
end)
local function snap(changes)
 local s={Sorcerers=2,Curses=1,SorcererLeader=true,CurseLeader=true,SorcererScore=180,CurseScore=90,Seals=0,BossDefeated=false,Revealed=true}
 for k,v in pairs(changes or {}) do s[k]=v end; return s
end
check("T11 Hunt distinct win conditions",function()
 equal(Mode.Decide("Hunt",snap({Curses=0}),false),"Sorcerers")
 equal(Mode.Decide("Hunt",snap({Sorcerers=0}),false),"Curses")
 equal(Mode.Decide("Hunt",snap({Seals=3}),false),nil)
 equal(Mode.Decide("Hunt",snap({Seals=3}),true),"Sorcerers")
 equal(Mode.Decide("Hunt",snap(),true),"Curses")
end)
check("T11 Clash leadership, score and simultaneous deaths",function()
 equal(Mode.Decide("Clash",snap({CurseLeader=false}),false),"Sorcerers")
 equal(Mode.Decide("Clash",snap({SorcererLeader=false}),false),"Curses")
 equal(Mode.Decide("Clash",snap({SorcererLeader=false,CurseLeader=false}),false),"Draw")
 equal(Mode.Decide("Clash",snap(),true),"Sorcerers")
 equal(Mode.Decide("Clash",snap({SorcererScore=90}),true),"Draw")
end)
check("T11 Invasion, Survival and Betrayal",function()
 equal(Mode.Decide("Invasion",snap({Seals=3}),false),"Sorcerers")
 equal(Mode.Decide("Invasion",snap(),true),"Curses")
 equal(Mode.Decide("Survival",snap({BossDefeated=true,Seals=2}),false),nil)
 equal(Mode.Decide("Survival",snap({BossDefeated=true,Seals=3}),false),"Sorcerers")
 equal(Mode.Decide("Survival",snap(),true),"Curses")
 equal(Mode.Decide("Betrayal",snap({Revealed=false,Curses=0}),false),nil)
 equal(Mode.Decide("Betrayal",snap({Revealed=true,Curses=0}),false),"Sorcerers")
 equal(Mode.Decide("Betrayal",snap({Revealed=true,Seals=0}),true),"Curses")
end)
check("T10 disconnect snapshots do not leave an unwinnable state",function()
 equal(Mode.Decide("Hunt",snap({Curses=0}),false),"Sorcerers")
 equal(Mode.Decide("Clash",snap({SorcererLeader=false}),false),"Curses")
 equal(Mode.Decide("Hunt",snap({Sorcerers=0,Curses=0}),false),"Draw")
end)
check("T06 damage, friendly fire, protection, duplicate lethal hits",function()
 local deaths=0; local combat=true; local hp={Health=100,MaxHealth=100}
 function hp:TakeDamage(n) self.Health=math.max(0,self.Health-n) end
 local target={Model={},Alive=true,Team="Curses",Participant=true,ShieldUntil=0,Definition={Defense=0.1}}
 local attacker={Alive=true,Team="Sorcerers",Actions=0,Damage=0,Ultimate=0}
 Damage:Init({RoundService={IsCombat=function() return combat end},U={finite=U.finite,humanoid=function() return hp end,root=function() return {Position=0} end},
 MapService={Seals=0},Remotes={Effect={FireAllClients=function() end}},CharacterService={Die=function(_,a) if a.Alive then deaths=deaths+1; a.Alive=false end end}})
 equal(Damage:Apply(attacker,target,20),18); equal(hp.Health,82)
 target.Team="Sorcerers"; equal(Damage:Apply(attacker,target,50),0); target.Team="Curses"
 target.ShieldUntil=os.clock()+5; equal(Damage:Apply(attacker,target,50),0); target.ShieldUntil=0
 combat=false; equal(Damage:Apply(attacker,target,50),0); combat=true
 equal(Damage:Apply(attacker,target,1000),82); equal(Damage:Apply(attacker,target,1000),0); equal(deaths,1)
end)
check("Balance and commerce defaults",function()
 equal(Config.RoundSeconds,240); equal(Config.Intermission,20); equal(Config.ResultsSeconds,10)
 for _,p in pairs(Config.Products) do equal(p.Id,0); equal(p.Status,"NOT_CONFIGURED") end
 for _,p in pairs(Config.Passes) do equal(p.Id,0) end
 equal(Config.StudioPersistence,false)
end)
print("CORE TEST GROUPS PASSED: "..passed)
