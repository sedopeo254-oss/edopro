--盗賊の七つ道具
--Seven Tools of the Bandit
local s,id=GetID()
local DUEL_BATTLE_ROYALE_FLAG=0x2000000000
local function is_battle_royal()
	return Duel.GetDuelType and (Duel.GetDuelType()&DUEL_BATTLE_ROYALE_FLAG)~=0
end
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_CHAINING)
	e1:SetCondition(s.condition)
	e1:SetCost(Cost.PayLP(1000))
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
	return re:IsTrapEffect() and re:IsHasType(EFFECT_TYPE_ACTIVATE) and Duel.IsChainNegatable(ev)
end
function s.gettraps(e)
	local g=Group.CreateGroup()
	local cc=Duel.GetCurrentChain()
	for i=1,cc do
		local te=Duel.GetChainInfo(i,CHAININFO_TRIGGERING_EFFECT)
		local tc=te and te:GetHandler() or nil
		if te and tc and tc~=e:GetHandler() and te:IsTrapEffect()
			and te:IsHasType(EFFECT_TYPE_ACTIVATE) and Duel.IsChainNegatable(i) then
			g:AddCard(tc)
		end
	end
	return g
end
function s.findchain(tc)
	for i=Duel.GetCurrentChain(),1,-1 do
		local te=Duel.GetChainInfo(i,CHAININFO_TRIGGERING_EFFECT)
		if te and te:GetHandler()==tc and te:IsTrapEffect()
			and te:IsHasType(EFFECT_TYPE_ACTIVATE) and Duel.IsChainNegatable(i) then
			return i
		end
	end
	return 0
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if not is_battle_royal() then
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
		if re:GetHandler():IsDestructable() and re:GetHandler():IsRelateToEffect(re) then
			Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0)
		end
		return
	end
	local g=s.gettraps(e)
	if chk==0 then return g:GetCount()>0 end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_NEGATE)
	local sg=g:Select(tp,1,1,nil)
	local tc=sg:GetFirst()
	local ch=tc and s.findchain(tc) or 0
	e:SetLabel(ch)
	Duel.SetOperationInfo(0,CATEGORY_NEGATE,sg,1,0,0)
	if tc and tc:IsDestructable() then
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,sg,1,0,0)
	end
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	if not is_battle_royal() then
		if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then
			Duel.Destroy(eg,REASON_EFFECT)
		end
		return
	end
	local ch=e:GetLabel()
	if not ch or ch<=0 then return end
	local te=Duel.GetChainInfo(ch,CHAININFO_TRIGGERING_EFFECT)
	local tc=te and te:GetHandler() or nil
	if not te or not tc then return end
	if Duel.NegateActivation(ch) and tc:IsRelateToEffect(te) then
		Duel.Destroy(tc,REASON_EFFECT)
	end
end
