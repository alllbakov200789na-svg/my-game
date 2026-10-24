local A={}
local function add(id,owner,kind,cost,cooldown,duration,range,damage,radius,color)
 A[id]={Id=id,Owner=owner,Kind=kind,Cost=cost,Cooldown=cooldown,Duration=duration,Range=range,Damage=damage,
 Radius=radius or 5,Color=color or {160,110,255},Animation="ProceduralCast",Sound=id,Particles=kind,
 RequireLineOfSight=true,AllowedStates={"InProgress","SuddenDeath"}}
end
add("Basic","Any","Melee",0,0.65,0.15,9,12,5)
add("Heavy","Any","Melee",12,4,0.35,11,28,6)
add("Blue","Gojo","Pull",22,9,1,55,28,15,{60,170,255})
add("Red","Gojo","Push",25,10,0.4,45,45,13,{255,70,100})
add("Infinity","Gojo","Shield",30,18,4,0,0,0,{130,220,255})
add("Teleport","Gojo","Teleport",18,7,0.2,38,0,0,{90,210,255})
add("HollowPurple","Gojo","Projectile",45,18,0.7,105,100,10,{180,60,255})
add("UnlimitedVoid","Gojo","Domain",40,35,6,0,14,32,{90,170,255})
add("Cleave","Sukuna","Melee",14,4,0.25,14,42,8,{255,60,80})
add("Dismantle","Sukuna","Projectile",20,7,0.15,75,38,4,{255,125,140})
add("FireAttack","Sukuna","Projectile",32,14,0.6,85,65,11,{255,125,40})
add("CursedDash","Sukuna","Dash",18,8,0.2,28,22,7,{255,55,90})
add("Regeneration","Sukuna","HealSelf",35,18,2,0,85,0,{255,120,145})
add("MalevolentShrine","Sukuna","Domain",40,35,6,0,22,30,{255,45,80})
add("BlackFlash","Sorcerer","Melee",18,8,0.2,10,40,5)
add("ShadowDog","Sorcerer","Summon",26,16,10,40,12,4,{125,80,215})
add("CursedSpeech","Sorcerer","Stun",24,14,1.8,30,15,12)
add("ElectricStrike","Sorcerer","Projectile",20,8,0.2,48,30,5,{250,220,90})
add("IceSpear","Sorcerer","Projectile",20,9,0.3,60,28,5,{120,235,255})
add("FireSphere","Sorcerer","Projectile",24,10,0.4,55,35,8,{255,145,60})
add("ShadowDash","Sorcerer","Dash",15,7,0.2,24,15,5)
add("AllyHeal","Sorcerer","Heal",28,14,0.5,30,35,14,{100,255,190})
add("Barrier","Sorcerer","Shield",28,18,3,0,0,0,{125,175,255})
add("Katana","Sorcerer","Melee",14,6,0.25,13,32,6)
add("AirPush","Sorcerer","Push",18,8,0.4,28,22,10,{185,235,255})
add("ShadowTrap","Sorcerer","Trap",22,12,8,25,25,8)
A.Pool={"BlackFlash","ShadowDog","CursedSpeech","ElectricStrike","IceSpear","FireSphere","ShadowDash","AllyHeal","Barrier","Katana","AirPush","ShadowTrap"}
A.Incompatible={AllyHeal={Barrier=true},Barrier={AllyHeal=true},BlackFlash={Katana=true},Katana={BlackFlash=true}}
A.Names={Basic="Удар",Heavy="Тяжёлый удар",Blue="Синий / притяжение",Red="Красный / толчок",Infinity="Бесконечность",Teleport="Телепорт",HollowPurple="Фиолетовый",UnlimitedVoid="Безграничная пустота",Cleave="Рассечение",Dismantle="Разрез",FireAttack="Пламя",CursedDash="Проклятый рывок",Regeneration="Регенерация",MalevolentShrine="Храм разлома",BlackFlash="Чёрная вспышка",ShadowDog="Теневая собака",CursedSpeech="Проклятая речь",ElectricStrike="Электроудар",IceSpear="Ледяное копьё",FireSphere="Огненная сфера",ShadowDash="Теневой рывок",AllyHeal="Лечение союзника",Barrier="Барьер",Katana="Проклятая катана",AirPush="Воздушный толчок",ShadowTrap="Теневая ловушка"}
return A
