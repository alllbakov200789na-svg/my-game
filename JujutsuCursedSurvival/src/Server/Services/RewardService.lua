local S={}
function S:Init(ctx) self.C=ctx; self.Awarded={} end
function S:Award(roundId,winner,reason)
 if self.Awarded[roundId] then return end
 self.Awarded={[roundId]=true}; local C=self.C
 for p,a in pairs(C.CharacterService.ByPlayer) do
  if a.Participant and p.Parent then
   local active=a.Actions>=C.Config.AFKMinimumActions and a.ActiveSeconds>=C.Config.AFKMinimumSeconds
   local won=a.Team==winner; local scale=C.RoundService.PlayerCount==1 and 0.5 or 1
   local coins=active and math.floor((25+(won and C.Modes[C.RoundService.Mode].Reward or 0)+math.min(30,(a.Objectives or 0)*10))*scale) or 0
   local xp=active and math.floor((40+(won and 70 or 0)+math.min(40,(a.Damage or 0)/30))*scale) or 0
   C.PlayerDataService:Mutate(p,function(d)
    if active then
     d.Coins=d.Coins+coins; d.XP=d.XP+xp; d.Level=1+math.floor(math.sqrt(d.XP/100)); d.TotalMatches=d.TotalMatches+1
     if won then d.TotalWins=d.TotalWins+1; local key=a.Team=="Curses" and "CurseWins" or "SorcererWins"; d[key]=d[key]+1 end
     if d.Level>=5 then d.OwnedCosmetics.Azure=true end
    end
   end)
   if active then C.QuestService:Progress(p,"Rounds",1); if a.Alive then C.QuestService:Progress(p,"Survive",1) end end
   C.Remotes.Results:FireClient(p,{Winner=winner,Won=won,Reason=reason,Coins=coins,XP=xp,Damage=math.floor(a.Damage or 0),
    Eliminations=a.Eliminations or 0,Active=active,Profile=C.PlayerDataService:Public(p)})
  end
 end
end
return S
