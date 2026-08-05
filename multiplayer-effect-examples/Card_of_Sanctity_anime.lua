--Card of Sanctity (anime) - universal multiplayer effect expansion example
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DRAW)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local ct1=6-Duel.GetFieldGroupCount(tp,LOCATION_HAND,0)
	local ct2=6-Duel.GetFieldGroupCount(tp,0,LOCATION_HAND)
	if chk==0 then return ct1>0 and Duel.IsPlayerCanDraw(tp,ct1)
		and ct2>0 and Duel.IsPlayerCanDraw(1-tp,ct2) end
	Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,tp,ct1)
	Duel.SetOperationInfo(0,CATEGORY_DRAW,nil,0,1-tp,ct2)
end
function s.draw_original(tp)
	local ht=Duel.GetFieldGroupCount(tp,LOCATION_HAND,0)
	if ht<6 then
		Duel.Draw(tp,6-ht,REASON_EFFECT)
	end
	ht=Duel.GetFieldGroupCount(1-tp,LOCATION_HAND,0)
	if ht<6 then
		Duel.Draw(1-tp,6-ht,REASON_EFFECT)
	end
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local players,expanded=Duel.SelectEffectPlayers(tp,true,true)
	if not expanded then
		s.draw_original(tp)
		return
	end
	for player=0,25 do
		if players&(1<<player)~=0 then
			local hand=Duel.GetPlayerFieldGroupCount(player,LOCATION_HAND)
			if hand<6 then
				Duel.DrawPlayer(player,6-hand,REASON_EFFECT)
			end
		end
	end
end
