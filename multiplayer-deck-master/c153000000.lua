--Deck Master System
--Independent logical-player implementation for normal duels, 2v1 and 3v1
local s,id=GetID()

function s.initial_effect(c)
	--Loaded by Virtual World (153999999).
end

if not DeckMaster then
	DeckMaster={}
	DeckMaster.Abilities={}
	DeckMaster.TeamLossProtected={}
	DeckMaster.TeamSharedCode={}
	DeckMaster.TeamSharedOwner={}
	DeckMaster.TeamSharedCard={}
	DeckMaster.TeamSharedMode=false
	DeckMaster.DragonRevivalEnabled=false
	DeckMasterZone={}
	FLAG_DECK_MASTER=id
	local TEAM_SHARED_DECK_MASTERS={
		[13722870]=true,   --Dark Flare Knight
		[120000336]=true, --Mirage Knight (Anime custom)
		[49217579]=true   --Mirage Knight
	}

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
	local function is_team_vs_solo_mode()
		if Duel.GetActiveLogicalPlayerMask()==0 then return false end
		local side0,side1=0,0
		for p=0,3 do
			local side=Duel.GetLogicalPlayerSide(p)
			if side==0 then side0=side0+1
			elseif side==1 then side1=side1+1 end
		end
		return side0>=2 and side1==1
	end
	local function is_shared_code(code)
		return code and TEAM_SHARED_DECK_MASTERS[code] or false
	end
	function DeckMaster.EnableTeamSharedDeckMasterMode()
		DeckMaster.TeamSharedMode=is_team_vs_solo_mode()
		return DeckMaster.TeamSharedMode
	end
	local function team_shared_enabled_for(p)
		return DeckMaster.TeamSharedMode and is_team_vs_solo_mode() and player_side(p)==0
	end
	local function mark_team_shared_master(p,c,code)
		if not team_shared_enabled_for(p) then return false end
		code=code or (c and c:GetOriginalCode())
		if not is_shared_code(code) then return false end
		local side=player_side(p)
		DeckMaster.TeamLossProtected[side]=true
		DeckMaster.TeamSharedCode[side]=code
		DeckMaster.TeamSharedOwner[side]=p
		if c then DeckMaster.TeamSharedCard[side]=c end
		return true
	end
	local function shared_master_for(p)
		if not team_shared_enabled_for(p) then return nil end
		local side=player_side(p)
		if not DeckMaster.TeamSharedCode[side] then return nil end
		local remembered=DeckMaster.TeamSharedCard[side]
		if remembered then return remembered end
		for q=0,3 do
			if player_side(q)==side then
				local dm=DeckMasterZone[q]
				if dm and is_shared_code(dm:GetOriginalCode()) then
					DeckMaster.TeamSharedCard[side]=dm
					return dm
				end
			end
		end
		return nil
	end

	DeckMaster.DragonRevivalDeckMasters={
		{field_code=153000020,zone_codes={153000020,153000013}}, --Jinzo
		{field_code=153000021,zone_codes={153000021,153000003}}, --Deepsea Warrior
		{field_code=153000022,zone_codes={153000022,153000005}}, --Nightmare Penguin
		{field_code=153000023,zone_codes={153000023,153000008}}, --Judge Man
		{field_code=153000024,zone_codes={153000024,153000009}}  --Robotic Knight
	}

	function DeckMaster.EnableDragonRevivalRitual()
		DeckMaster.DragonRevivalEnabled=true
	end

	function DeckMaster.MakeFieldDeckMaster(c,p,advertise)
		if not c then return false end
		p=p or c:GetLogicalControler()
		c:RegisterFlagEffect(FLAG_DECK_MASTER,
			RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_CONTROL,
			EFFECT_FLAG_CLIENT_HINT,1,nil,aux.Stringid(FLAG_DECK_MASTER,0))
		if advertise~=false and Duel.GetActiveLogicalPlayerMask()~=0 then
			Duel.SetDeckMasterPlayerState(p,c:GetOriginalCode(),true)
		end
		return true
	end

	local function matches_dragon_revival_zone_code(dm,entry)
		if not dm then return false end
		for _,code in ipairs(entry.zone_codes) do
			if dm:IsOriginalCode(code) then return true end
		end
		return false
	end

	local function find_dragon_revival_zone_master(entry,side)
		for p=0,3 do
			if player_side(p)==side then
				local dm=DeckMasterZone[p]
				if matches_dragon_revival_zone_code(dm,entry) then
					return p,dm
				end
			end
		end
		return nil,nil
	end

	function DeckMaster.CanSummonDragonRevivalMasters(p,e)
		if not DeckMaster.DragonRevivalEnabled then return true end
		local side=player_side(p)
		if side~=0 and side~=1 then return false end
		if Duel.GetLocationCount(side,LOCATION_MZONE)<5 then return false end
		for _,entry in ipairs(DeckMaster.DragonRevivalDeckMasters) do
			local _,dm=find_dragon_revival_zone_master(entry,side)
			if dm and not dm:IsCanBeSpecialSummoned(e,0,side,true,false) then
				return false
			end
		end
		return true
	end

	local function summon_dragon_revival_master(entry,p,e)
		local side=player_side(p)
		local zone_owner,dm=find_dragon_revival_zone_master(entry,side)
		local summon_owner=zone_owner or p
		if not dm then
			dm=Duel.CreateTokenPlayer(p,entry.field_code)
		end
		if not dm or Duel.GetLocationCount(side,LOCATION_MZONE)<=0
				or not dm:IsCanBeSpecialSummoned(e,0,side,true,false) then
			return 0
		end
		if zone_owner then
			Duel.ClearDeckMasterZonePlayer(zone_owner)
		end
		local res=Duel.SpecialSummon(dm,0,side,side,true,false,POS_FACEUP_ATTACK)
		if res>0 then
			DeckMaster.MakeFieldDeckMaster(dm,summon_owner,false)
		end
		return res
	end

	function DeckMaster.SummonDragonRevivalMasters(p,e)
		if not DeckMaster.DragonRevivalEnabled then return 0 end
		if not DeckMaster.CanSummonDragonRevivalMasters(p,e) then return 0 end
		local ct=0
		for _,entry in ipairs(DeckMaster.DragonRevivalDeckMasters) do
			ct=ct+summon_dragon_revival_master(entry,p,e)
		end
		return ct
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
		dm=get_player_cards(p,LOCATION_MZONE):Filter(Card.IsLogicalDeckMaster,nil,p):GetFirst()
		if dm then return dm end
		return shared_master_for(p)
	end
	function Duel.GetDeckMaster(p)
		return Duel.GetDeckMasterPlayer(resolve_player(p))
	end
	function Duel.IsDeckMasterPlayer(p,code)
		local dm=Duel.GetDeckMasterPlayer(p)
		if dm and dm:IsOriginalCode(code) then return true end
		return team_shared_enabled_for(p)
			and DeckMaster.TeamSharedCode[player_side(p)]==code
	end
	function Duel.IsDeckMaster(p,code)
		return Duel.IsDeckMasterPlayer(resolve_player(p),code)
	end

	function Card.MoveToDeckMasterZone(c,p,known_code)
		p=p or c:GetLogicalOwner()
		mark_team_shared_master(p,c,known_code)
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
		local ignore_condition=TEAM_SHARED_DECK_MASTERS[c:GetOriginalCode()] or false
		Duel.ClearDeckMasterZonePlayer(p)
		local res=Duel.SpecialSummon(c,0,side,side,ignore_condition,false,POS_FACEUP)
		if res>0 and ignore_condition then c:CompleteProcedure() end
		mark_team_shared_master(p,c,c:GetOriginalCode())
		DeckMaster.MakeFieldDeckMaster(c,p,false)
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
					--The handler remains c, so the 3v1 client routes every prompt
					--and chain opportunity to this Deck Master's logical owner.
					Duel.RegisterEffect(eff:Clone(),c:GetOwner())
				end
			end
			e:Reset()
		end)
		Duel.RegisterEffect(e0,0)
	end

	function DeckMaster.RegisterRules(c)
		for p=0,3 do
			if is_active_player(p) then
				local dmc=Duel.SelectCardsFromCodesPlayer(
					p,1,1,false,false,table.unpack(DeckMasterTableSelect))
				local side=player_side(p)
				--Register the shared team identity directly from the selected code.
				if team_shared_enabled_for(p) and is_shared_code(dmc) then
					DeckMaster.TeamLossProtected[side]=true
					DeckMaster.TeamSharedCode[side]=dmc
					DeckMaster.TeamSharedOwner[side]=p
				end
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
				t:MoveToDeckMasterZone(p,dmc)

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

		--Losing a Deck Master eliminates only that logical player in 3v1.
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
		local ignore_condition=dm and TEAM_SHARED_DECK_MASTERS[dm:GetOriginalCode()] or false
		return Duel.IsMainPhase() and is_active_player(p) and dm
			and dm:IsCanBeSpecialSummoned(e,0,side,ignore_condition,false)
			and Duel.GetLocationCount(side,LOCATION_MZONE)>0
	end
	function DeckMaster.spop(e,tp,eg,ep,ev,re,r,rp)
		local p=e:GetLabel()
		if not Duel.SelectYesNo(player_side(p),aux.Stringid(FLAG_DECK_MASTER,5)) then return end
		Duel.SummonDeckMasterPlayer(p)
	end

	function DeckMaster.inheritcon1(e,tp,eg,ep,ev,re,r,rp)
		return eg:IsExists(Card.IsDeckMaster,1,nil)
	end
	function DeckMaster.inheritop1(e,tp,eg,ep,ev,re,r,rp)
		local g=eg:Filter(Card.IsDeckMaster,nil)
		for tc in aux.Next(g) do
			if tc:GetReason()&REASON_BATTLE==0 and tc:GetReasonCard() then
				local rc=tc:GetReasonCard()
				rc:RegisterFlagEffect(FLAG_DECK_MASTER,
					RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_CONTROL,
					EFFECT_FLAG_CLIENT_HINT,1,nil,aux.Stringid(FLAG_DECK_MASTER,0))
				mark_team_shared_master(rc:GetLogicalControler(),rc,rc:GetOriginalCode())
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
		for p=0,3 do
			if is_active_player(p) then
				local dg=g:Filter(function(c,lp)
					return c:GetLogicalControler()==lp
				end,nil,p)
				if #dg>0 then
					local dm=dg:GetFirst()
					dm:RegisterFlagEffect(FLAG_DECK_MASTER,
						RESET_EVENT+RESETS_STANDARD-RESET_TOFIELD+RESET_CONTROL,
						EFFECT_FLAG_CLIENT_HINT,1,nil,aux.Stringid(FLAG_DECK_MASTER,0))
					mark_team_shared_master(p,dm,dm:GetOriginalCode())
				end
			end
		end
	end

	function DeckMaster.loss(e,tp,eg,ep,ev,re,r,rp)
		if Duel.GetActiveLogicalPlayerMask()~=0 then
			local lost={}
			local active_allies,active_solo=0,0
			local surviving_allies,surviving_solo=0,0
			for p=0,3 do
				if Duel.IsLogicalPlayerActive(p) then
					local side=player_side(p)
					local shared_team_master=side==0
						and DeckMaster.TeamSharedMode
						and DeckMaster.TeamSharedCode[side]~=nil
					local has_dm=shared_team_master or Duel.GetDeckMasterPlayer(p)~=nil
					if side==0 then
						active_allies=active_allies+1
						if has_dm then surviving_allies=surviving_allies+1 end
					elseif side==1 then
						active_solo=active_solo+1
						if has_dm then surviving_solo=surviving_solo+1 end
					end
					if not has_dm then lost[#lost+1]=p end
				end
			end
			if #lost==0 then return end
			--If a single resolving event removes the last Deck Master from both
			--teams, preserve the original simultaneous-loss draw.
			if active_allies>0 and active_solo>0
				and surviving_allies==0 and surviving_solo==0 then
				Duel.Win(PLAYER_NONE,WIN_REASON_DECK_MASTER)
				return
			end
			--Resolve the solo player's loss first. If an ally still owns a Deck
			--Master this ends the duel immediately in the allied team's favor.
			for _,p in ipairs(lost) do
				if player_side(p)==1 then
					Duel.EliminatePlayer(p,4,WIN_REASON_DECK_MASTER)
				end
			end
			for _,p in ipairs(lost) do
				if player_side(p)==0 then
					Duel.EliminatePlayer(p,4,WIN_REASON_DECK_MASTER)
				end
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
		153000016,153000017,
		13722870,120000336,49217579
	}
	DeckMasterTable={
		153000001,153000002,153000003,153000004,153000005,
		153000006,153000007,153000008,153000009,153000010,
		153000011,153000012,153000013,153000014,153000015,
		153000016,153000017,153000018,
		13722870,120000336,49217579,
		153000020,153000021,153000022,153000023,153000024
	}
end
