-- Fast anime Drop Off: opponent normal Draw Phase or effect draw in ANY phase.
-- Execute the real c55773067.lua, including three-player/two-team cases.
EFFECT_TYPE_ACTIVATE=0x10
EFFECT_FLAG_DELAY=0x10000
CATEGORY_TOGRAVE=16
CATEGORY_HANDES=32
EVENT_DRAW=1110
LOCATION_HAND=2
PHASE_DRAW=1
PHASE_STANDBY=2
PHASE_MAIN1=4
PHASE_BATTLE=128
PHASE_END=512
REASON_RULE=0x400
REASON_EFFECT=0x40
REASON_DISCARD=0x4000

local script
function GetID() script={} return script,55773067 end
local G={}
G.__index=G
G.__len=function(g) return #g.cards end
local function group(cards) return setmetatable({cards=cards or {}},G) end
function G:Filter(fn,except,...)
    local out={}
    for _,c in ipairs(self.cards) do
        if c~=except and fn(c,...) then out[#out+1]=c end
    end
    return group(out)
end
local function card(side,logical,related)
    local c={side=side,logical=logical,loc=LOCATION_HAND,related=related~=false}
    function c:IsLocation(loc) return self.loc==loc end
    function c:IsControler(p) return self.side==p end
    function c:IsRelateToEffect(e) return self.related end
    return c
end
local phase,turn,targets,info,discards
Duel={}
function Duel.GetCurrentPhase() return phase end
function Duel.GetTurnPlayer() return turn end
function Duel.SetTargetCard(g) targets=g end
function Duel.SetOperationInfo(_,category,g,count,player,location)
    info[#info+1]={category=category,cards=g,count=count,player=player,location=location}
end
function Duel.SendtoGrave(g,reason)
    assert(reason==(REASON_EFFECT|REASON_DISCARD))
    discards={}
    for _,c in ipairs(g.cards) do
        discards[#discards+1]=c
        c.loc=0
    end
    return #discards
end
Effect={}
function Effect.CreateEffect(c)
    local e={}
    function e:SetType(t) self.type=t end
    function e:SetProperty(p) self.property=p end
    function e:SetCategory(c) self.category=c end
    function e:SetCode(c) self.code=c end
    function e:SetCondition(c) self.condition=c end
    function e:SetTarget(t) self.target=t end
    function e:SetOperation(o) self.operation=o end
    return e
end
local e={}
dofile("multiplayer-anime-cards/c55773067.lua")
local trap={}
function trap:RegisterEffect(ef) self.ef=ef end
script.initial_effect(trap)
assert(trap.ef.type==EFFECT_TYPE_ACTIVATE
    and trap.ef.property==EFFECT_FLAG_DELAY
    and trap.ef.code==EVENT_DRAW,
    "Must remain a promptable quick Trap on each opponent draw event")
local function condition(tp,eg,ep,reason,effect)
    return script.condition(e,tp,eg,ep,#eg,effect,reason,ep)
end
local function activate(tp,eg,ep,reason)
    discards={}
    script.activate(e,tp,eg,ep,#eg,nil,reason,ep)
end
local function aim(tp,eg,ep)
    targets=nil
    info={}
    assert(script.target(e,tp,eg,ep,#eg,nil,REASON_EFFECT,ep,0))
    script.target(e,tp,eg,ep,#eg,nil,REASON_EFFECT,ep,1)
    assert(#targets==#eg and #info==2)
    for _,v in ipairs(info) do
        assert(v.count==#eg and v.player==ep and v.location==LOCATION_HAND)
    end
end
-- Ordinary Big Five draw in its own Draw Phase: legal.
phase=PHASE_DRAW;turn=1
local first=card(1,2)
local old=card(1,2)
local g=group({first})
assert(condition(0,g,1,REASON_RULE,nil))
aim(0,g,1);activate(0,g,1,REASON_RULE)
assert(#discards==1 and discards[1]==first and old.loc==LOCATION_HAND)

-- An effect draw during Big Five's Draw Phase also works.
local by_effect=card(1,2)
assert(condition(0,group({by_effect}),1,REASON_EFFECT,{}))

-- The opponent draws by Spell/monster ability in Standby/Main/Battle/End.
for _,new_phase in ipairs({PHASE_STANDBY,PHASE_MAIN1,PHASE_BATTLE,PHASE_END}) do
    phase=new_phase;turn=1
    assert(condition(0,group({card(1,2)}),1,REASON_EFFECT,{}))
end

-- The opponent draws during YOUR turn by a card effect.
phase=PHASE_MAIN1;turn=0
local offturn=card(1,2)
assert(condition(0,group({offturn}),1,REASON_EFFECT,{}))
aim(0,group({offturn}),1);activate(0,group({offturn}),1,REASON_EFFECT)
assert(#discards==1 and discards[1]==offturn)

-- An effect may accidentally use REASON_RULE; reason-effect pointer still
-- proves the draw came from an activated effect.
assert(condition(0,group({card(1,2)}),1,REASON_RULE,{}))

-- Ordinary rule-based draw outside opponent's Draw Phase isn't sufficient.
assert(not condition(0,group({card(1,2)}),1,REASON_RULE,nil))

-- A friendly player's draws must never trigger Drop Off.
phase=PHASE_DRAW;turn=0
assert(not condition(0,group({card(0,0)}),0,REASON_RULE,nil))
assert(not condition(0,group({card(0,1)}),0,REASON_EFFECT,{}))
assert(not condition(0,group({}),1,REASON_EFFECT,{}))

-- Multiple draws from one activated effect -> discard ALL new cards.
phase=PHASE_MAIN1;turn=1
local p1,p2,p3=card(1,2),card(1,2),card(1,2)
local many=group({p1,p2,p3})
assert(condition(0,many,1,REASON_EFFECT,{}))
aim(0,many,1);activate(0,many,1,REASON_EFFECT)
assert(#discards==3 and discards[1]==p1 and discards[2]==p2
    and discards[3]==p3 and old.loc==LOCATION_HAND,
    "Three newly drawn cards must ALL go to Graveyard")

-- Cards moved away, or no longer related, cannot be discarded again.
local moved=card(1,2)
moved.loc=0
local detached=card(1,2,false)
local valid=card(1,2)
activate(0,group({moved,detached,valid}),1,REASON_EFFECT)
assert(#discards==1 and discards[1]==valid)

-- When Big Five controls Drop Off, either Yugi (P1) or Joey (P2)
-- on the opposite physical side is a valid opponent.
phase=PHASE_MAIN1;turn=1
for logical=0,1 do
    local team_draw=card(0,logical)
    assert(condition(1,group({team_draw}),0,REASON_EFFECT,{}))
    aim(1,group({team_draw}),0)
    activate(1,group({team_draw}),0,REASON_EFFECT)
    assert(#discards==1 and discards[1]==team_draw)
end

-- Works in 3v1 (the 3 allies share a physical field side).
for logical=0,2 do
    local ally=card(0,logical)
    assert(condition(1,group({ally}),0,REASON_EFFECT,{}))
end
print("Drop Off fast response: 2v1, 3v1, effect draws and all drawn cards PASS")
