-- Test the REAL Dragon Revival Ritual and Deck Master scripts together,
-- matching the successful 30 Oct replay at Turn 19 Main Phase 1.
-- 2v1 + 3v1: use the actual in-zone Jinzo, create missing Big Five Deck
-- Masters from outside, Tribute all five, and Ritual Summon the ORIGINAL
-- Five-Headed Dragon without creating a phantom Deck Master Zone copy.
LOCATION_HAND=2
LOCATION_DECK=1
LOCATION_MZONE=4
LOCATION_GRAVE=16
LOCATION_EXTRA=64
LOCATION_ALL=0xffff
SUMMON_TYPE_RITUAL=0x20000
CATEGORY_SPECIAL_SUMMON=1
CATEGORY_RELEASE=2
EFFECT_TYPE_ACTIVATE=16
EVENT_FREE_CHAIN=100
POS_FACEUP=1
POS_FACEUP_ATTACK=1
REASON_EFFECT=0x40
REASON_MATERIAL=0x20
REASON_RITUAL=0x80000
REASON_RULE=0x400
RESET_EVENT=0x10000
RESETS_STANDARD=0x20000
RESET_TOFIELD=0x40
RESET_CONTROL=0x80
EFFECT_FLAG_CLIENT_HINT=0x100
HINT_SELECTMSG=1
HINTMSG_SPSUMMON=2

local id=153000000
function GetID() return {},id end
aux={}
function aux.Stringid() return 0 end
function aux.Next(g)
 local i=0
 return function() i=i+1 return g.cards[i] end
end
local G={}
G.__index=G
G.__len=function(g) return #g.cards end
function G:AddCard(c) self.cards[#self.cards+1]=c end
function G:Filter(f,except,...)
 local out={}
 for _,c in ipairs(self.cards) do
  if c~=except and f(c,...) then out[#out+1]=c end
 end
 return setmetatable({cards=out},G)
end
function G:GetFirst() return self.cards[1] end
function G:Select(p,a,b,except)
 assert(a==1 and b==1)
 return self:Filter(function(c) return c==self.cards[1] end,nil)
end
Group={}
function Group.CreateGroup() return setmetatable({cards={}},G) end
local function group(list) return setmetatable({cards=list or {}},G) end

Card={}
Card.__index=Card
local function card(p,code,location)
 return setmetatable({p=p,code=code,location=location,flags={},
    material=group({}),completed=false},Card)
end
function Card:IsOriginalCode(code) return self.code==code end
function Card:IsCode(code) return self.code==code end
function Card:GetOriginalCode() return self.code end
function Card:IsCanBeSpecialSummoned(e,typ,tp,ignore,ignore_limit)
 return not self.cannot_summon
end
function Card:IsLocation(loc) return self.location==loc end
function Card:GetLogicalControler() return self.p end
function Card:GetLogicalOwner() return self.p end
function Card:GetFlagEffect(flag) return self.flags[flag] or 0 end
function Card:RegisterFlagEffect(flag) self.flags[flag]=1 return 1 end
function Card:SetMaterial(g) self.material=g end
function Card:GetMaterial() return self.material end
function Card:CompleteProcedure() self.completed=true end

local mask,sides,piles,created,zone_messages,summons,releases,free,logical
Duel={}
function Duel.GetActiveLogicalPlayerMask() return mask end
function Duel.GetLogicalPlayerSide(p) return sides[p] end
function Duel.IsLogicalPlayerActive(p)
 return mask==0 and p<2 or (mask&(1<<p))~=0
end
function Duel.GetLogicalPlayer(side)
 return mask==0 and side or logical
end
function Duel.GetPlayerFieldGroup(p,locations)
 local out={}
 for _,c in ipairs(piles[p]) do
  if (c.location & locations)~=0 then out[#out+1]=c end
 end
 return group(out)
end
function Duel.GetMatchingGroup(f,tp,loc_self,loc_other,except,e,player)
 local out={}
 for _,c in ipairs(piles[tp]) do
  if (c.location&loc_self)~=0 and f(c,e,player) then
   out[#out+1]=c
  end
 end
 return group(out)
end
-- The proven Oct 30 activation route uses Duel.IsExistingMatchingCard /
-- Duel.SelectMatchingCard (NOT filtering a GetPlayerFieldGroup snapshot).
function Duel.IsExistingMatchingCard(filter,tp,loc_self,loc_other,min,except,e,player)
 return #Duel.GetMatchingGroup(filter,tp,loc_self,loc_other,except,e,player)>=min
end
function Duel.SelectMatchingCard(tp,filter,from_player,loc_self,loc_other,min,max,except,e,player)
 assert(tp==from_player and min==1 and max==1)
 local candidates=Duel.GetMatchingGroup(filter,from_player,loc_self,loc_other,except,e,player)
 return candidates:Select(tp,1,1,nil)
end
function Duel.GetFieldGroup(tp,loc1,loc2)
 return Duel.GetPlayerFieldGroup(tp,loc1)
end
function Duel.GetLocationCount(side,location)
 assert(location==LOCATION_MZONE and side==sides[logical])
 return free
end
function Duel.CreateTokenPlayer(p,code)
 assert(mask~=0 and p==logical)
 local c=card(p,code,0)
 created[#created+1]=c
 return c
end
function Duel.CreateToken(side,code)
 assert(mask==0 and side==sides[logical])
 local c=card(logical,code,0)
 created[#created+1]=c
 return c
end
function Duel.SetDeckMasterPlayerState(p,code,show)
 zone_messages[#zone_messages+1]={p=p,code=code,visible=show}
end
function Duel.Hint(...) end
function Duel.SetOperationInfo(...) end
function Duel.SpecialSummon(c,kind,side,recipient,ignore,ignore_limit,pos)
 assert(side==sides[logical] and recipient==side)
 if c.cards then
  assert(#c==5 and kind==0)
  -- The first five monsters appear physically before the Ritual Tribute.
  for _,tc in ipairs(c.cards) do
   assert(tc.p==logical and tc.location==0)
   tc.location=LOCATION_MZONE
   summons[#summons+1]=tc.code
  end
  return #c
 end
 assert(c.code==511013020 and kind==SUMMON_TYPE_RITUAL)
 assert(c.p==logical and (c.location==LOCATION_HAND or c.location==LOCATION_DECK))
 assert(#c.material==5)
 c.location=LOCATION_MZONE
 summons[#summons+1]=c.code
 return 1
end
function Duel.Release(g,reason)
 assert(reason==(REASON_EFFECT|REASON_MATERIAL|REASON_RITUAL))
 assert(#g==5,"Exactly five temporary Big Five Deck Masters are Tributed")
 for _,c in ipairs(g.cards) do
  assert(c.location==LOCATION_MZONE)
  releases[#releases+1]=c.code
  c.location=LOCATION_GRAVE
 end
 return #g
end

-- Load actual production files with no replacement stubs for the Duel logic.
dofile("multiplayer-deck-master/c153000000.lua")
local dm=DeckMaster
id=120000016
local spell
function GetID() spell={} return spell,id end
dofile("multiplayer-anime-cards/c120000016.lua")

local required={153000020,153000021,153000022,153000023,153000024}
local function reset(mode,p)
 logical=p
 mask=mode=="2v1" and 0x7 or (mode=="3v1" and 0xf or 0)
 sides=mode=="2v1" and {[0]=0,[1]=0,[2]=1,[3]=nil}
    or (mode=="3v1" and {[0]=0,[1]=0,[2]=0,[3]=1}
    or {[0]=0,[1]=1})
 piles={[0]={},[1]={},[2]={},[3]={}}
 created={};zone_messages={};summons={};releases={};free=5
 DeckMasterZone={}
 dm.DragonRevivalConsumed={}
 dm.DragonRevivalResolving={}
 dm.DragonRevivalMerged={}
 dm.FieldAbilityCards={}
 dm.TeamSharedMode=false
 dm.TeamSharedCode={}
end
local function put(p,c)
 piles[p][#piles[p]+1]=c
 return c
end
local function cast(p)
 local e={}
 assert(spell.target(e,sides[p],nil,nil,nil,nil,nil,nil,0),
    "Must be able to activate when FHD is in own hand/deck and slots are free")
 spell.activate(e,sides[p])
end
local function check_five(fhd,p,zone_code,expected_tokens)
 assert(#summons==6 and #releases==5,"Five summons + FHD, five Tributes")
 for i,code in ipairs(required) do
  assert(summons[i]==code and releases[i]==code,"Exact Big Five IDs and order")
 end
 assert(summons[6]==511013020)
 assert(fhd.location==LOCATION_MZONE and fhd.completed)
 assert(fhd:GetMaterial() and #fhd:GetMaterial()==5)
 assert(fhd:IsDeckMaster(),"FHD must inherit Deck Master on field")
 assert(Duel.GetDeckMasterPlayer(p)==fhd)
 assert(DeckMasterZone[p]==nil,"No FHD card or copy in Deck Master Zone")
 assert(#created==expected_tokens,"Never create duplicate token for real Zone card")
 for _,tc in ipairs(created) do
  assert(tc.code~=511013020,"Ritual MUST NOT create an FHD token")
 end
 for _,message in ipairs(zone_messages) do
  assert(not(message.code==511013020 and message.visible),
   "Never publish FHD as a new Deck Master Zone indicator")
 end
 if zone_code then
  assert(#zone_messages==1 and not zone_messages[1].visible
      and zone_messages[1].code==zone_code,
      "Consumed original Deck Master indicator must be cleared")
 else
  assert(#zone_messages==0)
 end
 -- Once FHD is destroyed there is no invisible permanent replacement.
 fhd.location=LOCATION_GRAVE
 assert(Duel.GetDeckMasterPlayer(p)==nil)
end

-- 2v1 P3: take the ACTUAL Jinzo card from the Big Five's DM Zone.
reset("2v1",2)
local jinzo=card(2,153000020,0)
DeckMasterZone[2]=jinzo
local fhd=put(2,card(2,511013020,LOCATION_HAND))
cast(2)
assert(jinzo.location==LOCATION_GRAVE and created[1].code==153000021)
check_five(fhd,2,153000020,4)

-- 2v1: source FHD can be in Deck, all five masters from outside Duel.
reset("2v1",2)
fhd=put(2,card(2,511013020,LOCATION_DECK))
cast(2)
check_five(fhd,2,nil,5)

-- 3v1 P4 Big Five: reuse existing Deepsea Warrior from Zone, no duplicate.
reset("3v1",3)
DeckMasterZone[3]=card(3,153000021,0)
fhd=put(3,card(3,511013020,LOCATION_DECK))
cast(3)
check_five(fhd,3,153000021,4)

-- 2v1 never borrow an ally's FHD: source is the activating logical owner.
reset("2v1",2)
put(0,card(0,511013020,LOCATION_HAND))
assert(not spell.target({},1,nil,nil,nil,nil,nil,nil,0))
assert(#created==0)

-- Insufficient monster slots must reject before consuming a Zone DM.
reset("2v1",2)
local original=card(2,153000020,0)
DeckMasterZone[2]=original
put(2,card(2,511013020,LOCATION_HAND))
free=4
assert(not spell.target({},1,nil,nil,nil,nil,nil,nil,0))
assert(DeckMasterZone[2]==original and #created==0)

-- Standard duel fallback: outside-Duel cards use Duel.CreateToken.
reset("standard",1)
fhd=put(1,card(1,511013020,LOCATION_HAND))
cast(1)
check_five(fhd,1,nil,5)

print("Dragon Revival: exact five, real Zone identities, 2v1/3v1, no FHD Zone duplicate PASS")
