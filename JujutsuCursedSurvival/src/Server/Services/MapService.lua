local SS=game:GetService("ServerStorage")
local SpawnSafety=require(script.Parent.SpawnSafety)
local S={}
function S:Init(ctx) self.C=ctx; self.Connections={}; self.Seals=0; self.Holds={} end
function S:Load(id,mode)
 self:Cleanup(); local template=SS.Maps:FindFirstChild(id); assert(template,"Missing map "..id)
 self.Active=template:Clone(); self.Active.Name="ActiveMap"; self.Active.Parent=workspace
 self.Seals=0; self.Mode=mode; self.C.DestructionService.Broken=0
 for _,p in ipairs(self.Active.Destructibles:GetChildren()) do
  local tier=string.match(p.Name,"^(%w+)_"); p:SetAttribute("Tier",tier)
  p:SetAttribute("Health",tier=="Heavy" and 130 or tier=="Medium" and 65 or 25)
 end
 if mode=="Clash" then
  local arena=Instance.new("Part"); arena.Name="ClashArena"; arena.Shape=Enum.PartType.Cylinder; arena.Size=Vector3.new(0.2,70,70)
  arena.CFrame=CFrame.new(0,0.5,0)*CFrame.Angles(0,0,math.pi/2); arena.Anchored=true; arena.Material=Enum.Material.Marble; arena.Color=Color3.fromRGB(55,51,85); arena.Parent=self.Active
 end
 local objs=self.Active:FindFirstChild("Objectives")
 -- Validate once during Loading, before any player is moved out of the lobby.
 self.SpawnSafety=SpawnSafety.new(self.Active,self.C.Config.ArenaRadius)
 SpawnSafety.CheckObjectives(self.SpawnSafety,objs)
 for i,p in ipairs(objs:GetChildren()) do
  p:SetAttribute("Activated",false)
  local prompt=Instance.new("ProximityPrompt"); prompt.Name="SealPrompt"; prompt.ActionText="Активировать"; prompt.ObjectText="Печать "..i
  prompt.KeyboardKeyCode=Enum.KeyCode.Y; prompt.HoldDuration=4; prompt.MaxActivationDistance=10; prompt.RequiresLineOfSight=true; prompt.Enabled=mode~="Clash"; prompt.Parent=p
  self.Connections[#self.Connections+1]=prompt.PromptButtonHoldBegan:Connect(function(player)
   self.Holds[player]={Part=p,Since=os.clock(),Last=os.clock(),Progress=0}
  end)
  self.Connections[#self.Connections+1]=prompt.PromptButtonHoldEnded:Connect(function(player)
   local hold=self.Holds[player]; if hold and hold.Part==p and hold.Progress<3.5 then self.Holds[player]=nil end
  end)
  self.Connections[#self.Connections+1]=prompt.Triggered:Connect(function(player)
   local a=self.C.CharacterService.ByPlayer[player]; local root=a and self.C.U.root(a.Model); local hold=self.Holds[player]
   if not self.C.RoundService:IsCombat() or not a or not a.Alive or not a.Participant or a.Team~="Sorcerers" then return end
   if not root or (root.Position-p.Position).Magnitude>12 or not hold or hold.Part~=p or hold.Progress<3.5 then return end
   if p:GetAttribute("Activated") then return end
   p:SetAttribute("Activated",true); prompt.Enabled=false; p.Color=Color3.fromRGB(80,255,200); self.Seals=self.Seals+1; self.Holds[player]=nil
   a.Actions=a.Actions+3; a.Ultimate=math.min(100,a.Ultimate+25); a.Objectives=(a.Objectives or 0)+1
   self.C.QuestService:Progress(player,"Help",1)
   self.C.Remotes.Effect:FireAllClients("Burst",p.Position,{80,255,200},15)
  end)
 end
 local pickups=self.Active:FindFirstChild("Pickups")
 for _,p in ipairs(pickups:GetChildren()) do
  local prompt=Instance.new("ProximityPrompt"); prompt.ActionText="Подобрать"; prompt.ObjectText="Проклятая энергия +35"
  prompt.KeyboardKeyCode=Enum.KeyCode.Y; prompt.HoldDuration=0.2; prompt.MaxActivationDistance=8; prompt.Parent=p
  self.Connections[#self.Connections+1]=prompt.Triggered:Connect(function(player)
   local a=self.C.CharacterService.ByPlayer[player]; local root=a and self.C.U.root(a.Model)
   if not self.C.RoundService:IsCombat() or not a or not a.Participant or not a.Alive or not root or (root.Position-p.Position).Magnitude>10 or not prompt.Enabled then return end
   if a.Energy>=100 then return end
   prompt.Enabled=false; p.Transparency=1; a.Energy=math.min(100,a.Energy+35)
  end)
 end
end
function S:Spawn(index,team)
 assert(self.SpawnSafety,"Map must be validated before spawning")
 if self.Mode=="Clash" then
  local cf=SpawnSafety.Find(self.SpawnSafety,CFrame.new((team=="Curses" and 1 or -1)*27,5,(index-1)*5-15))
  if cf then return cf end
 end
 local folder=self.Active and self.Active:FindFirstChild("SpawnPoints")
 local list=folder and folder:GetChildren() or {}; table.sort(list,function(a,b) return a.Name<b.Name end)
 assert(#list>0,"Map has no spawn points")
 local offset=team=="Curses" and math.floor(#list/2) or 0
 for retry=0,#list-1 do
  local point=list[((index-1+offset+retry)%#list)+1]
  if point:IsA("BasePart") then
   local requested=point.CFrame+Vector3.new(0,4,0)
   local cf=SpawnSafety.Find(self.SpawnSafety,requested)
   if cf then
    if retry>0 or Vector3.new(cf.X-requested.X,0,cf.Z-requested.Z).Magnitude>1 then
     warn("[Spawn] Safe alternative",self.Active.Name,point.Name,team,cf.Position)
    end
    return cf
   end
  end
 end
 error("No safe unoccupied spawn with a route to objectives on "..self.Active.Name)
end
function S:Step(dt)
 for p,hold in pairs(self.Holds) do
  local a=self.C.CharacterService.ByPlayer[p]; local root=a and self.C.U.root(a.Model)
  if not root or not a.Alive or not hold.Part.Parent or not self.C.RoundService:IsCombat() or (root.Position-hold.Part.Position).Magnitude>12 then self.Holds[p]=nil
  else
   local hit=self.C.CombatService:Ray(root.Position,hold.Part.Position-root.Position,{a.Model})
   if hit and hit.Instance~=hold.Part then self.Holds[p]=nil else hold.Progress=hold.Progress+dt end
  end
 end
end
function S:Cleanup()
 for _,c in ipairs(self.Connections) do c:Disconnect() end; self.Connections={}; self.Holds={}
 if self.Active then self.Active:Destroy(); self.Active=nil end
 self.SpawnSafety=nil
 self.Seals=0
end
return S

