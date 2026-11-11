-- Regression for EDOPro's two FIELD-effect SetTarget calling conventions.
-- Tests the exact callback mismatch seen in c153000017.lua:124.
-- Usage: lua5.4 .github/tests/shinatos_ark_send_replace_test.lua multiplayer-deck-master/c153000017.lua
local script
function GetID() script={} return script,153000017 end
LOCATION_GRAVE=16
LOCATION_ALL=127
REASON_EFFECT=2
EFFECT_TYPE_SINGLE=1
EFFECT_FLAG_IGNORE_IMMUNE=2
EFFECT_CANNOT_TRIGGER=3
RESET_EVENT=256
RESETS_STANDARD=0x1fe0000
RESET_LEAVE=0x800000
local function group(items)
 local obj={items=items}
 local methods={}
 function methods:Iter()
  local i=0
  return function() i=i+1 return self.items[i] end
 end
 function methods:Filter(pred,exception)
  local selected={}
  for _,c in ipairs(self.items) do
   if c~=exception and pred(c) then selected[#selected+1]=c end
  end
  return group(selected)
 end
 function methods:IsExists(pred,count,exception)
  local found=0
  for _,c in ipairs(self.items) do
   if c~=exception and pred(c) then
    found=found+1
    if found>=count then return true end
   end
  end
  return false
 end
 function methods:Merge(g)
  for _,c in ipairs(g.items) do self.items[#self.items+1]=c end
 end
 return setmetatable(obj,{__len=function(x)return #x.items end,__index=methods})
end
local function card(monster,destination)
 local c={monster=monster,destination=destination,effects={}}
 function c:GetDestination() return self.destination end
 function c:IsMonster() return self.monster end
 function c:IsLocation(x) return false end
 function c:RegisterEffect(e) self.effects[#self.effects+1]=e end
 return c
end
Card={IsLocation=function(c,loc)return c:IsLocation(loc) end}
aux={NOT=function(pred)return function(c,...)return not pred(c,...) end end}
local created=0
Effect={CreateEffect=function()
 created=created+1
 local e={}
 function e:SetType(x) self.type=x end
 function e:SetProperty(x) self.property=x end
 function e:SetCode(x) self.code=x end
 function e:SetReset(x) self.reset=x end
 return e
end}
local sent={}
local operated=group({})
Duel={
 SendtoDeck=function(g,tp,seq,reason)
  assert(tp==0 and seq==-2 and reason==REASON_EFFECT)
  sent[#sent+1]=g
  operated=g
  return #g
 end,
 GetOperatedGroup=function()return operated end
}
local ark=group({})
local effect={GetOwner=function() return {} end,GetLabelObject=function() return ark end}
local file=assert(arg[1],"script path required")
assert(loadfile(file))()
local eligible=card(true,LOCATION_GRAVE)
local spell=card(false,LOCATION_GRAVE)
local other=card(true,1)
-- Normal field-effect card applicability query (e, Card), with no eg/chk.
assert(script.reptg(effect,eligible)==true)
assert(script.reptg(effect,spell)==false)
assert(script.reptg(effect,other)==false)
assert(script.reptg(effect,nil)==false)
assert(script.reptg(effect,0)==false)
assert(#sent==0 and created==0 and #ark==0,"predicate query modified the duel")
-- Actual EVENT_SEND_REPLACE target legality (chk=0) and resolution (chk=1).
local event_group=group({eligible,spell,other})
assert(script.reptg(effect,0,event_group,0,0,nil,0,0,0))
assert(#sent==0 and #ark==0,"legality check mutated the Ark")
assert(not script.reptg(effect,0,group({spell,other}),0,0,nil,0,0,0))
assert(script.reptg(effect,0,event_group,0,0,nil,0,0,1))
assert(#sent==1 and #sent[1]==1 and sent[1].items[1]==eligible)
assert(#eligible.effects==1 and eligible.effects[1].code==EFFECT_CANNOT_TRIGGER)
assert(#ark==1 and ark.items[1]==eligible,"redirected monster was not added to Ark")
assert(script.reptg(effect,0,nil,0,0,nil,0,0,0)==false)
assert(script.reptg(effect,0,group({spell}),0,0,nil,0,0,1)==false)
assert(script.reptg(effect,0,event_group,0,0,nil,0,0,nil)==false)
assert(#sent==1 and #ark==1,"invalid callback changed Ark content")
print("Shinato's Ark nil-eg and send-replacement regression: PASS")
