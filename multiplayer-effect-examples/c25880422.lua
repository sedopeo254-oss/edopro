--『攻撃』封じ
--Block Attack
--Anime 3v1 opt-in expansion; original behavior is preserved in every other mode.
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_POSITION)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
function s.filter(c)
	return c:IsPosition(POS_FACEUP_ATTACK) and c:IsCanChangePosition()
end
function s.original_target(e,tp,chk)
	if chk==0 then return Duel.IsExistingTarget(s.filter,tp,0,LOCATION_MZONE,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	local g=Duel.SelectTarget(tp,s.filter,tp,0,LOCATION_MZONE,1,1,nil)
	Duel.SetOperationInfo(0,CATEGORY_POSITION,g,1,0,0)
end
function s.get_expanded_group(tp,mask)
	local origin=Duel.GetLogicalPlayer(tp)
	if origin~=nil then
		mask=mask&(~(1<<origin))
	end
	local g=Group.CreateGroup()
	for logical=0,3 do
		if mask&(1<<logical)~=0 then
			local pg=Duel.GetPlayerFieldGroup(logical,LOCATION_MZONE)
			local fg=pg:Filter(s.filter,nil)
			g:Merge(fg)
		end
	end
	return g
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	-- Keep the original pre-click validation. Expanded teammate selection is
	-- offered only after the card itself is activated in anime 3v1.
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and s.filter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.filter,tp,0,LOCATION_MZONE,1,nil) end
	local mask,expanded=Duel.SelectEffectPlayers(tp,true,true)
	if not expanded then
		return s.original_target(e,tp,1)
	end
	local g=s.get_expanded_group(tp,mask)
	if g:GetCount()==0 then
		return s.original_target(e,tp,1)
	end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	local sg=g:Select(tp,1,1,nil)
	Duel.SetTargetCard(sg)
	Duel.SetOperationInfo(0,CATEGORY_POSITION,sg,1,0,0)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if tc and tc:IsRelateToEffect(e) and tc:IsPosition(POS_FACEUP_ATTACK) then
		Duel.ChangePosition(tc,POS_FACEUP_DEFENSE)
	end
end
