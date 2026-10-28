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

function s.is_multiplayer()
	return Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0
end

function s.spell_candidate(c,tp)
	return c:IsSpell() and c:IsLocation(LOCATION_GRAVE|LOCATION_ONFIELD)
		and c:IsControler(tp) and c:GetActivateEffect()~=nil
end

function s.hats_target(c)
	return c:IsFaceup() and c:IsType(TYPE_MONSTER)
		and (c:IsRace(RACE_SPELLCASTER) or c:IsRace(RACE_WARRIOR))
		and not c:IsLocation(LOCATION_PZONE)
end

function s.can_receive_copy(logical,code)
	if code~=403 then return true end
	--The teammate needs a legal monster and three slots for the four hats.
	local g=Duel.GetPlayerFieldGroup(logical,LOCATION_MZONE)
	return #g<=4 and g:IsExists(s.hats_target,1,nil)
end

function s.copy_recipient(owner,code)
	if not s.is_multiplayer() then return owner end
	local side=Duel.GetLogicalPlayerSide(owner)
	if side==nil then return nil end
	for p=0,3 do
		if p~=owner and Duel.IsLogicalPlayerActive(p)
			and Duel.GetLogicalPlayerSide(p)==side
			and s.can_receive_copy(p,code) then
			return p
		end
	end
	return nil
end

function s.filter(c,e,tp)
	if not s.spell_candidate(c,tp) then return false end
	return s.copy_recipient(e:GetOwner():GetLogicalOwner(),c:GetOriginalCode())~=nil
end

function s.con(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetOwner()
	return DeckMaster.IsAbilityActiveCard(c) and s.ownturn(c,tp)
		and Duel.IsMainPhase() and Duel.CheckLPCost(tp,1000)
		and s.usedSpell:IsExists(s.filter,1,nil,e,tp)
end

function s.op(e,tp,eg,ep,ev,re,r,rp)
	if not Duel.SelectYesNo(tp,aux.Stringid(id,0)) then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_EFFECT)
	local g=s.usedSpell:FilterSelect(tp,s.filter,1,1,nil,e,tp)
	local original=g:GetFirst()
	if not original then return end
	local code=original:GetOriginalCode()
	local target=s.copy_recipient(e:GetOwner():GetLogicalOwner(),code)
	if target==nil then return end
	local side=s.is_multiplayer() and Duel.GetLogicalPlayerSide(target) or tp
	if side==nil then return end

	--Use a genuine Spell owned by the teammate. The source in the graveyard
	--or on the field stays untouched; c403.lua is not called manually.
	local copy=s.is_multiplayer() and Duel.CreateTokenPlayer(target,code)
		or Duel.CreateToken(side,code)
	if not copy then return end
	if Duel.SendtoHand(copy,side,REASON_EFFECT)==0 then return end
	local te=copy:GetActivateEffect()
	if not te then
		Duel.SendtoGrave(copy,REASON_RULE)
		return
	end
	Duel.PayLPCost(tp,1000)
	Duel.Hint(HINT_CARD,tp,id)
	Duel.Hint(HINT_CARD,side,code)
	--Native Spell activation: correct logical owner, normal Chain and replay.
	Duel.Activate(te)
end
