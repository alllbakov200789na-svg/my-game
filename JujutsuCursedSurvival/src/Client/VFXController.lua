local Tween=game:GetService("TweenService")
local S={}
function S:Init(ctx) self.C=ctx; self.Pool={}; self.Active=0; self.Generation=0; self.Fragments=0 end
function S:Part(color,cf,size,shape,life,target,transparency)
 local limit=self.C.Settings.LowFX and 24 or 80
 if self.Active>=limit then return end
 local p=table.remove(self.Pool) or Instance.new("Part")
 p.Name="LocalVFX"; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
 p.Material=Enum.Material.Neon; p.Shape=shape or Enum.PartType.Ball; p.Color=self.C.U.color(color)
 p.CFrame=cf; p.Size=size; p.Transparency=transparency or 0.25; p.Parent=workspace.GameplayEffects
 self.Active=self.Active+1
 local tw=Tween:Create(p,TweenInfo.new(life,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=target or size*2,Transparency=1}); tw:Play()
 task.delay(life,function()
  tw:Cancel(); self.Active=math.max(0,self.Active-1)
  if p.Parent then p.Parent=nil; if #self.Pool<40 then table.insert(self.Pool,p) else p:Destroy() end end
 end)
 return p
end
function S:ApplyQuality()
 local low=self.C.Settings.LowFX
 for _,o in ipairs(workspace:GetDescendants()) do if o:IsA("ParticleEmitter") then o.Enabled=not low end end
 local bloom=game:GetService("Lighting"):FindFirstChildOfClass("BloomEffect")
 if bloom then bloom.Enabled=not self.C.Settings.ReducedFlash end
end
function S:Effect(kind,pos,color,radius,model,id,extra)
 local C=self.C; local cam=workspace.CurrentCamera
 if not C.U.vector(pos) or (cam.CFrame.Position-pos).Magnitude>220 then return end
 local reduced=C.Settings.ReducedFlash; local duration=reduced and 0.6 or 0.3
 if kind=="Debris" then
  local count=C.Settings.LowFX and 2 or 5
  for _=1,count do if self.Fragments<C.Config.MaxDebris then
   self.Fragments=self.Fragments+1
   local offset=Vector3.new(math.random(-8,8),math.random(2,9),math.random(-8,8))
   local p=self:Part(color,CFrame.new(pos),Vector3.new(0.7,0.7,0.7),Enum.PartType.Block,0.8,Vector3.new(0.3,0.3,0.3),0.15)
   if p then Tween:Create(p,TweenInfo.new(0.8),{Position=pos+offset,Orientation=Vector3.new(70,110,35)}):Play() end
   task.delay(0.8,function() self.Fragments=math.max(0,self.Fragments-1) end)
  end end
 elseif kind=="Projectile" then
  self:Part(color,CFrame.new(pos),Vector3.one*math.max(0.6,radius*0.35),Enum.PartType.Ball,0.15,nil,reduced and 0.7 or 0.1)
  if typeof(extra)=="Vector3" and not C.Settings.LowFX then
   local delta=pos-extra
   if delta.Magnitude>0.01 then self:Part(color,CFrame.lookAt((pos+extra)/2,pos),Vector3.new(0.18,0.18,delta.Magnitude),Enum.PartType.Block,0.15,Vector3.new(0.05,0.05,delta.Magnitude)) end
  end
 elseif kind=="Domain" then
  self:Part(color,CFrame.new(pos),Vector3.one*2,Enum.PartType.Ball,6,Vector3.one*radius*2,0.93)
  self:Part(color,CFrame.new(pos-Vector3.new(0,2.8,0))*CFrame.Angles(0,0,math.pi/2),Vector3.new(0.15,2,2),Enum.PartType.Cylinder,1,Vector3.new(0.15,radius*2,radius*2),0.65)
  if model==C.Player.Character then C.UIController:Notice(C.Abilities.Names[id] or "РАСШИРЕНИЕ ТЕРРИТОРИИ") end
 elseif kind=="Trap" then
  self:Part(color,CFrame.new(pos)*CFrame.Angles(0,0,math.pi/2),Vector3.new(0.1,radius*2,radius*2),Enum.PartType.Cylinder,type(extra)=="number" and extra or 8,Vector3.new(0.1,radius*2,radius*2),0.6)
 elseif kind=="Cast" then
  self:Part(color,CFrame.new(pos),Vector3.one*1.5,Enum.PartType.Ball,duration,Vector3.one*4,reduced and 0.8 or 0.5)
  if model and not C.Settings.LowFX then
   local root=C.U.root(model)
   if root then
    local a=Instance.new("Attachment"); a.Position=Vector3.new(-0.8,0,0); a.Parent=root
    local b=Instance.new("Attachment"); b.Position=Vector3.new(0.8,0,0); b.Parent=root
    local trail=Instance.new("Trail"); trail.Attachment0=a; trail.Attachment1=b; trail.Lifetime=0.25; trail.Color=ColorSequence.new(C.U.color(color)); trail.Transparency=NumberSequence.new(0.3,1); trail.Parent=a
    local beam=Instance.new("Beam"); beam.Attachment0=a; beam.Attachment1=b; beam.Color=trail.Color; beam.Width0=0.12; beam.Width1=0.12; beam.FaceCamera=true; beam.Parent=a
    task.delay(0.45,function() a:Destroy(); b:Destroy() end)
   end
  end
 else
  self:Part(color,CFrame.new(pos),Vector3.one,Enum.PartType.Ball,duration,Vector3.one*math.min(radius,12),reduced and 0.8 or 0.4)
  self:Part(color,CFrame.new(pos-Vector3.new(0,2,0))*CFrame.Angles(0,0,math.pi/2),Vector3.new(0.1,1,1),Enum.PartType.Cylinder,duration+0.2,Vector3.new(0.1,radius*2,radius*2),0.6)
 end
end
return S
