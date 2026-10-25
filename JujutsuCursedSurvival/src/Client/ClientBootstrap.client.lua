local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local shared=RS:WaitForChild("Shared")
local C={Player=Players.LocalPlayer,Config=require(shared:WaitForChild("Config")),Abilities=require(shared:WaitForChild("AbilityDefinitions")),
 Characters=require(shared:WaitForChild("CharacterDefinitions")),U=require(shared:WaitForChild("Utility")),Remotes={},Settings={LowFX=false,Shake=true,ReducedFlash=false,Scares=true,Sound=true}}
local folder=RS:WaitForChild("Remotes")
for _,name in ipairs({"Cast","Sprint","Action","State","Vitals","Effect","Role","Results","Profile","Notice"}) do C.Remotes[name]=folder:WaitForChild(name) end
local names={"SoundController","VFXController","CameraController","SpectatorController","UIController","CombatController","InputController"}
for _,name in ipairs(names) do C[name]=require(script.Parent:WaitForChild(name)) end
for _,name in ipairs(names) do C[name]:Init(C) end
C.Remotes.State.OnClientEvent:Connect(function(s) C.State=s; C.UIController:State(s); C.SpectatorController:Update() end)
C.Remotes.Vitals.OnClientEvent:Connect(function(v) C.Vitals=v; C.UIController:Vitals(v) end)
C.Remotes.Profile.OnClientEvent:Connect(function(d)
 if not d then return end
 C.Profile=d; for k,v in pairs(d.Settings or {}) do C.Settings[k]=v end
 C.UIController:Profile(d); C.VFXController:ApplyQuality()
end)
C.Remotes.Role.OnClientEvent:Connect(function(r) C.UIController:Role(r); C.CameraController:Intro() end)
C.Remotes.Results.OnClientEvent:Connect(function(r) C.UIController:Results(r) end)
C.Remotes.Notice.OnClientEvent:Connect(function(t) C.UIController:Notice(t) end)
C.Remotes.Effect.OnClientEvent:Connect(function(kind,pos,color,radius,model,id,extra)
 C.VFXController:Effect(kind,pos,color,radius,model,id,extra)
 C.SoundController:Play(id or kind,pos)
 C.CameraController:Effect(kind,pos,model)
 C.CombatController:Animate(kind,model,id)
end)
C.Player.CharacterAdded:Connect(function(char)
 local h=char:WaitForChild("Humanoid",10); if h then workspace.CurrentCamera.CameraSubject=h; workspace.CurrentCamera.CameraType=Enum.CameraType.Custom end
end)
task.spawn(function()
 for _=1,6 do C.Remotes.Action:FireServer("Sync"); task.wait(3); if C.Profile then break end end
end)
