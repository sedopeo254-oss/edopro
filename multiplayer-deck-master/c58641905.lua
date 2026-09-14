--防御輪
--Ring of Defense
--Anime/Battle Royale: only the activating logical player is protected.
local s,id=GetID()
local DUEL_BATTLE_ROYALE_FLAG=0x2000000000
local function is_battle_royal()
	return Duel.GetDuelType and (Duel.GetDuelType()&DUEL_BATTLE_ROYALE_FLAG)~=0
end
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_CHAINING)
	e1:SetCondition(s.condition)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	if not re:IsTrapEffect() then return false end
	return aux.damcon1(e,tp,eg,ep,ev,re,r,rp)
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local cid=Duel.GetChainInfo(ev,CHAININFO_CHAIN_ID)
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_CHANGE_DAMAGE)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	-- In Battle Royale the Core's logical-duelist filter uses this card as the
	-- handler, so s_range=1/o_range=0 protects only its activating duelist.
	-- Outside Battle Royale retain Project Ignis' standard both-player behavior.
	if is_battle_royal() then
		e1:SetTargetRange(1,0)
	else
		e1:SetTargetRange(1,1)
	end
	e1:SetLabel(cid)
	e1:SetValue(s.refcon)
	e1:SetReset(RESET_CHAIN)
	Duel.RegisterEffect(e1,tp)
end
function s.refcon(e,re,val,r,rp,rc)
	local cc=Duel.GetCurrentChain()
	if cc==0 or (r&REASON_EFFECT)==0 then return end
	local cid=Duel.GetChainInfo(0,CHAININFO_CHAIN_ID)
	if cid==e:GetLabel() then return 0 end
	return val
end
