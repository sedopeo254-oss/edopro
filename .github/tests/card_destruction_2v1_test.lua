-- Regression tests for the user-supplied c8050010.lua in 2v1.
-- These tests intentionally mock public Duel Lua APIs, while Core CI separately
-- validates logical Hand/Deck storage and multiplayer draw packet handling.
CATEGORY_HANDES=1
CATEGORY_DRAW=2
LOCATION_HAND=4
REASON_EFFECT=1
REASON_DISCARD=2
PLAYER_ALL=2
local script
function GetID() script={},8050010 return script,8050010 end
local G={}
G.__index=G
G.__len=function(g) return #g.cards end
function G:RemoveCard(c)
	for i=#self.cards,1,-1 do
		if self.cards[i]==c then table.remove(self.cards,i) end
	end
end
local function copy_group(list)
	local out={}
	for _,c in ipairs(list) do out[#out+1]=c end
	return setmetatable({cards=out},G)
end
local hands,decks,graves,events,mask
local function card(owner)
	local c={owner=owner,location=LOCATION_HAND}
	function c:IsLocation(loc) return self.location==loc end
	function c:IsControler(player) return self.owner==player end
	return c
end
local source=card(0)
source.location=0
local e={}
function e:GetHandler() return source end
Duel={}
function Duel.GetActiveLogicalPlayerMask() return mask end
function Duel.IsLogicalPlayerActive(p) return (mask & (1<<p))~=0 end
function Duel.GetPlayerFieldGroup(p,loc)
	assert(loc==LOCATION_HAND)
	return copy_group(hands[p])
end
function Duel.IsPlayerCanDrawPlayer(p,n)
	return Duel.IsLogicalPlayerActive(p) and decks[p]>=n
end
function Duel.GetFieldGroupCount(p,l1,l2)
	assert(l1==LOCATION_HAND and l2==0)
	return #hands[p]
end
function Duel.GetFieldGroup(p,l1,l2)
	assert(l1==LOCATION_HAND and l2==0)
	return copy_group(hands[p])
end
function Duel.IsPlayerCanDraw(p,n) return decks[p]>=n end
function Duel.Draw(p,n,r) return Duel.DrawPlayer(p,n,r) end
function Duel.SetOperationInfo() end
function Duel.SendtoGrave(group,reason)
	assert(reason==(REASON_EFFECT|REASON_DISCARD))
	local n=0
	for _,c in ipairs(group.cards) do
		if not c.protected then
			for i=#hands[c.owner],1,-1 do
				if hands[c.owner][i]==c then table.remove(hands[c.owner],i) end
			end
			c.location=0
			graves[c.owner][#graves[c.owner]+1]=c
			n=n+1
		end
	end
	events[#events+1]={op='discard',n=n}
	return n
end
function Duel.DrawPlayer(p,n,r)
	assert(r==REASON_EFFECT and decks[p]>=n)
	decks[p]=decks[p]-n
	for _=1,n do hands[p][#hands[p]+1]=card(p) end
	events[#events+1]={op='draw',player=p,n=n}
	return n
end
function Duel.TagSwap() error('TagSwap must not run in logical 2v1') end
local function setup(newmask,counts,newdecks)
	mask=newmask; hands={}; decks={}; graves={}; events={}
	for p=0,3 do
		hands[p]={}; decks[p]=newdecks[p] or 0; graves[p]={}
		for _=1,(counts[p] or 0) do hands[p][#hands[p]+1]=card(p) end
	end
	source=card(0);source.location=0
end
dofile('multiplayer-anime-cards/c8050010.lua')
local function can() return script.target(e,0,nil,nil,nil,nil,nil,nil,0) end
local function activate() script.activate(e,0,nil,nil,nil,nil,nil,nil) end
local function chk(counts,grave_counts)
	for p=0,3 do
		assert(#hands[p]==(counts[p] or 0),('wrong hand count for P%d'):format(p+1))
		if grave_counts then
			assert(#graves[p]==(grave_counts[p] or 0),
				('wrong grave count for P%d'):format(p+1))
		end
	end
end
local function count_events(op)
	local n=0
	for _,v in ipairs(events) do if v.op==op then n=n+1 end end
	return n
end
-- Yugi, Joey, and Big Five independently discard then draw; no phantom P4.
setup(0x07,{[0]=2,[1]=1,[2]=3},{[0]=10,[1]=10,[2]=10})
assert(can());activate()
chk({[0]=2,[1]=1,[2]=3},{[0]=2,[1]=1,[2]=3})
assert(count_events('discard')==3 and count_events('draw')==3)
for i=1,3 do assert(events[i].op=='discard') end
for i=4,6 do assert(events[i].op=='draw') end
assert(events[4].player==0 and events[4].n==2)
assert(events[5].player==1 and events[5].n==1)
assert(events[6].player==2 and events[6].n==3)
-- Only one player has cards in hand.
setup(0x07,{[1]=2},{[0]=10,[1]=10,[2]=10})
assert(can());activate()
chk({[1]=2},{[1]=2})
assert(count_events('draw')==1 and events[2].player==1)
-- No cards in any hand: illegal to activate.
setup(0x07,{},{[0]=10,[1]=10,[2]=10})
assert(not can())
-- Reject if someone cannot draw as many cards as they would discard.
setup(0x07,{[0]=2,[1]=3,[2]=1},{[0]=10,[1]=2,[2]=10})
assert(not can())
-- Out/eliminated P2 must not discard or draw.
setup(0x05,{[0]=1,[1]=3,[2]=2},{[0]=10,[1]=10,[2]=10})
assert(can());activate()
chk({[0]=1,[1]=3,[2]=2},{[0]=1,[2]=2})
assert(count_events('draw')==2)
-- Source card remaining in its owner's Hand must never discard itself.
setup(0x07,{[0]=1,[1]=1},{[0]=10,[1]=10,[2]=10})
source=hands[0][1]
assert(can());activate()
chk({[0]=1,[1]=1},{[1]=1})
assert(hands[0][1]==source)
-- Immune cards do not count as discarded/drawn.
setup(0x07,{[0]=2,[1]=1},{[0]=10,[1]=10,[2]=10})
hands[0][1].protected=true
assert(can());activate()
chk({[0]=2,[1]=1},{[0]=1,[1]=1})
assert(events[3].n==1)
-- Standard fallback unchanged, with TagSwap unavailable.
setup(0,{[0]=2,[1]=1},{[0]=10,[1]=10})
Duel.TagSwap=nil
assert(can());activate()
chk({[0]=2,[1]=1},{[0]=2,[1]=1})
print('Card Destruction 2v1: 8 Lua regression scenarios PASS')
