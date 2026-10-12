--デーモンとの駆け引き
--A Deal with Dark Ruler (Anime)
local s,id=GetID()
local BERSERK_DRAGON_ANIME=99900042
local BERSERK_DRAGON=85605684
local MIN_LEVEL=8

function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_PRE_DAMAGE_CALCULATE)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e1:SetCondition(s.bcondition)
	e1:SetCost(s.cost)
	e1:SetTarget(s.btarget)
	e1:SetOperation(s.bactivate)
	c:RegisterEffect(e1)

	local e2=e1:Clone()
	e2:SetCode(EVENT_DESTROYED)
	e2:SetProperty(EFFECT_FLAG_DELAY+EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e2:SetCondition(s.econdition)
	e2:SetCost(s.cost)
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

function s.get_own_battler(tp,e)
	local own,opp=Duel.GetBattleMonster(tp)
	if not own or not opp or not s.is_yours(own,e) then
		return nil,nil
	end
	return own,opp
end

function s.would_be_destroyed(own,opp)
	if not own or not opp then return false end
	if own:IsAttackPos() then
		return opp:IsAttackPos() and own:GetAttack()<=opp:GetAttack()
	end
	return Duel.GetAttackTarget()==own and own:GetDefense()<opp:GetAttack()
end

function s.bcondition(e,tp,eg,ep,ev,re,r,rp)
	local own,opp=s.get_own_battler(tp,e)
	return own and own:IsFaceup()
		and own:IsLevelAbove(MIN_LEVEL)
		and s.would_be_destroyed(own,opp)
end

function s.efilter(c,e)
	return c:IsPreviousLocation(LOCATION_MZONE)
		and c:GetPreviousLevelOnField()>=MIN_LEVEL
		and c:IsReason(REASON_EFFECT)
		and not c:IsReason(REASON_BATTLE)
		and s.is_yours(c,e)
end
function s.econdition(e,tp,eg,ep,ev,re,r,rp)
	return eg:IsExists(s.efilter,1,nil,e)
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
function s.has_berserk(e,tp)
	return Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_HAND|LOCATION_DECK,0,1,nil,e,tp)
end

function s.btarget(e,tp,eg,ep,ev,re,r,rp,chk)
	local own=s.get_own_battler(tp,e)
	if chk==0 then return own and s.has_berserk(e,tp) end
	e:SetLabelObject(own)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND|LOCATION_DECK)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return s.has_berserk(e,tp) end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND|LOCATION_DECK)
end

function s.zero_this_battle(e,tp)
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CHANGE_BATTLE_DAMAGE)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetTargetRange(1,0)
	e1:SetValue(0)
	e1:SetReset(RESET_PHASE+PHASE_DAMAGE_CAL)
	Duel.RegisterEffect(e1,tp)
end

function s.bactivate(e,tp,eg,ep,ev,re,r,rp)
	local bc=e:GetLabelObject()
	if not bc or not bc:IsRelateToBattle() then return end
	s.zero_this_battle(e,tp)
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
function s.summon(e,tp)
	if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local g=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_HAND|LOCATION_DECK,0,1,1,nil,e,tp)
	if #g>0 then
		Duel.SpecialSummon(g,0,tp,tp,true,false,POS_FACEUP)
	end
end
function s.delayop(e,tp,eg,ep,ev,re,r,rp)
	s.summon(e,tp)
	e:Reset()
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	s.summon(e,tp)
end
