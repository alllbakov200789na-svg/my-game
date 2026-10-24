local Tween=game:GetService("TweenService")
local Run=game:GetService("RunService")
local S={}
function S:Init(ctx) self.C=ctx; self.Serial=0; self.ShakeUntil=0
 Run:BindToRenderStep("CursedCamera",Enum.RenderPriority.Camera.Value+1,function()
  local camera=workspace.CurrentCamera
  if ctx.Settings.Shake and not ctx.Settings.ReducedFlash and os.clock()<self.ShakeUntil then
   local amount=0.06*(self.ShakeUntil-os.clock())/0.2
   camera.CFrame=camera.CFrame*CFrame.new(math.sin(os.clock()*91)*amount,math.cos(os.clock()*73)*amount,0)
  end
 end)
end
function S:Intro()
 local C=self.C; local root=C.U.root(C.Player.Character); if not root then return end
 self.Serial=self.Serial+1; local serial=self.Serial; local camera=workspace.CurrentCamera
 camera.CameraType=Enum.CameraType.Scriptable
 camera.CFrame=CFrame.lookAt(root.Position+root.CFrame.LookVector*13+Vector3.new(5,5,0),root.Position)
 Tween:Create(camera,TweenInfo.new(1.6,Enum.EasingStyle.Sine),{CFrame=CFrame.lookAt(root.Position+root.CFrame.LookVector*8+Vector3.new(-3,2,0),root.Position+Vector3.new(0,1,0))}):Play()
 task.delay(1.7,function() if serial==self.Serial then camera.CameraType=Enum.CameraType.Custom; camera.CameraSubject=C.U.humanoid(C.Player.Character) end end)
end
function S:Effect(kind,pos,model)
 local C=self.C; local root=C.U.root(C.Player.Character); if not root then return end
 local distance=(root.Position-pos).Magnitude
 if kind=="Hit" and distance<15 then self.ShakeUntil=os.clock()+0.2 end
 if kind=="Domain" and distance<70 and not C.Settings.ReducedFlash then
  local cam=workspace.CurrentCamera; Tween:Create(cam,TweenInfo.new(0.25),{FieldOfView=80}):Play()
  task.delay(0.7,function() Tween:Create(cam,TweenInfo.new(0.6),{FieldOfView=70}):Play() end)
 end
 if kind=="Scare" and C.Settings.Scares then C.UIController:Notice("РАЗЛОМ ОТКРЫТ • ПРОКЛЯТИЕ ПРОБУДИЛОСЬ") end
end
return S
