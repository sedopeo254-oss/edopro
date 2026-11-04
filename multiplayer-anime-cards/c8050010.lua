--手札抹殺
--Card Destruction (Anime / Tag)
local s,id=GetID()

function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_HANDES+CATEGORY_DRAW)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end

-- Each logical player has a private Hand/Deck/GY in multiplayer (including 2v1).
-- TagSwap must not be used for this mode: it changes which teammate's piles
-- are projected instead of iterating the real players.
local function IsLogicalMultiplayer()
	return Duel.GetActiveLogicalPlayerMask ~= nil
		and Duel.GetActiveLogicalPlayerMask() ~= 0
end

local function LogicalHand(p,c)
	local hand=Duel.GetPlayerFieldGroup(p,LOCATION_HAND)
	-- A copied source or an activating Spell must never discard itself if
	-- a script still reports it as being in its owner's hand.
	if c and c:IsLocation(LOCATION_HAND) then
		hand:RemoveCard(c)
	end
	return hand
end

function s.logical_target(e)
	local mask=Duel.GetActiveLogicalPlayerMask()
	local total=0
	for p=0,3 do
		if (mask & (1<<p))~=0 then
			local count=#LogicalHand(p,e:GetHandler())
			if count>0 then
				total=total+count
				if not Duel.IsPlayerCanDrawPlayer(p,count) then return false end
			end
		end
	end
	return total>0
end

function s.logical_activate(e)
	local mask=Duel.GetActiveLogicalPlayerMask()
	local hands={}
	local discarded={}
	-- Snapshot every separate logical hand before any cards are sent away.
	for p=0,3 do
		if (mask & (1<<p))~=0 then
			hands[p]=LogicalHand(p,e:GetHandler())
		end
	end
	-- Discard first, for every active participant. Preserve the actual
	-- number discarded if a card cannot be sent to the Graveyard.
	for p=0,3 do
		local hand=hands[p]
		if hand and #hand>0 then
			discarded[p]=Duel.SendtoGrave(hand,REASON_EFFECT|REASON_DISCARD)
		end
	end
	-- Then refill each player's OWN hand from that player's OWN Deck.
	-- This includes Big Five, and never swaps Yugi/Joey's private piles.
	for p=0,3 do
		local count=discarded[p] or 0
		if count>0 and Duel.IsLogicalPlayerActive(p)
			and Duel.IsPlayerCanDrawPlayer(p,count) then
			Duel.DrawPlayer(p,count,REASON_EFFECT)
		end
	end
end

local function CanTagSwap()
	return Duel.TagSwap~=nil
end

function s.hand_count(p,c)
	local ct=Duel.GetFieldGroupCount(p,LOCATION_HAND,0)
	if c and c:IsLocation(LOCATION_HAND) and c:IsControler(p) then
		ct=ct-1
	end
	return ct
end

function s.discard_and_draw_player(p,c)
	local ct=s.hand_count(p,c)
	local g=Duel.GetFieldGroup(p,LOCATION_HAND,0)

	-- لا ترسل Card Destruction نفسها لو كانت ما زالت باليد وقت الحساب
	if c and c:IsLocation(LOCATION_HAND) and c:IsControler(p) then
		g:RemoveCard(c)
	end

	if #g>0 then
		Duel.SendtoGrave(g,REASON_EFFECT|REASON_DISCARD)
	end

	if ct>0 and Duel.IsPlayerCanDraw(p,ct) then
		Duel.Draw(p,ct,REASON_EFFECT)
	end
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	if chk==0 then
		if IsLogicalMultiplayer() then
			return s.logical_target(e)
		end
		if not CanTagSwap() then
			local h1=s.hand_count(tp,c)
			local h2=Duel.GetFieldGroupCount(1-tp,LOCATION_HAND,0)
			return (h1+h2)>0
				and (h1==0 or Duel.IsPlayerCanDraw(tp,h1))
				and (h2==0 or Duel.IsPlayerCanDraw(1-tp,h2))
		end
		return true
	end

	Duel.SetOperationInfo(0,CATEGORY_HANDES,nil,0,PLAYER_ALL,1)
	Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,PLAYER_ALL,1)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
	if IsLogicalMultiplayer() then
		s.logical_activate(e)
		return
	end
	local c=e:GetHandler()

	-- لاعبك الحالي
	s.discard_and_draw_player(tp,c)

	-- شريكك
	if CanTagSwap() then
		Duel.TagSwap(tp)
		s.discard_and_draw_player(tp,c)
		Duel.TagSwap(tp)
	end

	-- الخصم الحالي
	s.discard_and_draw_player(1-tp,c)

	-- شريك الخصم
	if CanTagSwap() then
		Duel.TagSwap(1-tp)
		s.discard_and_draw_player(1-tp,c)
		Duel.TagSwap(1-tp)
	end
end
