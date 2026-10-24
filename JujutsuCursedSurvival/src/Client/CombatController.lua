local Run=game:GetService("RunService")
local S={}
function S:Init(ctx)
 self.C=ctx; self.Poses=setmetatable({},{__mode="k"}); self.Rigs=setmetatable({},{__mode="k"}); self.Scan=0
 -- Procedural R15 locomotion and combat; no unpublished AnimationId is represented as working.
 Run.PreSimulation:Connect(function(dt)
  self.Scan=self.Scan+dt
  if self.Scan>1 then
   self.Scan=0
   for _,m in ipairs(workspace:GetChildren()) do if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and not self.Rigs[m] then
    local joints={}; for _,v in ipairs(m:GetDescendants()) do if v:IsA("Motor6D") then joints[v.Name]=v end end
    self.Rigs[m]=joints
   end end
  end
  for m,joints in pairs(self.Rigs) do
   if not m.Parent then self.Rigs[m]=nil else
    local h=ctx.U.humanoid(m); local root=ctx.U.root(m)
    if h and root then
     local speed=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude
     local t=os.clock(); local stride=math.sin(t*(speed>20 and 15 or 10))*math.min(speed/22,1)*0.65
     local pose=self.Poses[m]; local cast=pose and t<pose.Until; local dead=h.Health<=0
     local air=h.FloorMaterial==Enum.Material.Air; local attack=cast and (pose.Kind=="Hit" and -0.35 or -1.8) or 0
     local transforms={LeftShoulder=CFrame.Angles(air and -0.5 or stride,0,-0.08),
      RightShoulder=CFrame.Angles(cast and attack or (air and -0.5 or -stride),0,cast and -0.4 or 0.08),
      LeftHip=CFrame.Angles(air and -0.25 or -stride,0,0),RightHip=CFrame.Angles(air and 0.2 or stride,0,0),
      Waist=CFrame.Angles(dead and -0.9 or (cast and -0.12 or math.sin(t*2)*0.025),0,0),
      Neck=CFrame.Angles(dead and 0.5 or 0,0,0)}
     if cast and pose.Kind=="Emote" then transforms.RightShoulder=CFrame.Angles(-2.8,0,math.sin(t*10)*0.3) end
     for name,cf in pairs(transforms) do if joints[name] then joints[name].Transform=cf end end
    end
   end
  end
 end)
end
function S:Animate(kind,model,id)
 if model and (kind=="Cast" or kind=="Hit" or kind=="Domain" or kind=="Emote") then
  self.Poses[model]={Kind=kind,Id=id,Until=os.clock()+(kind=="Domain" and 1.2 or kind=="Emote" and 2 or 0.35)}
 end
end
return S
