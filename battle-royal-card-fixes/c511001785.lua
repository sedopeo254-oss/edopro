--痛魂の呪術 (Anime)
--Spell of Pain (Anime)
local s,id=GetID()
local DUEL_BATTLE_ROYALE_FLAG=0x2000000000
local MP_PLAYER_BASE=-68719476736 -- signed form of 0xfffffff000000000
local MP_MAX_PLAYERS=4

local function is_battle_royal()
	return Duel.GetDuelType and (Duel.GetDuelType()&DUEL_BATTLE_ROYALE_FLAG)~=0
end
local function opponent_mask(tp)
	if not is_battle_royal() then return 0 end
	local owner=Duel.GetLogicalPlayer(tp)
	if owner==nil then return 0 end
	local active=Duel.GetActiveLogicalPlayerMask()
	return active&~(1<<owner)
end
local function select_logical_player(tp,mask)
	local players,options={},{}
	for p=0,MP_MAX_PLAYERS-1 do
		if (mask&(1<<p))~=0 and Duel.IsLogicalPlayerActive(p) then
			players[#players+1]=p
			options[#options+1]=MP_PLAYER_BASE+p
		end
	end
	if #players==0 then return nil end
	if #players==1 then return players[1] end
	local op=Duel.SelectOption(tp,table.unpack(options))
	return players[op+1]
end

function s.initial_effect(c)
	--reflect effect damage
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e1:SetCode(EVENT_CHAINING)
	e1:SetCondition(aux.damcon1)
	e1:SetTarget(s.target1)
	e1:SetOperation(s.operation1)
	c:RegisterEffect(e1)
	--reflect battle damage
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_ACTIVATE)
	e2:SetCode(EVENT_PRE_DAMAGE_CALCULATE)
	e2:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e2:SetCondition(s.condition)
	e2:SetTarget(s.target2)
	e2:SetOperation(s.operation2)
	c:RegisterEffect(e2)
end
function s.target1(e,tp,eg,ep,ev,re,r,rp,chk)
	if not is_battle_royal() then
		if chk==0 then return true end
		return
	end
	local mask=opponent_mask(tp)
	if chk==0 then return mask~=0 end
	local logical=select_logical_player(tp,mask)
	e:SetLabel(logical or -1)
end
function s.operation1(e,tp,eg,ep,ev,re,r,rp)
	if not is_battle_royal() then
		local cid=Duel.GetChainInfo(ev,CHAININFO_CHAIN_ID)
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_FIELD)
		e1:SetCode(EFFECT_REFLECT_DAMAGE)
		e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		e1:SetTargetRange(1,0)
		e1:SetLabel(cid)
		e1:SetValue(s.refcon)
		e1:SetReset(RESET_CHAIN)
		Duel.RegisterEffect(e1,tp)
		return
	end
	local logical=e:GetLabel()
	if logical==nil or logical<0 or not Duel.IsLogicalPlayerActive(logical) then return end
	local cid=Duel.GetChainInfo(ev,CHAININFO_CHAIN_ID)
	local ce=Effect.CreateEffect(e:GetHandler())
	ce:SetType(EFFECT_TYPE_FIELD)
	ce:SetCode(EFFECT_CHANGE_DAMAGE)
	ce:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	ce:SetTargetRange(1,0)
	ce:SetLabel(cid,logical,0)
	ce:SetValue(s.capture)
	ce:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(ce,tp)
	local te=Effect.CreateEffect(e:GetHandler())
	te:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	te:SetCode(EVENT_CHAIN_SOLVED)
	te:SetLabelObject(ce)
	te:SetOperation(s.transfer)
	te:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(te,tp)
end
function s.refcon(e,re,val,r,rp,rc)
	local cc=Duel.GetCurrentChain()
	if cc==0 or (r&REASON_EFFECT)==0 then return end
	local cid=Duel.GetChainInfo(0,CHAININFO_CHAIN_ID)
	return cid==e:GetLabel()
end
function s.capture(e,re,val,r,rp,rc)
	if (r&REASON_EFFECT)==0 then return val end
	local cid,logical,total=e:GetLabel()
	local cc=Duel.GetCurrentChain()
	if cc==0 then return val end
	local now=Duel.GetChainInfo(0,CHAININFO_CHAIN_ID)
	if now~=cid then return val end
	e:SetLabel(cid,logical,total+val)
	return 0
end
function s.transfer(e,tp,eg,ep,ev,re,r,rp)
	local ce=e:GetLabelObject()
	if not ce then return end
	local cid,logical,total=ce:GetLabel()
	if logical==nil or logical<0 or not total or total<=0 then return end
	ce:SetLabel(cid,logical,0)
	if Duel.IsLogicalPlayerActive(logical) then
		Duel.DamagePlayer(logical,total,REASON_EFFECT)
	end
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return Duel.GetBattleDamage(tp)>0
end
function s.target2(e,tp,eg,ep,ev,re,r,rp,chk)
	if not is_battle_royal() then
		if chk==0 then return true end
		return
	end
	local mask=opponent_mask(tp)
	if chk==0 then return mask~=0 end
	local logical=select_logical_player(tp,mask)
	e:SetLabel(logical or -1)
end
function s.operation2(e,tp,eg,ep,ev,re,r,rp)
	if not is_battle_royal() then
		local e1=Effect.CreateEffect(e:GetHandler())
		e1:SetType(EFFECT_TYPE_FIELD)
		e1:SetCode(EFFECT_REFLECT_BATTLE_DAMAGE)
		e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		e1:SetTargetRange(1,0)
		e1:SetReset(RESET_PHASE+PHASE_DAMAGE)
		Duel.RegisterEffect(e1,tp)
		return
	end
	local logical=e:GetLabel()
	local dam=Duel.GetBattleDamage(tp)
	if logical==nil or logical<0 or dam<=0 then return end
	Duel.ChangeBattleDamage(tp,0)
	if Duel.IsLogicalPlayerActive(logical) then
		Duel.DamagePlayer(logical,dam,REASON_BATTLE)
	end
end
