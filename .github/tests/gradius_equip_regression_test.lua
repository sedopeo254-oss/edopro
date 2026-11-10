-- Script-level regression for Gradius + Cyclon Laser + Matter Leveller.
-- This tests Lua effect declarations and representative engine ATK ordering.
local laser_path=assert(arg[1])
local matter_path=assert(arg[2])
EFFECT_TYPE_EQUIP=30
EFFECT_UPDATE_ATTACK=31
EFFECT_SET_ATTACK=32
EFFECT_SET_ATTACK_FINAL=33
EFFECT_PIERCE=34
PHASE_DAMAGE_CAL=40
local phase=0
local gradius={code=10992251}
local attacker=gradius
local target={defense=1500,defense_pos=true}
function target:GetDefense() return self.defense end
function target:IsDefensePos() return self.defense_pos end
Duel={
  GetCurrentPhase=function() return phase end,
  GetAttacker=function() return attacker end,
  GetAttackTarget=function() return target end,
}
Card={IsCode=function(c,code) return c.code==code end}
aux={
  FilterBoolFunction=function(f,code)
    return function(c) return f(c,code) end
  end,
  AddEquipProcedure=function(c,_,filter)
    assert(filter(gradius) and not filter({code=1111}))
  end,
}
Effect={CreateEffect=function(handler)
  local e={handler=handler}
  function e:SetType(v) self.type=v end
  function e:SetCode(v) self.code=v end
  function e:SetValue(v) self.value=v end
  function e:SetCondition(v) self.condition=v end
  function e:GetHandler() return self.handler end
  return e
end}
local all={}
local function equip(path,code)
  local s={}
  function GetID() return s,code end
  assert(loadfile(path))()
  local card={effects={}}
  function card:RegisterEffect(e)
    self.effects[#self.effects+1]=e
    all[#all+1]=e
  end
  function card:GetEquipTarget() return gradius end
  s.initial_effect(card)
  return card
end
local laser=equip(laser_path,5494820)
local leveller=equip(matter_path,511000219)
assert(#laser.effects==2 and #leveller.effects==1)
assert(laser.effects[1].code==EFFECT_UPDATE_ATTACK)
assert(laser.effects[1].value==300)
assert(laser.effects[2].code==EFFECT_PIERCE)
assert(leveller.effects[1].code==EFFECT_SET_ATTACK_FINAL)
-- Core/card.cpp applies SET_ATTACK_FINAL equip effects after UPDATE_ATTACK.
local function atk()
  local base,bonus,final=1200,0,nil
  for _,e in ipairs(all) do
    if not e.condition or e.condition(e) then
      local value=type(e.value)=="function" and e.value(e,gradius) or e.value
      if e.code==EFFECT_UPDATE_ATTACK then bonus=bonus+value
      elseif e.code==EFFECT_SET_ATTACK then base=value
      elseif e.code==EFFECT_SET_ATTACK_FINAL then final=value end
    end
  end
  return final or (base+bonus)
end
local function check(expected,description)
  assert(atk()==expected,description..": expected "..expected..", got "..atk())
end
check(1500,"outside calculation")
phase=PHASE_DAMAGE_CAL
check(1600,"turn 16 replay: Gradius vs 1500 DEF")
target.defense=2500
check(2600,"target with 2500 DEF")
target.defense=1500
target.defense_pos=false
check(1500,"attack-position target")
target.defense_pos=true
attacker={code=12}
check(1500,"other attacker")
attacker=gradius
target=nil
check(1500,"direct attack")
phase=0
check(1500,"outside Damage Calculation")
print("Cyclon Laser + Matter Leveller: PASS")
