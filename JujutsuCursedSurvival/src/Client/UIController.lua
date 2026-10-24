local UIS=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local Social=game:GetService("SocialService")
local S={}
local bg=Color3.fromRGB(14,17,32)
local white=Color3.fromRGB(238,241,255)
local function rounded(o,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 10); c.Parent=o end
local function label(parent,text,size)
 local x=Instance.new("TextLabel"); x.BackgroundTransparency=1; x.Text=text; x.TextColor3=white; x.Font=Enum.Font.GothamMedium
 x.TextSize=size or 14; x.TextWrapped=true; x.TextXAlignment=Enum.TextXAlignment.Left; x.Parent=parent; return x
end
local function button(parent,text,fn)
 local x=Instance.new("TextButton"); x.Text=text; x.TextColor3=white; x.Font=Enum.Font.GothamBold; x.TextSize=14; x.TextWrapped=true
 x.BackgroundColor3=Color3.fromRGB(43,40,73); x.BorderSizePixel=0; x.AutoButtonColor=true; x.Parent=parent; rounded(x,9)
 x.Activated:Connect(fn); return x
end
local function panel(parent)
 local x=Instance.new("Frame"); x.BackgroundColor3=bg; x.BackgroundTransparency=0.12; x.BorderSizePixel=0; x.Parent=parent; rounded(x,12)
 local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(65,61,98); stroke.Transparency=0.35; stroke.Parent=x; return x
end
function S:Init(ctx)
 self.C=ctx; self.Buttons={}; self.Bars={}
 local gui=Instance.new("ScreenGui"); gui.Name="CursedSurvivalUI"; gui.ResetOnSpawn=false; gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=ctx.Player:WaitForChild("PlayerGui"); self.Gui=gui
 self.Top=panel(gui); self.Top.AnchorPoint=Vector2.new(0.5,0); self.Top.Position=UDim2.new(0.5,0,0,8)
 self.Mode=label(self.Top,"CURSED SURVIVAL",17); self.Mode.Position=UDim2.fromOffset(14,8); self.Mode.Size=UDim2.new(1,-80,0,23)
 self.Time=label(self.Top,"--:--",20); self.Time.TextXAlignment=Enum.TextXAlignment.Right; self.Time.Position=UDim2.new(1,-85,0,8); self.Time.Size=UDim2.fromOffset(72,25)
 self.Objective=label(self.Top,"Подключение к серверу…",12); self.Objective.Position=UDim2.fromOffset(14,35); self.Objective.Size=UDim2.new(1,-28,0,36)
 self.Detail=label(self.Top,"",11); self.Detail.TextColor3=Color3.fromRGB(160,165,195); self.Detail.Position=UDim2.fromOffset(14,73); self.Detail.Size=UDim2.new(1,-28,0,20)
 self.MenuButton=button(gui,"☰ МЕНЮ",function() self:Open("Menu") end); self.MenuButton.Position=UDim2.fromOffset(12,10)
 self.Wallet=label(gui,"",12); self.Wallet.Position=UDim2.fromOffset(14,60); self.Wallet.Size=UDim2.fromOffset(170,42)
 self.Stats=panel(gui)
 for i,spec in ipairs({{"HP",Color3.fromRGB(88,220,180)},{"Energy",Color3.fromRGB(107,156,255)},{"Stamina",Color3.fromRGB(228,196,99)}}) do
  local track=Instance.new("Frame"); track.BackgroundColor3=Color3.fromRGB(36,39,59); track.BorderSizePixel=0; track.Position=UDim2.new(0,12,0,12+(i-1)*25); track.Size=UDim2.new(1,-24,0,18); track.Parent=self.Stats; rounded(track,6)
  local fill=Instance.new("Frame"); fill.BackgroundColor3=spec[2]; fill.BorderSizePixel=0; fill.Size=UDim2.fromScale(1,1); fill.Parent=track; rounded(fill,6)
  local text=label(track,"",11); text.TextColor3=Color3.fromRGB(10,15,28); text.Font=Enum.Font.GothamBold; text.TextXAlignment=Enum.TextXAlignment.Center; text.Size=UDim2.fromScale(1,1)
  self.Bars[spec[1]]={Fill=fill,Text=text}
 end
 self.Skills=Instance.new("Frame"); self.Skills.BackgroundTransparency=1; self.Skills.Parent=gui
 self.Grid=Instance.new("UIGridLayout"); self.Grid.CellPadding=UDim2.fromOffset(5,5); self.Grid.SortOrder=Enum.SortOrder.LayoutOrder; self.Grid.Parent=self.Skills
 self.Spectate=button(gui,"НАБЛЮДАТЬ  →",function() ctx.SpectatorController:Next() end); self.Spectate.AnchorPoint=Vector2.new(0.5,1); self.Spectate.Position=UDim2.new(0.5,0,1,-20); self.Spectate.Size=UDim2.fromOffset(210,48); self.Spectate.Visible=false
 self.Sprint=button(gui,"БЕГ",function() self.SprintOn=not self.SprintOn; ctx.Remotes.Sprint:FireServer(self.SprintOn); self.Sprint.Text=self.SprintOn and "БЕГ ●" or "БЕГ" end); self.Sprint.Size=UDim2.fromOffset(62,48); self.Sprint.Visible=UIS.TouchEnabled
 local cross=label(gui,"+",22); cross.AnchorPoint=Vector2.new(0.5,0.5); cross.Position=UDim2.fromScale(0.5,0.5); cross.Size=UDim2.fromOffset(24,24); cross.TextXAlignment=Enum.TextXAlignment.Center; cross.TextTransparency=0.3
 self.Toast=panel(gui); self.Toast.AnchorPoint=Vector2.new(0.5,0); self.Toast.Position=UDim2.new(0.5,0,0.27,0); self.Toast.Visible=false; self.Toast.ZIndex=10
 self.ToastText=label(self.Toast,"",15); self.ToastText.Position=UDim2.fromOffset(12,4); self.ToastText.Size=UDim2.new(1,-24,1,-8); self.ToastText.TextXAlignment=Enum.TextXAlignment.Center; self.ToastText.ZIndex=11
 self.Modal=panel(gui); self.Modal.Name="Modal"; self.Modal.AnchorPoint=Vector2.new(0.5,0.5); self.Modal.Position=UDim2.fromScale(0.5,0.5); self.Modal.ZIndex=20; self.Modal.Visible=false
 self.Heading=label(self.Modal,"",21); self.Heading.Position=UDim2.fromOffset(20,12); self.Heading.Size=UDim2.new(1,-80,0,32); self.Heading.ZIndex=21
 local close=button(self.Modal,"×",function() self.Modal.Visible=false end); close.Position=UDim2.new(1,-52,0,8); close.Size=UDim2.fromOffset(44,44); close.ZIndex=22
 self.Scroll=Instance.new("ScrollingFrame"); self.Scroll.BackgroundTransparency=1; self.Scroll.BorderSizePixel=0; self.Scroll.ScrollBarThickness=5; self.Scroll.Position=UDim2.fromOffset(16,60); self.Scroll.Size=UDim2.new(1,-32,1,-76); self.Scroll.CanvasSize=UDim2.new(); self.Scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; self.Scroll.ZIndex=21; self.Scroll.Parent=self.Modal
 local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,9); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=self.Scroll
 local padding=Instance.new("UIPadding"); padding.PaddingBottom=UDim.new(0,12); padding.PaddingRight=UDim.new(0,8); padding.Parent=self.Scroll
 self.Reveal=panel(gui); self.Reveal.AnchorPoint=Vector2.new(0.5,0.5); self.Reveal.Position=UDim2.fromScale(0.5,0.43); self.Reveal.Visible=false; self.Reveal.ZIndex=15
 self.RevealTitle=label(self.Reveal,"",25); self.RevealTitle.Size=UDim2.new(1,-32,0,64); self.RevealTitle.Position=UDim2.fromOffset(16,15); self.RevealTitle.TextXAlignment=Enum.TextXAlignment.Center; self.RevealTitle.ZIndex=16
 self.RevealBody=label(self.Reveal,"",14); self.RevealBody.Size=UDim2.new(1,-32,0,60); self.RevealBody.Position=UDim2.fromOffset(16,80); self.RevealBody.TextXAlignment=Enum.TextXAlignment.Center; self.RevealBody.ZIndex=16
 local function resize() self:Resize() end
 workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize); self:Resize()
 Run.RenderStepped:Connect(function()
  local s=ctx.State; if s then
   local seconds=math.max(0,math.ceil(s.Deadline-workspace:GetServerTimeNow())); self.Time.Text=string.format("%02d:%02d",math.floor(seconds/60),seconds%60)
  end
 end)
 task.delay(2,function() if not ctx.State or ctx.State.State=="WaitingForPlayers" or ctx.State.State=="Intermission" then self:Open("Tutorial") end end)
end
function S:Resize()
 local size=workspace.CurrentCamera.ViewportSize; local mobile=UIS.TouchEnabled or size.X<900; self.Mobile=mobile
 self.Top.Size=UDim2.fromOffset(math.max(200,math.min(520,size.X-(mobile and 145 or 360))),100)
 self.Top.Position=mobile and UDim2.new(1,-8,0,8) or UDim2.new(0.5,0,0,8); self.Top.AnchorPoint=mobile and Vector2.new(1,0) or Vector2.new(0.5,0)
 self.MenuButton.Size=UDim2.fromOffset(mobile and 106 or 132,44)
 self.Wallet.Size=UDim2.fromOffset(mobile and 115 or 175,42)
 self.Stats.Size=UDim2.fromOffset(mobile and 175 or 260,94)
 self.Stats.Position=mobile and UDim2.fromOffset(12,112) or UDim2.new(0,16,1,-112)
 self.Skills.Size=UDim2.fromOffset(mobile and 229 or 405,mobile and 164 or 137)
 self.Skills.AnchorPoint=Vector2.new(1,1); self.Skills.Position=mobile and UDim2.new(1,-10,1,-92) or UDim2.new(1,-18,1,-18)
 self.Grid.CellSize=UDim2.fromOffset(mobile and 73 or 97,mobile and 51 or 65)
 self.Grid.FillDirectionMaxCells=mobile and 3 or 4
 self.Sprint.Position=UDim2.new(0,195,1,-67)
 self.Modal.Size=UDim2.fromOffset(math.min(580,size.X-24),math.min(580,size.Y-65))
 self.Toast.Size=UDim2.fromOffset(math.min(500,size.X-30),56)
 self.Reveal.Size=UDim2.fromOffset(math.min(500,size.X-30),154)
end
function S:Notice(text)
 self.ToastText.Text=text; self.Toast.Visible=true; self.ToastSerial=(self.ToastSerial or 0)+1; local serial=self.ToastSerial
 task.delay(3,function() if serial==self.ToastSerial then self.Toast.Visible=false end end)
end
function S:State(s)
 local names={WaitingForPlayers="ОЖИДАНИЕ",Intermission="ПЕРЕРЫВ",VotingOrSelection="ВЫБОР РЕЖИМА",Loading="ЗАГРУЗКА",Intro="ВАША РОЛЬ",InProgress="БОЙ",SuddenDeath="РЕШАЮЩАЯ СХВАТКА",Results="РЕЗУЛЬТАТЫ",Cleanup="ВОЗВРАЩЕНИЕ"}
 self.Mode.Text=(s.Training and "ТРЕНИРОВКА • " or "")..(names[s.State] or s.State)
 self.Objective.Text=s.Objective
 self.Detail.Text=string.format("%s  •  Печати %d/3  •  Живы %d  •  Волна %d",s.Map or s.Mode,s.Seals or 0,s.Alive or 0,s.Wave or 0)
 if s.State=="Intro" then self.Modal.Visible=false end
 if s.State=="Cleanup" then self.Modal.Visible=false; self.Reveal.Visible=false end
end
function S:Vitals(v)
 local labels={HP="ЗДОРОВЬЕ",Energy="ЭНЕРГИЯ",Stamina="ВЫНОСЛИВОСТЬ"}
 for key,b in pairs(self.Bars) do local val=v[key] or 0; local max=key=="HP" and v.MaxHP or 100
  Tween:Create(b.Fill,TweenInfo.new(0.18),{Size=UDim2.fromScale(math.clamp(val/max,0,1),1)}):Play(); b.Text.Text=labels[key].."  "..math.floor(val).." / "..max
 end
 local signature=table.concat(v.Abilities or {},",")..tostring(v.UltimateId)
 if signature~=self.Signature then self.Signature=signature; self:BuildSkills(v) end
 self.Skills.Visible=v.Alive and v.Participant
 for id,b in pairs(self.Buttons) do
  local cd=v.Cooldowns[id] or 0; local def=self.C.Abilities[id]
  local ready=cd<=0 and v.Energy>=def.Cost and (id~=v.UltimateId or v.Ultimate>=100)
  b.Button.BackgroundColor3=ready and Color3.fromRGB(60,46,102) or Color3.fromRGB(29,31,46)
  b.Button.Text=b.Key.."  "..(cd>0 and string.format("%.1fs",cd) or id==v.UltimateId and math.floor(v.Ultimate).."%" or tostring(def.Cost).." CE").."\n"..(self.C.Abilities.Names[id] or id)
 end
end
function S:BuildSkills(v)
 for _,b in pairs(self.Buttons) do b.Button:Destroy() end; self.Buttons={}
 local list={{Id="Basic",Index="Basic",Key="ЛКМ"},{Id="Heavy",Index="Heavy",Key="X"}}
 local keys={"Q","E","R","F","T"}
 for i,id in ipairs(v.Abilities or {}) do table.insert(list,{Id=id,Index=i,Key=keys[i]}) end
 if v.UltimateId then table.insert(list,{Id=v.UltimateId,Index="Ultimate",Key="G"}) end
 for i,item in ipairs(list) do local b=button(self.Skills,item.Id,function() self.C.InputController:Cast(item.Index) end); b.LayoutOrder=i; b.TextSize=11
  self.Buttons[item.Id]={Button=b,Key=item.Key}
 end
end
function S:Profile(d)
 self.Wallet.Text=string.format("◈ %d  ·  LV %d\n%s",d.Coins,d.Level,self.C.Player:GetAttribute("DataMode") or "")
 if self.Modal.Visible and self.Page~="Results" then self:Open(self.Page) end
end
function S:Role(r)
 self.RevealTitle.Text=r.Name; self.RevealTitle.TextColor3=r.Team=="Curses" and Color3.fromRGB(255,100,125) or Color3.fromRGB(120,200,255)
 self.RevealBody.Text=(r.Team=="Curses" and "ПРОКЛЯТИЯ" or "МАГИ").."\n"..table.concat(r.Abilities,"  •  ")
 self.Reveal.Visible=true; task.delay(4,function() self.Reveal.Visible=false end)
end
function S:Clear(title)
 self.Heading.Text=title; self.Modal.Visible=true
 for _,x in ipairs(self.Scroll:GetChildren()) do if x:IsA("GuiObject") then x:Destroy() end end
 self.Scroll.CanvasPosition=Vector2.zero
end
function S:Text(text,height)
 local l=label(self.Scroll,text,14); l.Size=UDim2.new(1,0,0,height or 65); l.ZIndex=22; return l
end
function S:Row(text,fn,disabled,color)
 local b=button(self.Scroll,text,fn or function() end); b.Size=UDim2.new(1,0,0,54); b.ZIndex=22
 if color then b.BackgroundColor3=color end
 if disabled then b.Active=false; b.AutoButtonColor=false; b.TextTransparency=0.5; b.BackgroundColor3=Color3.fromRGB(27,29,43) end
 return b
end
function S:Open(page)
 self.Page=page; local C=self.C; local d=C.Profile
 local titles={Menu="CURSED SURVIVAL",Shop="КОСМЕТИКА",Inventory="КОЛЛЕКЦИЯ",Stats="СТАТИСТИКА",Quests="ЗАДАНИЯ",Settings="НАСТРОЙКИ",Tutorial="КАК ИГРАТЬ",Monetization="МАГАЗИН ROBUX"}
 self:Clear(titles[page] or page)
 local function action(a,arg) C.Remotes.Action:FireServer(a,arg) end
 if page=="Menu" then
  self:Text("JUJUTSU: CURSED SURVIVAL\nВыберите раздел. Раунд начнётся автоматически.",55)
  for _,p in ipairs({"Shop","Inventory","Stats","Quests","Settings","Tutorial","Monetization"}) do self:Row(titles[p],function() self:Open(p) end) end
  self:Row("Ежедневная награда • +100 монет",function() action("Daily") end)
  self:Row("Пригласить друзей",function() task.spawn(function()
   local ok,allowed=pcall(function() return Social:CanSendGameInviteAsync(C.Player) end)
   if ok and allowed then pcall(function() Social:PromptGameInvite(C.Player) end) else self:Notice("Приглашения сейчас недоступны") end
  end) end)
  self:Row("Премиум-эмоция • в лобби",function() action("Emote") end,not (d and d.Entitlements.Emotes))
 elseif page=="Shop" then
  self:Text("Только внешний вид. Покупки не увеличивают урон или здоровье. Цвет карточки — превью ауры.",65)
  for _,id in ipairs({"Azure","Crimson","Violet","Gold","Eclipse"}) do local item=C.Config.Cosmetics[id]; local owned=d and d.OwnedCosmetics[id]
   self:Row(item.Name.."\n"..(owned and "НАДЕТЬ" or item.Price.." монет • КУПИТЬ"),function() action(owned and "Equip" or "Buy",id) end,false,C.U.color(item.Color):Lerp(bg,0.75))
  end
 elseif page=="Inventory" then
  self:Row("Снять косметику",function() action("Equip","") end)
  if d then for _,id in ipairs({"Azure","Crimson","Violet","Gold","Eclipse"}) do if d.OwnedCosmetics[id] then self:Row("Надеть "..id,function() action("Equip",id) end) end end end
  for i=1,(d and d.Entitlements.Loadouts and 3 or 1) do
   self:Row("Сохранить текущую ауру • слот "..i,function() action("SaveLoadout",tostring(i)) end)
   self:Row("Надеть ауру из слота "..i,function() action("LoadLoadout",tostring(i)) end)
  end
  self:Text("КОЛЛЕКЦИЯ ТЕХНИК • маг получает две случайные совместимые техники",50)
  for _,id in ipairs(C.Abilities.Pool) do local a=C.Abilities[id]; self:Text((C.Abilities.Names[id] or id).."\nЭнергия "..a.Cost.." • Перезарядка "..a.Cooldown.."с • Эффект "..a.Damage,52) end
 elseif page=="Stats" then
  if d then self:Text(string.format("Уровень %d • Опыт %d\nПобеды %d / Раунды %d\nУстранения %d\nМаги: %d побед • Проклятия: %d побед",d.Level,d.XP,d.TotalWins,d.TotalMatches,d.Eliminations,d.SorcererWins,d.CurseWins),160) end
  local s=C.State; self:Text("Счёт сервера: маги "..tostring(s and s.TeamWins.Sorcerers or 0).." / проклятия "..tostring(s and s.TeamWins.Curses or 0),60)
  self:Text("Диагностика: NPC "..tostring(s and s.NPCs or 0).." / "..C.Config.MaxNPCs.." • локальные эффекты "..C.VFXController.Active.."\n"..(C.Player:GetAttribute("DataMode") or ""),70)
 elseif page=="Quests" then
  local quests={{"Rounds",3,120,"День: активные раунды"},{"Survive",2,100,"День: выжить"},{"Damage",1000,250,"Неделя: урон"},{"Curse",3,120,"День: победить проклятия"},{"Help",8,200,"Неделя: помощь"},{"Abilities",12,180,"Неделя: разные техники за раунды"}}
  for _,q in ipairs(quests) do local progress=d and d.QuestProgress[q[1]]; local value=progress and progress.Value or 0; local claimed=progress and progress.Claimed
   self:Row(q[4].."  "..math.min(value,q[2]).."/"..q[2].."\n"..(claimed and "ПОЛУЧЕНО" or "+"..q[3].." монет • ПОЛУЧИТЬ"),function() action("Quest",q[1]) end,claimed or value<q[2])
  end
  self:Text("Сброс по UTC: ежедневно и по понедельникам. Награда за раунд требует движения и полезных действий.",70)
  self:Row("Ежедневная награда • 100 монет",function() action("Daily") end,d and os.time()-d.DailyRewardTimestamp<86400)
 elseif page=="Settings" then
  for _,pair in ipairs({{"LowFX","Низкое качество эффектов"},{"Shake","Тряска камеры"},{"ReducedFlash","Уменьшить вспышки"},{"Scares","Резкие экранные события"},{"Sound","Звук"}}) do
   self:Row(pair[2]..": "..(C.Settings[pair[1]] and "ВКЛ" or "ВЫКЛ"),function() C.Settings[pair[1]]=not C.Settings[pair[1]]; C.VFXController:ApplyQuality(); action("Setting:"..pair[1],C.Settings[pair[1]]); self:Open("Settings") end)
  end
 elseif page=="Monetization" then
  self:Text("Ненастроенные товары отключены. Сундук имеет фиксированный состав. Никаких платных боевых преимуществ.",70)
  for key,item in pairs(C.Config.Products) do self:Row(item.Name..(item.Id<=0 and " • NOT_CONFIGURED" or " • купить за Robux"),function() action("Product",key) end,item.Id<=0) end
  for key,item in pairs(C.Config.Passes) do self:Row(item.Name..(item.Id<=0 and " • NOT_CONFIGURED" or " • Game Pass"),function() action("Pass",key) end,item.Id<=0) end
 elseif page=="Tutorial" then
  self:Text("1. Дождитесь раунда и получите роль. В одиночку запускается тренировка с NPC.\n2. Сражайтесь и выполняйте цель вверху экрана.\n3. Удерживайте Y возле печатей. После смерти можно наблюдать за союзниками.",145)
  self:Text("ПК: WASD — движение • Shift — бег\nЛКМ — удар • X — тяжёлый удар\nQ / E / R / F / T — техники • G — ультимейт\nT — пятая техника главного персонажа.",110)
  self:Text("Телефон: двигайтесь стандартным джойстиком, направляйте центр камеры на цель и нажимайте технику. Кнопка БЕГ переключает спринт.\nУльтимейт заряжается уроном, лечением союзников и печатями.",115)
  self:Text("Монеты: активная игра, победы, задания, ежедневный бонус. Магазин продаёт косметику. В Studio прогресс не сохраняется.\nВ этом билде звук требует загрузки приложенных WAV и заполнения Config.Sounds.",110)
  self:Row("ПОНЯТНО • В ИГРУ",function() self.Modal.Visible=false end)
 end
 if page~="Menu" then self:Row("← Главное меню",function() self:Open("Menu") end) end
end
function S:Results(r)
 self.Page="Results"; self:Clear(r.Winner=="Draw" and "НИЧЬЯ" or r.Won and "ПОБЕДА" or "РАУНД ЗАВЕРШЁН")
 self:Text(r.Reason,65)
 self:Text(string.format("+%d МОНЕТ    +%d XP\nУрон: %d  •  Устранения: %d",r.Coins,r.XP,r.Damage,r.Eliminations),90)
 if not r.Active then self:Text("Награда не начислена: нужно не менее 15 секунд движения и 3 полезных действий.",70) end
 self:Row("Следующий раунд начнётся автоматически",function() self.Modal.Visible=false end)
end
return S
