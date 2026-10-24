local C=require(script.Parent.Config)
local function char(id,name,original,team,hp,speed,sprint,power,defense,abilities,ultimate,color)
 return {CharacterId=id,DisplayName=C.UseOriginalNames and original or name,Team=team,BaseHealth=hp,
 WalkSpeed=speed,SprintSpeed=sprint,Stamina=100,Energy=100,AttackPower=power,Defense=defense,
 AbilitySet=abilities,UltimateAbility=ultimate,AnimationSet="ProceduralR15",VFXProfile=color,SFXProfile=id}
end
return {
 Sorcerer=char("Sorcerer","Маг","Маг","Sorcerers",100,17,26,12,0,{},nil,{137,117,255}),
 Gojo=char("Gojo","Годжо","Астра • хранитель пространства","Sorcerers",650,20,30,20,0.08,{"Blue","Red","Infinity","Teleport","HollowPurple"},"UnlimitedVoid",{55,192,255}),
 Sukuna=char("Sukuna","Сукуна","Рэн • владыка разлома","Curses",850,18,27,26,0.12,{"Cleave","Dismantle","FireAttack","CursedDash","Regeneration"},"MalevolentShrine",{255,63,91}),
 Curse=char("Curse","Главное проклятие","Высшее проклятие","Curses",430,19,28,22,0.06,{"Dismantle","FireAttack","CursedDash","Regeneration"},"MalevolentShrine",{255,113,58}),
}
