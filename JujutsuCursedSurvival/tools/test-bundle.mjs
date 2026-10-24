import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const src=n=>fs.readFileSync(path.join(root,'src/Server/Services',n+'.lua'),'utf8').replace(/^\uFEFF/,'');
const head=`local U=require("../src/Shared/Utility")
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
`;
const body=`
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
print("BOUNDARY TEST GROUPS PASSED: "..count)
`;
const modules=[['Data','PlayerDataService'],['Guard','AntiExploitService'],['Ability','AbilityService'],['Round','RoundService']].map(([name,n])=>`local ${name}=(function()\n${src(n)}\nend)()\n`).join('');
fs.writeFileSync(path.join(root,'tests','boundaries.generated.lua'),head+modules+body);
console.log('Generated engine-boundary tests with explicit test doubles; not a Roblox Engine test.');
