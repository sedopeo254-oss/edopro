-- Validate that Gradius' Option uses printed stats and copies Equip effects.
-- Lua mock regression; in-game selection/animation still requires runtime testing.
local script,card_id
function GetID() script={} card_id=14291024 return script,card_id end
local function check(ok,why) assert(ok,why) end
EFFECT_TYPE_SINGLE=1; EFFECT_TYPE_FIELD=2; EFFECT_TYPE_EQUIP=4
EFFECT_TYPE_CONTINUOUS=8; EFFECT_SPSUMMON_PROC=34
EFFECT_SPSUMMON_CONDITION=30; EFFECT_FLAG_CANNOT_DISABLE=1
EFFECT_FLAG_UNCOPYABLE=2; EFFECT_FLAG_SINGLE_RANGE=4
EFFECT_SET_ATTACK=101; EFFECT_SET_DEFENSE=102; EFFECT_SET_ATTACK_FINAL=103
EFFECT_UPDATE_ATTACK=104; EFFECT_PIERCE=105; EFFECT_SELF_DESTROY=106
EVENT_SPSUMMON_SUCCESS=201; EVENT_ADJUST=202
RESET_EVENT=256; RESETS_STANDARD=4096; LOCATION_HAND=2; LOCATION_MZONE=4
HINT_SELECTMSG=1; HINTMSG_FACEUP=2; PHASE_DAMAGE_CAL=64
local function effect(owner)
 local e={handler=owner}
 function e:Clone()
   local clone=effect(owner)
   for k,v in pairs(self) do clone[k]=v end
   return clone
 end
 function e:GetHandler() return self.handler end
 function e:GetCode() return self.code end
 function e:GetValue() return self.value end
 function e:GetCondition() return self.condition end
 function e:IsHasType(v) return (self.type&v)~=0 end
 for _,field in ipairs({"Type","Code","Value","Condition","Property","Range","Reset","Operation"}) do
   e["Set"..field]=function(self,value) self[field:lower()]=value end
 end
 return e
end
Effect={CreateEffect=effect}
local function makecard(code,atk,def)
 local c={code=code,atk=atk,def=def,effects={},faceup=true,location=LOCATION_MZONE,flag=0,equips={}}
 function c:EnableUnsummonable() self.cannot_normal=true end
 function c:EnableReviveLimit() self.revive=true end
 function c:RegisterEffect(e) e.handler=self;self.effects[#self.effects+1]=e end
 function c:IsFaceup() return self.faceup end
 function c:IsDisabled() return false end
 function c:IsLocation(x) return self.location==x end
 function c:IsCode(x) return self.code==x end
 function c:GetControler() return 0 end
 function c:GetTextAttack() return self.atk end
 function c:GetTextDefense() return self.def end
 function c:GetFirstCardTarget() return self.target end
 function c:SetCardTarget(t) self.target=t end
 function c:RegisterFlagEffect() self.flag=1 end
 function c:GetFlagEffect() return self.flag end
 function c:GetEquipTarget() return self.equipped_to end
 function c:GetOwnEffects() return table.unpack(self.effects) end
 function c:GetEquipGroup() return {Iter=function()
   local i=0;return function() i=i+1 return c.equips[i] end
 end} end
 return c
end
local gradius=makecard(10992251,1200,800)
local attacker,phase,target
Duel={
 GetLocationCount=function() return 3 end,
 IsExistingMatchingCard=function(f) return gradius.location==LOCATION_MZONE and f(gradius) end,
 Hint=function() end,HINT=nil,
 HintSelection=function() end,
 SelectMatchingCard=function() return {GetFirst=function() return gradius end} end,
 GetAttacker=function() return attacker end,
 GetCurrentPhase=function() return phase end,
 GetAttackTarget=function() return target end
}
local path=assert(arg[1],"script path")
assert(loadfile(path))()
local s=script
local opt=makecard(14291024,-1,-1)
s.initial_effect(opt)
check(opt.cannot_normal and opt.revive,"unsummonable and revive condition")
local proc,limit,link,sync,sd,atk
for _,e in ipairs(opt.effects) do
 if e.code==EFFECT_SPSUMMON_PROC then proc=e end
 if e.code==EFFECT_SPSUMMON_CONDITION then limit=e end
 if e.code==EVENT_SPSUMMON_SUCCESS then link=e end
 if e.code==EVENT_ADJUST then sync=e end
 if e.code==EFFECT_SELF_DESTROY then sd=e end
 if e.code==EFFECT_SET_ATTACK then atk=e end
end
check(proc and limit and link and sync and sd and atk,"all abilities registered")
check(proc.condition(proc,opt) and not limit.value(),"only own summon procedure")
check(sync.type==EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS,"global equip changes")
link.operation(link,0)
check(atk.value(atk,opt)==1200,"printed Gradius ATK, not boosted ATK")
local laser=makecard(5494820,0,0)
laser.equipped_to=gradius
local stat=effect(laser);stat:SetType(EFFECT_TYPE_EQUIP)
stat:SetCode(EFFECT_UPDATE_ATTACK);stat:SetValue(300);laser:RegisterEffect(stat)
local pierce=effect(laser);pierce:SetType(EFFECT_TYPE_EQUIP)
pierce:SetCode(EFFECT_PIERCE);laser:RegisterEffect(pierce)
gradius.equips={laser}
sync.operation(sync,0)
local bonus,pc=0,0
for _,e in ipairs(opt.effects) do
 if (e.code==EFFECT_UPDATE_ATTACK or e.code==EFFECT_PIERCE)
    and (not e.condition or e.condition(e)) then
   if e.code==EFFECT_UPDATE_ATTACK then bonus=bonus+(type(e.value)=="function" and e.value(e,opt) or e.value) end
   if e.code==EFFECT_PIERCE then pc=pc+1 end
 end
end
check(bonus==300 and pc==1,"Cyclon Laser +300 and piercing replicated")
local count=#opt.effects;sync.operation(sync,0)
check(count==#opt.effects,"no duplicate effects on repeated Adjust")
local matter=makecard(511000219,0,0);matter.equipped_to=gradius
local final=effect(matter);final:SetType(EFFECT_TYPE_EQUIP)
final:SetCode(EFFECT_SET_ATTACK_FINAL)
final:SetCondition(function()return attacker==gradius end)
final:SetValue(function()return target:GetDefense()+100 end)
matter:RegisterEffect(final)
gradius.equips={laser,matter};sync.operation(sync,0)
attacker=opt;phase=PHASE_DAMAGE_CAL
target={IsDefensePos=function()return true end,GetDefense=function()return 2500 end}
local inherited
for _,e in ipairs(opt.effects) do if e.code==EFFECT_SET_ATTACK_FINAL then inherited=e end end
check(inherited and inherited.condition(inherited),"Matter Leveler should apply when Option attacks")
check(inherited.value(inherited,opt)==2600,"DEF 2500+100, no extra +300")
attacker=gradius;check(not inherited.condition(inherited),"not when Gradius attacks")
laser.equipped_to=nil
for _,e in ipairs(opt.effects) do if e.code==EFFECT_PIERCE then check(not e.condition(e),"piercing removed with equip") end end
gradius.location=LOCATION_HAND
check(sd.condition(sd),"Option destroyed when selected Gradius leaves")
print("Gradius' Option anime equip-inheritance regression: PASS")

