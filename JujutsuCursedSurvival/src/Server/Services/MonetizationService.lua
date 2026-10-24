local Marketplace=game:GetService("MarketplaceService")
local Players=game:GetService("Players")
local S={}
function S:Init(ctx)
 self.C=ctx
 Marketplace.ProcessReceipt=function(receipt)
  local p=Players:GetPlayerByUserId(receipt.PlayerId); if not p then return Enum.ProductPurchaseDecision.NotProcessedYet end
  local product
  for _,v in pairs(ctx.Config.Products) do if v.Id>0 and v.Id==receipt.ProductId then product=v; break end end
  if not product then warn("Unknown product receipt",receipt.ProductId); return Enum.ProductPurchaseDecision.NotProcessedYet end
  if ctx.PlayerDataService:Receipt(p,tostring(receipt.PurchaseId),product) then
   ctx.Remotes.Profile:FireClient(p,ctx.PlayerDataService:Public(p)); return Enum.ProductPurchaseDecision.PurchaseGranted
  end
  return Enum.ProductPurchaseDecision.NotProcessedYet
 end
 Marketplace.PromptGamePassPurchaseFinished:Connect(function(p,_,bought) if bought then self:RefreshPasses(p) end end)
end
function S:RefreshPasses(p)
 for key,pass in pairs(self.C.Config.Passes) do
  if pass.Id>0 then
   local ok,owns=pcall(function() return Marketplace:UserOwnsGamePassAsync(p.UserId,pass.Id) end)
   if ok and owns then self.C.PlayerDataService:Mutate(p,function(d)
    d.Entitlements[key]=true
    for _,id in ipairs(pass.Cosmetics or {}) do d.OwnedCosmetics[id]=true end
   end) end
  end
 end
end
function S:Purchase(p,id)
 local item=self.C.Config.Cosmetics[id]; if not item then return false end
 local ok,result=self.C.PlayerDataService:Mutate(p,function(d)
  if d.OwnedCosmetics[id] or d.Coins<item.Price then return false end
  d.Coins=d.Coins-item.Price; d.OwnedCosmetics[id]=true; return true
 end)
 return ok and result
end
function S:Equip(p,id)
 if id~="" and not self.C.Config.Cosmetics[id] then return false end
 local ok,result=self.C.PlayerDataService:Mutate(p,function(d)
  if id~="" and not d.OwnedCosmetics[id] then return false end
  d.EquippedCosmetics=id; return true
 end)
 if ok and result then self.C.CharacterService:Cosmetic(p) end
 return ok and result
end
function S:Prompt(p,kind,key)
 local cfg=kind=="Product" and self.C.Config.Products[key] or self.C.Config.Passes[key]
 if not cfg or cfg.Id<=0 or game:GetService("RunService"):IsStudio() then return false end
 if kind=="Product" then Marketplace:PromptProductPurchase(p,cfg.Id) else Marketplace:PromptGamePassPurchase(p,cfg.Id) end
 return true
end
return S
