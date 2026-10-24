local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
Players.CharacterAutoLoads=false
local shared=RS:WaitForChild("Shared")
local C={Config=require(shared.Config),U=require(shared.Utility),Characters=require(shared.CharacterDefinitions),
 Abilities=require(shared.AbilityDefinitions),Modes=require(shared.RoundDefinitions),Maps=require(shared.MapDefinitions),Rng=Random.new(),Remotes={}}
local remotes=RS:FindFirstChild("Remotes") or Instance.new("Folder"); remotes.Name="Remotes"; remotes.Parent=RS
for _,name in ipairs({"Cast","Sprint","Action","State","Vitals","Effect","Role","Results","Profile","Notice"}) do
 local r=remotes:FindFirstChild(name) or Instance.new("RemoteEvent"); r.Name=name; r.Parent=remotes; C.Remotes[name]=r
end
for _,name in ipairs({"GameplayEffects","SpawnPoints"}) do if not workspace:FindFirstChild(name) then local f=Instance.new("Folder"); f.Name=name; f.Parent=workspace end end
local services=script.Parent:WaitForChild("Services")
local order={"PlayerDataService","AntiExploitService","RoleService","ModeService","CombatService","DamageService","DestructionService","MapService","NPCService","QuestService","RewardService","RoundService","CharacterService","AbilityService","MonetizationService"}
for _,name in ipairs(order) do C[name]=require(services[name]) end
for _,name in ipairs(order) do C[name]:Init(C) end
local function profile(p) if p.Parent then C.Remotes.Profile:FireClient(p,C.PlayerDataService:Public(p)) end end
local function join(p)
 if #Players:GetPlayers()>C.Config.MaxPlayers then p:Kick("Сервер заполнен."); return end
 if not C.PlayerDataService:Load(p) then return end
 if not p.Parent then C.PlayerDataService:Save(p,true); return end
 C.QuestService:Progress(p,"Rounds",0)
 C.PlayerDataService:Mutate(p,function(d) C.QuestService:Reset(d) end)
 C.CharacterService:Lobby(p); p:SetAttribute("Ready",true)
 task.spawn(function() C.MonetizationService:RefreshPasses(p); profile(p) end)
end
Players.PlayerAdded:Connect(function(p) task.spawn(join,p) end)
for _,p in ipairs(Players:GetPlayers()) do task.spawn(join,p) end
Players.PlayerRemoving:Connect(function(p)
 C.CharacterService:Remove(p); C.AntiExploitService:Remove(p); C.MapService.Holds[p]=nil
 C.PlayerDataService:Save(p,true)
end)
C.Remotes.Cast.OnServerEvent:Connect(function(p,id,dir) C.AbilityService:Cast(p,id,dir) end)
C.Remotes.Sprint.OnServerEvent:Connect(function(p,on)
 if type(on)~="boolean" or not C.AntiExploitService:Allow(p,"Sprint",5,8) then return end
 local a=C.CharacterService.ByPlayer[p]; if a then a.Sprinting=on end
end)
C.Remotes.Action.OnServerEvent:Connect(function(p,action,arg)
 if type(action)~="string" or not C.AntiExploitService:Allow(p,"UI",3,6) then return end
 if not C.PlayerDataService:Get(p) then return end
 if arg~=nil and type(arg)~="string" and type(arg)~="boolean" then return end
 if type(arg)=="string" and #arg>80 then return end
 local ok=false
 if action=="Sync" then C.RoundService:Broadcast(); profile(p); return
 elseif action=="Buy" then ok=C.MonetizationService:Purchase(p,arg)
 elseif action=="Equip" then ok=C.MonetizationService:Equip(p,arg)
 elseif action=="Daily" then ok=C.QuestService:Daily(p)
 elseif action=="Quest" then ok=C.QuestService:Claim(p,arg)
 elseif action=="Product" or action=="Pass" then ok=C.MonetizationService:Prompt(p,action,arg)
 elseif action=="Emote" then
  local a=C.CharacterService.ByPlayer[p]; local d=C.PlayerDataService:Get(p)
  if a and a.Alive and not a.Participant and d.Entitlements.Emotes then C.Remotes.Effect:FireAllClients("Emote",C.U.root(a.Model).Position,{170,120,255},7,a.Model); ok=true end
 elseif action=="SaveLoadout" or action=="LoadLoadout" then
  local slot=tonumber(arg); local d=C.PlayerDataService:Get(p); local max=d.Entitlements.Loadouts and 3 or 1
  if slot and slot%1==0 and slot>=1 and slot<=max then
   if action=="SaveLoadout" then ok=C.PlayerDataService:Mutate(p,function(data) data.Loadouts[tostring(slot)]=data.EquippedCosmetics end)
   else ok=C.MonetizationService:Equip(p,d.Loadouts[tostring(slot)] or "") end
  end
 elseif string.sub(action,1,8)=="Setting:" then
  local key=string.sub(action,9)
  if table.find({"LowFX","Shake","ReducedFlash","Scares","Sound"},key) and type(arg)=="boolean" then ok=C.PlayerDataService:Mutate(p,function(d) d.Settings[key]=arg end) end
 end
 C.Remotes.Notice:FireClient(p,ok and "Готово" or "Сейчас недоступно или условие не выполнено")
 profile(p)
end)
local accumulated=0; local net=0; local npc=0
Run.Heartbeat:Connect(function(dt)
 accumulated=accumulated+dt; net=net+dt; npc=npc+dt
 if accumulated>=0.25 then
  local step=math.min(accumulated,0.5); accumulated=0
  C.CharacterService:Step(step); C.MapService:Step(step)
 end
 if npc>=C.Config.NPCThinkSeconds then npc=0; C.NPCService:Step() end
 if net>=0.2 then
  net=0
  for p,a in pairs(C.CharacterService.ByPlayer) do if p.Parent then
   local h=C.U.humanoid(a.Model); local cooldowns={}
   for id,time in pairs(a.Cooldowns) do cooldowns[id]=math.max(0,time-os.clock()) end
   C.Remotes.Vitals:FireClient(p,{HP=h and h.Health or 0,MaxHP=h and h.MaxHealth or 100,Energy=a.Energy,Stamina=a.Stamina,
    Ultimate=a.Ultimate,Alive=a.Alive,Participant=a.Participant,Team=a.Team,Abilities=a.Abilities,UltimateId=a.Definition.UltimateAbility,Cooldowns=cooldowns})
  end end
 end
end)
game:BindToClose(function()
 C.RoundService.Closing=true; C.RoundService.Token=C.RoundService.Token+1; C.PlayerDataService.Closing=true
 local pending=0
 for p in pairs(C.PlayerDataService.Profiles) do pending=pending+1; task.spawn(function() C.PlayerDataService:Save(p,true); pending=pending-1 end) end
 local deadline=os.clock()+25; while pending>0 and os.clock()<deadline do task.wait(0.1) end
end)
C.RoundService:Start()
print("Cursed Survival",C.Config.Version,"server ready; persistence:",C.PlayerDataService.Memory and "MEMORY" or "LIVE")
