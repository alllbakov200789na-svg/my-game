local S={}
function S:Init(ctx) self.C=ctx end
function S:Apply(attacker,target,amount,origin,knock)
 local C=self.C
 if not C.RoundService:IsCombat() or not attacker or not attacker.Alive or not target.Alive then return 0 end
 if attacker.Team==target.Team or not target.Participant then return 0 end
 if not C.U.finite(amount) or amount<=0 then return 0 end
 local h=C.U.humanoid(target.Model); local root=C.U.root(target.Model)
 if not h or not root or h.Health<=0 or os.clock()<(target.ShieldUntil or 0) then return 0 end
 local multiplier=1-(target.Definition.Defense or 0)
 if target.Team=="Curses" then multiplier=multiplier*(1+0.08*(C.MapService.Seals or 0)) end
 local damage=math.min(h.Health,amount*multiplier)
 target.LastAttacker=attacker; target.LastHitAt=os.clock()
 h:TakeDamage(damage)
 attacker.Damage=(attacker.Damage or 0)+damage; attacker.Ultimate=math.min(100,(attacker.Ultimate or 0)+damage*0.12)
 attacker.Actions=(attacker.Actions or 0)+1
 if attacker.Player then C.QuestService:Progress(attacker.Player,"Damage",math.floor(damage)) end
 if knock and origin then
  local v=root.Position-origin; if v.Magnitude>0.1 then
   local velocity=v.Unit*knock+Vector3.new(0,12,0)
   C.AntiExploitService:AuthorizeImpulse(target,velocity,1.3); root.AssemblyLinearVelocity=velocity
  end
 end
 C.Remotes.Effect:FireAllClients("Hit",root.Position,{255,240,220},3,target.Model)
 if h.Health<=0 then C.CharacterService:Die(target) end
 return damage
end
function S:Heal(a,target,amount)
 if not a.Alive or not target.Alive or a.Team~=target.Team or not target.Participant then return 0 end
 local h=self.C.U.humanoid(target.Model); if not h then return 0 end
 local healed=math.min(amount,h.MaxHealth-h.Health); h.Health=h.Health+healed
 if target~=a and healed>0 then
  a.Healed=(a.Healed or 0)+healed; a.Actions=a.Actions+1; a.Ultimate=math.min(100,a.Ultimate+healed*0.2)
  if a.Player then self.C.QuestService:Progress(a.Player,"Help",1) end
 end
 return healed
end
return S
