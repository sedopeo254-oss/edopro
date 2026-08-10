--Deck Master System
--Independent logical-player implementation for normal and multiplayer Duels
local s,id=GetID()

function s.initial_effect(c)
	--Loaded by Virtual World (153999999).
end

if not DeckMaster then
	DeckMaster={}
	DeckMaster.Abilities={}
	DeckMasterZone={}
	FLAG_DECK_MASTER=id

	local function active_mask()
		local mask=Duel.GetActiveLogicalPlayerMask()
		return mask~=0 and mask or 0x3
	end
	local function is_active_player(p)
		return active_mask()&(1<<p)~=0
	end
	local function resolve_player(p)
		return Duel.GetLogicalPlayer(p) or p
	end
	local function player_side(p)
		return Duel.GetLogicalPlayerSide(p) or p
	end
	local function get_player_cards(p,locations)
		if Duel.GetActiveLogicalPlayerMask()~=0 then
			return Duel.GetPlayerFieldGroup(p,locations)
		end
		return Duel.GetFieldGroup(p,locations,0)
	end

	function Card.IsDeckMaster(c)
		return c:GetFlagEffect(FLAG_DECK_MASTER)>0
	end
	function Card.IsLogicalDeckMaster(c,p)
		return c:IsDeckMaster() and c:GetLogicalControler()==p
	end

	function Duel.GetDeckMasterPlayer(p)
		local dm=DeckMasterZone[p]
		if dm then return dm end
		return get_player_cards(p,LOCATION_MZONE):Filter(Card.IsLogicalDeckMaster,nil,p):GetFirst()
	end
	function Duel.GetDeckMaster(p)
		return Duel.GetDeckMasterPlayer(resolve_player(p))
	end
	function Duel.IsDeckMasterPlayer(p,code)
		local dm=Duel.GetDeckMasterPlayer(p)
		return dm and dm:IsOriginalCode(code)
	end
	function Duel.IsDeckMaster(p,code)
		return Duel.IsDeckMasterPlayer(resolve_player(p),code)
	end

	function Card.MoveToDeckMasterZone(c,p)
		p=p or c:GetLogicalOwner()
		Duel.DisableShuffleCheck()
		Duel.SendtoDeck(c,nil,-2,REASON_RULE)
		if Duel.GetActiveLogicalPlayerMask()~=0 then
			Duel.SetDeckMasterPlayerState(p,c:GetOriginalCode(),true)
		else
			Duel.Hint(HINT_SKILL_FLIP,player_side(p),c:GetOriginalCode()|(1<<32))
		end
		DeckMasterZone[p]=c
	end
	function Duel.ClearDeckMasterZonePlayer(p)
		local c=DeckMasterZone[p]
		if not c then return end
		if Duel.GetActiveLogicalPlayerMask()~=0 then
			Duel.SetDeckMasterPlayerState(p,c:GetOriginalCode(),false)
		else
			Duel.Hint(HINT_SKILL_REMOVE,player_side(p),c:GetOriginalCode())
		end
		DeckMasterZone[p]=nil
	end
	function Duel.ClearDeckMasterZone(p)
		Duel.ClearDeckMasterZonePlayer(resolve_player(p))
	end
	function Duel.SummonDeckMasterPlayer(p)
		local c=DeckMasterZone[p]
		if not c then return false end
		local side=player_side(p)
		Duel.ClearDeckMasterZonePlayer(p)
		local res=Duel.SpecialSummon(c,0,side,side,false,false,POS_FACEUP)
		c:RegisterFlagEffect(FLAG_DECK_MASTER,
			RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_CONTROL,
			EFFECT_FLAG_CLIENT_HINT,1,nil,aux.Stringid(FLAG_DECK_MASTER,0))
		return res
	end
	function Duel.SummonDeckMaster(p)
		return Duel.SummonDeckMasterPlayer(resolve_player(p))
	end

	function DeckMaster.RegisterAbilities(c,...)
		local deck_master_effects={...}
		local e0=Effect.GlobalEffect()
		e0:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		e0:SetCode(EVENT_ADJUST)
		e0:SetOperation(function(e)
			--CreateTokenPlayer assigns owner/duelist after initial_effect, so
			--resolve the logical owner on EVENT_ADJUST rather than immediately.
			local logical=c:GetLogicalOwner()
			DeckMaster.Abilities[logical]=DeckMaster.Abilities[logical] or {}
			local card_id=c:GetOriginalCode()
			if not DeckMaster.Abilities[logical][card_id] then
				DeckMaster.Abilities[logical][card_id]=true
				for _,eff in ipairs(deck_master_effects) do
					--The handler remains c, so the multiplayer client routes every prompt
					--and chain opportunity to this Deck Master's logical owner.
					Duel.RegisterEffect(eff:Clone(),c:GetOwner())
				end
			end
			e:Reset()
		end)
		Duel.RegisterEffect(e0,0)
	end

	function DeckMaster.RegisterRules(c)
		for p=0,25 do
			if is_active_player(p) then
				local dmc=Duel.SelectCardsFromCodesPlayer(
					p,1,1,false,false,table.unpack(DeckMasterTableSelect))
				local dg=get_player_cards(p,LOCATION_ALL):Filter(Card.IsOriginalCode,nil,dmc)
				local remove_copy=#dg==3
					or (#dg>0 and Duel.SelectYesNoPlayer(
						p,aux.Stringid(FLAG_DECK_MASTER,3)))
				if remove_copy then
					--Using the logical-player group prevents another ally's copy
					--from being removed when all three share field side 0.
					Duel.SendtoDeck(dg:GetFirst(),nil,-2,REASON_RULE)
				end
				local t=Duel.CreateTokenPlayer(p,dmc)
				t:MoveToDeckMasterZone(p)

				--Each Deck Master gets its own free-chain summon effect. Its
				--handler identifies which logical teammate must receive prompts.
				local e1=Effect.CreateEffect(t)
				e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
				e1:SetCode(EVENT_FREE_CHAIN)
				e1:SetLabel(p)
				e1:SetCondition(DeckMaster.spcon)
				e1:SetOperation(DeckMaster.spop)
				Duel.RegisterEffect(e1,player_side(p))
			end
		end

		--Losing a Deck Master eliminates only that logical player.
		for _,phase in ipairs({
			PHASE_DRAW,PHASE_STANDBY,PHASE_MAIN1,
			PHASE_BATTLE_START,PHASE_MAIN2,PHASE_END
		}) do
			local e=Effect.GlobalEffect()
			e:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
			e:SetCode(EVENT_PHASE_START+phase)
			e:SetCountLimit(1)
			e:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
			e:SetOperation(DeckMaster.loss)
			Duel.RegisterEffect(e,0)
		end

		local e9=Effect.GlobalEffect()
		e9:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		e9:SetCode(EVENT_LEAVE_FIELD_P)
		e9:SetCondition(DeckMaster.inheritcon1)
		e9:SetOperation(DeckMaster.inheritop1)
		Duel.RegisterEffect(e9,0)
		for _,event in ipairs({
			EVENT_SUMMON_SUCCESS,EVENT_FLIP_SUMMON_SUCCESS,EVENT_SPSUMMON_SUCCESS
		}) do
			local e=Effect.GlobalEffect()
			e:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
			e:SetCode(event)
			e:SetCondition(DeckMaster.inheritcon2)
			e:SetOperation(DeckMaster.inheritop2)
			Duel.RegisterEffect(e,0)
		end
	end

	function DeckMaster.spcon(e,tp,eg,ep,ev,re,r,rp)
		local p=e:GetLabel()
		local dm=DeckMasterZone[p]
		local side=player_side(p)
		return Duel.IsMainPhase() and is_active_player(p) and dm
			and dm:IsCanBeSpecialSummoned(e,0,side,false,false)
			and Duel.GetLocationCount(side,LOCATION_MZONE)>0
	end
	function DeckMaster.spop(e,tp,eg,ep,ev,re,r,rp)
		local p=e:GetLabel()
		if not Duel.SelectYesNoPlayer(p,aux.Stringid(FLAG_DECK_MASTER,5)) then return end
		Duel.SummonDeckMasterPlayer(p)
	end

	function DeckMaster.inheritcon1(e,tp,eg,ep,ev,re,r,rp)
		return eg:IsExists(Card.IsDeckMaster,1,nil)
	end
	function DeckMaster.inheritop1(e,tp,eg,ep,ev,re,r,rp)
		local g=eg:Filter(Card.IsDeckMaster,nil)
		for tc in aux.Next(g) do
			if tc:GetReason()&REASON_BATTLE==0 and tc:GetReasonCard() then
				tc:GetReasonCard():RegisterFlagEffect(FLAG_DECK_MASTER,
					RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_CONTROL,
					EFFECT_FLAG_CLIENT_HINT,1,nil,aux.Stringid(FLAG_DECK_MASTER,0))
			end
		end
	end
	function DeckMaster.inheritFilter(c)
		local p=c:GetLogicalControler()
		return not Duel.GetDeckMasterPlayer(p)
			and c:GetControler()==c:GetSummonPlayer()
	end
	function DeckMaster.inheritcon2(e,tp,eg,ep,ev,re,r,rp)
		return eg:IsExists(DeckMaster.inheritFilter,1,nil)
	end
	function DeckMaster.inheritop2(e,tp,eg,ep,ev,re,r,rp)
		local g=eg:Filter(DeckMaster.inheritFilter,nil)
		for p=0,25 do
			if is_active_player(p) then
				local dg=g:Filter(function(c,lp)
					return c:GetLogicalControler()==lp
				end,nil,p)
				if #dg>0 then
					local dm=dg:GetFirst()
					dm:RegisterFlagEffect(FLAG_DECK_MASTER,
						RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_CONTROL,
						EFFECT_FLAG_CLIENT_HINT,1,nil,aux.Stringid(FLAG_DECK_MASTER,0))
				end
			end
		end
	end

	function DeckMaster.loss(e,tp,eg,ep,ev,re,r,rp)
		if Duel.GetActiveLogicalPlayerMask()~=0 then
			local lost={}
			local active=0
			for p=0,25 do
				if Duel.IsLogicalPlayerActive(p) then
					active=active+1
					local has_dm=Duel.GetDeckMasterPlayer(p)~=nil
					if not has_dm then lost[#lost+1]=p end
				end
			end
			if #lost==0 then return end
			--If one resolving event removes every remaining Deck Master, preserve
			--the simultaneous-loss draw regardless of the multiplayer format.
			if #lost==active then
				Duel.Win(PLAYER_NONE,WIN_REASON_DECK_MASTER)
				return
			end
			for _,p in ipairs(lost) do
				Duel.EliminatePlayer(p,4,WIN_REASON_DECK_MASTER)
			end
			return
		end
		local dm1=Duel.GetDeckMasterPlayer(0)
		local dm2=Duel.GetDeckMasterPlayer(1)
		if not dm1 and dm2 then
			Duel.Win(1,WIN_REASON_DECK_MASTER)
		elseif dm1 and not dm2 then
			Duel.Win(0,WIN_REASON_DECK_MASTER)
		elseif not dm1 and not dm2 then
			Duel.Win(PLAYER_NONE,WIN_REASON_DECK_MASTER)
		end
	end

	DeckMasterTableSelect={
		153000001,153000002,153000003,153000004,153000005,
		153000006,153000007,153000008,153000009,153000010,
		153000011,153000012,153000013,153000014,153000015,
		153000016,153000017
	}
	DeckMasterTable={
		153000001,153000002,153000003,153000004,153000005,
		153000006,153000007,153000008,153000009,153000010,
		153000011,153000012,153000013,153000014,153000015,
		153000016,153000017,153000018
	}
end
