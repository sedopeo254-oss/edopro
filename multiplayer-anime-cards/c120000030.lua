--Magical Hats (Anime) - Refactored / Merged Version
--Merged from clean prototype + advanced anime behavior
--Includes:
-- remain on field
-- global RegisterEffect patch
-- hidden real Spellcaster + optional extra monsters
-- Hat Tokens
-- hidden Spell/Trap as hats
-- on attack/effect target: restore real monster, move hidden S/T to SZONE and activate
-- Slifer redirect handling
-- cleanup on leave/negate

local s,id=GetID()

local HAT_TOKEN_CODE = 511005062
local SLIFER_CODE    = 10000020

-- main flags
local FLAG_CARD_ACTIVE   = id
local FLAG_REAL_MONSTER  = id+1
local FLAG_OTHER_MONSTER = id+2
local FLAG_HAT_TOKEN     = id+3
local FLAG_SETST         = id+4
local FLAG_SET_ORDER     = id+10

if not MagicalHatsAnime_HatTokenFidList then
	MagicalHatsAnime_HatTokenFidList={}
end

-- =========================================================
-- Global RegisterEffect patch
-- =========================================================
if not s.global_patch_chk then
	s.global_patch_chk=true
	local regeff=Card.RegisterEffect
	Card.RegisterEffect=function(c,e,f)
		local tc=e:GetOwner()
		if tc then
			local tg=e:GetTarget()
			if tg then
				if c35803249 and tg==c35803249.distg then
					e:SetTargetRange(LOCATION_ONFIELD,LOCATION_ONFIELD)
				elseif c51452091 and tg==c51452091.distarget then
					e:SetTargetRange(LOCATION_ONFIELD,LOCATION_ONFIELD)
				elseif c77585513 and tg==c77585513.distg then
					e:SetTargetRange(LOCATION_ONFIELD,LOCATION_ONFIELD)
				elseif c84636823 and tg==c84636823.distg then
					e:SetTargetRange(LOCATION_ONFIELD,LOCATION_ONFIELD)
				end
			end
		end
		return regeff(c,e,f)
	end
end

-- =========================================================
-- Init
-- =========================================================
function s.initial_effect(c)
	-- Activate / remain
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOKEN)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)

	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_SINGLE)
	e0:SetCode(EFFECT_REMAIN_FIELD)
	c:RegisterEffect(e0)

	-- self destroy if core hidden monster no longer maintained
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e2:SetRange(LOCATION_ONFIELD)
	e2:SetCode(EFFECT_SELF_DESTROY)
	e2:SetCondition(s.selfdescon)
	c:RegisterEffect(e2)

	-- anime protection
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE)
	e3:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e3:SetRange(LOCATION_ONFIELD)
	e3:SetCode(EFFECT_IMMUNE_EFFECT)
	e3:SetValue(function(e,te) return te:GetOwner()~=e:GetOwner() end)
	c:RegisterEffect(e3)

	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_SINGLE)
	e4:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e4:SetRange(LOCATION_ONFIELD)
	e4:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
	e4:SetValue(aux.tgoval)
	c:RegisterEffect(e4)

	-- once per turn: send 1 hat token to GY, set 1 S/T from hand as hidden hat
	local e5=Effect.CreateEffect(c)
	e5:SetDescription(aux.Stringid(id,0))
	e5:SetCategory(CATEGORY_TOGRAVE)
	e5:SetType(EFFECT_TYPE_IGNITION)
	e5:SetRange(LOCATION_ONFIELD)
	e5:SetCountLimit(1)
	e5:SetCost(s.stcost)
	e5:SetTarget(s.sttg)
	e5:SetOperation(s.stop)
	c:RegisterEffect(e5)

	-- attacked hidden real monster
	local e6=Effect.CreateEffect(c)
	e6:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
	e6:SetRange(LOCATION_ONFIELD)
	e6:SetCode(EVENT_BE_BATTLE_TARGET)
	e6:SetCondition(s.attacked_real_con)
	e6:SetOperation(s.reveal_and_break)
	e6:SetReset(RESET_EVENT+RESETS_STANDARD)
	c:RegisterEffect(e6)

	-- targeted hidden real monster by opponent effect
	local e7=Effect.CreateEffect(c)
	e7:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
	e7:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e7:SetRange(LOCATION_ONFIELD)
	e7:SetCode(EVENT_CHAINING)
	e7:SetCondition(s.targeted_real_con)
	e7:SetOperation(s.reveal_and_break)
	e7:SetReset(RESET_EVENT+RESETS_STANDARD)
	c:RegisterEffect(e7)

	-- hidden extra monster attacked
	local e8=Effect.CreateEffect(c)
	e8:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
	e8:SetRange(LOCATION_SZONE)
	e8:SetCode(EVENT_BATTLE_START)
	e8:SetCondition(s.attacked_fake_con)
	e8:SetOperation(s.reveal_fake_only)
	e8:SetReset(RESET_EVENT+RESETS_STANDARD)
	c:RegisterEffect(e8)

	-- hidden extra monster targeted by effect
	local e9=Effect.CreateEffect(c)
	e9:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e9:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e9:SetRange(LOCATION_ONFIELD)
	e9:SetCode(EVENT_CHAINING)
	e9:SetCondition(s.targeted_fake_con)
	e9:SetOperation(s.reveal_fake_only)
	e9:SetReset(RESET_EVENT+RESETS_STANDARD)
	c:RegisterEffect(e9)

	-- cleanup if core monster leaves
	local e10=Effect.CreateEffect(c)
	e10:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e10:SetRange(LOCATION_ONFIELD)
	e10:SetCode(EVENT_LEAVE_FIELD)
	e10:SetCondition(s.core_leave_con)
	e10:SetOperation(s.full_cleanup)
	e10:SetReset(RESET_EVENT+RESETS_STANDARD)
	c:RegisterEffect(e10)

	-- cleanup on leave field
	local e11=Effect.CreateEffect(c)
	e11:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_SINGLE)
	e11:SetCode(EVENT_LEAVE_FIELD)
	e11:SetOperation(s.full_cleanup)
	c:RegisterEffect(e11)

	-- cleanup on adjust if state broken
	local e12=Effect.CreateEffect(c)
	e12:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_FIELD)
	e12:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_REPEAT+EFFECT_FLAG_NO_TURN_RESET)
	e12:SetRange(LOCATION_ONFIELD)
	e12:SetCode(EVENT_ADJUST)
	e12:SetCondition(s.adjust_cleanup_con)
	e12:SetOperation(s.full_cleanup)
	e12:SetReset(RESET_EVENT+RESETS_STANDARD)
	c:RegisterEffect(e12)

	-- global Slifer handling
	if not s.global_monitor_slifer then
		s.global_monitor_slifer=true
		local ge1=Effect.CreateEffect(c)
		ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
		ge1:SetCode(EVENT_CHAIN_SOLVING)
		ge1:SetOperation(s.check_slifer_resolve)
		Duel.RegisterEffect(ge1,0)
	end
end

-- =========================================================
-- Helpers
-- =========================================================
function s.getfid(c)
	return c:GetFieldID()
end

function s.spellcaster_filter(c)
	return c:IsFaceup() and c:IsRace(RACE_SPELLCASTER) and not c:IsLocation(LOCATION_PZONE)
end

function s.mon_filter(c)
	return c:IsType(TYPE_MONSTER)
end

function s.is_real(c,fid)
	return c:GetFlagEffectLabel(FLAG_REAL_MONSTER)==fid
end
function s.is_other_hidden(c,fid)
	return c:GetFlagEffectLabel(FLAG_OTHER_MONSTER)==fid
end
function s.is_hat_token(c,fid)
	return c:GetFlagEffectLabel(FLAG_HAT_TOKEN)==fid
end
function s.is_setst(c,fid)
	return c:GetFlagEffectLabel(FLAG_SETST)==fid
end

function s.hidden_group(tp,fid)
	return Duel.GetMatchingGroup(function(c)
		return c:IsFacedown() and (
			s.is_real(c,fid) or
			s.is_other_hidden(c,fid) or
			s.is_hat_token(c,fid) or
			s.is_setst(c,fid)
		)
	end,tp,LOCATION_MZONE,0,nil)
end

function s.get_real(tp,fid)
	return Duel.GetMatchingGroup(function(c) return s.is_real(c,fid) end,tp,LOCATION_MZONE,0,nil):GetFirst()
end

function s.get_other_hidden_group(tp,fid)
	return Duel.GetMatchingGroup(function(c) return s.is_other_hidden(c,fid) end,tp,LOCATION_MZONE,0,nil)
end

function s.get_hat_tokens(tp,fid)
	return Duel.GetMatchingGroup(function(c) return s.is_hat_token(c,fid) end,tp,LOCATION_MZONE,0,nil)
end

--Dark Magician Deck Master: copy the already-resolved Magical Hats effect
function s.deckmaster_copy_monster_filter(c,fid)
	return c:IsFaceup() and c:IsType(TYPE_MONSTER)
		and not s.is_real(c,fid)
		and not s.is_other_hidden(c,fid)
		and not s.is_hat_token(c,fid)
end

function MagicalHatsAnime_CanDeckMasterCopy(tp,hats_card)
	if not hats_card or not hats_card:IsCode(id) or not hats_card:IsOnField() then
		return false
	end
	local fid=hats_card:GetFieldID()
	return #s.get_hat_tokens(tp,fid)>0
		and Duel.IsExistingMatchingCard(
			s.deckmaster_copy_monster_filter,tp,LOCATION_MZONE,0,1,nil,fid)
end

function MagicalHatsAnime_DeckMasterCopy(tp,source,hats_card)
	if not MagicalHatsAnime_CanDeckMasterCopy(tp,hats_card) then return false end
	local fid=hats_card:GetFieldID()
	local hats=s.get_hat_tokens(tp,fid)
	local hat=hats:GetFirst()
	if not hat then return false end
	Duel.SendtoGrave(hat,REASON_RULE)

	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_POSCHANGE)
	local tc=Duel.SelectMatchingCard(
		tp,s.deckmaster_copy_monster_filter,tp,LOCATION_MZONE,0,1,1,nil,fid):GetFirst()
	if not tc then return false end

	Duel.ChangePosition(tc,POS_FACEDOWN_DEFENSE)
	s.store_prev_position(tc,hats_card,fid,FLAG_OTHER_MONSTER)
	local gs=s.hidden_group(tp,fid)
	if #gs>1 then Duel.ShuffleSetCard(gs) end
	return true
end

function s.get_hidden_setst_mzone(tp,fid)
	return Duel.GetMatchingGroup(function(c) return s.is_setst(c,fid) end,tp,LOCATION_MZONE,0,nil)
end

function s.get_hidden_setst_ordered(tp,fid)
	local g=s.get_hidden_setst_mzone(tp,fid)
	local cards={}
	for tc in aux.Next(g) do
		local ord=tc:GetFlagEffectLabel(FLAG_SET_ORDER) or 99
		table.insert(cards,{card=tc,order=ord})
	end
	table.sort(cards,function(a,b) return a.order<b.order end)
	return cards
end

function s.store_prev_position(c,handler,fid,flagcode)
	local e1=Effect.CreateEffect(handler)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_CHANGE_TYPE)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e1:SetValue(TYPE_TOKEN)
	e1:SetLabel(fid)
	e1:SetCondition(s.face_down_cond)
	e1:SetReset(RESET_EVENT+RESETS_STANDARD)
	c:RegisterEffect(e1)

	local e2=e1:Clone()
	e2:SetCode(EFFECT_REMOVE_RACE)
	e2:SetValue(RACE_ALL)
	c:RegisterEffect(e2)

	local e3=e1:Clone()
	e3:SetCode(EFFECT_REMOVE_ATTRIBUTE)
	e3:SetValue(0xff)
	c:RegisterEffect(e3)

	local e4=e1:Clone()
	e4:SetCode(EFFECT_SET_BASE_ATTACK)
	e4:SetValue(0)
	c:RegisterEffect(e4)

	local e5=e1:Clone()
	e5:SetCode(EFFECT_SET_BASE_DEFENSE)
	e5:SetValue(0)
	c:RegisterEffect(e5)

	local e6=e1:Clone()
	e6:SetCode(EFFECT_CHANGE_LEVEL)
	e6:SetValue(0)
	c:RegisterEffect(e6)

	local e7=e1:Clone()
	e7:SetCode(EFFECT_UNRELEASABLE_SUM)
	e7:SetValue(1)
	c:RegisterEffect(e7)

	local e8=e7:Clone()
	e8:SetCode(EFFECT_UNRELEASABLE_NONSUM)
	c:RegisterEffect(e8)

	c:RegisterFlagEffect(flagcode,RESET_EVENT+RESETS_STANDARD,0,0,fid)
end

function s.setup_hat_token(tc,handler,fid)
	local e1=Effect.CreateEffect(handler)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_CHANGE_TYPE)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e1:SetValue(TYPE_TOKEN)
	e1:SetReset(RESET_EVENT+RESETS_STANDARD)
	tc:RegisterEffect(e1,true)

	local e2=e1:Clone()
	e2:SetCode(EFFECT_REMOVE_RACE)
	e2:SetValue(RACE_ALL)
	tc:RegisterEffect(e2,true)

	local e3=e1:Clone()
	e3:SetCode(EFFECT_REMOVE_ATTRIBUTE)
	e3:SetValue(0xff)
	tc:RegisterEffect(e3,true)

	local e4=e1:Clone()
	e4:SetCode(EFFECT_SET_BASE_ATTACK)
	e4:SetValue(0)
	tc:RegisterEffect(e4,true)

	local e5=e1:Clone()
	e5:SetCode(EFFECT_SET_BASE_DEFENSE)
	e5:SetValue(0)
	tc:RegisterEffect(e5,true)

	local e6=Effect.CreateEffect(handler)
	e6:SetType(EFFECT_TYPE_SINGLE)
	e6:SetCode(EFFECT_CANNOT_CHANGE_POSITION)
	tc:RegisterEffect(e6,true)

	local e7=e1:Clone()
	e7:SetCode(EFFECT_CANNOT_ATTACK)
	tc:RegisterEffect(e7,true)

	local e8=e1:Clone()
	e8:SetCode(EFFECT_UNRELEASABLE_SUM)
	e8:SetValue(1)
	tc:RegisterEffect(e8,true)

	local e9=e8:Clone()
	e9:SetCode(EFFECT_UNRELEASABLE_NONSUM)
	tc:RegisterEffect(e9,true)

	local e10=e1:Clone()
	e10:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e10:SetCode(EFFECT_CANNOT_BE_SYNCHRO_MATERIAL)
	e10:SetValue(1)
	tc:RegisterEffect(e10,true)

	local e11=e1:Clone()
	e11:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE)
	e11:SetCode(EFFECT_CANNOT_BE_XYZ_MATERIAL)
	e11:SetValue(1)
	tc:RegisterEffect(e11,true)

	local e12=e1:Clone()
	e12:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE)
	e12:SetCode(EFFECT_AVOID_BATTLE_DAMAGE)
	e12:SetValue(1)
	tc:RegisterEffect(e12,true)

	local e13=Effect.CreateEffect(handler)
	e13:SetCategory(CATEGORY_DESTROY)
	e13:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e13:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e13:SetCode(EVENT_FLIP)
	e13:SetOperation(function(e) Duel.Destroy(e:GetHandler(),REASON_EFFECT) end)
	e13:SetReset(RESET_EVENT+RESETS_STANDARD)
	tc:RegisterEffect(e13)

	local e14=Effect.CreateEffect(handler)
	e14:SetType(EFFECT_TYPE_SINGLE)
	e14:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL+EFFECT_FLAG_SET_AVAILABLE)
	e14:SetCode(EFFECT_SELF_DESTROY)
	e14:SetCondition(function(e)
		local c=e:GetHandler()
		local hc=e:GetLabelObject()
		local hf=e:GetLabel()
		return not Duel.IsExistingMatchingCard(function(sc)
			return sc:IsFaceup() and sc:GetFlagEffectLabel(FLAG_CARD_ACTIVE)==hf and not (sc:IsDisabled() or sc:IsStatus(STATUS_DISABLED))
		end,c:GetControler(),LOCATION_ONFIELD,0,1,nil)
	end)
	e14:SetLabelObject(handler)
	e14:SetLabel(fid)
	e14:SetReset(RESET_EVENT+RESETS_STANDARD)
	tc:RegisterEffect(e14)

	tc:SetStatus(STATUS_NO_LEVEL,true)
	tc:RegisterFlagEffect(FLAG_HAT_TOKEN,RESET_EVENT+RESETS_STANDARD,0,0,fid)
end

function s.face_down_cond(e,tp,eg,ep,ev,re,r,rp)
	return e:GetHandler():IsFacedown()
end

function s.restore_hidden_monsters(tp,fid)
	local g=Duel.GetMatchingGroup(function(c)
		return c:IsFacedown() and (s.is_real(c,fid) or s.is_other_hidden(c,fid))
	end,tp,LOCATION_MZONE,0,nil)
	for tc in aux.Next(g) do
		Duel.ChangePosition(tc,tc:GetPreviousPosition())
		if s.is_real(tc,fid) then
			tc:ResetFlagEffect(FLAG_REAL_MONSTER)
		else
			tc:ResetFlagEffect(FLAG_OTHER_MONSTER)
		end
	end
end

function s.destroy_hat_tokens(tp,fid)
	local g=Duel.GetMatchingGroup(function(c) return s.is_hat_token(c,fid) end,tp,LOCATION_MZONE,0,nil)
	if #g>0 then Duel.Destroy(g,REASON_EFFECT) end
end

function s.destroy_hidden_setst(tp,fid)
	local g=Duel.GetMatchingGroup(function(c) return s.is_setst(c,fid) end,tp,LOCATION_MZONE|LOCATION_SZONE|LOCATION_FZONE,0,nil)
	if #g>0 then Duel.Destroy(g,REASON_EFFECT) end
end

function s.hidden_state_broken(tp,fid)
	local core=s.get_real(tp,fid)
	local has4034=Duel.IsExistingMatchingCard(function(c) return s.is_setst(c,fid) end,tp,LOCATION_MZONE,0,1,nil)
	if has4034 then return false end
	return not core or not core:IsPosition(POS_FACEDOWN_DEFENSE)
end

function s.move_and_activate(tc,e,tp,eg,ep,ev,re,r,rp)
	if not tc or not tc:IsLocation(LOCATION_MZONE) or not tc:IsFacedown() then return end
	local te=tc:GetActivateEffect()
	if not te then return end

	local tpe=tc:GetOriginalType()
	local tg_func=te:GetTarget()
	local co_func=te:GetCost()
	local op_func=te:GetOperation()

	if (tpe&TYPE_FIELD)~=0 then
		Duel.MoveToField(tc,tp,tp,LOCATION_FZONE,POS_FACEUP,true)
	else
		Duel.MoveToField(tc,tp,tp,LOCATION_SZONE,POS_FACEUP,true)
	end

	e:SetCategory(te:GetCategory())
	e:SetProperty(te:GetProperty())
	Duel.ClearTargetCard()
	Duel.Hint(HINT_CARD,0,tc:GetCode())
	tc:CreateEffectRelation(te)

	if (tpe&(TYPE_EQUIP+TYPE_CONTINUOUS+TYPE_FIELD))==0 and not tc:IsHasEffect(EFFECT_REMAIN_FIELD) and not (te and te:IsHasCategory(CATEGORY_EQUIP)) then
		tc:CancelToGrave(false)
	end

	if te:GetCode()==EVENT_CHAINING then
		local chain=Duel.GetCurrentChain()-1
		local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
		local tc2=te2 and te2:GetHandler()
		if tc2 then
			local g2=Group.FromCards(tc2)
			local p=tc2:GetControler()
			if co_func then co_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
			if tg_func then tg_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
		end
	elseif te:GetCode()==EVENT_FREE_CHAIN then
		if co_func then co_func(te,tp,eg,ep,ev,re,r,rp,1) end
		if tg_func then tg_func(te,tp,eg,ep,ev,re,r,rp,1) end
	else
		local _,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
		if co_func then co_func(te,tp,teg,tep,tev,tre,tr,trp,1) end
		if tg_func then tg_func(te,tp,teg,tep,tev,tre,tr,trp,1) end
	end

	Duel.BreakEffect()
	local g=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
	if g then
		for etc in aux.Next(g) do
			etc:CreateEffectRelation(te)
		end
	end

	tc:SetStatus(STATUS_ACTIVATED,true)
	if not tc:IsDisabled() then
		if te:GetCode()==EVENT_CHAINING then
			local chain=Duel.GetCurrentChain()-1
			local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
			local tc2=te2 and te2:GetHandler()
			if tc2 then
				local g2=Group.FromCards(tc2)
				local p=tc2:GetControler()
				if op_func then op_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p) end
			end
		elseif te:GetCode()==EVENT_FREE_CHAIN then
			if op_func then op_func(te,tp,eg,ep,ev,re,r,rp) end
		else
			local _,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
			if op_func then op_func(te,tp,teg,tep,tev,tre,tr,trp) end
		end
	end

	Duel.RaiseEvent(Group.FromCards(tc),EVENT_CHAIN_SOLVED,te,0,tp,tp,Duel.GetCurrentChain())
	if g and tc:IsType(TYPE_EQUIP) and not tc:GetEquipTarget() then
		Duel.Equip(tp,tc,g:GetFirst())
	end

	tc:ReleaseEffectRelation(te)
	if g then
		for etc in aux.Next(g) do
			etc:ReleaseEffectRelation(te)
		end
	end
end

function s.resolve_hidden_setst_targets(e,tp,fid)
	local g=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
	if not g or #g==0 then return end
	local ordered=s.get_hidden_setst_ordered(tp,fid)
	for _,info in ipairs(ordered) do
		local tc=info.card
		if g:IsContains(tc) and tc:IsRelateToEffect(e) and tc:IsFacedown() then
			s.move_and_activate(tc,e,tp,nil,nil,nil,nil,nil,nil)
		end
	end
end

-- =========================================================
-- Conditions / target
-- =========================================================
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then return false end
	return Duel.IsExistingMatchingCard(s.spellcaster_filter,tp,LOCATION_ONFIELD,0,1,nil)
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chk==0 then
		return not Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT)
			and Duel.IsExistingMatchingCard(s.spellcaster_filter,tp,LOCATION_ONFIELD,0,1,nil)
	end
	local ct=Duel.GetMatchingGroupCount(Card.IsType,tp,LOCATION_ONFIELD,0,nil,TYPE_MONSTER)
	Duel.SetOperationInfo(0,CATEGORY_POSITION,nil,ct,0,0)
	Duel.SetOperationInfo(0,CATEGORY_TOKEN,nil,3-ct,0,0)
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,3-ct,0,0)
end

-- =========================================================
-- Activate
-- =========================================================
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local fid=c:GetFieldID()

	if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then return end

	c:RegisterFlagEffect(FLAG_CARD_ACTIVE,RESET_EVENT+RESETS_STANDARD_DISABLE,0,0,fid)

	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_POSCHANGE)
	local g1=Duel.SelectMatchingCard(tp,s.spellcaster_filter,tp,LOCATION_ONFIELD,0,1,1,nil)
	local real=g1:GetFirst()
	if not real then return end

	local ct=Duel.GetMatchingGroupCount(Card.IsType,tp,LOCATION_ONFIELD,0,real,TYPE_MONSTER)

	-- optionally also hide other monsters
	if ct>0 and Duel.SelectYesNo(tp,aux.Stringid(id,0)) then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_POSCHANGE)
		local g2=Duel.SelectMatchingCard(tp,Card.IsType,tp,LOCATION_ONFIELD,0,1,3,real,TYPE_MONSTER)
		g1:Merge(g2)
		for hatma in aux.Next(g2) do
			Duel.ChangePosition(hatma,POS_FACEDOWN_DEFENSE)
			s.store_prev_position(hatma,c,fid,FLAG_OTHER_MONSTER)
		end
	end

	local zone=4-#g1
	local ft=Duel.GetLocationCount(tp,LOCATION_MZONE)
	if ft<zone then
		Duel.Destroy(c,REASON_EFFECT)
		return
	end

	-- create hat tokens
	for i=1,zone do
		local hat=Duel.CreateToken(tp,HAT_TOKEN_CODE)
		Duel.MoveToField(hat,tp,tp,LOCATION_MZONE,POS_FACEDOWN_DEFENSE,true)
		s.setup_hat_token(hat,c,fid)
	end

	-- hide real monster
	Duel.ChangePosition(real,POS_FACEDOWN_DEFENSE)
	s.store_prev_position(real,c,fid,FLAG_REAL_MONSTER)

	-- shuffle all involved
	local gs=Duel.GetMatchingGroup(function(sc)
		return sc:IsFacedown() and (
			s.is_real(sc,fid) or s.is_other_hidden(sc,fid) or s.is_hat_token(sc,fid) or s.is_setst(sc,fid)
		)
	end,tp,LOCATION_ONFIELD,0,nil)
	Duel.ShuffleSetCard(gs)

	-- if activated in chain with Slifer
	local ch=Duel.GetCurrentChain()
	if ch>1 then
		local prev_re=Duel.GetChainInfo(ch-1,CHAININFO_TRIGGERING_EFFECT)
		if prev_re and prev_re:GetHandler():GetCode()==SLIFER_CODE then
			table.insert(MagicalHatsAnime_HatTokenFidList,{fid=fid,player=tp})
		end
	end
end

-- =========================================================
-- Once per turn add hidden S/T hat from hand
-- =========================================================
function s.costfilter(c)
	return c:GetFlagEffect(FLAG_HAT_TOKEN)~=0 and c:IsType(TYPE_TOKEN)
end

function s.stcost(e,tp,eg,ep,ev,re,r,rp,chk)
	local fid=e:GetHandler():GetFieldID()
	if chk==0 then
		return Duel.IsExistingMatchingCard(function(c) return s.is_hat_token(c,fid) end,tp,LOCATION_ONFIELD,0,1,nil)
	end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
	local g=Duel.SelectMatchingCard(tp,function(c) return s.is_hat_token(c,fid) end,tp,LOCATION_ONFIELD,0,1,1,nil)
	Duel.SendtoGrave(g,REASON_COST)
end

function s.stfilter(c)
	return c:IsType(TYPE_SPELL+TYPE_TRAP)
end

function s.sttg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.stfilter,tp,LOCATION_HAND,0,1,nil) end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND)
end

function s.stop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local fid=c:GetFieldID()
	if Duel.GetLocationCount(tp,LOCATION_MZONE)<1 then return end

	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOFIELD)
	local g=Duel.SelectMatchingCard(tp,s.stfilter,tp,LOCATION_HAND,0,1,1,nil)
	local tc=g:GetFirst()
	if not tc then return end

	if not s.set_order then s.set_order=1 end

	Duel.MoveToField(tc,tp,tp,LOCATION_MZONE,POS_FACEDOWN_DEFENSE,true)

	local e1=Effect.CreateEffect(tc)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_CHANGE_TYPE)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e1:SetValue(TYPE_TOKEN)
	e1:SetReset(RESET_EVENT|(RESETS_STANDARD|RESET_MSCHANGE|RESET_TOFIELD))
	tc:RegisterEffect(e1,true)

	local e2=e1:Clone()
	e2:SetCode(EFFECT_REMOVE_RACE)
	e2:SetValue(RACE_ALL)
	tc:RegisterEffect(e2,true)

	local e3=e1:Clone()
	e3:SetCode(EFFECT_REMOVE_ATTRIBUTE)
	e3:SetValue(0xff)
	tc:RegisterEffect(e3,true)

	local e4=e1:Clone()
	e4:SetCode(EFFECT_SET_BASE_ATTACK)
	e4:SetValue(0)
	tc:RegisterEffect(e4,true)

	local e5=e1:Clone()
	e5:SetCode(EFFECT_SET_BASE_DEFENSE)
	e5:SetValue(0)
	tc:RegisterEffect(e5,true)

	local e6=Effect.CreateEffect(tc)
	e6:SetType(EFFECT_TYPE_SINGLE)
	e6:SetCode(EFFECT_CANNOT_CHANGE_POSITION)
	tc:RegisterEffect(e6,true)

	local e7=e1:Clone()
	e7:SetCode(EFFECT_CANNOT_ATTACK)
	tc:RegisterEffect(e7,true)

	local e8=e1:Clone()
	e8:SetCode(EFFECT_UNRELEASABLE_SUM)
	e8:SetValue(1)
	tc:RegisterEffect(e8,true)

	local e9=e8:Clone()
	e9:SetCode(EFFECT_UNRELEASABLE_NONSUM)
	tc:RegisterEffect(e9,true)

	local e10=e1:Clone()
	e10:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e10:SetCode(EFFECT_CANNOT_BE_SYNCHRO_MATERIAL)
	e10:SetValue(1)
	tc:RegisterEffect(e10,true)

	local e11=e1:Clone()
	e11:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE)
	e11:SetCode(EFFECT_CANNOT_BE_XYZ_MATERIAL)
	e11:SetValue(1)
	tc:RegisterEffect(e11,true)

	tc:SetStatus(STATUS_NO_LEVEL,true)
	tc:RegisterFlagEffect(FLAG_SETST,RESET_EVENT+0x17a0000,0,0,fid)
	tc:RegisterFlagEffect(FLAG_SET_ORDER,RESET_EVENT+0x17a0000,0,0,s.set_order)
	s.set_order=s.set_order+1

	local gs=Duel.GetMatchingGroup(function(sc)
		return sc:IsFacedown() and (
			s.is_real(sc,fid) or s.is_other_hidden(sc,fid) or s.is_hat_token(sc,fid) or s.is_setst(sc,fid)
		)
	end,tp,LOCATION_ONFIELD,0,nil)
	Duel.ChangePosition(gs,POS_FACEDOWN_DEFENSE)
	Duel.ShuffleSetCard(gs)
end

-- =========================================================
-- Battle / effect conditions
-- =========================================================
function s.attacked_real_con(e,tp,eg,ep,ev,re,r,rp)
	local d=Duel.GetAttackTarget()
	local fid=e:GetHandler():GetFieldID()
	return d and d:IsControler(tp) and s.is_real(d,fid)
end

function s.targeted_real_con(e,tp,eg,ep,ev,re,r,rp)
	if rp==tp then return false end
	local fid=e:GetHandler():GetFieldID()
	local tg=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
	return tg and tg:IsExists(function(c) return s.is_real(c,fid) end,1,nil)
end

function s.attacked_fake_con(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetAttackTarget()
	local fid=e:GetHandler():GetFieldID()
	return tc and s.is_other_hidden(tc,fid)
end

function s.targeted_fake_con(e,tp,eg,ep,ev,re,r,rp)
	local fid=e:GetHandler():GetFieldID()
	if not re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) then return false end
	local tg=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
	return tg and tg:IsExists(function(c) return s.is_other_hidden(c,fid) end,1,nil)
end

function s.core_leave_con(e,tp,eg,ep,ev,re,r,rp)
	local fid=e:GetHandler():GetFieldID()
	local real=s.get_real(tp,fid)
	return real and eg:IsContains(real)
end

function s.adjust_cleanup_con(e,tp,eg,ep,ev,re,r,rp)
	local fid=e:GetHandler():GetFieldID()
	return s.hidden_state_broken(tp,fid)
end

function s.selfdescon(e)
	local c=e:GetHandler()
	local fid=c:GetFieldID()
	return not Duel.IsExistingMatchingCard(function(sc)
		return sc:IsFaceup() and sc:GetFlagEffectLabel(FLAG_CARD_ACTIVE)==fid and not (sc:IsDisabled() or sc:IsStatus(STATUS_DISABLED))
	end,c:GetControler(),LOCATION_ONFIELD,0,1,nil)
end

-- =========================================================
-- Reveal / cleanup flows
-- =========================================================
function s.reveal_and_break(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local fid=c:GetFieldID()

	-- restore real monster
	local real=s.get_real(tp,fid)
	if real then
		Duel.ChangePosition(real,real:GetPreviousPosition())
		real:ResetFlagEffect(FLAG_REAL_MONSTER)
	end

	-- restore other hidden monsters
	local g1=s.get_other_hidden_group(tp,fid)
	for tc in aux.Next(g1) do
		Duel.ChangePosition(tc,tc:GetPreviousPosition())
		tc:ResetFlagEffect(FLAG_OTHER_MONSTER)
	end

	-- if targeting/attack involved hidden set S/T, move + activate in order
	s.resolve_hidden_setst_targets(e,tp,fid)

	-- destroy hat tokens
	local hats=s.get_hat_tokens(tp,fid)
	if #hats>0 then
		Duel.Destroy(hats,REASON_EFFECT)
	end

	-- destroy magical hats
	Duel.Destroy(c,REASON_EFFECT)
end

function s.reveal_fake_only(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local fid=c:GetFieldID()

	local tc=Duel.GetAttackTarget()
	if tc and s.is_other_hidden(tc,fid) then
		Duel.ChangePosition(tc,tc:GetPreviousPosition())
		tc:ResetFlagEffect(FLAG_OTHER_MONSTER)
	end
end

function s.full_cleanup(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local fid=c:GetFieldID()

	s.restore_hidden_monsters(tp,fid)
	s.destroy_hat_tokens(tp,fid)
	s.destroy_hidden_setst(tp,fid)

	if c:IsOnField() then
		c:ResetFlagEffect(FLAG_CARD_ACTIVE)
	end
	if c:IsOnField() and c:IsFaceup() then
		Duel.Destroy(c,REASON_EFFECT)
	end
end

-- =========================================================
-- Slifer handling
-- =========================================================
function s.check_slifer_resolve(e,tp,eg,ep,ev,re,r,rp)
	if not re or re:GetHandler():GetCode()~=SLIFER_CODE then return end
	for idx=#MagicalHatsAnime_HatTokenFidList,1,-1 do
		local info=MagicalHatsAnime_HatTokenFidList[idx]
		local fid=info.fid
		local player=info.player
		local g=Duel.GetMatchingGroup(function(tc)
			return tc:IsFacedown() and tc:IsOnField() and (
				s.is_other_hidden(tc,fid) or s.is_hat_token(tc,fid) or s.is_setst(tc,fid)
			)
		end,player,LOCATION_MZONE,0,nil)
		if #g>0 then
			local sg=g:RandomSelect(player,1)
			Duel.Destroy(sg,REASON_EFFECT)
		end
		table.remove(MagicalHatsAnime_HatTokenFidList,idx)
	end
end