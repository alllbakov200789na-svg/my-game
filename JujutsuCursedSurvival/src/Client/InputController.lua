local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local S={}
function S:Init(ctx)
 self.C=ctx
 local function cast(index)
  if UIS:GetFocusedTextBox() or ctx.UIController.Modal.Visible then return end
  self:Cast(index)
 end
 local keys={Enum.KeyCode.Q,Enum.KeyCode.E,Enum.KeyCode.R,Enum.KeyCode.F,Enum.KeyCode.T}
 for i,key in ipairs(keys) do CAS:BindAction("Technique"..i,function(_,state) if state==Enum.UserInputState.Begin then cast(i) end; return Enum.ContextActionResult.Sink end,false,key) end
 CAS:BindAction("Basic",function(_,state) if state==Enum.UserInputState.Begin then cast("Basic") end; return Enum.ContextActionResult.Pass end,false,Enum.UserInputType.MouseButton1,Enum.KeyCode.ButtonR2)
 CAS:BindAction("Heavy",function(_,state) if state==Enum.UserInputState.Begin then cast("Heavy") end; return Enum.ContextActionResult.Sink end,false,Enum.KeyCode.X)
 CAS:BindAction("Ultimate",function(_,state) if state==Enum.UserInputState.Begin then cast("Ultimate") end; return Enum.ContextActionResult.Sink end,false,Enum.KeyCode.G)
 CAS:BindAction("Sprint",function(_,state) ctx.Remotes.Sprint:FireServer(state==Enum.UserInputState.Begin); return Enum.ContextActionResult.Sink end,false,Enum.KeyCode.LeftShift,Enum.KeyCode.ButtonL3)
end
function S:Cast(index)
 local C=self.C; local v=C.Vitals; if not v or not v.Alive or not v.Participant then return end
 local id=type(index)=="number" and v.Abilities[index] or index
 if id=="Ultimate" then id=v.UltimateId end; if not id then return end
 local camera=workspace.CurrentCamera; local point=UIS.TouchEnabled and camera.ViewportSize/2 or UIS:GetMouseLocation()
 local ray=UIS.TouchEnabled and camera:ViewportPointToRay(point.X,point.Y) or camera:ScreenPointToRay(point.X,point.Y)
 local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances={C.Player.Character,workspace.GameplayEffects}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*300,rp)
 local target=hit and hit.Position or ray.Origin+ray.Direction*160
 local root=C.U.root(C.Player.Character); if not root then return end
 local delta=target-root.Position; if delta.Magnitude<0.1 then return end
 C.Remotes.Cast:FireServer(id,delta.Unit)
end
return S
