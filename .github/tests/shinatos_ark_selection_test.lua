-- Lightweight regression run against the real uploaded Shinato's Ark script.
-- Usage: lua5.4 .github/tests/shinatos_ark_selection_test.lua multiplayer-deck-master/c153000017.lua
local id=153000017
LOCATION_MZONE=4; POS_FACEUP_DEFENSE=4; PHASE_BATTLE=8
RESET_PHASE=0x40000000; RESET_EVENT=0x1000; RESETS_STANDARD=0x1ff0000
RESET_CHAIN=0x80000000; EFFECT_TYPE_SINGLE=1; EFFECT_SET_CONTROL=4
HINT_CARD=1; HINT_SELECTMSG=2; HINTMSG_SPSUMMON=3
local script
function GetID() script={} return script,id end
aux={Stringid=function() return 1 end}
local st
local function reset()
    st={opponent=3,zones=1,turn=0,yes=true,dm=true,selected={},
        attempts={},flags={},failed={},selection_max=0,pick_indices={},revealed_codes=nil}
end
local next_instance=0
local function card(owner,code)
    next_instance=next_instance+1
    return {owner=owner,controller=owner,code=code or 70000000+next_instance,
        effects={},GetOriginalCode=function(self) return self.code end,
        RegisterEffect=function(self,fx) table.insert(self.effects,fx) end}
end
local function group(cards)
    local g={cards=cards}
    local methods={
        Iter=function(self)
            local i=0
            return function() i=i+1 return self.cards[i] end
        end,
        RemoveCard=function(self,c)
            for i,x in ipairs(self.cards) do
                if x==c then table.remove(self.cards,i);return end
            end
            error("summoned card missing from Ark")
        end,
        Select=function(_,tp,min,max,exclude)
            assert(tp==1 and min==1 and exclude==nil)
            assert(max==st.selection_max, "wrong selection limit")
            assert(#st.selected<=max, "more than maximum selected")
            return group(st.selected)
        end,
    }
    return setmetatable(g,{__len=function(self)return #self.cards end,
        __index=methods})
end
Duel={
    GetFlagEffect=function(tp,flag) assert(tp==1);return st.flags[flag] or 0 end,
    RegisterFlagEffect=function(tp,flag,reset_value)
        assert(tp==1 and flag==id+PHASE_BATTLE)
        assert(reset_value==RESET_PHASE+PHASE_BATTLE)
        st.flags[flag]=(st.flags[flag] or 0)+1
    end,
    GetFieldGroupCount=function(tp,s,o)
        assert(tp==1 and s==0 and o==LOCATION_MZONE)
        return st.opponent
    end,
    GetLocationCount=function(tp,loc)
        assert(tp==1 and loc==LOCATION_MZONE)
        return st.zones
    end,
    IsTurnPlayer=function(p)return p==st.turn end,
    IsDeckMaster=function(p,code)return st.dm and p==1 and code==id end,
    SelectYesNo=function(p)assert(p==1);return st.yes end,
    Hint=function()end,
    SelectCardsFromCodes=function(tp,min,max,cancelable,return_index,codes)
        assert(tp==1 and min==1 and max==st.selection_max)
        assert(cancelable==false and return_index==true)
        assert(type(codes)=="table" and #codes>0,"face-up card codes required")
        st.revealed_codes={table.unpack(codes)}
        assert(#st.pick_indices>=min and #st.pick_indices<=max)
        local result={}
        for _,index in ipairs(st.pick_indices) do
            assert(index>=1 and index<=#codes)
            result[#result+1]={codes[index],index}
        end
        return table.unpack(result)
    end,
    MoveToField=function(c,p,controller,loc,pos,enable)
        assert(p==1 and controller==1 and loc==LOCATION_MZONE
            and pos==POS_FACEUP_DEFENSE and enable)
        table.insert(st.attempts,c)
        if st.failed[c] then return false end
        assert(st.zones>0)
        st.zones=st.zones-1
        c.controller=controller
        return true
    end
}
Effect={CreateEffect=function(owner)
    local fx={}
    function fx:SetType(v)self.type=v end
    function fx:SetCode(v)self.code=v end
    function fx:SetValue(v)self.value=v end
    function fx:SetReset(v)self.reset=v end
    return fx
end}
local file=assert(arg[1],"supply the actual card script path")
assert(loadfile(file))()
assert(script and script.defcon and script.defop)
local function make_event(ark)
    return {
        GetLabelObject=function()return ark end,
        GetHandler=function()return {} end,
        Reset=function(self)self.is_reset=true end,
    }
end
local function summon(event)
    assert(script.defcon(event,1))
    script.defop(event,1)
end
-- Reproduction: Vampire Lord originally belongs to opponent (side 0),
-- but must stay on side 1 when Noah summons it from the Ark.
reset()
local vampire=card(0,53839837)
local other=card(0,1234)
local ark=group({other,vampire})
local event=make_event(ark)
st.selection_max=1
st.pick_indices={2}
assert(script.defcon(event,1))
assert(script.defcon(event,1))
assert(st.flags[id+PHASE_BATTLE]==nil,"condition consumed its activation")
summon(event)
assert(st.revealed_codes[1]==1234 and st.revealed_codes[2]==53839837)
assert(#st.attempts==1 and st.attempts[1]==vampire)
assert(vampire.controller==1 and #vampire.effects==1)
local fx=vampire.effects[1]
assert(fx.code==EFFECT_SET_CONTROL and fx.value==1)
assert(fx.reset==RESET_EVENT+RESETS_STANDARD)
assert(fx.reset & RESET_CHAIN==0,"control must not expire after the chain")
assert(#ark==1 and ark.cards[1]==other)
assert(not script.defcon(event,1),"once per Battle Phase")
-- Selection is capped to opponent monster count, and allows choosing fewer.
reset()
local first,second,third=card(0),card(0),card(0)
ark=group({first,second,third})
event=make_event(ark)
st.opponent=2;st.zones=3;st.selection_max=2;st.pick_indices={3,1}
summon(event)
assert(#st.attempts==2 and st.attempts[1]==third and st.attempts[2]==first)
assert(#ark==1 and ark.cards[1]==second)
-- Identical card codes must resolve to the physical copy the player chose.
reset()
local copy1,copy2=card(0,53839837),card(0,53839837)
ark=group({copy1,copy2});event=make_event(ark)
st.selection_max=1;st.pick_indices={2}
summon(event)
assert(st.revealed_codes[1]==53839837 and st.revealed_codes[2]==53839837)
assert(#st.attempts==1 and st.attempts[1]==copy2)
assert(#ark==1 and ark.cards[1]==copy1)
-- Failed field movement cannot remove the card from the Ark.
reset()
ark=group({first,second});event=make_event(ark)
st.opponent=1;st.selection_max=1;st.pick_indices={2};st.failed[second]=true
local previous_effects=#second.effects
summon(event)
assert(#ark==2 and #second.effects==previous_effects)
-- Optional summon may be declined.
reset()
ark=group({first});event=make_event(ark)
st.selection_max=1;st.yes=false
summon(event)
assert(#st.attempts==0 and #ark==1 and st.revealed_codes==nil)
-- Only in opponent's Battle Phase, with open zones and an active Ark.
reset()
ark=group({first});event=make_event(ark)
st.turn=1;assert(not script.defcon(event,1))
st.turn=0;st.zones=0;assert(not script.defcon(event,1))
st.zones=1;st.opponent=0;assert(not script.defcon(event,1))
st.opponent=1;st.dm=false;assert(not script.defcon(event,1))
print("Shinato's Ark face-up selection, duplicates and stable control: PASS")
