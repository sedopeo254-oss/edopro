--Dice Dungeon
--Anime multiplayer version: each battling player's logical controller
--chooses a die result from 1 to 6 instead of receiving a random roll.
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e1)
	--Self-destroy if its controller has no monsters
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCode(EFFECT_SELF_DESTROY)
	e2:SetCondition(s.sdcon)
	c:RegisterEffect(e2)
	--Apply the chosen die results before damage calculation
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
	local at=Duel.GetAttacker()
	local bc=Duel.GetAttackTarget()
	return at and bc and at:IsFaceup() and bc:IsFaceup()
		and at:IsPosition(POS_FACEUP_ATTACK)
		and bc:IsPosition(POS_FACEUP_ATTACK)
end
function s.getlogicalplayer(c)
	local p=c:GetLogicalControler()
	if p==nil then
		p=c:GetControler()
	end
	return p
end
function s.selectresult(c)
	return Duel.AnnounceNumberPlayer(s.getlogicalplayer(c),1,2,3,4,5,6)
end
function s.applyresult(c,result,source)
	if not c or not c:IsFaceup() or not c:IsPosition(POS_FACEUP_ATTACK) then return end
	local e1=Effect.CreateEffect(source)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_DAMAGE)
	if result==1 then
		--1: Lose 1000 ATK
		e1:SetCode(EFFECT_UPDATE_ATTACK)
		e1:SetValue(-1000)
	elseif result==2 then
		--2: Gain 1000 ATK
		e1:SetCode(EFFECT_UPDATE_ATTACK)
		e1:SetValue(1000)
	elseif result==3 then
		--3: ATK becomes 0
		e1:SetCode(EFFECT_SET_ATTACK_FINAL)
		e1:SetValue(0)
	elseif result==4 then
		--4: ATK becomes 2000
		e1:SetCode(EFFECT_SET_ATTACK_FINAL)
		e1:SetValue(2000)
	elseif result==5 then
		--5: Current ATK is halved
		e1:SetCode(EFFECT_SET_ATTACK_FINAL)
		e1:SetValue(math.floor(math.max(0,c:GetAttack())/2))
	elseif result==6 then
		--6: Current ATK is doubled
		e1:SetCode(EFFECT_SET_ATTACK_FINAL)
		e1:SetValue(math.max(0,c:GetAttack())*2)
	else
		return
	end
	c:RegisterEffect(e1)
end
function s.op(e,tp,eg,ep,ev,re,r,rp)
	local at=Duel.GetAttacker()
	local bc=Duel.GetAttackTarget()
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) or not at or not bc then return end

	--Each participant receives their own 1-6 menu. AnnounceNumberPlayer routes
	--the prompt to the correct logical player in 3v1 and Battle Royale.
	local result_at=s.selectresult(at)
	local result_bc=s.selectresult(bc)
	s.applyresult(at,result_at,c)
	s.applyresult(bc,result_bc,c)
end
