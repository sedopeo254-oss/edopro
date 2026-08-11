--レアメタル・ナイト (Deck Master)
--Super Roboyarou (Deck Master)
--Scripted by Larry126
local s,id=GetID()
function s.initial_effect(c)
	if not DeckMaster then
		return
	end
	--Deck Master Effect: when an opponent declares an attack, Special Summon
	--this Deck Master in Attack Position and redirect that attack to it.
	local dme1=Effect.CreateEffect(c)
	dme1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	dme1:SetCode(EVENT_ATTACK_ANNOUNCE)
	dme1:SetCondition(s.dmcon)
	dme1:SetOperation(s.dmop)
	DeckMaster.RegisterAbilities(c,dme1)
	--fusion material
	c:EnableReviveLimit()
	Fusion.AddProcMix(c,true,true,92421852,38916461)
	--atk up
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCondition(s.atkcon)
	e1:SetValue(1000)
	c:RegisterEffect(e1)
	--spsummon
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCondition(s.spcon)
	e2:SetTarget(s.sptg)
	e2:SetOperation(s.spop)
	c:RegisterEffect(e2)
end
s.listed_names={75923050}
function s.atkcon(e)
	local ph=Duel.GetCurrentPhase()
	if not (ph==PHASE_DAMAGE or ph==PHASE_DAMAGE_CAL) then return false end
	local a=Duel.GetAttacker()
	local d=Duel.GetAttackTarget()
	return a==e:GetHandler() and d~=nil
end
function s.spcon(e,tp,eg,ep,ev,re,r,rp)
	return e:GetHandler():GetTurnID()~=Duel.GetTurnCount()
end
function s.spfilter(c,e,tp,mc)
	return c:IsCode(75923050) and Duel.GetLocationCountFromEx(tp,tp,mc,c)>0
		and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
function s.sptg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return e:GetHandler():IsAbleToExtra()
		and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_EXTRA,0,1,nil,e,tp) end
	Duel.SetOperationInfo(0,CATEGORY_TODECK,e:GetHandler(),1,0,0)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_EXTRA)
end
function s.spop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if c:IsRelateToEffect(e) and c:IsFaceup()
		and Duel.SendtoDeck(c,nil,2,REASON_EFFECT)~=0 then
		local tc=Duel.GetFirstMatchingCard(s.spfilter,tp,LOCATION_EXTRA,0,nil,e,tp)
		if tc then
			Duel.SpecialSummon(tc,0,tp,tp,false,false,POS_FACEUP)
		end
	end
end

--Deck Master battle ability
function s.getlogicalplayer(tp)
	return Duel.GetLogicalPlayer(tp) or tp
end
function s.getzonemaster(tp)
	local logical=s.getlogicalplayer(tp)
	local dm=DeckMasterZone and DeckMasterZone[logical]
	if dm and dm:IsOriginalCode(id) then
		return dm,logical
	end
	return nil,logical
end
function s.isopponentattack(tp)
	local a=Duel.GetAttacker()
	if not a then return false end
	local owner=s.getlogicalplayer(tp)
	local attacker=a:GetLogicalControler()
	local owner_side=Duel.GetLogicalPlayerSide(owner)
	local attacker_side=Duel.GetLogicalPlayerSide(attacker)
	if owner_side==nil or attacker_side==nil then
		return a:IsControler(1-tp)
	end
	return owner_side~=attacker_side
end
function s.dmcon(e,tp,eg,ep,ev,re,r,rp)
	local dm=s.getzonemaster(tp)
	return dm and s.isopponentattack(tp)
		and Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and dm:IsCanBeSpecialSummoned(e,0,tp,false,false)
		and Duel.IsDeckMaster(tp,id)
end
function s.summonfromdeckmaster(e,tp)
	local c,logical=s.getzonemaster(tp)
	if not c then return nil end
	local side=Duel.GetLogicalPlayerSide(logical) or tp
	Duel.ClearDeckMasterZonePlayer(logical)
	local res=Duel.SpecialSummon(c,0,side,side,false,false,POS_FACEUP_ATTACK)
	if res==0 then return nil end
	c:RegisterFlagEffect(FLAG_DECK_MASTER,
		RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_CONTROL,
		EFFECT_FLAG_CLIENT_HINT,1,nil,aux.Stringid(FLAG_DECK_MASTER,0))
	return c
end
function s.setfilter(c)
	return c:IsSpellTrap() and c:IsSSetable()
end
function s.setfromhand(tp)
	if not Duel.IsExistingMatchingCard(s.setfilter,tp,LOCATION_HAND,0,1,nil) then
		return
	end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SET)
	local tc=Duel.SelectMatchingCard(tp,s.setfilter,tp,LOCATION_HAND,0,1,1,nil):GetFirst()
	if tc then
		Duel.SSet(tp,tc,tp,false)
	end
end
function s.dmop(e,tp,eg,ep,ev,re,r,rp)
	if not Duel.SelectYesNo(tp,aux.Stringid(id,1)) then return end
	local attacker=Duel.GetAttacker()
	if not attacker then return end
	Duel.Hint(HINT_CARD,tp,id)
	Duel.Hint(HINT_CARD,1-tp,id)
	local c=s.summonfromdeckmaster(e,tp)
	if not c then return end
	--The second argument deliberately allows an attack aimed at another
	--logical teammate to be transferred to this newly Summoned Deck Master.
	if Duel.GetAttacker()==attacker and c:IsFaceup()
		and c:IsLocation(LOCATION_MZONE) then
		Duel.ChangeAttackTarget(c,true)
	end
	--After this Deck Master ability resolves, Set any 1 Spell/Trap from hand.
	s.setfromhand(tp)
end
