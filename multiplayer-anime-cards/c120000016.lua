--邪龍復活の儀式
--Dragon Revival Ritual (Anime) - simplified Big Five version
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

s.listed_names={
	FHD_ANIME,
	153000020,153000021,153000022,153000023,153000024,
	153000013,153000003,153000005,153000008,153000009
}

function s.logical_player(e,tp)
	if Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0 then
		-- The Spell's actual owner is authoritative for a 2v1/3v1
		-- private Deck/Hand, even during another player's field focus.
		local c=e and e.GetHandler and e:GetHandler()
		if c and c.GetLogicalOwner then return c:GetLogicalOwner() end
		return Duel.GetLogicalPlayer(tp) or tp
	end
	return tp
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local logical=s.logical_player(e,tp)
	if chk==0 then
		-- Activation legality is resolved by c153000000.lua, which knows
		-- the REAL logical player's Deck Master Zone and private Deck/Hand.
		return DeckMaster and DeckMaster.CanActivateDragonRevivalRitual
			and DeckMaster.CanActivateDragonRevivalRitual(logical,e)
	end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,6,tp,
		LOCATION_HAND|LOCATION_DECK)
	Duel.SetOperationInfo(0,CATEGORY_RELEASE,nil,5,tp,LOCATION_MZONE)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
	if not DeckMaster or not DeckMaster.CallDragonRevivalMasters
		or not DeckMaster.GetDragonRevivalTargets then return end
	local logical=s.logical_player(e,tp)

	-- Select the real FHD from THIS logical player's own Deck/Hand.
	-- Do not filter it through IsCanBeSpecialSummoned before the five
	-- Deck Masters have entered the field and become Ritual materials.
	local choices=DeckMaster.GetDragonRevivalTargets(logical)
	if #choices==0 or not DeckMaster.CanCallDragonRevivalMasters(logical,e) then
		return
	end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local fhd=choices:Select(tp,1,1,nil):GetFirst()
	if not fhd then return end

	local five=DeckMaster.CallDragonRevivalMasters(logical,e)
	if not five or #five~=5 then
		if DeckMaster.FinishDragonRevival then
			DeckMaster.FinishDragonRevival(logical,false)
		end
		return
	end

	fhd:SetMaterial(five)
	local released=Duel.Release(
		five,REASON_EFFECT|REASON_MATERIAL|REASON_RITUAL)
	if released~=5 then
		if DeckMaster.FinishDragonRevival then
			DeckMaster.FinishDragonRevival(logical,false)
		end
		return
	end

	--The inheritance lock is still active while FHD is summoned, so the client
	--never receives a Deck Master Zone copy of Five-Headed Dragon.
	local res=Duel.SpecialSummon(
		fhd,SUMMON_TYPE_RITUAL,tp,tp,true,true,POS_FACEUP)
	if res>0 then fhd:CompleteProcedure() end
	if DeckMaster.FinishDragonRevival then
		-- FHD is the successor of the five material Deck Masters.
		-- Store the real card, not a permanent exemption from losing.
		DeckMaster.FinishDragonRevival(logical,res>0,res>0 and fhd or nil)
	end
end
