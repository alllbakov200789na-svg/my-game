local Players=game:GetService("Players")
local S={}
local nextStates={
 WaitingForPlayers={Intermission=true},Intermission={VotingOrSelection=true,WaitingForPlayers=true},
 VotingOrSelection={Loading=true,WaitingForPlayers=true},Loading={Intro=true,Cleanup=true},Intro={InProgress=true,Cleanup=true},
 InProgress={SuddenDeath=true,Results=true,Cleanup=true},SuddenDeath={Results=true,Cleanup=true},
 Results={Cleanup=true},Cleanup={WaitingForPlayers=true},
}
function S:Init(ctx)
 self.C=ctx; self.State="WaitingForPlayers"; self.Token=0; self.RoundId=0; self.PlayerCount=0; self.Deadline=0; self.TeamWins={Sorcerers=0,Curses=0}
end
function S:IsCombat() return self.State=="InProgress" or self.State=="SuddenDeath" end
function S:Transition(state,seconds)
 if state==self.State then return false end
 assert(nextStates[self.State] and nextStates[self.State][state],"Illegal transition "..self.State.." -> "..state)
 self.State=state; self.Deadline=workspace:GetServerTimeNow()+(seconds or 0); self:Broadcast(); return true
end
function S:EligiblePlayers()
 local list={}; for _,p in ipairs(Players:GetPlayers()) do if self.C.PlayerDataService:Get(p) and p:GetAttribute("Ready") then table.insert(list,p) end end
 return list
end
function S:Broadcast()
 local C=self.C; local alive=0
 for _,a in pairs(C.CharacterService.Actors) do if a.Player and a.Alive and a.Participant then alive=alive+1 end end
 local mode=self.Mode and C.Modes[self.Mode]
 C.Remotes.State:FireAllClients({State=self.State,Deadline=self.Deadline,Mode=mode and mode.Name or "CURSED SURVIVAL",
 ModeId=self.Mode,Objective=mode and mode.Objective or "Ожидание игроков. Один игрок запускает тренировку с NPC.",
 Map=self.MapName,Seals=C.MapService.Seals,Alive=alive,Wave=C.NPCService.Wave,NPCs=C.NPCService:Count(),
 RoundId=self.RoundId,TeamWins=self.TeamWins,Revealed=self.Revealed,Training=self.PlayerCount==1})
end
function S:Countdown(seconds,abortEmpty)
 local untilTime=os.clock()+seconds
 while os.clock()<untilTime and not self.Closing do
  if abortEmpty and #self:EligiblePlayers()==0 then return false end
  self:Broadcast(); task.wait(math.min(0.5,math.max(0,untilTime-os.clock())))
 end
 return not self.Closing
end
function S:RevealCarrier()
 local C=self.C; local a=self.Carrier and C.CharacterService.ByPlayer[self.Carrier]
 if not a or not a.Alive or not self.Carrier.Parent then
  local candidates={}; for p,b in pairs(C.CharacterService.ByPlayer) do if b.Participant and b.Alive and p.Parent then table.insert(candidates,p) end end
  if #candidates<2 then self.ForcedResult={"Sorcerers","Носитель исчез; оставшиеся маги спасены"}; return end
  self.Carrier=candidates[C.Rng:NextInteger(1,#candidates)]
 end
 if C.CharacterService:Transform(self.Carrier) then
  self.Revealed=true
  local b=C.CharacterService.ByPlayer[self.Carrier]
  C.Remotes.Role:FireClient(self.Carrier,{Name=b.Definition.DisplayName,Role=b.Role,Team=b.Team,Abilities=b.Abilities,Ultimate=b.Definition.UltimateAbility})
  C.Remotes.Effect:FireAllClients("Scare",C.U.root(b.Model).Position,{255,60,90},20,b.Model)
 end
end
function S:RunOne()
 local C=self.C
 while #self:EligiblePlayers()==0 and not self.Closing do self:Broadcast(); task.wait(1) end
 if self.Closing then return end
 self:Transition("Intermission",C.Config.Intermission)
 if not self:Countdown(C.Config.Intermission,true) then self:Transition("WaitingForPlayers"); return end
 self:Transition("VotingOrSelection",C.Config.SelectionSeconds)
 if not self:Countdown(C.Config.SelectionSeconds,true) then self:Transition("WaitingForPlayers"); return end
 local players=self:EligiblePlayers(); if #players==0 then self:Transition("WaitingForPlayers"); return end
 self.PlayerCount=#players; local modes=C.ModeService:Eligible(#players); self.Mode=modes[C.Rng:NextInteger(1,#modes)]
 local map=C.Maps[C.Rng:NextInteger(1,#C.Maps)]; self.MapName=map.Name
 self.Token=self.Token+1; self.RoundId=self.RoundId+1; self.Revealed=false; self.ForcedResult=nil
 self:Transition("Loading",0); C.MapService:Load(map.Id,self.Mode)
 local roles,carrier=C.RoleService:Assign(players,self.Mode,C.Rng); self.Carrier=carrier
 -- Solo practice uses a durable hero and reduced rewards.
 if #players==1 then roles[players[1]]={Role="Gojo",Team="Sorcerers",Abilities=table.clone(C.Characters.Gojo.AbilitySet)} end
 local index=0
 for _,p in ipairs(players) do
  if p.Parent then
   index=index+1; local r=roles[p]; local cf=C.MapService:Spawn(index,r.Team)
   -- Pathfinding yields; the player can leave while a safe point is being selected.
   if not p.Parent then continue end
   local a=C.CharacterService:Spawn(p,r.Role,r.Team,r.Abilities,cf,true)
   C.Remotes.Role:FireClient(p,{Name=a.Definition.DisplayName,Role=a.Role,Team=a.Team,Abilities=a.Abilities,Ultimate=a.Definition.UltimateAbility})
  end
 end
 self:Transition("Intro",C.Config.IntroSeconds); self:Countdown(C.Config.IntroSeconds)
 self.StartedAt=os.clock(); self:Transition("InProgress",C.Config.RoundSeconds)
 local winner,reason
 while not winner and not self.Closing do
  if self.Mode=="Betrayal" and not self.Revealed and os.clock()-self.StartedAt>=60 then self:RevealCarrier() end
  if self.ForcedResult then winner,reason=table.unpack(self.ForcedResult)
  else
   local expired=workspace:GetServerTimeNow()>=self.Deadline
   winner,reason=C.ModeService.Decide(self.Mode,C.ModeService:Snapshot(),expired)
   if winner=="Draw" and expired and self.State=="InProgress" and self.Mode=="Clash" then
    winner=nil; self:Transition("SuddenDeath",C.Config.SuddenDeathSeconds)
   end
  end
  self:Broadcast(); if not winner then task.wait(0.5) end
 end
 if self.Closing then return end
 self:Transition("Results",C.Config.ResultsSeconds); self.Token=self.Token+1
 if self.TeamWins[winner] then self.TeamWins[winner]=self.TeamWins[winner]+1 end
 C.RewardService:Award(self.RoundId,winner,reason); self:Countdown(C.Config.ResultsSeconds)
 self:Cleanup()
end
function S:Cleanup()
 if self.State~="Cleanup" then self:Transition("Cleanup") end
 self.Token=self.Token+1; self.C.NPCService:Cleanup()
 for _,p in ipairs(Players:GetPlayers()) do if self.C.PlayerDataService:Get(p) then self.C.CharacterService:Lobby(p) end end
 self.C.MapService:Cleanup(); workspace.GameplayEffects:ClearAllChildren()
 self.Mode=nil; self.MapName=nil; self.Carrier=nil; self.PlayerCount=0; self:Transition("WaitingForPlayers")
end
function S:Start()
 task.spawn(function()
  while not self.Closing do
   local ok,err=xpcall(function() self:RunOne() end,debug.traceback)
   if not ok then
    warn("Round recovery",err)
    self.Token=self.Token+1; self.State="Cleanup"; self.C.NPCService:Cleanup(); self.C.MapService:Cleanup()
    for _,p in ipairs(Players:GetPlayers()) do if self.C.PlayerDataService:Get(p) then pcall(function() self.C.CharacterService:Lobby(p) end) end end
    self.State="WaitingForPlayers"; self.Mode=nil; self.MapName=nil; task.wait(3)
   end
  end
 end)
end
return S
