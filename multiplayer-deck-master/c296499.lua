--一族の掟
--The Regulation of Tribe
--Anime/Battle Royale safe version
local s,id=GetID()
function s.initial_effect(c)
	--Activate and declare 1 monster Race (old card text says Type).
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--Maintain: Tribute 1 monster during each of your Standby Phases or destroy this card.
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e2:SetCode(EVENT_PHASE|PHASE_STANDBY)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCountLimit(1)
	e2:SetCondition(s.mtcon)
	e2:SetOperation(s.mtop)
	c:RegisterEffect(e2)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RACE)
	local rc=Duel.AnnounceRace(tp,1,RACE_ALL)
	e:SetLabel(rc)
	e:GetHandler():SetHint(CHINT_RACE,rc)
end
function s.cardmatches(c,rc)
	return rc~=0 and c:IsMonster() and (c:GetRace()&rc)~=0
end
function s.atktarget(e,c)
	local h=e:GetHandler()
	return h and h:IsFaceup() and not h:IsDisabled()
		and s.cardmatches(c,e:GetLabel())
end
function s.attackop(e,tp,eg,ep,ev,re,r,rp)
	local h=e:GetHandler()
	if not h or not h:IsFaceup() or h:IsDisabled() then return end
	local a=Duel.GetAttacker()
	if a and s.cardmatches(a,e:GetLabel()) then
		Duel.NegateAttack()
	end
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) then return end
	local rc=e:GetLabel()
	if rc==0 then return end
	--Persistent attack lock. Store the declared Race directly on this effect;
	--do not depend on the activation effect's label after its chain resolves.
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CANNOT_ATTACK)
	e1:SetRange(LOCATION_SZONE)
	e1:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e1:SetTarget(s.atktarget)
	e1:SetLabel(rc)
	c:RegisterEffect(e1)
	--Battle-announcement safety net for multiplayer and for an attack already
	--in progress when this card resolves.
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_ATTACK_ANNOUNCE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetLabel(rc)
	e2:SetOperation(s.attackop)
	c:RegisterEffect(e2)
	local a=Duel.GetAttacker()
	if a and s.cardmatches(a,rc) then
		Duel.NegateAttack()
	end
end
function s.mtcon(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsTurnPlayer(tp)
end
function s.mtop(e,tp,eg,ep,ev,re,r,rp)
	if Duel.CheckReleaseGroupCost(tp,Card.IsReleasable,1,false,nil,nil)
		and Duel.SelectYesNo(tp,aux.Stringid(id,0)) then
		local g=Duel.SelectReleaseGroupCost(tp,Card.IsReleasable,1,1,false,nil,nil)
		Duel.Release(g,REASON_COST)
	else
		Duel.Destroy(e:GetHandler(),REASON_COST)
	end
end
