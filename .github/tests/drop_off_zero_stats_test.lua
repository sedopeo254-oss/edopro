-- Drop Off's replacement effect: all monsters get exactly +0 ATK/DEF.
-- Preserve 2v1/3v1 independent fields, Standard, and immunity.
EFFECT_TYPE_ACTIVATE=16
EFFECT_TYPE_SINGLE=1
EVENT_FREE_CHAIN=1000
EFFECT_UPDATE_ATTACK=101
EFFECT_UPDATE_DEFENSE=102
CATEGORY_ATKCHANGE=8
CATEGORY_DEFCHANGE=16
LOCATION_MZONE=4
RESET_EVENT=0x10000
RESETS_STANDARD=0x20000
RESET_PHASE=0x40000
PHASE_END=0x200

local script
function GetID() script={} return script,55773067 end
aux={}
function aux.Next(g)
 local i=0
 return function() i=i+1 return g.cards[i] end
end
local G={}
G.__index=G
G.__len=function(g) return #g.cards end
function G:AddCard(c) self.cards[#self.cards+1]=c end
function G:Merge(other)
 for _,c in ipairs(other.cards) do
  local found=false
  for _,existing in ipairs(self.cards) do if existing==c then found=true end end
  if not found then self:AddCard(c) end
 end
end
Group={}
function Group.CreateGroup() return setmetatable({cards={}},G) end
local function group(cards) return setmetatable({cards=cards or {}},G) end

Effect={}
function Effect.CreateEffect(owner)
 local e={owner=owner}
 function e:SetType(v) self.kind=v end
 function e:SetCode(v) self.code=v end
 function e:SetCategory(v) self.category=v end
 function e:SetTarget(v) self.target=v end
 function e:SetOperation(v) self.operation=v end
 function e:SetValue(v) self.value=v end
 function e:SetReset(v) self.reset=v end
 function e:GetHandler() return self.owner end
 function e:Clone()
  local c=Effect.CreateEffect(self.owner)
  for k,v in pairs(self) do if type(v)~="function" then c[k]=v end end
  return c
 end
 return e
end
local function monster(p,immune)
 local c={owner=p,immune=immune,atk=2600,def=1900,effects={}}
 function c:IsImmuneToEffect(e) return self.immune==true end
 function c:RegisterEffect(e) self.effects[#self.effects+1]=e end
 return c
end
local cards,mask,logs
Duel={}
function Duel.GetActiveLogicalPlayerMask() return mask end
function Duel.GetPlayerFieldGroup(p,location)
 assert(location==LOCATION_MZONE)
 return group(cards[p])
end
function Duel.GetFieldGroup(tp,loc1,loc2)
 assert(loc1==LOCATION_MZONE and loc2==LOCATION_MZONE)
 local t={}
 for _,p in ipairs({0,1}) do for _,c in ipairs(cards[p]) do t[#t+1]=c end end
 return group(t)
end
function Duel.SetOperationInfo(chain,cat,g,count)
 logs[#logs+1]={category=cat,count=count}
end

local trap={effects={}}
function trap:RegisterEffect(e) self.effects[#self.effects+1]=e end
dofile("multiplayer-anime-cards/c55773067.lua")
script.initial_effect(trap)
assert(#trap.effects==1,"Only one free-chain Trap activation")
local ef=trap.effects[1]
assert(ef.code==EVENT_FREE_CHAIN
 and ef.category==CATEGORY_ATKCHANGE+CATEGORY_DEFCHANGE)
local function run(newmask,newcards,expected)
 mask=newmask
 cards=newcards
 logs={}
 assert(ef.target(ef,0,nil,nil,nil,nil,nil,nil,0)==(expected>0))
 if expected==0 then return end
 ef.target(ef,0,nil,nil,nil,nil,nil,nil,1)
 assert(#logs==2 and logs[1].count==expected and logs[2].count==expected)
 ef.operation(ef,0)
 local applied=0
 for p=0,3 do
  for _,c in ipairs(cards[p]) do
   assert(c.atk==2600 and c.def==1900,"+0 must not alter original stats")
   if c.immune then
    assert(#c.effects==0,"Unaffected monsters cannot receive buffs")
   else
    assert(#c.effects==2)
    assert(c.effects[1].code==EFFECT_UPDATE_ATTACK)
    assert(c.effects[2].code==EFFECT_UPDATE_DEFENSE)
    for _,e in ipairs(c.effects) do
     assert(e.value==0,"value must be exactly zero")
     assert(e.reset==(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END))
    end
    applied=applied+1
   end
  end
 end
 return applied
end
local function empty() return {[0]={},[1]={},[2]={},[3]={}} end
local piles=empty()
piles[0]={monster(0),monster(0)}
piles[1]={monster(1)}
piles[2]={monster(2),monster(2)}
assert(run(0x07,piles,5)==5,"2v1 includes both teammates and Big Five")
piles=empty()
piles[0]={monster(0)}
piles[1]={monster(1)}
piles[2]={monster(2)}
piles[3]={monster(3,true)}
assert(run(0x0f,piles,4)==3,"3v1 includes all four logical fields")
piles=empty()
piles[0]={monster(0)}
piles[1]={monster(1)}
assert(run(0,piles,2)==2,"Standard 1v1 both physical fields")
assert(run(0,empty(),0)==nil,"No monsters: don't activate")
print("Drop Off: +0 ATK/DEF for all monster fields in 2v1, 3v1 and Standard PASS")
