--邪龍復活の儀式
--Dragon Revival Ritual (Anime) - Big Five immediate five-master Ritual
local s,id=GetID()
local FHD_ANIME=511013020

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

-- Exactly the five Deck Masters used as Ritual materials; no attribute or
-- five-turn accumulation is required.
s.listed_names={
	FHD_ANIME,153000020,153000021,153000022,153000023,153000024
}

function s.logical_player(tp)
	if Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0 then
		return Duel.GetLogicalPlayer(tp) or tp
	end
	return tp
end

function s.fhdfilter(c,e,tp)
	return c:IsCode(FHD_ANIME)
		and c:IsCanBeSpecialSummoned(e,SUMMON_TYPE_RITUAL,tp,true,true)
end

function s.fhdgroup(e,tp,logical)
	-- The team has two or three PRIVATE Decks and Hands. Select only from
	-- the Ritual's actual logical owner; never borrow a teammate's FHD.
	if Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0 then
		return Duel.GetPlayerFieldGroup(logical,LOCATION_HAND|LOCATION_DECK)
			:Filter(s.fhdfilter,nil,e,tp)
	end
	return Duel.GetMatchingGroup(s.fhdfilter,tp,
		LOCATION_HAND|LOCATION_DECK,0,nil,e,tp)
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local logical=s.logical_player(tp)
	if chk==0 then
		return DeckMaster and DeckMaster.CanCallDragonRevivalMasters
			and DeckMaster.CanCallDragonRevivalMasters(logical,e)
			and #s.fhdgroup(e,tp,logical)>0
	end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,6,tp,
		LOCATION_HAND|LOCATION_DECK)
	Duel.SetOperationInfo(0,CATEGORY_RELEASE,nil,5,tp,LOCATION_MZONE)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
	if not DeckMaster or not DeckMaster.CallDragonRevivalMasters then return end
	local logical=s.logical_player(tp)
	local choices=s.fhdgroup(e,tp,logical)
	if #choices==0 or not DeckMaster.CanCallDragonRevivalMasters(logical,e) then
		return
	end

	-- 1: Select the ORIGINAL FHD in this player's Hand or Deck.
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local fhd=choices:Select(tp,1,1,nil):GetFirst()
	if not fhd then return end

	-- 2: Put Jinzo, Deepsea Warrior, Nightmare Penguin, Judge Man and
	-- Robotic Knight on the field, taking any real Deck Master Zone copy
	-- first and creating only missing monsters from outside the Duel.
	local five=DeckMaster.CallDragonRevivalMasters(logical,e)
	if not five or #five~=5 then
		DeckMaster.FinishDragonRevival(logical,false)
		return
	end

	-- 3: Tribute those exact five summoned monsters immediately.
	fhd:SetMaterial(five)
	local released=Duel.Release(
		five,REASON_EFFECT|REASON_MATERIAL|REASON_RITUAL)
	if released~=5 then
		DeckMaster.FinishDragonRevival(logical,false)
		return
	end

	-- 4: Ritual Summon the ORIGINAL FHD onto the Monster Zone.
	-- It inherits the Deck Master role on FIELD ONLY. This code never
	-- creates an FHD token or moves FHD into the Deck Master Zone.
	local res=Duel.SpecialSummon(
		fhd,SUMMON_TYPE_RITUAL,tp,tp,true,true,POS_FACEUP)
	if res>0 then fhd:CompleteProcedure() end
	DeckMaster.FinishDragonRevival(logical,res>0,res>0 and fhd or nil)
end
