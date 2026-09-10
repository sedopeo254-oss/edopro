--Attack Guidance Armor (Anime)
--Multiplayer anime fix: redirect the attack to another monster controlled by
--any active logical player, not merely one physical opponent field.
local s,id=GetID()
local MP_PLAYER_BASE=-68719476736 -- signed form of 0xfffffff000000000
local MP_MAX_PLAYERS=26
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_ATKCHANGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_ATTACK_ANNOUNCE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.ismulti()
	return Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0
end
function s.valid(c,a,old)
	return c:IsLocation(LOCATION_MZONE) and c~=a and c~=old
end
function s.playergroup(logical,a,old)
	local g=Duel.GetPlayerFieldGroup(logical,LOCATION_MZONE)
	return g and g:Filter(s.valid,nil,a,old) or Group.CreateGroup()
end
function s.candidateplayers(a,old)
	local mask=Duel.GetActiveLogicalPlayerMask()
	local candidates=0
	for p=0,MP_MAX_PLAYERS-1 do
		if (mask&(1<<p))~=0 and Duel.IsLogicalPlayerActive(p) then
			local g=s.playergroup(p,a,old)
			if g:GetCount()>0 then candidates=candidates|(1<<p) end
		end
	end
	return candidates
end
function s.selectplayer(tp,mask)
	local players,options={},{}
	for p=0,MP_MAX_PLAYERS-1 do
		if (mask&(1<<p))~=0 then
			players[#players+1]=p
			options[#options+1]=MP_PLAYER_BASE+p
		end
	end
	if #players==0 then return nil end
	if #players==1 then return players[1] end
	local op=Duel.SelectOption(tp,table.unpack(options))
	return players[op+1]
end
function s.stdvalid(c,a,old)
	return c~=a and c~=old
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	local a=Duel.GetAttacker()
	local old=Duel.GetAttackTarget()
	if s.ismulti() then
		local pm=s.candidateplayers(a,old)
		if chk==0 then return pm~=0 end
		local owner=Duel.GetLogicalPlayer(tp)
		local logical=s.selectplayer(tp,pm)
		if logical==nil then return end
		Duel.FocusLogicalPlayer(logical)
		local g=s.playergroup(logical,a,old)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACKTARGET)
		local sg=g:Select(tp,1,1,nil)
		Duel.SetTargetCard(sg)
		if owner~=nil then Duel.FocusLogicalPlayer(owner) end
		return
	end
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and s.stdvalid(chkc,a,old) end
	if chk==0 then return Duel.IsExistingTarget(s.stdvalid,tp,LOCATION_MZONE,LOCATION_MZONE,1,nil,a,old) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATTACKTARGET)
	Duel.SelectTarget(tp,s.stdvalid,tp,LOCATION_MZONE,LOCATION_MZONE,1,1,nil,a,old)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if tc and tc:IsRelateToEffect(e) and tc:IsLocation(LOCATION_MZONE) then
		Duel.ChangeAttackTarget(tc,true)
	end
end
