-- Exact Draw-Phase Drop Off script regression for 2v1 / 3v1 / Standard.
CATEGORY_TOGRAVE=16
CATEGORY_HANDES=32
EVENT_DRAW=1104
LOCATION_HAND=2
PHASE_DRAW=1
PHASE_STANDBY=2
REASON_RULE=0x400
REASON_EFFECT=0x40
REASON_DISCARD=0x4000
POS_FACEUP=5
HINT_SELECTMSG=1
HINTMSG_TOGRAVE=2

local script
function GetID() script={} return script,55773067 end
local G={}
G.__index=G
G.__len=function(g) return #g.cards end
local function group(cards)
 return setmetatable({cards=cards or {}},G)
end
function G:Filter(fn,except,...)
 local t={}
 for _,c in ipairs(self.cards) do
  if c~=except and fn(c,...) then t[#t+1]=c end
 end
 return group(t)
end
function G:Select(p,n,m,except)
 assert(n==1 and m==1)
 -- The opponent, not the Trap's owner, chooses among multiple drawn cards.
 assert(p==Duel.GetTurnPlayer())
 return group({self.cards[#self.cards]})
end
local function card(controller,loc,related)
 local c={owner=controller,loc=loc or LOCATION_HAND,related=related~=false}
 function c:IsLocation(location) return self.loc==location end
 function c:IsControler(p) return self.owner==p end
 function c:IsRelateToEffect(e) return self.related end
 return c
end
local phase,turn,target_group,discarded
Duel={}
function Duel.GetCurrentPhase() return phase end
function Duel.GetTurnPlayer() return turn end
function Duel.SetTargetCard(g) target_group=g end
function Duel.SetOperationInfo(...) end
function Duel.Hint(...) end
function Duel.SendtoGrave(g,reason)
 assert(reason==(REASON_EFFECT|REASON_DISCARD))
 discarded={}
 for _,c in ipairs(g.cards) do
  discarded[#discarded+1]=c
  c.loc=0
 end
 return #discarded
end
local e={}
dofile("multiplayer-anime-cards/c55773067.lua")
local function condition(tp,eg,ep,reason)
 return script.condition(e,tp,eg,ep,1,nil,reason,reason,ep)
end
local function target(tp,eg,ep,chk)
 return script.target(e,tp,eg,ep,1,nil,REASON_RULE,REASON_RULE,chk)
end
local function activate(tp,eg,ep)
 discarded={}
 script.activate(e,tp,eg,ep,1,nil,REASON_RULE,REASON_RULE)
end
-- Physical side1 is Big Five; side0 is Joey/Yugi.
phase=PHASE_DRAW;turn=1
local drawn=card(1)
local other=card(1)
local eg=group({drawn})
assert(condition(0,eg,1,REASON_RULE))
assert(target(0,eg,1,0))
target(0,eg,1,1)
assert(#target_group==1 and target_group.cards[1]==drawn)
activate(0,eg,1)
assert(#discarded==1 and discarded[1]==drawn and other.loc==LOCATION_HAND)
-- An additional draw from an effect *during opponent Draw Phase* is legal.
local extra=card(1)
assert(condition(0,group({extra}),1,REASON_EFFECT))
-- Your own Draw Phase is not a legal activation window.
turn=0;assert(not condition(0,group({card(0)}),0,REASON_RULE))
-- The opponent drawing during your Draw Phase is not their own Draw Phase.
assert(not condition(0,group({card(1)}),1,REASON_EFFECT))
-- No Standby/Main/End Phase activation.
turn=1;phase=PHASE_STANDBY
assert(not condition(0,group({card(1)}),1,REASON_RULE))
-- The previously-held hand cards are not legal targets.
phase=PHASE_DRAW
local incoming=card(1)
target(0,group({incoming}),1,1)
assert(#target_group==1 and target_group.cards[1]==incoming)
-- Cards no longer in hand or no longer related are NOT discarded.
local escaped=card(1,LOCATION_HAND,false)
activate(0,group({escaped}),1);assert(#discarded==0)
-- Multiple cards drawn by one effect: only one *newly drawn* card discarded.
local c1,c2,c3=card(1),card(1),card(1)
activate(0,group({c1,c2,c3}),1)
assert(#discarded==1 and discarded[1]==c3)
-- Big Five's Trap must affect the drawn team member's card on physical side0.
turn=0
local j=card(0)
assert(condition(1,group({j}),0,REASON_RULE))
activate(1,group({j}),0)
assert(#discarded==1 and discarded[1]==j)
print("Drop Off: Draw Phase and exact drawn-card regression PASS")
