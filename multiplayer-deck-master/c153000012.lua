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
function s.getlogicalowner(e,tp)
	local h=e:GetHandler()
	local p=h and h:GetLogicalOwner()
	return p~=nil and p or (Duel.GetLogicalPlayer(tp) or tp)
end
function s.getzonemaster(e,tp)
	local logical=s.getlogicalowner(e,tp)
	local dm=DeckMasterZone and DeckMasterZone[logical]
	if dm and dm:IsOriginalCode(id) then
		return dm,logical
	end
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

--Duel.SpecialSummon uses the currently focused teammate field on a shared
--physical side. Identify that field from any card physically visible in its
--local zones, then rotate TagSwap until the Deck Master's logical owner is the
--focused duelist. This prevents P2's Deck Master from appearing on P3's field.
local scan_locations={LOCATION_MZONE,LOCATION_SZONE,LOCATION_HAND,LOCATION_DECK,LOCATION_EXTRA,LOCATION_GRAVE,LOCATION_REMOVED}
local scan_limits={7,8,100,100,100,100,100}
function s.currentlogical(side)
	for i,loc in ipairs(scan_locations) do
		for seq=0,scan_limits[i]-1 do
			local tc=Duel.GetFieldCard(side,loc,seq)
			if tc then
				local p=tc:GetLogicalControler()
				if p~=nil then return p end
			end
		end
	end
	return nil
end
function s.players_on_side(side)
	local mask=Duel.GetActiveLogicalPlayerMask()
	local ct=0
	for p=0,3 do
		if mask&(1<<p)~=0 and Duel.GetLogicalPlayerSide(p)==side then
			ct=ct+1
		end
	end
	return ct
end
function s.focuslogical(logical)
	local side=Duel.GetLogicalPlayerSide(logical)
	if side==nil or Duel.GetActiveLogicalPlayerMask()==0 then
		return side or logical
	end
	local peers=s.players_on_side(side)
	if peers<=1 then return side end
	for _=1,peers do
		if s.currentlogical(side)==logical then
			return side
		end
		Duel.TagSwap(side)
	end
	--One final check after a complete cycle. If every zone of a duelist is
	--empty, the identity cannot be inferred from a card; keep the last valid
	--shared side rather than touching another player's field data directly.
	return side
end
function s.dmcon(e,tp,eg,ep,ev,re,r,rp)
	local dm,logical=s.getzonemaster(e,tp)
	if not dm or not s.isopponentattack(e,tp) then return false end
	local side=Duel.GetLogicalPlayerSide(logical) or tp
	return dm:IsCanBeSpecialSummoned(e,0,side,false,false)
		and Duel.IsDeckMasterPlayer(logical,id)
end
function s.summonfromdeckmaster(e,tp)
	local c,logical=s.getzonemaster(e,tp)
	if not c then return nil end
	local side=s.focuslogical(logical)
	if side==nil or Duel.GetLocationCount(side,LOCATION_MZONE)<=0 then return nil end
	Duel.ClearDeckMasterZonePlayer(logical)
	local res=Duel.SpecialSummon(c,0,side,side,false,false,POS_FACEUP_ATTACK)
	if res==0 then
		--Restore the Deck Master zone state if the Summon unexpectedly fails.
		DeckMasterZone[logical]=c
		if Duel.GetActiveLogicalPlayerMask()~=0 then
			Duel.SetDeckMasterPlayerState(logical,c:GetOriginalCode(),true)
		end
		return nil
	end
	c:RegisterFlagEffect(FLAG_DECK_MASTER,
		RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_CONTROL,
		EFFECT_FLAG_CLIENT_HINT,1,nil,aux.Stringid(FLAG_DECK_MASTER,0))
	return c,logical,side
end
function s.setfilter(c)
	return c:IsSpellTrap() and c:IsSSetable()
end
function s.setfromhand(side)
	if not Duel.IsExistingMatchingCard(s.setfilter,side,LOCATION_HAND,0,1,nil) then
		return
	end
	Duel.Hint(HINT_SELECTMSG,side,HINTMSG_SET)
	local tc=Duel.SelectMatchingCard(side,s.setfilter,side,LOCATION_HAND,0,1,1,nil):GetFirst()
	if tc then
		Duel.SSet(side,tc,side,false)
	end
end
function s.dmop(e,tp,eg,ep,ev,re,r,rp)
	if not Duel.SelectYesNo(tp,aux.Stringid(id,1)) then return end
	local attacker=Duel.GetAttacker()
	if not attacker then return end
	Duel.Hint(HINT_CARD,tp,id)
	Duel.Hint(HINT_CARD,1-tp,id)
	local c,logical,side=s.summonfromdeckmaster(e,tp)
	if not c then return end
	--The second argument deliberately allows an attack aimed at another
	--logical teammate to be transferred to this newly Summoned Deck Master.
	if Duel.GetAttacker()==attacker and c:IsFaceup()
		and c:IsLocation(LOCATION_MZONE) then
		Duel.ChangeAttackTarget(c,true)
	end
	--After this Deck Master ability resolves, Set any 1 Spell/Trap from the
	--same logical owner's hand. No S/T is required for the Summon/redirect.
	s.setfromhand(side)
end
