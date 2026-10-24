local S={}
S.Definitions={
 {Id="Rounds",Name="Сыграть 3 активных раунда",Goal=3,Reward=120,Period="Daily"},
 {Id="Survive",Name="Выжить 2 раза",Goal=2,Reward=100,Period="Daily"},
 {Id="Damage",Name="Нанести 1000 урона",Goal=1000,Reward=250,Period="Weekly"},
 {Id="Curse",Name="Победить 3 проклятия",Goal=3,Reward=120,Period="Daily"},
 {Id="Help",Name="Помочь союзникам 8 раз",Goal=8,Reward=200,Period="Weekly"},
 {Id="Abilities",Name="Применить 12 разных техник за раунды",Goal=12,Reward=180,Period="Weekly"},
}
function S:Init(ctx) self.C=ctx end
function S:Reset(d)
 local now=os.time(); local keys={Daily=math.floor(now/86400),Weekly=math.floor((now+3*86400)/604800)}
 for _,q in ipairs(self.Definitions) do
  local old=d.QuestProgress[q.Id]
  if not old or old.Period~=keys[q.Period] then d.QuestProgress[q.Id]={Period=keys[q.Period],Value=0,Claimed=false} end
 end
end
function S:Progress(p,id,n)
 if n<=0 then return end
 self.C.PlayerDataService:Mutate(p,function(d) self:Reset(d); local q=d.QuestProgress[id]; if q then q.Value=q.Value+n end end)
end
function S:Claim(p,id)
 local q; for _,v in ipairs(self.Definitions) do if v.Id==id then q=v end end
 if not q then return false end
 local ok,result=self.C.PlayerDataService:Mutate(p,function(d)
  self:Reset(d); local v=d.QuestProgress[id]
  if v.Claimed or v.Value<q.Goal then return false end
  v.Claimed=true; d.Coins=d.Coins+q.Reward; return true
 end)
 return ok and result
end
function S:Daily(p)
 local ok,result=self.C.PlayerDataService:Mutate(p,function(d)
  if os.time()-d.DailyRewardTimestamp<86400 then return false end
  d.DailyRewardTimestamp=os.time(); d.Coins=d.Coins+self.C.Config.DailyCoins; return true
 end)
 return ok and result
end
return S
