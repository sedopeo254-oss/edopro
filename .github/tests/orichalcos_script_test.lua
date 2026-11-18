-- Check Seal of Orichalcos effect coverage and fail-safe runtime on
-- the current Core without the additional anime S/T-monster battle feature.
local path=assert(arg[1])
local code=assert(io.open(path,"rb")):read("*a")
for _,fragment in ipairs({
 "EFFECT_FLAG_CANNOT_INACTIVATE","EFFECT_FLAG_CANNOT_NEGATE",
 "EFFECT_INDESTRUCTABLE_EFFECT","EFFECT_CANNOT_TO_GRAVE",
 "EFFECT_CANNOT_TO_HAND","EFFECT_CANNOT_TO_DECK","EFFECT_CANNOT_REMOVE",
 "EFFECT_CANNOT_SSET","EFFECT_CANNOT_ACTIVATE","EFFECT_ORICA",
 "EFFECT_ORICA_SZONE","EFFECT_CANNOT_BE_BATTLE_TARGET",
 "e3:SetValue(500)","s.freezonemask","Duel.MoveToField",
 "e1:SetOperation(s.restore_original_forms)",
 "s.legendary_dragon_codes","s.has_orica_core=has_orica_core"
}) do assert(code:find(fragment,1,true),"Missing anime Seal source feature: "..fragment) end

local constants={
 EFFECT_FLAG_CANNOT_DISABLE=1,EFFECT_FLAG_IGNORE_IMMUNE=2,
 EFFECT_FLAG_CANNOT_INACTIVATE=4,EFFECT_FLAG_CANNOT_NEGATE=8,
 EFFECT_FLAG_SINGLE_RANGE=16,EFFECT_FLAG_SET_AVAILABLE=32,
 EFFECT_FLAG_PLAYER_TARGET=64,
 EFFECT_TYPE_SINGLE=1,EFFECT_TYPE_FIELD=2,EFFECT_TYPE_ACTIVATE=4,
 EFFECT_TYPE_IGNITION=8,EFFECT_TYPE_CONTINUOUS=16,
 EVENT_FREE_CHAIN=100,EVENT_LEAVE_FIELD_P=101,
 EFFECT_INDESTRUCTABLE_EFFECT=200,EFFECT_CANNOT_REMOVE=201,
 EFFECT_CANNOT_TO_HAND=202,EFFECT_CANNOT_TO_DECK=203,
 EFFECT_CANNOT_TO_GRAVE=204,EFFECT_CANNOT_DISABLE=205,
 EFFECT_CANNOT_TURN_SET=206,EFFECT_CANNOT_USE_AS_COST=207,
 EFFECT_CANNOT_DISEFFECT=208,EFFECT_CANNOT_ACTIVATE=209,
 EFFECT_CANNOT_SSET=210,EFFECT_UPDATE_ATTACK=211,
 EFFECT_CANNOT_BE_BATTLE_TARGET=212,
 LOCATION_FZONE=8,LOCATION_MZONE=4
}
for key,value in pairs(constants) do _G[key]=value end
local script
function GetID() script={} return script,291 end
aux={Stringid=function()return 1 end}
local function effect(card)
 local obj={owner=card,calls={}}
 function obj:Clone()
  local c=effect(self.owner)
  for k,v in pairs(self) do
   if k~="calls" and k~="owner" then c[k]=v end
  end
  for k,args in pairs(self.calls) do c.calls[k]={table.unpack(args)} end
  return c
 end
 for _,method in ipairs({
 "SetProperty","SetType","SetCode","SetCost","SetTarget",
 "SetOperation","SetRange","SetTargetRange","SetValue","SetDescription",
 "SetCondition","SetReset","SetCountLimit"
 }) do
  obj[method]=function(self,...)self.calls[method]={...}end
 end
 return obj
end
Effect={CreateEffect=effect}
local function initialize()
 script=nil
 assert(loadfile(path))()
 assert(script and script.initial_effect)
 local c={effects={}}
 function c:RegisterEffect(e) self.effects[#self.effects+1]=e end
 script.initial_effect(c)
 return script,c
end
-- Native-only extensions absent: card must still register its protection,
-- 500 ATK and Field Spell restrictions without crashing at SetCode(nil).
EFFECT_ORICA=nil
EFFECT_ORICA_SZONE=nil
EFFECT_SANCT_MZONE=nil
LOCATION_RMZONE=nil
LOCATION_RSZONE=nil
local s,card=initialize()
assert(s.has_orica_core==false)
assert(#card.effects==13,"expected 13 compatible effects, got "..#card.effects)
local function has_code(code)
 for _,e in ipairs(card.effects) do
  if e.calls.SetCode and e.calls.SetCode[1]==code then return true end
 end
 return false
end
assert(has_code(EFFECT_UPDATE_ATTACK),"500 ATK remains")
assert(has_code(EFFECT_CANNOT_ACTIVATE),"other non-Orichalcos Field Spells blocked")
assert(has_code(EFFECT_INDESTRUCTABLE_EFFECT),"protection remains")
assert(type(s.restore_original_forms)=="function","fusion restore callback exists")
-- Imported KCG Lua constants alone must NOT activate unsupported native
-- zone mechanics on the custom five-mode Core.
EFFECT_ORICA=4001
EFFECT_ORICA_SZONE=4002
EFFECT_SANCT_MZONE=4003
LOCATION_RMZONE=4
LOCATION_RSZONE=8
s,card=initialize()
assert(s.has_orica_core==false,"Lua constants alone must not enable back-row combat")
assert(#card.effects==13,"unsupported zone mechanics must remain inactive")
Duel={SupportsOrichalcosZones=function()return true end}
s,card=initialize()
assert(s.has_orica_core==true)
assert(#card.effects==17,"expected full native effects, got "..#card.effects)
assert(has_code(EFFECT_ORICA),"full native Orichalcos effect missing")
print("Orichalcos graceful standard Core / extension-aware anime script: PASS")
