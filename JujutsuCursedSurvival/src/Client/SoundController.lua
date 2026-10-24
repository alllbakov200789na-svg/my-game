local Content=game:GetService("ContentProvider")
local Debris=game:GetService("Debris")
local S={}
function S:Init(ctx)
 self.C=ctx; self.Active=0
 local ids={}; for _,id in pairs(ctx.Config.Sounds) do if type(id)=="string" and id~="" then table.insert(ids,id) end end
 if #ids>0 then task.spawn(function() pcall(function() Content:PreloadAsync(ids) end) end) end
end
function S:Play(id,pos)
 local C=self.C; local asset=C.Config.Sounds[id]
 if not C.Settings.Sound or not asset or self.Active>=12 then return end
 local camera=workspace.CurrentCamera; if (camera.CFrame.Position-pos).Magnitude>160 then return end
 local p=Instance.new("Part"); p.Anchored=true; p.Transparency=1; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false; p.Position=pos; p.Parent=workspace.GameplayEffects
 local sound=Instance.new("Sound"); sound.SoundId=asset; sound.Volume=0.35; sound.RollOffMaxDistance=130; sound.Parent=p
 self.Active=self.Active+1; sound:Play(); Debris:AddItem(p,5)
 task.delay(5,function() self.Active=math.max(0,self.Active-1) end)
end
return S
