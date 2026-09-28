--幻影の騎士－ミラージュ・ナイト－
--Mirage Knight (Anime)
local s,id=GetID()
local DARK_MAGICIAN=46986414
local FLAME_SWORDSMAN=45231177
function s.initial_effect(c)
	c:EnableReviveLimit()
	--Cannot be Special Summoned normally (Dark Flare Knight bypasses this condition)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetCode(EFFECT_SPSUMMON_CONDITION)
	e1:SetValue(aux.FALSE)
	c:RegisterEffect(e1)
	--Gain ATK equal to the ATK of the monster this card battles during damage calculation
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_UPDATE_ATTACK)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_ONFIELD)
	e2:SetCondition(s.atkcon)
	e2:SetValue(s.atkval)
	c:RegisterEffect(e2)
	--After the Battle Phase, if this card battled: you can banish it, then revive
	--Dark Magician and Flame Swordsman to their respective logical owners' fields.
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_REMOVE+CATEGORY_SPECIAL_SUMMON)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e3:SetCode(EVENT_PHASE+PHASE_BATTLE)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCondition(s.rmcon)
	e3:SetTarget(s.rmtg)
	e3:SetOperation(s.rmop)
	c:RegisterEffect(e3)
end
s.listed_names={DARK_MAGICIAN,FLAME_SWORDSMAN}
function s.atkcon(e)
	return e:GetHandler():IsType(TYPE_MONSTER)
		and Duel.GetCurrentPhase()==PHASE_DAMAGE_CAL
		and e:GetHandler():GetBattleTarget()
end
function s.atkval(e,c)
	local bc=e:GetHandler():GetBattleTarget()
	return bc and bc:GetAttack() or 0
end
function s.rmcon(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	return c:IsType(TYPE_MONSTER) and c:GetBattledGroupCount()>0
end
function s.ownerteam(c)
	local lp=c:GetLogicalOwner()
	local side=Duel.GetLogicalPlayerSide(lp)
	return side~=nil and side or c:GetOwner()
end
function s.teamgrave(code,side,e)
	if Duel.GetActiveLogicalPlayerMask()==0 then
		return Duel.GetMatchingGroup(function(c,code,e,side)
			return c:IsCode(code) and c:IsCanBeSpecialSummoned(e,0,side,false,false)
		end,side,LOCATION_GRAVE,0,nil,code,e,side)
	end
	local g=Group.CreateGroup()
	for p=0,3 do
		if Duel.GetLogicalPlayerSide(p)==side then
			local pg=Duel.GetPlayerFieldGroup(p,LOCATION_GRAVE)
			local fg=pg:Filter(function(c,code,e,side)
				return c:IsCode(code) and c:IsCanBeSpecialSummoned(e,0,side,false,false)
			end,nil,code,e,side)
			g:Merge(fg)
		end
	end
	return g
end
function s.rmtg(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	local side=s.ownerteam(c)
	if chk==0 then
		if not c:IsAbleToRemove() or Duel.IsPlayerAffectedByEffect(side,CARD_BLUEEYES_SPIRIT) then return false end
		return #s.teamgrave(DARK_MAGICIAN,side,e)>0 and #s.teamgrave(FLAME_SWORDSMAN,side,e)>0
	end
	Duel.SetOperationInfo(0,CATEGORY_REMOVE,c,1,0,0)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,2,side,LOCATION_GRAVE)
end
function s.summon_to_true_owner(tc,e)
	if not tc then return 0 end
	local lp=tc:GetLogicalOwner()
	local side=Duel.GetLogicalPlayerSide(lp)
	if side==nil then side=tc:GetOwner() end
	return Duel.SpecialSummon(tc,0,side,side,false,false,POS_FACEUP)
end
function s.rmop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) or Duel.Remove(c,POS_FACEUP,REASON_EFFECT)==0 then return end
	local side=s.ownerteam(c)
	if Duel.IsPlayerAffectedByEffect(side,CARD_BLUEEYES_SPIRIT) then return end
	local g1=s.teamgrave(DARK_MAGICIAN,side,e)
	local g2=s.teamgrave(FLAME_SWORDSMAN,side,e)
	if #g1==0 or #g2==0 then return end
	Duel.Hint(HINT_SELECTMSG,side,HINTMSG_SPSUMMON)
	local dm=g1:Select(side,1,1,nil):GetFirst()
	Duel.Hint(HINT_SELECTMSG,side,HINTMSG_SPSUMMON)
	local fs=g2:Select(side,1,1,nil):GetFirst()
	if dm then s.summon_to_true_owner(dm,e) end
	if fs then s.summon_to_true_owner(fs,e) end
end
