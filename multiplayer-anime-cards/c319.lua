-- Surprise Attack From Beyond (anime) - original c319 behavior
-- except that the extra Battle Phase is now INSIDE the same turn.
-- Requires the updated EDOPro Core: Duel.RequestExtraBattlePhase.
local s,id=GetID()
s.listed_names={}
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
	aux.GlobalCheck(s,function()
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE)
		ge1:SetCode(EVENT_SUMMON_SUCCESS)
		ge1:SetOperation(s.checkop)
		Duel.RegisterEffect(ge1,0)
		local ge2=ge1:Clone()
		ge2:SetCode(EVENT_SPSUMMON_SUCCESS)
		Duel.RegisterEffect(ge2,0)
	end)
end
function s.checkop(e,tp,eg,ep,ev,re,r,rp)
	if not eg then return end
	for tc in eg:Iter() do
		if tc:GetFlagEffect(id)==0 then
			-- Two End Phases occur in the same turn when this resolves.
			tc:RegisterFlagEffect(id,RESET_PHASE+PHASE_END+RESET_SELF_TURN,0,2)
		end
	end
end
function s.eligible(c)
	return c:IsType(TYPE_MONSTER) and
		(c:IsStatus(STATUS_SUMMON_TURN|STATUS_SPSUMMON_TURN)
			or c:GetFlagEffect(id)>0)
end
function s.leftfield(c,tp,turn)
	return c:IsType(TYPE_MONSTER) and c:GetFlagEffect(id)>0
		and c:GetPreviousControler()==tp and c:GetTurnID()==turn
		and c:GetPreviousLocation()==LOCATION_MZONE
end
function s.available(tp)
	return Duel.IsExistingMatchingCard(s.eligible,tp,LOCATION_MZONE|LOCATION_SZONE,0,1,nil)
		or Duel.IsExistingMatchingCard(s.leftfield,tp,
			LOCATION_DECK|LOCATION_HAND|LOCATION_GRAVE|LOCATION_REMOVED|LOCATION_EXTRA,
			0,1,nil,tp,Duel.GetTurnCount())
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.GetCurrentPhase()==PHASE_END
		and Duel.GetTurnPlayer()==tp
		and Duel.CanRequestExtraBattlePhase
		and Duel.CanRequestExtraBattlePhase(tp)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return s.available(tp) end
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	if not s.available(tp) or not Duel.RequestExtraBattlePhase
		or not Duel.RequestExtraBattlePhase(tp) then return end
	-- Restrict attacks to monsters Normal/Special Summoned during THIS turn.
	local restrict=Effect.CreateEffect(e:GetHandler())
	restrict:SetType(EFFECT_TYPE_FIELD)
	restrict:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	restrict:SetCode(EFFECT_CANNOT_ATTACK)
	restrict:SetTargetRange(LOCATION_MZONE,0)
	restrict:SetTarget(s.attack_limit)
	restrict:SetReset(RESET_PHASE+PHASE_END+RESET_SELF_TURN,2)
	Duel.RegisterEffect(restrict,tp)
	-- EVENT_PHASE_START is raised by the Core when the SAME TURN's extra BP
	-- begins. No skipped Draw/Standby/Main Phases or opponent turns.
	local summon=Effect.CreateEffect(e:GetHandler())
	summon:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	summon:SetCode(EVENT_PHASE_START+PHASE_BATTLE_START)
	summon:SetCountLimit(1)
	summon:SetOperation(s.redeploy)
	summon:SetReset(RESET_PHASE+PHASE_END+RESET_SELF_TURN,2)
	Duel.RegisterEffect(summon,tp)
end
function s.attack_limit(e,c)
	return not s.eligible(c)
end
function s.redeploy(e,tp,eg,ep,ev,re,r,rp)
	local turn=Duel.GetTurnCount()
	local g=Duel.GetMatchingGroup(s.leftfield,tp,
		LOCATION_DECK|LOCATION_HAND|LOCATION_GRAVE|LOCATION_REMOVED|LOCATION_EXTRA,
		0,nil,tp,turn)
	for tc in g:Iter() do
		if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then break end
		local position=tc:GetPreviousPosition()
		if Duel.MoveToField(tc,tp,tp,LOCATION_MZONE,position,true) then
			-- The original anime script explicitly raised these events.
			-- They allow relevant summon-triggered effects to resolve.
			Duel.RaiseSingleEvent(tc,EVENT_SPSUMMON_SUCCESS,e,REASON_RULE,tp,tp,0)
			Duel.RaiseEvent(tc,EVENT_SPSUMMON_SUCCESS,e,REASON_RULE,tp,tp,0)
			tc:SetStatus(STATUS_SUMMON_TURN,true)
		end
	end
end
