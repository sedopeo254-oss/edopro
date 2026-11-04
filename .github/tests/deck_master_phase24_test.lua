-- Replay-derived rules regression: 2v1 P3 Big Five loses when the
-- Five-Headed Dragon -> Berserk Dragon successor leaves in turn 24.
-- Also validate 3v1, Standard, simultaneous summons, and shared masters.
LOCATION_MZONE=4
LOCATION_DECK=1
LOCATION_EXTRA=64
LOCATION_GRAVE=16
LOCATION_ALL=0xffff
TYPE_MONSTER=1
REASON_MATERIAL=0x20
REASON_BATTLE=0x80
RESETS_STANDARD=0x20000
RESET_EVENT=0x10000
RESET_TOFIELD=0x40
RESET_CONTROL=0x80
EFFECT_FLAG_CLIENT_HINT=0x100
PLAYER_NONE=2
WIN_REASON_DECK_MASTER=1000
PHASE_MAIN1=4
FLAG_DECK_MASTER=153000000

local s
function GetID() s={} return s,153000000 end
aux={}
function aux.Stringid() return 0 end
function aux.Next(g)
 local i=0
 return function() i=i+1 return g.cards[i] end
end
Card={}
Card.__index=Card
local function card(p,loc,code)
 local c=setmetatable({
   p=p, loc=loc, code=code, flags={}, materials=nil,
 },Card)
 return c
end
function Card:GetLogicalOwner() return self.p end
function Card:GetLogicalControler() return self.p end
function Card:GetOriginalCode() return self.code end
function Card:IsOriginalCode(code) return self.code==code end
function Card:GetFlagEffect(flag) return self.flags[flag] or 0 end
function Card:RegisterFlagEffect(flag,...) self.flags[flag]=1 return 1 end
function Card:IsLocation(loc) return self.loc==loc end
function Card:IsType(kind) return kind==TYPE_MONSTER end
function Card:GetMaterial() return self.materials or group({}) end
function Card:GetControler() return side(self.p) end
function Card:GetSummonPlayer() return side(self.p) end
function Card:IsCanBeSpecialSummoned() return true end
function Card:IsFaceup() return true end
function Card:GetReason() return 0 end
function Card:GetReasonCard() return nil end

local G={}
G.__index=G
G.__len=function(g) return #g.cards end
function group(cards) return setmetatable({cards=cards or {}},G) end
function G:Filter(fn,except,...)
 local t={}
 for _,c in ipairs(self.cards) do
  if c~=except and fn(c,...) then t[#t+1]=c end
 end
 return group(t)
end
function G:IsExists(fn,n,except,...)
 local count=0
 for _,c in ipairs(self.cards) do
  if c~=except and fn(c,...) then count=count+1 end
 end
 return count>=n
end
function G:GetFirst() return self.cards[1] end
function G:Select(p,n,m,except) return group({self.cards[#self.cards]}) end

local mask,sides,piles,eliminated,wins,turn,mainphase
function side(p) return sides[p] end
Duel={}
function Duel.GetActiveLogicalPlayerMask() return mask end
function Duel.IsLogicalPlayerActive(p) return (mask&(1<<p))~=0 end
function Duel.GetLogicalPlayerSide(p) return sides[p] end
function Duel.GetLogicalPlayer(p)
 for logical=0,3 do
  if sides[logical]==p and Duel.IsLogicalPlayerActive(logical) then
   return logical
  end
 end
 return p
end
function Duel.GetLogicalTurnPlayer() return turn end
function Duel.GetTurnPlayer() return side(turn) end
function Duel.IsTurnPlayer(p) return p==side(turn) end
function Duel.IsMainPhase() return mainphase end
function Duel.GetLocationCount() return 5 end
function Duel.GetPlayerFieldGroup(p,loc)
 local t={}
 for _,c in ipairs(piles[p]) do
  if c.loc==LOCATION_MZONE and (loc&LOCATION_MZONE)~=0 then
   t[#t+1]=c
  end
 end
 return group(t)
end
function Duel.GetFieldGroup(p,loc,other) return Duel.GetPlayerFieldGroup(p,loc) end
function Duel.SelectCardsFromCodesPlayer(p,min,max,cancel,index,...)
 local codes={...}
 return {codes[#codes],#codes}
end
function Duel.SelectYesNoPlayer() return true end
function Duel.SelectYesNo() return true end
function Duel.EliminatePlayer(p,reason,win_reason)
 eliminated[#eliminated+1]={p,reason,win_reason}
 return true
end
function Duel.Win(p,reason) wins[#wins+1]={p,reason} end
local function setup(mode)
 sides={[0]=0,[1]=0,[2]=1,[3]=nil}
 mask=0x7
 if mode=="3v1" then sides={[0]=0,[1]=0,[2]=0,[3]=1};mask=0xf end
 if mode=="standard" then sides={[0]=0,[1]=1};mask=0 end
 piles={[0]={},[1]={},[2]={},[3]={}}
 DeckMasterZone={}
 DeckMaster.FieldAbilityCards={}
 DeckMaster.DragonRevivalMerged={}
 DeckMaster.DragonRevivalResolving={}
 DeckMaster.DragonRevivalConsumed={}
 DeckMaster.TeamSharedMode=false
 DeckMaster.TeamSharedCode={}
 DeckMaster.TeamSharedCard={}
 DeckMaster.TeamLossProtected={}
 eliminated={};wins={};turn=0;mainphase=true
end
local function onfield(p,code)
 local c=card(p,LOCATION_MZONE,code)
 piles[p][#piles[p]+1]=c
 return c
end
dofile("multiplayer-deck-master/c153000000.lua")
local dm=DeckMaster
local function give(p,code)
 local c=onfield(p,code)
 assert(dm.AssignFieldDeckMaster(p,c))
 return c
end
-- Turn 19: Big Five's ritual material Deck Masters merge into Five-Headed.
setup("2v1")
give(0,200);give(1,201)
local fhd=onfield(2,511013020)
dm.DragonRevivalConsumed[1]={[2]=true}
dm.DragonRevivalResolving[1]=true
dm.FinishDragonRevival(2,true,fhd)
assert(Duel.GetDeckMasterPlayer(2)==fhd and fhd:IsDeckMaster())
assert(dm.DragonRevivalMerged[2]==fhd)
dm.loss()
assert(#eliminated==0,"Big Five must survive while FHD is on field")
-- Turn 21: FHD destroyed by battle; A Deal summons Berserk Dragon.
fhd.loc=LOCATION_GRAVE
local berserk=onfield(2,511000378)
local eg=group({berserk})
assert(dm.inheritcon2(nil,0,eg))
dm.inheritop2(nil,0,eg)
assert(Duel.GetDeckMasterPlayer(2)==berserk and berserk:IsDeckMaster())
dm.loss()
assert(#eliminated==0,"Big Five must survive while Berserk is Deck Master")
-- Turn 24 Battle Phase: Berserk destroyed, next Main2 boundary: Big Five loses.
berserk.loc=LOCATION_GRAVE
assert(Duel.GetDeckMasterPlayer(2)==nil,"Berserk must no longer count after leaving")
dm.loss()
assert(#eliminated==1 and eliminated[1][1]==2 and eliminated[1][2]==4,
 "Big Five must lose at phase boundary immediately after Berserk is destroyed")
assert(#wins==0)
-- Simultaneous loss on both sides must produce a draw, not 2 unrelated wins.
setup("2v1")
dm.loss()
assert(#wins==1 and wins[1][1]==PLAYER_NONE,"both sides with no master: DRAW")
-- 3v1: the same rule eliminates only solo Big Five, preserving all 3 allies.
setup("3v1")
give(0,301);give(1,302);give(2,303)
local solo=onfield(3,511013020)
dm.DragonRevivalConsumed[1]={[3]=true}
dm.FinishDragonRevival(3,true,solo)
solo.loc=LOCATION_GRAVE
dm.loss()
assert(#eliminated==1 and eliminated[1][1]==3,
 "3v1: only the solo player loses when their last master leaves")
-- Previous anime shared Dark Flare/Mirage team exemption is NOT removed.
setup("3v1")
give(3,400)
dm.TeamSharedMode=true
dm.TeamSharedCode[0]=13722870
dm.TeamSharedCard[0]=card(0,LOCATION_GRAVE,13722870)
dm.loss()
assert(#eliminated==0,"shared anime team master exemption remains")
-- Material inheritance even while an unrelated master exists in the zone.
setup("2v1")
local old=card(0,LOCATION_GRAVE,500)
dm.FieldAbilityCards[old]=0
local successor=onfield(0,501)
successor.materials=group({old})
DeckMasterZone[0]=card(0,0,502)
local special=group({successor})
assert(dm.inheritcon2(nil,0,special))
dm.inheritop2(nil,0,special)
assert(successor:IsDeckMaster(),"material of a Deck Master must pass the role")
-- Simultaneously Summoned monsters: choose rather than silently taking first.
setup("2v1")
local first=onfield(0,700)
local second=onfield(0,701)
dm.inheritop2(nil,0,group({first,second}))
assert(second:IsDeckMaster(),"logical player must choose simultaneous successor")
assert(not first:IsDeckMaster(),"unchosen monster must not inherit")
-- Deck Master cannot be summoned from its zone during a teammate's turn.
setup("2v1")
local z=card(1,0,800)
DeckMasterZone[1]=z
local e={}
function e:GetLabel() return 1 end
turn=0
assert(not dm.spcon(e,0))
turn=1
assert(dm.spcon(e,0))
mainphase=false
assert(not dm.spcon(e,0))
-- Standard duel loss behavior stays exactly as before.
setup("standard")
give(0,900)
dm.loss()
assert(#wins==1 and wins[1][1]==0)
print("Deck Master: turn 24, 2v1, 3v1, 1v1 and material tests PASS")
