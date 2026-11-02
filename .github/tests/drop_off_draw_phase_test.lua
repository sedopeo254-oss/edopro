-- Regression: the ORIGINAL rule draw MUST offer Drop Off in Draw Phase,
-- even in 2v1/3v1. Extension for effect draws is a SEPARATE delayed effect.
EFFECT_TYPE_ACTIVATE=0x10
EFFECT_FLAG_DELAY=0x10000
CATEGORY_TOGRAVE=0x20
CATEGORY_HANDES=0x80
EVENT_DRAW=1110
LOCATION_HAND=2
LOCATION_GRAVE=0x10
REASON_RULE=0x400
REASON_EFFECT=0x40
REASON_DISCARD=0x4000

local script
function GetID() script={} return script,55773067 end
local G={}
G.__index=G
G.__len=function(g) return #g.cards end
local function group(cards) return setmetatable({cards=cards or {}},G) end
function G:Filter(filter,except,...)
    local result={}
    for _,c in ipairs(self.cards) do
        if c~=except and filter(c,...) then result[#result+1]=c end
    end
    return group(result)
end
Card={}
Card.__index=Card
function Card.IsRelateToEffect(c,e) return c.related end
function Card.IsLocation(c,loc) return c.location==loc end
local function card(side,logical,related)
    return setmetatable({side=side,logical=logical,related=related~=false,
        location=LOCATION_HAND},Card)
end
local original,delayed,targets,handes,discarded
Effect={}
function Effect.CreateEffect(c)
    local e={owner=c}
    function e:SetType(t) self.type=t end
    function e:SetProperty(p) self.property=p end
    function e:SetCategory(c) self.category=c end
    function e:SetCode(c) self.code=c end
    function e:SetCondition(c) self.condition=c end
    function e:SetTarget(t) self.target=t end
    function e:SetOperation(o) self.operation=o end
    function e:Clone()
        local cloned=Effect.CreateEffect(self.owner)
        for k,v in pairs(self) do
            if type(v)~="function" then cloned[k]=v end
        end
        cloned.condition=self.condition
        cloned.target=self.target
        cloned.operation=self.operation
        return cloned
    end
    return e
end
Duel={}
function Duel.SetTargetCard(g) targets=g end
function Duel.SetOperationInfo(chain,category,g,count,player,flag)
    handes={category=category,count=count,player=player}
end
function Duel.SendtoGrave(g,reason)
    assert(reason==(REASON_EFFECT|REASON_DISCARD))
    discarded={}
    for _,c in ipairs(g.cards) do
        discarded[#discarded+1]=c
        c.location=LOCATION_GRAVE
    end
    return #discarded
end
local trap={effects={}}
function trap:RegisterEffect(e) self.effects[#self.effects+1]=e end
dofile("multiplayer-anime-cards/c55773067.lua")
script.initial_effect(trap)
assert(#trap.effects==2,"Normal rule and effect draws have distinct activations")
original,delayed=trap.effects[1],trap.effects[2]
assert(original.type==EFFECT_TYPE_ACTIVATE and original.code==EVENT_DRAW
    and not original.property,
    "Normal draw must use the UNMODIFIED EDOPro activation window")
assert(delayed.code==EVENT_DRAW and delayed.property==EFFECT_FLAG_DELAY,
    "Only effect draws need delayed event timing")
local function check_condition(e,tp,eg,ep,r,re)
    return e.condition(e,tp,eg,ep,#eg,re,r,ep)
end
local function activate(e,tp,eg,ep,r)
    targets=nil
    handes=nil
    discarded={}
    assert(e.target(e,tp,eg,ep,#eg,nil,r,ep,0),
        "Canonical target must ALWAYS permit the normal draw prompt")
    e.target(e,tp,eg,ep,#eg,nil,r,ep,1)
    assert(targets==eg and handes.count==1 and handes.player==1-tp)
    e.operation(e,tp,eg,ep,#eg,nil,r,ep)
end

-- The regular Draw Phase uses REASON_RULE even without a reason effect.
-- P3 (Big Five) draws on physical side 1; P1 or P2 on side 0 can respond.
local first=card(1,2)
local existing=card(1,2)
local g=group({first})
assert(check_condition(original,0,g,1,REASON_RULE,nil))
assert(not check_condition(delayed,0,g,1,REASON_RULE,nil))
activate(original,0,g,1,REASON_RULE)
assert(#discarded==1 and discarded[1]==first and existing.location==LOCATION_HAND,
    "Normal draw: only newly drawn card is discarded")

-- Big Five can respond to P1 or P2's normal draw, both on physical side 0.
for logical=0,1 do
    local teammate_draw=card(0,logical)
    local event=group({teammate_draw})
    assert(check_condition(original,1,event,0,REASON_RULE,nil))
    activate(original,1,event,0,REASON_RULE)
    assert(#discarded==1 and discarded[1]==teammate_draw)
end

-- 3v1: allied P1, P2, P3 normal draws also use physical side 0.
for logical=0,2 do
    local allied=card(0,logical)
    assert(check_condition(original,1,group({allied}),0,REASON_RULE,nil))
end

-- Draw due to a card effect: only the separately registered delayed
-- activation is offered. No duplicate prompts from original normal draw.
local by_effect=card(1,2)
assert(not check_condition(original,0,group({by_effect}),1,REASON_EFFECT,{}))
assert(check_condition(delayed,0,group({by_effect}),1,REASON_EFFECT,{}))
activate(delayed,0,group({by_effect}),1,REASON_EFFECT)
assert(#discarded==1 and discarded[1]==by_effect)

-- An effect draw of three cards sends THREE to the GY, not pre-existing cards.
local a,b,c=card(1,2),card(1,2),card(1,2)
local three=group({a,b,c})
assert(check_condition(delayed,0,three,1,REASON_EFFECT,{}))
activate(delayed,0,three,1,REASON_EFFECT)
assert(#discarded==3 and existing.location==LOCATION_HAND)

-- Moving the drawn card out of hand in response cancels that discard.
local moved=card(1,2)
moved.location=LOCATION_GRAVE
local detached=card(1,2,false)
activate(delayed,0,group({moved,detached}),1,REASON_EFFECT)
assert(#discarded==0)

-- No activation when YOU draw, even in the normal Draw Phase.
assert(not check_condition(original,0,group({card(0,0)}),0,REASON_RULE,nil))
assert(not check_condition(delayed,0,group({card(0,1)}),0,REASON_EFFECT,{}))
print("Drop Off: canonical normal Draw Phase + separate effect draw tests PASS")
