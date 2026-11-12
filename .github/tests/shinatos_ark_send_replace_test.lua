-- Native redirect/Ark collection regression: Kaiba's Gradius and its
-- linked Option must both enter Shinato's Ark without nested replacements.
-- Usage: lua5.4 .github/tests/shinatos_ark_send_replace_test.lua multiplayer-deck-master/c153000017.lua
local s
function GetID() s={} return s,153000017 end
REASON_RULE=0x400; REASON_DESTROY=0x1; REASON_EFFECT=0x40
LOCATION_NONE=0; LOCATION_DECK=1; LOCATION_EXTRA=0x40
LOCATION_GRAVE=0x10; LOCATION_MZONE=4; LOCATION_ALL=0x7f
RESET_EVENT=0x1000; RESETS_STANDARD=0x1fe0000
RESET_TODECK=0x00400000; RESET_LEAVE=0x00800000
EFFECT_TYPE_SINGLE=1; EFFECT_FLAG_IGNORE_IMMUNE=2; EFFECT_CANNOT_TRIGGER=3
local active=true
local turns=0
local sent,operated,in_send={},nil,false
local function group(items)
 local v={items=items}
 local methods={}
 function methods:Filter(fn,except,...)
  local result={}
  for _,c in ipairs(self.items) do
   if c~=except and fn(c,...) then result[#result+1]=c end
  end
  return group(result)
 end
 function methods:Merge(other)
  for _,c in ipairs(other.items) do
   local found=false
   for _,x in ipairs(self.items) do if x==c then found=true end end
   if not found then self.items[#self.items+1]=c end
  end
 end
 function methods:Iter()
  local i=0;return function() i=i+1 return self.items[i] end
 end
 return setmetatable(v,{__index=methods,__len=function(v)return #v.items end})
end
local function card(code,location,reason,monster)
 local o={code=code,location=location,reason=reason,monster=monster,flags={}}
 function o:IsMonster() return self.monster end
 function o:IsReason(r) return (self.reason & r)~=0 end
 function o:IsLocation(loc) return (self.location & loc)~=0 end
 function o:GetFlagEffect(id) return self.flags[id] or 0 end
 function o:RegisterFlagEffect(id,reset,...)
  assert(reset & RESET_EVENT~=0)
  assert(reset & RESET_TODECK==0 and reset & RESET_LEAVE==0)
  self.flags[id]=(self.flags[id] or 0)+1
 end
 function o:RegisterEffect(e) self.effects=self.effects or {};self.effects[#self.effects+1]=e end
 return o
end
Card={IsLocation=function(c,loc) return c:IsLocation(loc) end}
aux={NOT=function(f) return function(c,...) return not f(c,...) end end}
Effect={CreateEffect=function()
 local e={}
 function e:SetType(x) self.type=x end
 function e:SetProperty(x) self.property=x end
 function e:SetCode(x) self.code=x end
 function e:SetReset(x) self.reset=x end
 return e
end}
Duel={
 IsDeckMaster=function(tp,code) assert(tp==1 and code==153000017);return active end,
 GetFlagEffect=function(tp,code) assert(tp==1 and code==153000017);return turns end,
 DisableShuffleCheck=function()end,
 SendtoDeck=function(g,tp,seq,reason)
  assert(not in_send,"recursive send-to-deck detected")
  in_send=true
  assert(tp==1 and seq==-2 and reason==REASON_EFFECT)
  local moved={}
  for c in g:Iter() do
   assert(c:IsLocation(LOCATION_DECK|LOCATION_EXTRA),"only fully redirected cards may enter Ark")
   c.location=LOCATION_NONE
   moved[#moved+1]=c
  end
  operated=group(moved)
  sent[#sent+1]=moved
  in_send=false
  return #moved
 end,
 GetOperatedGroup=function() return operated end
}
assert(loadfile(assert(arg[1])))()
local ark=group({})
local e={
 GetHandlerPlayer=function() return 1 end,
 GetOwner=function() return {} end,
 GetLabelObject=function() return ark end
}
-- Both monsters are destroyed; the actual redirect occurs in core SendTo,
-- rather than invoking another Lua SendtoDeck from a replacement callback.
local gradius=card(10992251,LOCATION_MZONE,REASON_DESTROY|REASON_EFFECT,true)
local option=card(14291024,LOCATION_MZONE,REASON_DESTROY|REASON_EFFECT,true)
local spell=card(5494820,LOCATION_MZONE,REASON_EFFECT,false)
assert(s.repRuleTg(e,gradius))
assert(s.repRuleTg(e,option))
assert(not s.repRuleTg(e,spell))
assert(gradius:GetFlagEffect(153000017)==1 and option:GetFlagEffect(153000017)==1)
assert(s.repRuleTg(e,gradius))
assert(gradius:GetFlagEffect(153000017)==1,"repeated redirect query duplicated flag")
-- Simulate the engine redirecting both pending graveyard destinations into
-- the bottom of the Deck. EVENT_TO_DECK arrives after this native movement.
gradius.location=LOCATION_DECK;option.location=LOCATION_DECK
s.repRuleOp(e,1,group({gradius,option,spell}))
assert(#sent==1 and #sent[1]==2,"Gradius and Option should move together")
assert(gradius.location==LOCATION_NONE and option.location==LOCATION_NONE)
assert(#ark==2 and ark.items[1]==gradius and ark.items[2]==option)
assert(#gradius.effects==1 and #option.effects==1)
assert(#ark:Filter(function(c)return c.code==10992251 end,nil)==1)
assert(#ark:Filter(function(c)return c.code==14291024 end,nil)==1)
-- A later redundant event must not register cards twice.
s.repRuleOp(e,1,group({gradius,option}))
assert(#ark==2 and #sent==1)
-- Separate destruction events are also supported (Option dies on ADJUST).
ark=group({});e.GetLabelObject=function()return ark end;sent={}
local g2=card(10992251,LOCATION_MZONE,REASON_DESTROY|REASON_EFFECT,true)
local o2=card(14291024,LOCATION_MZONE,REASON_DESTROY|REASON_EFFECT,true)
assert(s.repRuleTg(e,g2))
g2.location=LOCATION_DECK
s.repRuleOp(e,1,group({g2}))
assert(s.repRuleTg(e,o2))
o2.location=LOCATION_DECK
s.repRuleOp(e,1,group({o2}))
assert(#ark==2 and #sent==2)
-- Other cards sent straight to Deck must not be stolen by the Ark.
local unrelated=card(9999,LOCATION_DECK,REASON_EFFECT,true)
s.repRuleOp(e,1,group({unrelated}))
assert(#ark==2)
-- When Ark has expired, normal monster destruction must NOT redirect.
active=false;local late=card(10,LOCATION_MZONE,REASON_EFFECT,true)
assert(not s.repRuleTg(e,late))
-- The previous rule-based redirection remains supported.
local rule=card(11,LOCATION_MZONE,REASON_RULE,true)
assert(s.repRuleTg(e,rule))
rule.location=LOCATION_EXTRA
s.repRuleOp(e,1,group({rule}))
assert(#ark==3 and ark.items[3]==rule)
assert(#sent==3)
assert(s.repRuleOp(e,1,nil)==nil)
print("Shinato's Ark simultaneous/sequential redirect into Ark: PASS")
