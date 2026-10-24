local S={}
function S:Init(ctx) self.C=ctx end
function S:Eligible(count)
 local out={}; for id,m in pairs(self.C.Modes) do if count>=m.MinPlayers then table.insert(out,id) end end
 table.sort(out); return out
end
-- Pure decision function. Snapshot counts exclude ordinary NPCs.
function S.Decide(mode,s,timedOut)
 if s.Sorcerers==0 and s.Curses==0 and mode~="Survival" then return "Draw","Обе команды устранены" end
 if s.Sorcerers==0 then return "Curses","Команда магов устранена" end
 if mode=="Survival" then
  if s.BossDefeated and s.Seals>=3 then return "Sorcerers","Босс побеждён, защитный контур восстановлен" end
  if timedOut then return "Curses","Ритуал не завершён вовремя" end
 elseif mode=="Clash" then
  if not s.SorcererLeader and not s.CurseLeader then return "Draw","Оба лидера устранены" end
  if not s.CurseLeader then return "Sorcerers","Лидер проклятий устранён" end
  if not s.SorcererLeader then return "Curses","Лидер магов устранён" end
  if timedOut then
   if math.abs(s.SorcererScore-s.CurseScore)<0.01 then return "Draw","Равный счёт" end
   return s.SorcererScore>s.CurseScore and "Sorcerers" or "Curses","Победа по очкам здоровья"
  end
 elseif mode=="Invasion" then
  if s.Curses==0 or s.Seals>=3 then return "Sorcerers","Проклятия запечатаны" end
  if timedOut then return "Curses","Вторжение не остановлено" end
 elseif mode=="Hunt" or (mode=="Betrayal" and s.Revealed) then
  if s.Curses==0 then return "Sorcerers","Главное проклятие побеждено" end
  if timedOut then return s.Seals>=3 and "Sorcerers" or "Curses",s.Seals>=3 and "Спасение через печати" or "Печати не активированы" end
 elseif mode=="Betrayal" and timedOut then return "Draw","Носитель не появился" end
 return nil
end
function S:Snapshot()
 local C=self.C; local r=C.RoundService
 local s={Sorcerers=0,Curses=0,SorcererLeader=false,CurseLeader=false,SorcererScore=0,CurseScore=0,
 Seals=C.MapService.Seals or 0,BossDefeated=C.NPCService.BossDefeated,Revealed=r.Revealed}
 for _,a in pairs(C.CharacterService.Actors) do
  if a.Player and a.Participant and a.Alive and a.Player.Parent then
   s[a.Team]=s[a.Team]+1; local h=C.U.humanoid(a.Model)
   local key=a.Team=="Sorcerers" and "SorcererScore" or "CurseScore"
   s[key]=s[key]+(h and h.Health/h.MaxHealth or 0)*100
   if a.Role=="Gojo" then s.SorcererLeader=true elseif a.Role=="Sukuna" then s.CurseLeader=true end
  end
 end
 return s
end
return S
