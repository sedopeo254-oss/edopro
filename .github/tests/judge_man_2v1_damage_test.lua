-- Judge Man (Deck Master) logical-player damage regression tests.
-- Execute directly with the Lua interpreter against the actual script.
LOCATION_MZONE=4
LOCATION_REMOVED=32
REASON_EFFECT=64
POS_FACEUP=5
HINT_CARD=1

local script
function GetID()
    script={}
    return script,153000022
end
aux={Stringid=function(code,number) return number end}

local G={}
G.__index=G
G.__len=function(self) return #self.cards end
local function make_group(cards)
    local list={}
    for _,c in ipairs(cards or {}) do list[#list+1]=c end
    return setmetatable({cards=list},G)
end
function G:IsContains(c)
    for _,tc in ipairs(self.cards) do if tc==c then return true end end
    return false
end
function G:Merge(other)
    for _,c in ipairs(other.cards) do
        if not self:IsContains(c) then self.cards[#self.cards+1]=c end
    end
    return self
end
function G:Filter(predicate,exception,...)
    local out={}
    for _,c in ipairs(self.cards) do
        if c~=exception and predicate(c,...) then out[#out+1]=c end
    end
    return make_group(out)
end
function G:FilterCount(predicate,exception,...)
    return #self:Filter(predicate,exception,...)
end
Group={CreateGroup=function() return make_group() end}
Card={
    IsAbleToRemove=function(c) return c.can_banish end,
    IsLocation=function(c,location) return c.location==location end,
}
local e={owner={GetLogicalOwner=function() return 2 end}}
function e:GetOwner() return self.owner end
local fields,legacy_monsters,events,removed,lp,active_mask,mode,can_use_master,accept
local function monster(controller,can_banish,replacement)
    local c={controller=controller,location=LOCATION_MZONE,
        can_banish=can_banish~=false,replacement=replacement}
    function c:IsLocation(location) return self.location==location end
    return c
end
local function setup(p1,p2,solo,options)
    options=options or {}
    fields={[0]=p1 or {},[1]=p2 or {},[2]=solo or {}}
    legacy_monsters=options.legacy or {}
    events={}
    removed={}
    active_mask=options.mask or 7
    mode=options.mode or "two_vs_one"
    lp={[0]=options.lp0 or 4000,[1]=options.lp1 or 8000}
    can_use_master=options.master~=false
    accept=options.accept~=false
end
Duel={}
function Duel.IsDuelType(flag)
    assert(flag==0x8000000000)
    return mode=="two_vs_one"
end
function Duel.GetPlayerFieldGroup(player,location)
    assert(mode=="two_vs_one" and location==LOCATION_MZONE and player<2)
    return make_group(fields[player])
end
function Duel.IsLogicalPlayerActive(player)
    return active_mask & (1 << player) ~= 0
end
function Duel.CheckLPCost(side,cost) return lp[side]>=cost end
function Duel.IsDeckMaster(side,code)
    assert(code==153000022)
    return can_use_master and side==1
end
function Duel.SelectYesNoPlayer(player,desc)
    assert(player==2)
    events[#events+1]={type="prompt",player=player}
    return accept
end
function Duel.SelectYesNo(side,desc)
    events[#events+1]={type="legacy_prompt",side=side}
    return accept
end
function Duel.PayLPCost(side,cost)
    assert(lp[side]>=cost)
    lp[side]=lp[side]-cost
    events[#events+1]={type="cost",side=side,cost=cost}
end
function Duel.Hint() end
function Duel.BreakEffect() end
function Duel.Remove(cards,pos,reason)
    assert(pos==POS_FACEUP and reason==REASON_EFFECT)
    for _,c in ipairs(cards.cards) do
        if c.can_banish and not c.replacement then
            c.location=LOCATION_REMOVED
            removed[#removed+1]=c
        end
    end
    events[#events+1]={type="banish",count=#removed}
    return #removed
end
function Duel.GetOperatedGroup() return make_group(removed) end
function Duel.DamagePlayer(player,amount,reason,step,source,interception)
    assert(reason==REASON_EFFECT and step==false and source==1)
    assert(interception==false,"damage must not move to a teammate")
    assert(player==0 or player==1)
    events[#events+1]={type="damage",player=player,amount=amount}
    return amount
end
function Duel.IsExistingMatchingCard(predicate,side,own,opponent,required,exception)
    assert(mode~="two_vs_one")
    for _,c in ipairs(legacy_monsters) do if predicate(c) then return true end end
    return false
end
function Duel.GetMatchingGroup(predicate,side,own,opponent,exception)
    assert(mode~="two_vs_one")
    return make_group(legacy_monsters):Filter(predicate,exception)
end
function Duel.Damage(side,amount,reason)
    assert(mode~="two_vs_one" and side==0 and reason==REASON_EFFECT)
    events[#events+1]={type="legacy_damage",side=side,amount=amount}
end

dofile("multiplayer-deck-master/c153000022.lua")
local function count(event)
    local n=0
    for _,v in ipairs(events) do if v.type==event then n=n+1 end end
    return n
end
local function damage(player)
    local amount=0
    for _,v in ipairs(events) do
        if v.type=="damage" and v.player==player then amount=amount+v.amount end
    end
    return amount
end

-- 2 + 3 monsters: exactly 1000 to P1, 1500 to P2, 1000 LP Big Five cost.
setup({monster(0),monster(0)},
    {monster(1),monster(1),monster(1)},{monster(2)})
assert(script.con(e,1))
script.op(e,1)
assert(damage(0)==1000 and damage(1)==1500)
assert(count("damage")==2 and count("legacy_damage")==0)
assert(lp[1]==7000 and #removed==5)
assert(fields[2][1].location==LOCATION_MZONE)
assert(count("prompt")==1 and events[1].player==2)

-- Damage must follow real banish results, not merely initial field counts.
setup({monster(0),monster(0,false)},{monster(1),monster(1,true,true)})
assert(script.con(e,1))
script.op(e,1)
assert(damage(0)==500 and damage(1)==500 and #removed==2)

-- Single teammate with monsters: never transfer their damage to the other.
setup({}, {monster(1),monster(1)})
assert(script.con(e,1))
script.op(e,1)
assert(damage(0)==0 and damage(1)==1000 and count("damage")==1)

-- No removable opponents: ability cannot be used.
setup({monster(0,false)},{})
assert(not script.con(e,1))

-- Big Five cannot activate without 1000 LP or valid Deck Master identity.
setup({monster(0)},{},{},{lp1=999})
assert(not script.con(e,1))
setup({monster(0)},{},{},{master=false})
assert(not script.con(e,1))

-- Big Five declining does not pay or banish.
setup({monster(0)}, {monster(1)}, {}, {accept=false})
script.op(e,1)
assert(lp[1]==8000 and #removed==0 and count("damage")==0)

-- OUT teammate's surviving cards can be banished, but no LP damage is
-- inflicted on an eliminated logical player or reassigned to their partner.
setup({monster(0)},{monster(1),monster(1)},{},{mask=0x05})
assert(script.con(e,1))
script.op(e,1)
assert(#removed==3 and damage(0)==500 and damage(1)==0)

-- Non-2v1 (Standard / 3v1 / Battle Royale) uses the original physical side.
for _,mode_name in ipairs({"standard","three_vs_one","battle_royale"}) do
    setup({}, {}, {}, {mode=mode_name,legacy={monster(0),monster(0),monster(0)}})
    assert(script.con(e,1))
    script.op(e,1)
    assert(count("legacy_prompt")==1)
    assert(count("legacy_damage")==1 and count("damage")==0)
    assert(events[#events].amount==1500 and lp[1]==7000)
end
print("Judge Man 2v1: logical damage, cost, banish and legacy tests PASS")
