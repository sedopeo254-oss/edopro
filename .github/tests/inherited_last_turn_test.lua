-- Mock Duel API regression tests: Last Turn 28566710 in Inherited Duel.
-- Runs under Lua 5.4 (real EDOPro engine integration is tested separately).
local script_file=arg and arg[1] or "multiplayer-inherited-duel/c28566710.lua"
local s={}
local state={}
local function expect(ok,message)
    if not ok then error("FAIL: "..message,2) end
end
GetID=function() return s,28566710 end
LOCATION_DECK=1
LOCATION_HAND=2
LOCATION_MZONE=4
LOCATION_ONFIELD=12
POS_FACEUP_ATTACK=1
EFFECT_TYPE_ACTIVATE=1
EFFECT_TYPE_FIELD=2
EFFECT_TYPE_CONTINUOUS=4
EFFECT_FLAG_PLAYER_TARGET=1
EFFECT_AVOID_BATTLE_DAMAGE=100
CATEGORY_SPECIAL_SUMMON=1
EVENT_FREE_CHAIN=1
EVENT_PHASE=1000
PHASE_END=16
PHASE_DAMAGE=8
TIMING_STANDBY_PHASE=1
RESET_PHASE=4096
HINT_SELECTMSG=1
HINTMSG_FACEUP=1
HINTMSG_SPSUMMON=2
REASON_EFFECT=1
WIN_REASON_LAST_TURN=0x16
PLAYER_NONE=2
local effect_methods={}
for _,m in ipairs({"SetType","SetCategory","SetCode","SetHintTiming","SetCondition",
        "SetTarget","SetOperation","SetProperty","SetTargetRange","SetReset","SetCountLimit"}) do
    effect_methods[m]=function(self,...) self[m]={...} end
end
function effect_methods:GetHandler() return self.handler end
Effect={CreateEffect=function(c)
    return setmetatable({handler=c},{__index=effect_methods})
end}
local function card(code,loc)
    return {
        code=code,loc=loc,
        IsLocation=function(self,location) return self.loc==location end,
        GetOriginalCode=function(self) return self.code end,
        IsCanBeSpecialSummoned=function() return state.summonable~=false end
    }
end
local function group(arr)
    return {
        cards=arr,
        GetFirst=function(self) return self.cards[1] end,
        RemoveCard=function(self,x)
            for i,v in ipairs(self.cards) do
                if v==x then table.remove(self.cards,i);break end
            end
        end
    }
end
Duel={}
Duel.IsDuelType=function() return state.inherited end
Duel.GetLP=function() return state.lp end
Duel.GetTurnPlayer=function() return state.turn end
Duel.IsExistingMatchingCard=function() return state.selected~=nil end
Duel.SetOperationInfo=function(_,_,_,_,_,loc) state.reported_location=loc end
Duel.SelectMatchingCard=function(_,filter,_,location)
    if filter then
        state.deck_selected=true
        return group({state.deck_monster})
    end
    return group({state.selected})
end
Duel.GetFieldGroup=function()
    return group({state.selected,state.field_other,state.hand_own,state.hand_enemy})
end
Duel.SendtoGrave=function(g)
    state.sent={}
    for _,c in ipairs(g.cards) do
        c.loc="GRAVE"
        state.sent[#state.sent+1]=c
    end
end
Duel.Hint=function() end
Duel.BreakEffect=function() end
Duel.SummonDeckMasterPlayer=function(p,pos)
    state.summoned_by_helper={p,pos}
    local c=DeckMasterZone[p]
    if not c then return 0 end
    c.loc=LOCATION_MZONE
    DeckMasterZone[p]=nil
    return 1
end
Duel.SpecialSummon=function(c,_,p,__,___,____,pos)
    state.normal_deck_summon={c,p,pos}
    c.loc=LOCATION_MZONE
    return 1
end
Duel.RegisterEffect=function(e) state.effects[#state.effects+1]=e end
Duel.ForceAttack=function(c,t) state.forced={c,t} end
Duel.GetFieldGroupCount=function(p) return state.count[p+1] end
Duel.IsPhase=function(p) return state.in_endphase and p==PHASE_END end
Duel.Win=function(player,reason) state.win={player,reason} end
DeckMaster={IsTeamSharedDeckMasterCode=function() return false end}
local handler={}
function handler:RegisterEffect(e) self.effect=e end
dofile(script_file)
s.initial_effect(handler)
expect(handler.effect~=nil,"Last Turn activation must register")
local e=handler.effect
local function reset(inherited)
    state={inherited=inherited,lp=1000,turn=0,effects={},count={1,1}}
    state.selected=card(111,LOCATION_MZONE)
    state.field_other=card(222,LOCATION_ONFIELD)
    state.hand_own=card(333,LOCATION_HAND)
    state.hand_enemy=card(444,LOCATION_HAND)
    state.master=card(555,"DECK_MASTER")
    state.deck_monster=card(666,LOCATION_DECK)
    DeckMasterZone={[0]=state.master}
end
reset(true)
expect(s.condition(e,1),"1000 LP and opponent's turn allow Last Turn")
state.lp=1001
expect(not s.condition(e,1),"1001 LP rejects Last Turn")
state.lp=1000;state.turn=1
expect(not s.condition(e,1),"own turn rejects Last Turn")
state.turn=0
expect(s.target(e,1,nil,nil,nil,nil,nil,nil,0),"real Deck Master Zone card required")
state.summonable=false
expect(not s.target(e,1,nil,nil,nil,nil,nil,nil,0),"non-summonable master rejected")
state.summonable=true
s.target(e,1,nil,nil,nil,nil,nil,nil,1)
expect(state.reported_location==0,"inherited summon must not report normal Deck")
s.operation(e,1)
expect(#state.sent==3,"all other cards from both hands and fields go to GY")
expect(state.selected.loc==LOCATION_MZONE,"original selected monster stays")
expect(state.summoned_by_helper[1]==0 and state.summoned_by_helper[2]==POS_FACEUP_ATTACK,
    "opponent's Deck Master summoned in face-up ATK")
expect(state.forced and state.forced[1]==state.master and state.forced[2]==state.selected,
    "the new Deck Master attacks the selected monster")
local protected=false
for _,effect in ipairs(state.effects) do
    if effect.SetCode and effect.SetCode[1]==EFFECT_AVOID_BATTLE_DAMAGE then
        protected=effect.SetTargetRange[1]==1 and effect.SetTargetRange[2]==1
            and effect.SetReset[1]==(RESET_PHASE|PHASE_DAMAGE)
    end
end
expect(protected,"battle damage must be zero for both sides during forced Damage Step")
for _,case in ipairs({
    {{1,0},0}, {{0,1},1}, {{1,1},2}, {{0,0},2},
    {{2,0},2}, {{0,2},2}, {{2,1},2}
}) do
    state.count=case[1]
    s.checkop_inherited(e,1)
    expect(state.win[1]==case[2] and state.win[2]==WIN_REASON_LAST_TURN,
        "one-and-only-one monster determines End Phase victory or draw")
end
reset(true)
DeckMasterZone={}
expect(not s.target(e,1,nil,nil,nil,nil,nil,nil,0),
    "cannot silently fall back to Deck if DM zone is empty")
reset(false)
expect(s.target(e,1,nil,nil,nil,nil,nil,nil,0),
    "legacy modes still permit their original card effect")
s.target(e,1,nil,nil,nil,nil,nil,nil,1)
expect(state.reported_location==LOCATION_DECK,"legacy modes still select normal Deck")
s.operation(e,1)
expect(state.deck_selected and state.normal_deck_summon
    and state.normal_deck_summon[3]==POS_FACEUP_ATTACK,
    "legacy modes retain their normal Deck summon")
state.count={2,0}
s.checkop_legacy(e,1)
expect(state.win[1]==0 and state.win[2]==WIN_REASON_LAST_TURN,
    "legacy End Phase still uses greater-than-zero test")
print("Last Turn: Inherited Duel mode-gating, Master summon, battle and draw tests PASS")
