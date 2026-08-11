--機械軍曹機械軍曹
--Robotic Knight (Deck Master)
--Scripted by Larry126
--3v1 correction: every discarded Machine assigns 500 damage to one opponent.
local s,id=GetID()
function s.initial_effect(c)
	if not DeckMaster then
		return
	end
	--Deck Master Effect
	local dme1=Effect.CreateEffect(c)
	dme1:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_FIELD)
	dme1:SetCode(EVENT_FREE_CHAIN)
	dme1:SetCondition(s.con)
	dme1:SetOperation(s.op)
	local dme2=dme1:Clone()
	dme2:SetCode(EVENT_CHAIN_END)
	DeckMaster.RegisterAbilities(c,dme1,dme2)
end
function s.costfilter(c)
	return c:IsRace(RACE_MACHINE) and c:IsDiscardable(REASON_EFFECT)
end
function s.con(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsExistingMatchingCard(s.costfilter,tp,LOCATION_HAND,0,1,nil)
		and Duel.IsDeckMaster(tp,id)
end
function s.countplayers(mask)
	local ct=0
	for player=0,3 do
		if mask&(1<<player)~=0 then
			ct=ct+1
		end
	end
	return ct
end
function s.op(e,tp,eg,ep,ev,re,r,rp)
	if not Duel.SelectYesNo(tp,aux.Stringid(id,0)) then return end
	Duel.Hint(HINT_CARD,tp,id)
	Duel.Hint(HINT_CARD,1-tp,id)

	--In a normal Duel (or when expansion is declined), only the current
	--opponent is selected. In anime 3v1, expansion returns all active opponents.
	local players,expanded=Duel.SelectEffectPlayers(tp,false,true)
	local max_targets=expanded and s.countplayers(players) or 1
	if max_targets<=0 then return end

	--One discarded Machine corresponds to one opponent taking exactly 500.
	--Example: discard 3 Machines against three opponents -> each loses 500,
	--not 1500 damage to every opponent.
	local ct=Duel.DiscardHand(tp,s.costfilter,1,max_targets,
		REASON_EFFECT+REASON_DISCARD)
	if ct<=0 then return end
	if not expanded then
		Duel.Damage(1-tp,500,REASON_EFFECT)
		return
	end
	for player=0,3 do
		if ct<=0 then break end
		if players&(1<<player)~=0 then
			Duel.DamagePlayer(player,500,REASON_EFFECT,false,tp,false)
			ct=ct-1
		end
	end
end
