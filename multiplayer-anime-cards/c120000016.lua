--邪龍復活の儀式
--Dragon Revival Ritual (Anime) - simplified Big Five version
local s,id=GetID()
local FHD_ANIME=511013020
local FHD=99267150

function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_RELEASE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end

s.listed_names={
	FHD_ANIME,FHD,
	153000020,153000021,153000022,153000023,153000024,
	153000013,153000003,153000005,153000008,153000009
}

function s.logical_player(tp)
	if Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0 then
		return Duel.GetLogicalPlayer(tp) or tp
	end
	return tp
end

function s.fhdfilter(c,e,tp)
	return c:IsCode(FHD_ANIME,FHD)
		and c:IsCanBeSpecialSummoned(e,SUMMON_TYPE_RITUAL,tp,true,true)
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local logical=s.logical_player(tp)
	if chk==0 then
		return DeckMaster and DeckMaster.CanCallDragonRevivalMasters
			and DeckMaster.CanCallDragonRevivalMasters(logical,e)
			and Duel.IsExistingMatchingCard(
				s.fhdfilter,tp,LOCATION_HAND|LOCATION_DECK,0,1,nil,e,tp)
	end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,6,tp,
		LOCATION_HAND|LOCATION_DECK)
	Duel.SetOperationInfo(0,CATEGORY_RELEASE,nil,5,tp,LOCATION_MZONE)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
	if not DeckMaster or not DeckMaster.CallDragonRevivalMasters then return end
	local logical=s.logical_player(tp)
	local five=DeckMaster.CallDragonRevivalMasters(logical,e)
	if not five or #five~=5 then return end

	if not Duel.IsExistingMatchingCard(
		s.fhdfilter,tp,LOCATION_HAND|LOCATION_DECK,0,1,nil,e,tp) then
		return
	end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local fhd=Duel.SelectMatchingCard(
		tp,s.fhdfilter,tp,LOCATION_HAND|LOCATION_DECK,0,1,1,nil,e,tp):GetFirst()
	if not fhd then return end

	fhd:SetMaterial(five)
	local released=Duel.Release(
		five,REASON_EFFECT|REASON_MATERIAL|REASON_RITUAL)
	if released~=5 then return end

	--No DeckMaster.MakeFieldDeckMaster / SetDeckMasterPlayerState here.
	--Five-Headed Dragon only exists on the field, never as a duplicated DM icon.
	if Duel.SpecialSummon(
		fhd,SUMMON_TYPE_RITUAL,tp,tp,true,true,POS_FACEUP)>0 then
		fhd:CompleteProcedure()
	end
end
