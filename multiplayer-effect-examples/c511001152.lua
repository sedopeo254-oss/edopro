--Dice Dungeon
--Manual dice selection for each battling logical player (1-6)
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e1)
	--selfdes
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCode(EFFECT_SELF_DESTROY)
	e2:SetCondition(s.sdcon)
	c:RegisterEffect(e2)
	--Choose a die result for each battling monster
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_ATKCHANGE)
	e3:SetType(EFFECT_TYPE_TRIGGER_F+EFFECT_TYPE_FIELD)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCode(EVENT_PRE_DAMAGE_CALCULATE)
	e3:SetCondition(s.con)
	e3:SetOperation(s.op)
	c:RegisterEffect(e3)
end
s.roll_dice=true
function s.sdcon(e)
	return Duel.GetFieldGroupCount(e:GetHandlerPlayer(),LOCATION_MZONE,0)==0
end
function s.con(e,tp,eg,ep,ev,re,r,rp)
	return Duel.GetAttacker()~=nil and Duel.GetAttackTarget()~=nil
end
function s.getlogicalplayer(c)
	if c.GetLogicalControler then
		local logical=c:GetLogicalControler()
		if logical~=nil then
			return logical
		end
	end
	return c:GetControler()
end
function s.choosedie(c)
	local logical=s.getlogicalplayer(c)
	if Duel.AnnounceNumberPlayer then
		local result=Duel.AnnounceNumberPlayer(logical,1,2,3,4,5,6)
		if result~=nil then
			return result
		end
	end
	--Compatibility fallback for an older two-player core.
	return Duel.AnnounceNumber(c:GetControler(),1,2,3,4,5,6)
end
function s.applyresult(c,tc,dice)
	if not tc or (dice~=1 and dice~=5 and dice~=6) then return end
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetReset(RESET_PHASE|PHASE_DAMAGE)
	if dice==1 then
		e1:SetCode(EFFECT_UPDATE_ATTACK)
		e1:SetValue(1000)
	elseif dice==5 then
		e1:SetCode(EFFECT_SET_BASE_ATTACK)
		e1:SetValue(math.floor(tc:GetBaseAttack()/2))
	else
		e1:SetCode(EFFECT_SET_BASE_ATTACK)
		e1:SetValue(tc:GetBaseAttack()*2)
	end
	tc:RegisterEffect(e1)
end
function s.op(e,tp,eg,ep,ev,re,r,rp)
	local attacker=Duel.GetAttacker()
	local defender=Duel.GetAttackTarget()
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) or not attacker or not defender then return end

	--The attacker chooses first, then the defending monster's owner chooses.
	--In 3v1/Battle Royale each prompt is routed to the exact logical player.
	local attacker_die=s.choosedie(attacker)
	local defender_die=s.choosedie(defender)
	s.applyresult(c,attacker,attacker_die)
	s.applyresult(c,defender,defender_die)
end
