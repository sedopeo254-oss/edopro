-- Test same-turn Surprise Attack script callback contract.
-- Does not replace the Core state machine test, which checks turn handling.
local path=assert(arg[1])
local text=assert(io.open(path,"rb")):read("*a")
assert(not text:find("Duel.SkipPhase",1,true))
assert(not text:find("EFFECT_SKIP_TURN",1,true))
assert(text:find("Duel.RequestExtraBattlePhase(tp)",1,true))
assert(text:find("EVENT_PHASE_START+PHASE_BATTLE_START",1,true))
assert(text:find("Duel.RaiseSingleEvent(tc,EVENT_SPSUMMON_SUCCESS",1,true))
local s
function GetID() s={} return s,319 end
local values={
 EFFECT_TYPE_ACTIVATE=1,EFFECT_TYPE_FIELD=2,EFFECT_TYPE_CONTINUOUS=4,
 EFFECT_FLAG_CANNOT_DISABLE=8,EFFECT_FLAG_IGNORE_IMMUNE=16,
 EVENT_FREE_CHAIN=100,EVENT_SUMMON_SUCCESS=101,EVENT_SPSUMMON_SUCCESS=102,
 EVENT_PHASE_START=10000,PHASE_BATTLE_START=0x08,PHASE_END=0x200,
 EFFECT_CANNOT_ATTACK=103,LOCATION_MZONE=4,LOCATION_SZONE=8,
 LOCATION_DECK=1,LOCATION_HAND=2,LOCATION_GRAVE=16,LOCATION_REMOVED=32,LOCATION_EXTRA=64,
 RESET_PHASE=0x40000000,RESET_SELF_TURN=0x10000000,
 STATUS_SUMMON_TURN=1,STATUS_SPSUMMON_TURN=2,TYPE_MONSTER=1,REASON_RULE=1024
}
for name,v in pairs(values) do _G[name]=v end
local calls={phase=PHASE_END,turn=1,current=1,requested=0,can=true,recover={{}}}
local function effect(owner)
 local e={handler=owner}
 function e:Clone() local x=effect(owner);for k,v in pairs(self) do x[k]=v end;return x end
 function e:GetHandler()return self.handler end
 for _,name in ipairs({"Type","Code","Property","Condition","Target","Operation","CountLimit","Reset","TargetRange"}) do
  e["Set"..name]=function(self,v)self[name:lower()]=v end
 end
 return e
end
Effect={CreateEffect=effect}
aux={GlobalCheck=function(s,callback)callback()end}
local global={}
Duel={
 RegisterEffect=function(e,tp)global[#global+1]=e end,
 GetCurrentPhase=function()return calls.phase end,
 GetTurnPlayer=function()return calls.current end,
 CanRequestExtraBattlePhase=function(tp)return calls.can and tp==calls.current end,
 GetTurnCount=function()return calls.turn end,
 IsExistingMatchingCard=function(filter,tp,loc,ex,min,excluded,...)
  return loc & LOCATION_MZONE~=0 and #calls.recover>0
 end,
 RequestExtraBattlePhase=function()calls.requested=calls.requested+1;return true end,
 GetMatchingGroup=function() return {Iter=function()
  local i=0;return function()i=i+1;return calls.recover[i] end
 end} end,
 GetLocationCount=function()return 2 end,
 MoveToField=function()return true end,
 RaiseSingleEvent=function() calls.single=(calls.single or 0)+1 end,
 RaiseEvent=function()calls.group=(calls.group or 0)+1 end
}
local card={effects={}}
function card:RegisterEffect(e)self.effects[#self.effects+1]=e end
assert(loadfile(path))()
s.initial_effect(card)
local activation=card.effects[1]
assert(activation.code==EVENT_FREE_CHAIN)
assert(activation.condition(activation,1))
calls.phase=0x100;assert(not activation.condition(activation,1))
calls.phase=PHASE_END
assert(activation.target(activation,1,nil,nil,nil,nil,nil,nil,0))
activation.operation(activation,1)
assert(calls.requested==1)
assert(#global==4,"two global summon trackers and two end-phase helpers expected")
calls.can=false
assert(not activation.condition(activation,1),"no infinite repeat")
print("Surprise Attack same-turn script: PASS")
