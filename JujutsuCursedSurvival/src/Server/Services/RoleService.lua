local S={}
function S:Init(ctx) self.C=ctx end
function S:Abilities(rng)
 local A=self.C.Abilities; local pool=self.C.U.shuffle(A.Pool,rng); local first=pool[1]
 for i=2,#pool do if not (A.Incompatible[first] and A.Incompatible[first][pool[i]]) then return {first,pool[i]} end end
 error("No compatible ability pair")
end
function S:Assign(players,mode,rng)
 local C=self.C; local remaining=table.clone(players); local roles={}
 local function pick(role,team)
  local sum=0
  for _,p in ipairs(remaining) do local d=C.PlayerDataService:Get(p); sum=sum+1+math.min(d and d.RolePity or 0,15)*0.3 end
  local n=rng:NextNumber()*sum; local chosen=#remaining
  for i,p in ipairs(remaining) do local d=C.PlayerDataService:Get(p); n=n-(1+math.min(d and d.RolePity or 0,15)*0.3); if n<=0 then chosen=i; break end end
  local p=table.remove(remaining,chosen); if p then roles[p]={Role=role,Team=team,Special=true}; return p end
  return nil
 end
 local carrier
 if mode=="Hunt" or mode=="Clash" then pick("Sukuna","Curses"); pick("Gojo","Sorcerers")
 elseif mode=="Invasion" then pick("Curse","Curses"); pick("Curse","Curses")
 elseif mode=="Betrayal" then carrier=pick("Sorcerer","Sorcerers") end
 local counts={Sorcerers=0,Curses=0}; for _,r in pairs(roles) do counts[r.Team]=counts[r.Team]+1 end
 for _,p in ipairs(C.U.shuffle(remaining,rng)) do
  local team="Sorcerers"
  if mode=="Clash" and counts.Curses<counts.Sorcerers then team="Curses" end
  roles[p]={Role="Sorcerer",Team=team}; counts[team]=counts[team]+1
 end
 for p,r in pairs(roles) do
  r.Abilities=r.Role=="Sorcerer" and self:Abilities(rng) or table.clone(C.Characters[r.Role].AbilitySet)
  C.PlayerDataService:Mutate(p,function(d) d.RolePity=r.Special and 0 or math.min(50,d.RolePity+1) end)
 end
 return roles,carrier
end
return S
