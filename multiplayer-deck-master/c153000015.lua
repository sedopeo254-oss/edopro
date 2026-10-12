--ブラック・マジシャン (Deck Master)
--Dark Magician (Deck Master)
--Anime multiplayer update
local s,id=GetID()

function s.initial_effect(c)
	if not DeckMaster then return end

	local dme1=Effect.CreateEffect(c)
	dme1:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_FIELD)
	dme1:SetCode(EVENT_FREE_CHAIN)
	dme1:SetCondition(s.con)
	dme1:SetOperation(s.op)
	DeckMaster.RegisterAbilities(c,dme1)

	aux.GlobalCheck(s,function()
		s.usedSpell=Group.CreateGroup()
		s.usedSpell:KeepAlive()
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_CHAINING)
		ge1:SetOperation(s.checkop)
		Duel.RegisterEffect(ge1,0)
		aux.AddValuesReset(function()
			s.usedSpell:Clear()
		end)
	end)
end

function s.checkop(e,tp,eg,ep,ev,re,r,rp)
	if re and re:IsActiveType(TYPE_SPELL)
		and re:IsHasType(EFFECT_TYPE_ACTIVATE) then
		s.usedSpell:AddCard(re:GetHandler())
	end
end

function s.ownturn(c,tp)
	if Duel.GetActiveLogicalPlayerMask
		and Duel.GetActiveLogicalPlayerMask()~=0 then
		return Duel.GetLogicalPlayer(tp)==c:GetLogicalOwner()
	end
	return Duel.IsTurnPlayer(tp)
end

function s.filter(c,e,tp)
	if not c:IsSpell()
		or not c:IsLocation(LOCATION_GRAVE|LOCATION_ONFIELD)
		or not c:IsControler(tp) then
		return false
	end
	return c:GetActivateEffect()~=nil
end

function s.con(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetOwner()
	return DeckMaster.IsAbilityActiveCard(c)
		and s.ownturn(c,tp)
		and Duel.IsMainPhase()
		and Duel.CheckLPCost(tp,1000)
		and s.usedSpell:IsExists(s.filter,1,nil,e,tp)
end

function s.can_run(te,tp,eg,ep,ev,re,r,rp)
	if not te then return false end
	local con=te:GetCondition()
	local co=te:GetCost()
	local tg=te:GetTarget()
	if con and not con(te,tp,eg,ep,ev,re,r,rp) then return false end
	if co and not co(te,tp,eg,ep,ev,re,r,rp,0) then return false end
	if tg and not tg(te,tp,eg,ep,ev,re,r,rp,0) then return false end
	return true
end

function s.replay_spell(tc,e,tp,eg,ep,ev,re,r,rp)
	local te=tc:GetActivateEffect()
	if not te then return false end
	local was_grave=tc:IsLocation(LOCATION_GRAVE)
	if was_grave then
		local loc=tc:IsType(TYPE_FIELD) and LOCATION_FZONE or LOCATION_SZONE
		if loc==LOCATION_SZONE and Duel.GetLocationCount(tp,LOCATION_SZONE)<=0 then
			return false
		end
		if not Duel.MoveToField(tc,tp,tp,loc,POS_FACEUP,true) then
			return false
		end
	end
	if not s.can_run(te,tp,eg,ep,ev,re,r,rp) then
		if was_grave and tc:IsOnField() then
			Duel.SendtoGrave(tc,REASON_RULE)
		end
		return false
	end
	local co=te:GetCost()
	local tg=te:GetTarget()
	local op=te:GetOperation()
	Duel.Hint(HINT_CARD,tp,tc:GetOriginalCode())
	Duel.BreakEffect()
	Duel.ClearTargetCard()
	if co then co(te,tp,eg,ep,ev,re,r,rp,1) end
	if tg then tg(te,tp,eg,ep,ev,re,r,rp,1) end
	if op then op(te,tp,eg,ep,ev,re,r,rp) end
	if was_grave and tc:IsLocation(LOCATION_SZONE)
		and (tc:GetOriginalType()&(TYPE_CONTINUOUS|TYPE_EQUIP|TYPE_FIELD))==0
		and not tc:IsHasEffect(EFFECT_REMAIN_FIELD) then
		Duel.SendtoGrave(tc,REASON_RULE)
	end
	return true
end

function s.op(e,tp,eg,ep,ev,re,r,rp)
	if not Duel.SelectYesNo(tp,aux.Stringid(id,0)) then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_EFFECT)
	local sg=s.usedSpell:FilterSelect(tp,s.filter,1,1,nil,e,tp)
	local tc=sg:GetFirst()
	if not tc then return end
	Duel.PayLPCost(tp,1000)
	Duel.Hint(HINT_CARD,tp,id)
	Duel.Hint(HINT_CARD,1-tp,id)
	s.replay_spell(tc,e,tp,eg,ep,ev,re,r,rp)
end
