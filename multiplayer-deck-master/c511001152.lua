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
	--If either anime/alternate Orgoth the Relentless is destroyed, destroy Dice Dungeon.
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCode(EVENT_DESTROYED)
	e3:SetCondition(s.orgothcon)
	e3:SetOperation(s.orgothop)
	c:RegisterEffect(e3)
	--Apply the chosen die results before damage calculation
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,0))
	e4:SetCategory(CATEGORY_ATKCHANGE)
	e4:SetType(EFFECT_TYPE_TRIGGER_F+EFFECT_TYPE_FIELD)
	e4:SetRange(LOCATION_SZONE)
	e4:SetCode(EVENT_PRE_DAMAGE_CALCULATE)
	e4:SetCondition(s.con)
	e4:SetOperation(s.op)
	c:RegisterEffect(e4)
end
s.roll_dice=true
s.listed_names={15744417,140000073}
function s.sdcon(e)
	return Duel.GetFieldGroupCount(e:GetHandlerPlayer(),LOCATION_MZONE,0)==0
end
function s.orgothfilter(c)
	local code=c:GetOriginalCode()
	return code==15744417 or code==140000073
end
function s.orgothcon(e,tp,eg,ep,ev,re,r,rp)
	return eg and eg:IsExists(s.orgothfilter,1,nil)
end
function s.orgothop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsFaceup() and c:IsLocation(LOCATION_SZONE) then
		Duel.Destroy(c,REASON_EFFECT)
	end
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
	if p==nil then p=c:GetControler() end
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
		e1:SetCode(EFFECT_UPDATE_ATTACK)
		e1:SetValue(-1000)
	elseif result==2 then
		e1:SetCode(EFFECT_UPDATE_ATTACK)
		e1:SetValue(1000)
	elseif result==3 then
		e1:SetCode(EFFECT_SET_ATTACK_FINAL)
		e1:SetValue(0)
	elseif result==4 then
		e1:SetCode(EFFECT_SET_ATTACK_FINAL)
		e1:SetValue(2000)
	elseif result==5 then
		--5: Lose exactly 1350 ATK
		e1:SetCode(EFFECT_UPDATE_ATTACK)
		e1:SetValue(-1350)
	elseif result==6 then
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
	local result_at=s.selectresult(at)
	local result_bc=s.selectresult(bc)
	s.applyresult(at,result_at,c)
	s.applyresult(bc,result_bc,c)
end
