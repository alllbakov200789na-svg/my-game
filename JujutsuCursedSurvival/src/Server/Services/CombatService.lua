local S={}
function S:Init(ctx) self.C=ctx end
function S:Ray(origin,direction,exclude)
 local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances=exclude or {}
 rp.IgnoreWater=true; return workspace:Raycast(origin,direction,rp)
end
function S:Visible(origin,target,exclude)
 local root=self.C.U.root(target.Model); if not root then return false end
 local hit=self:Ray(origin,root.Position-origin,exclude)
 return not hit or hit.Instance:IsDescendantOf(target.Model)
end
function S:Area(a,center,radius,damage,knock,stun)
 local C=self.C; local hits=0
 for _,b in pairs(C.CharacterService.Actors) do
  local root=C.U.root(b.Model)
  if b~=a and b.Alive and b.Team~=a.Team and root and (root.Position-center).Magnitude<=radius and self:Visible(center,b,{a.Model}) then
   local dealt=C.DamageService:Apply(a,b,damage,center,knock)
   if dealt>0 then hits=hits+1; if stun then b.StunUntil=math.max(b.StunUntil or 0,os.clock()+stun) end end
  end
 end
 return hits
end
function S:Targets(a,range)
 local out={}; local root=self.C.U.root(a.Model); if not root then return out end
 for _,b in pairs(self.C.CharacterService.Actors) do
  local br=self.C.U.root(b.Model)
  if b.Alive and b.Participant and b.Team~=a.Team and br and (br.Position-root.Position).Magnitude<=range then table.insert(out,b) end
 end
 table.sort(out,function(x,y) return (self.C.U.root(x.Model).Position-root.Position).Magnitude<(self.C.U.root(y.Model).Position-root.Position).Magnitude end)
 return out
end
return S
