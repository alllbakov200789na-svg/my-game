local Players=game:GetService("Players")
local S={}
function S:Init(ctx)
 self.C=ctx; self.Actors={}; self.ByPlayer={}; self.Connections={}
 local desc=Instance.new("HumanoidDescription")
 desc.HeadColor=Color3.fromRGB(242,205,183); desc.LeftArmColor=desc.HeadColor; desc.RightArmColor=desc.HeadColor
 desc.TorsoColor=Color3.fromRGB(25,23,44); desc.LeftLegColor=desc.TorsoColor; desc.RightLegColor=desc.TorsoColor
 local ok,rig=pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(desc,Enum.HumanoidRigType.R15) end)
 desc:Destroy()
 assert(ok and rig,"R15 template creation failed: "..tostring(rig))
 self.Template=rig; rig.Name="ProceduralR15"; rig.Parent=game:GetService("ServerStorage").ServerAssets
 local h=ctx.U.humanoid(rig); h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
end
function S:Attach(model,name,size,offset,color,shape)
 local head=model:FindFirstChild("Head"); if not head then return end
 local p=Instance.new("Part"); p.Name=name; p.Size=size; p.Color=color; p.Material=Enum.Material.SmoothPlastic
 p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Massless=true
 if shape then p.Shape=shape end
 p.CFrame=head.CFrame*offset; p.Parent=model
 local w=Instance.new("WeldConstraint"); w.Part0=head; w.Part1=p; w.Parent=p
end
function S:Style(model,role,team)
 local C=self.C; local d=C.Characters[role]; local tint=C.U.color(d.VFXProfile)
 for _,o in ipairs(model:GetDescendants()) do
  if o:IsA("Accessory") or o:IsA("Shirt") or o:IsA("Pants") or o:IsA("ShirtGraphic") then o:Destroy()
  elseif o:IsA("BasePart") and o.Name~="HumanoidRootPart" then
   o.Material=Enum.Material.SmoothPlastic
   if o.Name~="Head" and not string.find(o.Name,"Hand") then o.Color=Color3.fromRGB(25,23,43) end
  end
 end
 self:Attach(model,"Collar",Vector3.new(1.6,0.6,1.15),CFrame.new(0,-0.65,0),tint)
 self:Attach(model,"Hair",Vector3.new(1.3,0.55,1.1),CFrame.new(0,0.55,0.04),role=="Gojo" and Color3.fromRGB(235,247,255) or Color3.fromRGB(95,40,75))
 for i=-2,2 do self:Attach(model,"HairSpike",Vector3.new(0.28,0.65,0.45),CFrame.new(i*0.24,0.75,-0.05)*CFrame.Angles(0,0,i*0.18),role=="Gojo" and Color3.fromRGB(235,247,255) or Color3.fromRGB(95,40,75)) end
 if role=="Gojo" then self:Attach(model,"Blindfold",Vector3.new(1.25,0.25,0.16),CFrame.new(0,0.12,-0.55),Color3.fromRGB(15,18,32))
 elseif role=="Sukuna" or role=="Curse" then
  for _,x in ipairs({-0.32,0.32}) do self:Attach(model,"CurseMark",Vector3.new(0.1,0.48,0.08),CFrame.new(x,0,-0.56)*CFrame.Angles(0,0,x),tint) end
 end
 local hi=Instance.new("Highlight"); hi.Name="TeamOutline"; hi.Adornee=model
 hi.FillTransparency=1; hi.OutlineTransparency=0.45; hi.OutlineColor=team=="Curses" and Color3.fromRGB(255,80,100) or Color3.fromRGB(90,185,255)
 hi.DepthMode=Enum.HighlightDepthMode.Occluded; hi.Parent=model
end
function S:Spawn(p,role,team,abilities,cf,participant)
 local C=self.C
 local old=self.ByPlayer[p]
 if old then old.Alive=false; self.Actors[old.Model]=nil; if old.Connection then old.Connection:Disconnect() end end
 if p.Character then p.Character:Destroy() end
 local model=self.Template:Clone(); model.Name=p.Name
 local d=C.Characters[role]; local h=C.U.humanoid(model); h.MaxHealth=d.BaseHealth; h.Health=d.BaseHealth; h.WalkSpeed=d.WalkSpeed
 h.BreakJointsOnDeath=false; h.DisplayName=p.DisplayName; h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.Viewer
 model:SetAttribute("Role",role); model:SetAttribute("Faction",team); model:SetAttribute("Participant",participant)
 self:Style(model,role,team)
 model:SetAttribute("Weapon",table.find(abilities,"Katana") and "Katana" or "Fists")
 if table.find(abilities,"Katana") then
  local hand=model:FindFirstChild("RightHand")
  if hand then
   local blade=Instance.new("Part"); blade.Name="CursedKatana"; blade.Size=Vector3.new(0.16,3.7,0.35); blade.Color=Color3.fromRGB(180,170,255); blade.Material=Enum.Material.Metal
   blade.CanCollide=false; blade.CanQuery=false; blade.CanTouch=false; blade.Massless=true; blade.CFrame=hand.CFrame*CFrame.new(0,-1.6,-0.5); blade.Parent=model
   local weld=Instance.new("WeldConstraint"); weld.Part0=hand; weld.Part1=blade; weld.Parent=blade
  end
 end
 model.Parent=workspace; model:PivotTo(cf); p.Character=model
 local root=C.U.root(model); if root then root:SetNetworkOwner(p) end
 local a={Model=model,Player=p,Role=role,Team=team,Definition=d,Alive=true,Participant=participant,Energy=d.Energy,
 Stamina=d.Stamina,Ultimate=0,Abilities=abilities,Cooldowns={},Actions=0,ActiveSeconds=0,Damage=0,Healed=0,
 UsedAbilities={},Eliminations=0,MotionGrace=os.clock()+3,SpawnAt=os.clock(),ShieldUntil=0,StunUntil=0}
 self.Actors[model]=a; self.ByPlayer[p]=a; C.AntiExploitService.Motion[p]=nil; p:SetAttribute("Spectator",not participant)
 a.Connection=h.Died:Connect(function() self:Die(a) end)
 self:Cosmetic(p)
 local profile=C.PlayerDataService:Get(p)
 if root and profile and profile.Entitlements.Spawn then C.Remotes.Effect:FireAllClients("Spawn",root.Position,{200,150,255},14,model) end
 return a
end
function S:Die(a)
 if not a.Alive then return end
 a.Alive=false; a.Sprinting=false; a.Model:SetAttribute("Dead",true)
 if a.Player then a.Player:SetAttribute("Spectator",true) end
 local killer=a.LastAttacker
 if killer and killer~=a and (os.clock()-(a.LastHitAt or 0))<8 then
  killer.Eliminations=(killer.Eliminations or 0)+1
  if killer.Player then
   self.C.QuestService:Progress(killer.Player,"Curse",a.Team=="Curses" and 1 or 0)
   self.C.PlayerDataService:Mutate(killer.Player,function(d) d.Eliminations=d.Eliminations+1 end)
   local d=self.C.PlayerDataService:Get(killer.Player)
   if d and d.EquippedCosmetics=="Eclipse" then self.C.Remotes.Effect:FireAllClients("Finisher",self.C.U.root(a.Model).Position,{240,225,255},9) end
  end
 end
end
function S:Lobby(p)
 if not p.Parent then return end
 return self:Spawn(p,"Sorcerer","Sorcerers",{},CFrame.new(0,7,360),false)
end
function S:Cosmetic(p)
 local d=self.C.PlayerDataService:Get(p); local a=self.ByPlayer[p]
 if not d or not a then return end
 local old=a.Model:FindFirstChild("Cosmetic"); if old then old:Destroy() end
 local c=self.C.Config.Cosmetics[d.EquippedCosmetics]; local root=self.C.U.root(a.Model)
 if not c or not root then return end
 local holder=Instance.new("Folder"); holder.Name="Cosmetic"; holder.Parent=a.Model
 local at=Instance.new("Attachment"); at.Name="AuraAttachment"; at.Parent=root
 local previous=root:FindFirstChild("PreviousAura"); if previous then previous:Destroy() end
 at.Name="PreviousAura"
 local emitter=Instance.new("ParticleEmitter"); emitter.Color=ColorSequence.new(self.C.U.color(c.Color))
 emitter.Rate=9; emitter.Lifetime=NumberRange.new(0.5,1); emitter.Speed=NumberRange.new(0.5,2)
 emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(1,0)})
 emitter.Transparency=NumberSequence.new(0.2,1); emitter.LightEmission=0.8; emitter.Parent=at
 holder.Destroying:Connect(function() if at.Parent then at:Destroy() end end)
end
function S:Transform(p)
 local a=self.ByPlayer[p]; if not a or not a.Alive then return false end
 local pos=a.Model:GetPivot()
 local b=self:Spawn(p,"Sukuna","Curses",table.clone(self.C.Characters.Sukuna.AbilitySet),pos,true)
 for _,key in ipairs({"Actions","ActiveSeconds","Damage","Healed","UsedAbilities","Eliminations","Objectives"}) do b[key]=a[key] end
 self.C.AntiExploitService.Motion[p]=nil
 return true
end
function S:Step(dt)
 local C=self.C
 for _,a in pairs(self.Actors) do
  if a.Alive then
   local h=C.U.humanoid(a.Model); local root=C.U.root(a.Model)
   if h and root then
    if root.Position.Y<C.Config.KillY then h.Health=0 end
    if a.Participant and C.RoundService:IsCombat() then
     a.Energy=math.min(100,a.Energy+C.Config.EnergyRegen*dt)
     local moving=h.MoveDirection.Magnitude>0.1
     if moving then a.ActiveSeconds=a.ActiveSeconds+dt end
     if a.Sprinting and moving and a.Stamina>0 and os.clock()>a.StunUntil then
      a.Stamina=math.max(0,a.Stamina-C.Config.SprintDrain*dt); h.WalkSpeed=a.Definition.SprintSpeed
     else a.Stamina=math.min(100,a.Stamina+C.Config.StaminaRegen*dt); h.WalkSpeed=a.Definition.WalkSpeed end
     if os.clock()<a.StunUntil then h.WalkSpeed=0; h.Jump=false end
     C.AntiExploitService:Step(a,dt)
    end
   end
  end
 end
end
function S:Remove(p)
 local a=self.ByPlayer[p]; if a then a.Alive=false; if a.Connection then a.Connection:Disconnect() end; self.Actors[a.Model]=nil end
 self.ByPlayer[p]=nil
end
return S
