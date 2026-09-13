--破壊輪
--Ring of Destruction
--Battle Royale anime extension: destroy 1 face-up monster and damage every active player by its ATK.
local s,id=GetID()
local DUEL_BATTLE_ROYALE_FLAG=0x2000000000
local MP_MAX_PLAYERS=4

local function is_battle_royal()
	return Duel.GetDuelType and (Duel.GetDuelType()&DUEL_BATTLE_ROYALE_FLAG)~=0
end

function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DESTROY+CATEGORY_DAMAGE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetHintTiming(0,TIMINGS_CHECK_MONSTER_E)
	if not is_battle_royal() then
		e1:SetCountLimit(1,id,EFFECT_COUNT_CODE_OATH)
	end
	e1:SetCondition(s.condition)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end

function s.condition(e,tp,eg,ep,ev,re,r,rp)
	if is_battle_royal() then return true end
	return Duel.IsTurnPlayer(1-tp)
end

function s.filter(c,lp)
	if is_battle_royal() then
		return c:IsFaceup()
	end
	return c:IsFaceup() and c:IsAttackBelow(lp)
end

local function get_battle_royal_targets()
	local g=Group.CreateGroup()
	local active=Duel.GetActiveLogicalPlayerMask()
	for p=0,MP_MAX_PLAYERS-1 do
		if (active&(1<<p))~=0 and Duel.IsLogicalPlayerActive(p) then
			local pg=Duel.GetPlayerFieldGroup(p,LOCATION_MZONE)
			if pg then g:Merge(pg:Filter(Card.IsFaceup,nil)) end
		end
	end
	return g
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if not is_battle_royal() then
		local lp=Duel.GetLP(1-tp)
		if chkc then
			return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(1-tp) and s.filter(chkc,lp)
		end
		if chk==0 then
			return Duel.IsExistingTarget(s.filter,tp,0,LOCATION_MZONE,1,nil,lp)
		end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
		local g=Duel.SelectTarget(tp,s.filter,tp,0,LOCATION_MZONE,1,1,nil,lp)
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,1,0,0)
		Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,PLAYER_ALL,0)
		return
	end

	local g=get_battle_royal_targets()
	if chkc then
		local logical=chkc:GetLogicalControler()
		return chkc:IsLocation(LOCATION_MZONE) and chkc:IsFaceup()
			and logical~=nil and Duel.IsLogicalPlayerActive(logical)
	end
	if chk==0 then return g:GetCount()>0 end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
	local sg=g:Select(tp,1,1,nil)
	Duel.SetTargetCard(sg)
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,sg,1,0,0)
	Duel.SetOperationInfo(0,CATEGORY_DAMAGE,nil,0,PLAYER_ALL,0)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if not tc or not tc:IsRelateToEffect(e) or not tc:IsFaceup() then return end
	if Duel.Destroy(tc,REASON_EFFECT)==0 then return end
	local atk=tc:GetTextAttack()
	if atk<0 then atk=0 end

	if not is_battle_royal() then
		local val=Duel.Damage(tp,atk,REASON_EFFECT)
		if val>0 and Duel.GetLP(tp)>0 then
			Duel.BreakEffect()
			Duel.Damage(1-tp,val,REASON_EFFECT)
		end
		return
	end

	-- Snapshot all active duelists before applying damage so the card behaves as
	-- simultaneous "damage to all players" rather than stopping after an early elimination.
	local active=Duel.GetActiveLogicalPlayerMask()
	for p=0,MP_MAX_PLAYERS-1 do
		if (active&(1<<p))~=0 then
			-- is_step=true queues every player's damage for one RDComplete resolution.
			-- allow_interception=false prevents Battle Royale's generic damage-routing
			-- prompt from redirecting Ring of Destruction away from any player.
			Duel.DamagePlayer(p,atk,REASON_EFFECT,true,tp,false)
		end
	end
	Duel.RDComplete()
end
