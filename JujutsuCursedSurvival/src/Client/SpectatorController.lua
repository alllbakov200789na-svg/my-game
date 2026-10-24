local Players=game:GetService("Players")
local S={}
function S:Init(ctx) self.C=ctx; self.Index=0
 ctx.Player:GetAttributeChangedSignal("Spectator"):Connect(function() self:Update() end)
end
function S:Update()
 local C=self.C; local enabled=C.Player:GetAttribute("Spectator") and C.State and (C.State.State=="InProgress" or C.State.State=="SuddenDeath")
 if C.UIController.Spectate then C.UIController.Spectate.Visible=enabled==true end
 if not enabled then
  local h=C.U.humanoid(C.Player.Character); if h then workspace.CurrentCamera.CameraSubject=h end
 end
end
function S:Next()
 local list={}
 for _,p in ipairs(Players:GetPlayers()) do
  local char=p.Character; local h=self.C.U.humanoid(char)
  if p~=self.C.Player and char and char:GetAttribute("Participant") and h and h.Health>0 then table.insert(list,p) end
 end
 table.sort(list,function(a,b) return a.UserId<b.UserId end)
 if #list==0 then self.C.UIController:Notice("Нет доступных участников"); return end
 self.Index=self.Index%#list+1; local p=list[self.Index]; workspace.CurrentCamera.CameraType=Enum.CameraType.Custom
 workspace.CurrentCamera.CameraSubject=self.C.U.humanoid(p.Character); self.C.UIController:Notice("Наблюдение: "..p.DisplayName)
end
return S
