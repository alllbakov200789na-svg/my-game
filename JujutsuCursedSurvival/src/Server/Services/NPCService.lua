local Pathfinding=game:GetService("PathfindingService")
local S={}
function S:Init(ctx) self.C=ctx; self.NPCs={}; self.LastWave=0; self.Wave=0; self.BossDefeated=false; self.BossSpawned=false end
function S:Count() local n=0; for _ in pairs(self.NPCs) do n=n+1 end; return n end
function S:Spawn(kind,pos,owner,life)
 local C=self.C; if self:Count()>=C.Config.MaxNPCs then return end
 local m=C.CharacterService.Template:Clone(); m.Name=kind
 local specs={Weak={55,12,6,1},Fast={38,23,5,0.8},Elite={140,14,12,1.25},Boss={400+120*C.RoundService.PlayerCount,15,19,2.2},ShadowDog={65,25,12,0.65}}
 local stat=specs[kind]; local h=C.U.humanoid(m)
 h.MaxHealth=stat[1]; h.Health=stat[1]; h.WalkSpeed=stat[2]; h.DisplayName=kind; h.BreakJointsOnDeath=false
 local team=owner and owner.Team or "Curses"
 C.CharacterService:Style(m,"Curse",team); m:ScaleTo(stat[4]); m:SetAttribute("Faction",team); m:SetAttribute("NPC",true)
 m.Parent=workspace; m:PivotTo(CFrame.new(pos)); local root=C.U.root(m); root:SetNetworkOwner(nil)
 if kind=="ShadowDog" then
  for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then p.Transparency=1 end end
  local function limb(name,size,offset,color)
   local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Color=color; p.Material=Enum.Material.SmoothPlastic; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false; p.Massless=true
   p.CFrame=root.CFrame*CFrame.new(offset); p.Parent=m
   local w=Instance.new("WeldConstraint"); w.Part0=root; w.Part1=p; w.Parent=p
  end
  local fur=Color3.fromRGB(39,29,62)
  limb("DogBody",Vector3.new(1.6,1.2,2.8),Vector3.new(0,-0.3,0),fur)
  limb("DogHead",Vector3.new(1.1,1.1,1.2),Vector3.new(0,0.2,-1.7),fur)
  for _,x in ipairs({-0.45,0.45}) do
   limb("Ear",Vector3.new(0.25,0.7,0.4),Vector3.new(x,1,-1.6),fur)
   limb("Eye",Vector3.new(0.15,0.15,0.12),Vector3.new(x,0.35,-2.32),Color3.fromRGB(170,100,255))
   for _,z in ipairs({-0.8,0.8}) do limb("Paw",Vector3.new(0.4,0.9,0.5),Vector3.new(x,-1,z),fur) end
  end
  limb("Tail",Vector3.new(0.3,0.5,1.1),Vector3.new(0,0.1,1.8),fur)
 end
 local a={Model=m,Role=kind,Team=team,Alive=true,Participant=true,Definition={Defense=kind=="Boss" and 0.1 or 0,WalkSpeed=stat[2],SprintSpeed=stat[2]},
 Energy=100,Stamina=100,Ultimate=0,Actions=0,Damage=0,Eliminations=0,Power=stat[3],NextHit=0,StunUntil=0,ShieldUntil=0,
 Owner=owner,Expires=life and os.clock()+life,NextPath=0,Token=C.RoundService.Token}
 C.CharacterService.Actors[m]=a; self.NPCs[m]=a
 a.Connection=h.Died:Connect(function()
  C.CharacterService:Die(a)
  if kind=="Boss" then self.BossDefeated=true end
  task.delay(2,function() self:Remove(m) end)
 end)
 return a
end
function S:Remove(m)
 local a=self.NPCs[m]; if not a then return end
 if a.Connection then a.Connection:Disconnect() end
 self.NPCs[m]=nil; self.C.CharacterService.Actors[m]=nil; m:Destroy()
end
function S:Summon(owner,def,token)
 if token~=self.C.RoundService.Token then return end
 local root=self.C.U.root(owner.Model)
 local a=self:Spawn("ShadowDog",root.Position+root.CFrame.LookVector*5,owner,def.Duration)
 if a then a.Power=def.Damage end
end
function S:Step()
 local C=self.C; local r=C.RoundService; if not r:IsCombat() then return end
 local now=os.clock(); local elapsed=now-r.StartedAt
 local waves=r.Mode=="Survival" or r.Mode=="Invasion" or (r.Mode=="Betrayal" and not r.Revealed)
 if waves and now-self.LastWave>C.Config.WaveSeconds and elapsed<C.Config.RoundSeconds-25 then
  self.LastWave=now; self.Wave=self.Wave+1
  local n=math.min(2+math.floor(r.PlayerCount/3),7)
  for i=1,n do
   local angle=C.Rng:NextNumber()*math.pi*2
   self:Spawn(self.Wave%3==0 and "Elite" or (i%2==0 and "Fast" or "Weak"),Vector3.new(math.cos(angle)*100,5,math.sin(angle)*100))
  end
 end
 if r.Mode=="Survival" and not self.BossSpawned and elapsed>=135 then
  if self:Count()>=C.Config.MaxNPCs then for m,a in pairs(self.NPCs) do if not a.Owner then self:Remove(m); break end end end
  local boss=self:Spawn("Boss",Vector3.new(0,7,0))
  if boss then self.BossSpawned=true; C.Remotes.Effect:FireAllClients("Scare",Vector3.new(0,7,0),{255,80,100},18,boss.Model) end
 end
 local pathBudget=2
 for m,a in pairs(self.NPCs) do
  local root=C.U.root(m); local h=C.U.humanoid(m)
  if not root or not h or (a.Expires and now>a.Expires) or (a.Owner and not a.Owner.Alive) or root.Position.Y<C.Config.KillY then self:Remove(m)
  elseif a.Alive then
   local targets=C.CombatService:Targets(a,220); local target=targets[1]; local tr=target and C.U.root(target.Model)
   if tr and now>a.StunUntil then
    h.WalkSpeed=a.Definition.WalkSpeed
    local distance=(tr.Position-root.Position).Magnitude
    if distance<7+(a.Role=="Boss" and 3 or 0) and now>a.NextHit and C.CombatService:Visible(root.Position,target,{m}) then
     a.NextHit=now+1.1; C.DamageService:Apply(a.Owner or a,target,a.Power,root.Position,15)
     C.Remotes.Effect:FireAllClients("Cast",root.Position,{255,75,100},4,m,"Basic")
    end
    if C.CombatService:Visible(root.Position,target,{m}) then h:MoveTo(tr.Position)
    elseif now>a.NextPath and not a.PathPending and pathBudget>0 then
     pathBudget=pathBudget-1; a.PathPending=true; a.NextPath=now+2
     local start=root.Position; local goal=tr.Position; local token=r.Token
     task.spawn(function()
      local path=Pathfinding:CreatePath({AgentRadius=a.Role=="Boss" and 3 or 2,AgentHeight=6,AgentCanJump=true})
      local ok=pcall(function() path:ComputeAsync(start,goal) end)
      if ok and a.Alive and self.NPCs[m] and token==r.Token and path.Status==Enum.PathStatus.Success then a.Waypoints=path:GetWaypoints(); a.Waypoint=2 end
      a.PathPending=false
     end)
    elseif a.Waypoints then
     local wp=a.Waypoints[a.Waypoint]
     if wp then h:MoveTo(wp.Position); if wp.Action==Enum.PathWaypointAction.Jump then h.Jump=true end
      if (wp.Position-root.Position).Magnitude<5 then a.Waypoint=a.Waypoint+1 end
     end
    end
   else h.WalkSpeed=0 end
  end
 end
end
function S:Cleanup()
 local list={}; for m in pairs(self.NPCs) do table.insert(list,m) end
 for _,m in ipairs(list) do self:Remove(m) end
 self.Wave=0; self.LastWave=0; self.BossDefeated=false; self.BossSpawned=false
end
return S
