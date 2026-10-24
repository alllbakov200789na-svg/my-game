local S={}
function S:Init(ctx) self.C=ctx; self.Broken=0 end
function S:Blast(position,radius,power)
 local map=self.C.MapService.Active; if not map then return end
 local folder=map:FindFirstChild("Destructibles"); if not folder then return end
 for _,p in ipairs(folder:GetChildren()) do
  if p:IsA("BasePart") and p.CanCollide and (p.Position-position).Magnitude<radius+p.Size.Magnitude*0.25 then
   local hp=(p:GetAttribute("Health") or 30)-power; p:SetAttribute("Health",hp)
   if hp<=0 then
    self.Broken=self.Broken+1; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Transparency=1
    self.C.Remotes.Effect:FireAllClients("Debris",p.Position,{p.Color.R*255,p.Color.G*255,p.Color.B*255},math.min(p.Size.Magnitude,10))
   end
  end
 end
end
return S
