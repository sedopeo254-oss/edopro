--デーモンとの駆け引き
--A Deal with Dark Ruler (Anime)
local s,id=GetID()
local BERSERK_DRAGON_ANIME=99900042
local BERSERK_DRAGON=85605684
function s.initial_effect(c)
	--Battle destruction version: activate before battle damage is applied so the
	--"no Battle Damage involving the destroyed monster" clause works correctly.
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_PRE_BATTLE_DAMAGE)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e1:SetCondition(s.bcondition)
	e1:SetCost(s.bcost)
	e1:SetTarget(s.btarget)
	e1:SetOperation(s.bactivate)
	c:RegisterEffect(e1)
	--Effect destruction (and zero-damage battle destruction fallback)
	local e2=e1:Clone()
	e2:SetCode(EVENT_DESTROYED)
	e2:SetProperty(EFFECT_FLAG_DELAY+EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e2:SetCondition(s.dcondition)
	e2:SetTarget(s.target)
	e2:SetOperation(s.activate)
	c:RegisterEffect(e2)
end
s.listed_names={BERSERK_DRAGON_ANIME,BERSERK_DRAGON}
function s.logicalplayer(e)
	return e:GetHandler():GetLogicalOwner()
end
function s.is_yours(c,e)
	return c and c:GetLogicalControler()==s.logicalplayer(e)
end
function s.bcondition(e,tp,eg,ep,ev,re,r,rp)
	local bc=Duel.GetBattleMonster(tp)
	return bc and s.is_yours(bc,e) and bc:IsFaceup() and bc:IsLevelAbove(8)
		and bc:IsStatus(STATUS_BATTLE_RESULT)
end
function s.cfilter(c,e)
	return c:IsPreviousLocation(LOCATION_MZONE)
		and c:GetPreviousLevelOnField()>=8
		and c:IsReason(REASON_EFFECT)
		and not c:IsReason(REASON_BATTLE)
		and s.is_yours(c,e)
end
function s.dcondition(e,tp,eg,ep,ev,re,r,rp)
	return eg:IsExists(s.cfilter,1,nil,e)
end
function s.bcost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetLP(tp)>1 end
	local lp=Duel.GetLP(tp)
	Duel.ChangeBattleDamage(tp,0)
	Duel.PayLPCost(tp,math.floor(lp/2))
end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetLP(tp)>1 end
	local lp=Duel.GetLP(tp)
	Duel.PayLPCost(tp,math.floor(lp/2))
end
function s.spfilter(c,e,tp)
	return c:IsCode(BERSERK_DRAGON_ANIME,BERSERK_DRAGON)
		and c:IsCanBeSpecialSummoned(e,0,tp,true,false)
end
function s.can_summon(e,tp)
	return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_HAND|LOCATION_DECK,0,1,nil,e,tp)
end
function s.btarget(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return s.can_summon(e,tp) end
	e:SetLabelObject(Duel.GetBattleMonster(tp))
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND|LOCATION_DECK)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return s.can_summon(e,tp) end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND|LOCATION_DECK)
end
function s.summon(e,tp)
	if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local g=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_HAND|LOCATION_DECK,0,1,1,nil,e,tp)
	if #g>0 then
		Duel.SpecialSummon(g,0,tp,tp,true,false,POS_FACEUP)
	end
end
function s.bactivate(e,tp,eg,ep,ev,re,r,rp)
	local bc=e:GetLabelObject()
	if not bc or not bc:IsRelateToBattle() then return end
	--Battle Damage was already changed to 0 during s.bcost.
	--Summon Berserk Dragon only after that monster is actually destroyed by battle.
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e1:SetCode(EVENT_BATTLE_DESTROYED)
	e1:SetLabelObject(bc)
	e1:SetCondition(s.delaycon)
	e1:SetOperation(s.delayop)
	e1:SetReset(RESET_PHASE+PHASE_DAMAGE)
	Duel.RegisterEffect(e1,tp)
end
function s.delaycon(e,tp,eg,ep,ev,re,r,rp)
	local bc=e:GetLabelObject()
	return bc and eg:IsContains(bc)
end
function s.delayop(e,tp,eg,ep,ev,re,r,rp)
	s.summon(e,tp)
	e:Reset()
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	s.summon(e,tp)
end
