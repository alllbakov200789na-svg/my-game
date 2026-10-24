local DS=game:GetService("DataStoreService")
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local S={}
local function fresh()
 return {SchemaVersion=1,Coins=0,Level=1,XP=0,TotalWins=0,TotalMatches=0,Eliminations=0,SorcererWins=0,CurseWins=0,
 OwnedCosmetics={},EquippedCosmetics="",DailyRewardTimestamp=0,QuestProgress={},RolePity=0,
 ProcessedPurchaseReceipts={},Loadouts={},Settings={},Entitlements={}}
end
function S:Init(ctx)
 self.C=ctx; self.Profiles={}; self.Session=game.JobId~="" and game.JobId or Http:GenerateGUID(false)
 self.Memory=Run:IsStudio(); if not self.Memory then self.Store=DS:GetDataStore(ctx.Config.DataStoreName) end
 task.spawn(function() while not self.Closing do task.wait(ctx.Config.AutosaveSeconds)
  for p in pairs(self.Profiles) do task.spawn(function() self:Save(p,false) end) end
 end end)
end
function S:Load(p)
 local profile={Data=fresh(),Busy=false,Valid=true,Persistent=not self.Memory}
 if not self.Memory then
  local ok,result
  for attempt=1,4 do
   ok,result=pcall(function() return self.Store:UpdateAsync("u_"..p.UserId,function(old)
    old=old or {Data=fresh()}
    if old.Lease and old.Lease.Session~=self.Session and old.Lease.Expires>os.time() then return nil end
    old.Lease={Session=self.Session,Expires=os.time()+self.C.Config.LeaseSeconds}; return old
   end) end)
   if ok and result then break end; task.wait(attempt*1.5)
  end
  if not ok or not result then p:Kick("Данные временно недоступны или открыты на другом сервере. Повторите вход позже."); return false end
  for k,v in pairs(fresh()) do if result.Data[k]==nil then result.Data[k]=v end end
  profile.Data=result.Data
 end
 self.Profiles[p]=profile
 p:SetAttribute("DataMode",self.Memory and "STUDIO · прогресс не сохраняется" or "Облачное сохранение")
 return true
end
function S:Get(p) local f=self.Profiles[p]; return f and f.Valid and f.Data end
function S:Acquire(p)
 local f=self.Profiles[p]; if not f then return end
 local deadline=os.clock()+20
 while f.Busy and f.Valid and os.clock()<deadline do task.wait(0.05) end
 if not f.Valid or f.Busy then return end; f.Busy=true; return f
end
function S:Mutate(p,fn)
 local f=self:Acquire(p); if not f then return false end
 local ok,result=pcall(fn,f.Data); f.Busy=false
 if not ok then warn("Profile mutation:",result); return false end
 return true,result
end
function S:Persist(p,f,data,release)
 local ok,result
 for attempt=1,3 do
  ok,result=pcall(function() return self.Store:UpdateAsync("u_"..p.UserId,function(old)
   if not old or not old.Lease or old.Lease.Session~=self.Session then return nil end
   return {Data=data,Lease=not release and {Session=self.Session,Expires=os.time()+self.C.Config.LeaseSeconds} or nil}
  end) end)
  if ok and result then return true end
  task.wait(attempt)
 end
 -- Fail closed. Never overwrite an uncertain purchase with an older in-memory snapshot.
 f.Valid=false; warn("Profile persistence failed",p.UserId,tostring(result))
 if p.Parent then p:Kick("Сохранение временно недоступно. Сессия закрыта для защиты данных; войдите позже.") end
 return false
end
function S:Save(p,release)
 local f=self:Acquire(p); if not f then if release then self.Profiles[p]=nil end; return false end
 local ok=true
 if f.Persistent then ok=self:Persist(p,f,self.C.U.copy(f.Data),release) end
 f.Busy=false
 if release then f.Valid=false; self.Profiles[p]=nil end
 return ok
end
function S:Receipt(p,purchaseId,product)
 local f=self:Acquire(p); if not f or not f.Persistent then if f then f.Busy=false end; return false end
 if f.Data.ProcessedPurchaseReceipts[purchaseId] then f.Busy=false; return true end
 local nextData=self.C.U.copy(f.Data)
 nextData.Coins=nextData.Coins+(product.Coins or 0)
 for _,id in ipairs(product.Cosmetics or {}) do nextData.OwnedCosmetics[id]=true end
 nextData.ProcessedPurchaseReceipts[purchaseId]=os.time()
 local ok=self:Persist(p,f,nextData,false)
 if ok then f.Data=nextData end
 f.Busy=false; return ok
end
function S:Public(p)
 local d=self:Get(p); if not d then return nil end
 local out={}
 for _,k in ipairs({"Coins","Level","XP","TotalWins","TotalMatches","Eliminations","SorcererWins","CurseWins","OwnedCosmetics","EquippedCosmetics","DailyRewardTimestamp","QuestProgress","Loadouts","Settings","Entitlements"}) do out[k]=self.C.U.copy(d[k]) end
 return out
end
return S
