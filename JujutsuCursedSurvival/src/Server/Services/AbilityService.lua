local S={}
function S:Init(ctx) self.C=ctx; self.Tasks={} end
function S:Valid(a,token) return a.Alive and a.Model.Parent and self.C.RoundService.Token==token and self.C.RoundService:IsCombat() end
function S:Cast(p,id,direction)
 local C=self.C
 if type(id)~="string" or #id>32 or not C.AntiExploitService:Allow(p,"Cast",7,10) then return end
 local a=C.CharacterService.ByPlayer[p]; local def=C.Abilities[id]
 if not a or not a.Participant or not a.Alive or not C.RoundService:IsCombat() or not def then return end
 if id~="Basic" and id~="Heavy" and id~=a.Definition.UltimateAbility and not table.find(a.Abilities,id) then C.AntiExploitService:Flag(p,"ability ownership"); return end
 if not C.U.vector(direction) or direction.Magnitude<0.5 or direction.Magnitude>1.5 then C.AntiExploitService:Flag(p,"invalid aim"); return end
 direction=direction.Unit
 local root=C.U.root(a.Model); if not root then return end
 local now=os.clock()
 if now<a.StunUntil or now<(a.CastUntil or 0) or now<(a.Cooldowns[id] or 0) or a.Energy<def.Cost then return end
 local ultimate=id==a.Definition.UltimateAbility
 if ultimate and a.Ultimate<100 then return end
 -- Reserve resources synchronously, before creating any deferred effect.
 a.Cooldowns[id]=now+def.Cooldown; a.CastUntil=now+math.min(def.Duration,0.45); a.Energy=a.Energy-def.Cost
 if ultimate then a.Ultimate=0 end
 if not a.UsedAbilities[id] then a.UsedAbilities[id]=true; C.QuestService:Progress(p,"Abilities",1) end
 local token=C.RoundService.Token; local origin=root.Position
 local facing=Vector3.new(direction.X,0,direction.Z)
 if facing.Magnitude>0.05 then root.CFrame=CFrame.lookAt(origin,origin+facing.Unit) end
 C.Remotes.Effect:FireAllClients("Cast",origin,def.Color,def.Radius,a.Model,id)
 local function area(center,damage,radius,knock,stun)
  if not self:Valid(a,token) then return end
  C.CombatService:Area(a,center,radius or def.Radius,damage,knock,stun)
 end
 if def.Kind=="Melee" then
  local power=id=="Basic" and a.Definition.AttackPower or def.Damage
  for _,b in ipairs(C.CombatService:Targets(a,def.Range)) do
   local br=C.U.root(b.Model); local v=br.Position-origin
   if v.Magnitude>0 and v.Unit:Dot(direction)>0.25 and C.CombatService:Visible(origin,b,{a.Model}) then C.DamageService:Apply(a,b,power,origin,id=="Heavy" and 45 or 15) end
  end
  C.DestructionService:Blast(origin+direction*5,7,power)
 elseif def.Kind=="Projectile" then
  task.spawn(function()
   local position=origin+direction*3; local traveled=0; local speed=115; local step=0.05
   while self:Valid(a,token) and traveled<def.Range do
    local segment=direction*math.min(speed*step,def.Range-traveled)
    local hit=C.CombatService:Ray(position,segment,{a.Model,workspace.GameplayEffects})
    local nextPos=hit and hit.Position or position+segment
    C.Remotes.Effect:FireAllClients("Projectile",nextPos,def.Color,def.Radius,nil,id,position)
    if hit then
     local impact=nextPos-direction*0.35
     area(impact,def.Damage,nil,25,id=="IceSpear" and 1.2 or nil)
     C.DestructionService:Blast(impact,def.Radius,def.Damage); break
    end
    position=nextPos; traveled=traveled+segment.Magnitude; task.wait(step)
   end
  end)
 elseif def.Kind=="Push" or def.Kind=="Pull" or def.Kind=="Stun" then
  local hit=C.CombatService:Ray(origin,direction*def.Range,{a.Model})
  local center=hit and hit.Position-direction*0.5 or origin+direction*math.min(def.Range,20)
  area(center,def.Damage,def.Radius,def.Kind=="Push" and 65 or nil,def.Kind=="Stun" and def.Duration or nil)
  if def.Kind=="Pull" then
   for _,b in ipairs(C.CombatService:Targets(a,def.Range+def.Radius)) do
    local br=C.U.root(b.Model); local delta=center-br.Position
    if delta.Magnitude<def.Radius and delta.Magnitude>1 and C.CombatService:Visible(center,b,{a.Model}) then
     local velocity=delta.Unit*48; C.AntiExploitService:AuthorizeImpulse(b,velocity,1)
     br.AssemblyLinearVelocity=velocity
    end
   end
  end
  C.Remotes.Effect:FireAllClients("Burst",center,def.Color,def.Radius)
  C.DestructionService:Blast(center,def.Radius,def.Damage)
 elseif def.Kind=="Shield" then
  a.ShieldUntil=now+def.Duration; a.Model:SetAttribute("ShieldUntil",workspace:GetServerTimeNow()+def.Duration)
 elseif def.Kind=="HealSelf" then C.DamageService:Heal(a,a,def.Damage)
 elseif def.Kind=="Heal" then
  for _,b in pairs(C.CharacterService.Actors) do
   local br=C.U.root(b.Model)
   if br and (br.Position-origin).Magnitude<=def.Range and C.CombatService:Visible(origin,b,{a.Model}) then C.DamageService:Heal(a,b,def.Damage) end
  end
 elseif def.Kind=="Teleport" or def.Kind=="Dash" then
  local flat=Vector3.new(direction.X,0,direction.Z); if flat.Magnitude<0.1 then return end; flat=flat.Unit
  -- Blockcast checks character width; ground and arena bounds are independently validated.
  local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Exclude; rp.FilterDescendantsInstances={a.Model,workspace.GameplayEffects}
  local hit=workspace:Blockcast(root.CFrame,Vector3.new(3,4,3),flat*def.Range,rp)
  local length=hit and math.max(0,hit.Distance-2) or def.Range
  local pos=origin+flat*length; local ground=C.CombatService:Ray(pos+Vector3.new(0,3,0),Vector3.new(0,-16,0),{a.Model})
  if ground and math.abs(pos.X)<C.Config.ArenaRadius and math.abs(pos.Z)<C.Config.ArenaRadius then
   pos=Vector3.new(pos.X,ground.Position.Y+3.2,pos.Z)
   root.CFrame=CFrame.lookAt(pos,pos+flat); root.AssemblyLinearVelocity=Vector3.zero
   C.AntiExploitService:ResetMotion(a,pos)
   if def.Kind=="Dash" then area(pos,def.Damage,nil,35) end
  end
 elseif def.Kind=="Domain" then
  C.Remotes.Effect:FireAllClients("Domain",origin,def.Color,def.Radius,a.Model,id)
  task.spawn(function()
   for _=1,math.floor(def.Duration) do
    if not self:Valid(a,token) then break end
    area(origin,def.Damage,nil,nil,id=="UnlimitedVoid" and 0.65 or nil)
    C.DestructionService:Blast(origin,def.Radius,20); task.wait(1)
   end
  end)
 elseif def.Kind=="Trap" then
  local hit=C.CombatService:Ray(origin,direction*def.Range,{a.Model})
  local center=hit and hit.Position-direction or origin+direction*def.Range
  local ground=C.CombatService:Ray(center+Vector3.new(0,6,0),Vector3.new(0,-30,0),{a.Model})
  if ground then center=ground.Position+Vector3.new(0,0.3,0) end
  C.Remotes.Effect:FireAllClients("Trap",center,def.Color,def.Radius,nil,id,def.Duration)
  task.spawn(function()
   local finish=os.clock()+def.Duration
   while self:Valid(a,token) and os.clock()<finish do
    if C.CombatService:Area(a,center+Vector3.new(0,2,0),def.Radius,def.Damage,0,2)>0 then break end
    task.wait(0.25)
   end
  end)
 elseif def.Kind=="Summon" then C.NPCService:Summon(a,def,token) end
end
return S
