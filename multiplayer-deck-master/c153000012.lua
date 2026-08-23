--レアメタル・ナイト (Deck Master)
--Super Roboyarou (Deck Master)
--Scripted by Larry126
local s,id=GetID()
function s.initial_effect(c)
	if not DeckMaster then return end
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
		if tc then Duel.SpecialSummon(tc,0,tp,tp,false,false,POS_FACEUP) end
	end
end

--Deck Master battle ability
function s.getlogicalowner(e,tp)
	local h=e:GetHandler()
	local p=h and h:GetLogicalOwner()
	return p~=nil and p or (Duel.GetLogicalPlayer(tp) or tp)
end
function s.getzonemaster(e,tp)
	local logical=s.getlogicalowner(e,tp)
	local dm=DeckMasterZone and DeckMasterZone[logical]
	if dm and dm:IsOriginalCode(id) then return dm,logical end
	return nil,logical
end
function s.is3v1()
	if Duel.GetActiveLogicalPlayerMask()==0 then return false end
	return Duel.GetLogicalPlayerSide(0)==0
		and Duel.GetLogicalPlayerSide(1)==0
		and Duel.GetLogicalPlayerSide(2)==0
		and Duel.GetLogicalPlayerSide(3)==1
end
function s.isopponentattack(e,tp)
	local a=Duel.GetAttacker()
	if not a then return false end
	local owner=s.getlogicalowner(e,tp)
	local attacker=a:GetLogicalControler()
	if attacker==nil then attacker=a:GetControler() end
	if owner==attacker then return false end
	if s.is3v1() then
		return (owner<3 and attacker==3) or (owner==3 and attacker<3)
	end
	return owner~=attacker
end
function s.haslogicalzone(logical,side)
	if Duel.GetActiveLogicalPlayerMask()~=0 then
		return Duel.GetPlayerFieldGroupCount(logical,LOCATION_MZONE)<5
	end
	return Duel.GetLocationCount(side,LOCATION_MZONE)>0
end
--Force the physical side to the exact logical owner before any summon or
--battle redirect. The patched Core implements FocusLogicalPlayer with
--field::tag_swap_to(), so P2 cannot inherit P3's currently displayed field.
function s.focuslogical(logical)
	if Duel.GetActiveLogicalPlayerMask()==0 then return true end
	if Duel.FocusLogicalPlayer then
		return Duel.FocusLogicalPlayer(logical)
	end
	--Compatibility fallback for older clients: identify the currently swapped
	--private pile and cycle TagSwap until the requested logical player is active.
	local side=Duel.GetLogicalPlayerSide(logical)
	if side==nil then return false end
	for _=1,4 do
		local g=Duel.GetFieldGroup(side,
			LOCATION_DECK|LOCATION_HAND|LOCATION_EXTRA|LOCATION_GRAVE|LOCATION_REMOVED,0)
		local tc=g:GetFirst()
		if tc and tc:GetLogicalControler()==logical then return true end
		Duel.TagSwap(side)
	end
	return false
end
function s.dmcon(e,tp,eg,ep,ev,re,r,rp)
	local dm,logical=s.getzonemaster(e,tp)
	if not dm or not s.isopponentattack(e,tp) then return false end
	local side=Duel.GetLogicalPlayerSide(logical) or tp
	return s.haslogicalzone(logical,side)
		and dm:IsCanBeSpecialSummoned(e,0,side,false,false)
		and Duel.IsDeckMasterPlayer(logical,id)
end
function s.restoredeckmaster(c,logical)
	DeckMasterZone[logical]=c
	if Duel.GetActiveLogicalPlayerMask()~=0 then
		Duel.SetDeckMasterPlayerState(logical,c:GetOriginalCode(),true)
	end
end
function s.summonfromdeckmaster(e,tp)
	local c,logical=s.getzonemaster(e,tp)
	if not c then return nil end
	if not s.focuslogical(logical) then return nil end
	local side=Duel.GetLogicalPlayerSide(logical) or tp
	if not s.haslogicalzone(logical,side) then return nil end
	Duel.ClearDeckMasterZonePlayer(logical)
	local res=Duel.SpecialSummon(c,0,side,side,false,false,POS_FACEUP_ATTACK)
	if res==0 then
		s.restoredeckmaster(c,logical)
		return nil
	end
	c:RegisterFlagEffect(FLAG_DECK_MASTER,
		RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_CONTROL,
		EFFECT_FLAG_CLIENT_HINT,1,nil,aux.Stringid(FLAG_DECK_MASTER,0))
	--A Deck Master is public after being Summoned. Explicit confirmation also
	--repairs clients that first knew this card only as a hidden private-pile card.
	Duel.ConfirmCards(0,c)
	Duel.ConfirmCards(1,c)
	return c,logical,side
end
function s.setfilter(c)
	return c:IsSpellTrap() and c:IsSSetable()
end
function s.setfromhand(logical,side)
	if Duel.GetActiveLogicalPlayerMask()==0 then
		if not Duel.IsExistingMatchingCard(s.setfilter,side,LOCATION_HAND,0,1,nil) then return end
		Duel.Hint(HINT_SELECTMSG,side,HINTMSG_SET)
		local tc=Duel.SelectMatchingCard(side,s.setfilter,side,LOCATION_HAND,0,1,1,nil):GetFirst()
		if tc then Duel.SSet(side,tc,side,false) end
		return
	end
	local g=Duel.GetPlayerFieldGroup(logical,LOCATION_HAND):Filter(s.setfilter,nil)
	if #g==0 then return end
	Duel.Hint(HINT_SELECTMSG,side,HINTMSG_SET)
	local tc=g:Select(side,1,1,nil):GetFirst()
	if tc then Duel.SSet(side,tc,side,false) end
end
function s.dmop(e,tp,eg,ep,ev,re,r,rp)
	local dm,logical=s.getzonemaster(e,tp)
	if not dm then return end
	local yes
	if Duel.GetActiveLogicalPlayerMask()~=0 then
		yes=Duel.SelectYesNoPlayer(logical,aux.Stringid(id,1))
	else
		yes=Duel.SelectYesNo(tp,aux.Stringid(id,1))
	end
	if not yes then return end
	local attacker=Duel.GetAttacker()
	if not attacker then return end
	Duel.Hint(HINT_CARD,tp,id)
	Duel.Hint(HINT_CARD,1-tp,id)
	local c,owner,side=s.summonfromdeckmaster(e,tp)
	if not c then return end
	if Duel.GetAttacker()==attacker and c:IsFaceup()
		and c:IsLocation(LOCATION_MZONE) then
		--ChangeAttackTarget records c:GetLogicalControler(), so after the owner
		--focus above battle damage is charged to P2 rather than the previously
		--displayed teammate (for example P3).
		Duel.ChangeAttackTarget(c,true)
	end
	--Set any 1 S/T from the same logical owner's hand. The summon/redirect
	--still succeeds if no S/T is available.
	s.setfromhand(owner,side)
end
