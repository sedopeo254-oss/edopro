--The Seal of Orichalcos (Anime)


local s,id=GetID()
-- Native first-party Core constants are made available to Lua only when
-- the engine explicitly advertises complete Orichalcos support. This lets
-- custom anime profiles evolve without importing third-party binaries.
if type(Duel)=="table" and type(Duel.SupportsOrichalcosZones)=="function"
		and Duel.SupportsOrichalcosZones()==true then
	EFFECT_ORICA=EFFECT_ORICA or 2005
	EFFECT_ORICA_SZONE=EFFECT_ORICA_SZONE or 2006
	EFFECT_SANCT_MZONE=EFFECT_SANCT_MZONE or 2008
	LOCATION_RMZONE=LOCATION_RMZONE or 0x2000
	LOCATION_RSZONE=LOCATION_RSZONE or 0x4000
end
-- This anime card relies on a nonstandard engine extension for physical
-- Monster/Spell&Trap interchangeable zones and combat. Keep all standard
-- effects usable without causing nil SetCode/SetTarget Lua errors when the
-- connected Core does not provide this extension. Imported Lua-only constants
-- do NOT prove the native engine can place or battle with back-row monsters.
-- Require an explicit native Core capability instead of checking only globals.
local has_orica_core =
	type(Duel)=="table" and
	type(Duel.SupportsOrichalcosZones)=="function" and
	Duel.SupportsOrichalcosZones() == true and
	type(EFFECT_ORICA)=="number" and
	type(EFFECT_ORICA_SZONE)=="number" and
	type(EFFECT_SANCT_MZONE)=="number" and
	type(LOCATION_RMZONE)=="number" and
	type(LOCATION_RSZONE)=="number"
s.has_orica_core=has_orica_core

function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_CANNOT_INACTIVATE+EFFECT_FLAG_CANNOT_NEGATE)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCost(s.actcost)
	e1:SetTarget(s.actg)
	e1:SetOperation(s.restore_original_forms)
	c:RegisterEffect(e1)
	if has_orica_core then
	local e2=Effect.CreateEffect(c)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_SINGLE_RANGE+EFFECT_FLAG_SET_AVAILABLE)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_CANNOT_BE_BATTLE_TARGET)
	e2:SetRange(LOCATION_FZONE)
	e2:SetTargetRange(LOCATION_MZONE,0)
	e2:SetTarget(s.attg)
	e2:SetCondition(s.atkcon)
	e2:SetValue(1)
	c:RegisterEffect(e2)
	end
	local e3=Effect.CreateEffect(c)
	e3:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetRange(LOCATION_FZONE)
	e3:SetCode(EFFECT_UPDATE_ATTACK)
	e3:SetTargetRange(LOCATION_MZONE,0)
	e3:SetValue(500)
	c:RegisterEffect(e3)
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_SINGLE)
	e4:SetProperty(EFFECT_FLAG_SINGLE_RANGE+EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e4:SetRange(LOCATION_FZONE)
	e4:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
	e4:SetValue(s.efilterr)
	c:RegisterEffect(e4)
	local e5=e4:Clone()
	e5:SetCode(EFFECT_CANNOT_REMOVE)
	c:RegisterEffect(e5)
	local e6=e4:Clone()
	e6:SetCode(EFFECT_CANNOT_TO_HAND)
	c:RegisterEffect(e6)
	local e7=e4:Clone()
	e7:SetCode(EFFECT_CANNOT_TO_DECK)
	c:RegisterEffect(e7)
	local e8=e4:Clone()
	e8:SetCode(EFFECT_CANNOT_TO_GRAVE)
	c:RegisterEffect(e8)
	local e9=e4:Clone()
	e9:SetCode(EFFECT_CANNOT_DISABLE)
	c:RegisterEffect(e9)
	local e10=e4:Clone()
	e10:SetCode(EFFECT_CANNOT_TURN_SET)
	c:RegisterEffect(e10)
	local e11=e4:Clone()
	e11:SetCode(EFFECT_CANNOT_USE_AS_COST)
	c:RegisterEffect(e11)
	local e12=e4:Clone()
	e12:SetCode(EFFECT_CANNOT_DISEFFECT)
	c:RegisterEffect(e12)
	local e13=Effect.CreateEffect(c)
	e13:SetType(EFFECT_TYPE_FIELD)
	e13:SetCode(EFFECT_CANNOT_ACTIVATE)
	e13:SetProperty(EFFECT_FLAG_PLAYER_TARGET+EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_SET_AVAILABLE)
	e13:SetRange(LOCATION_FZONE)
	e13:SetTargetRange(1,0)
	e13:SetValue(s.distg)
	c:RegisterEffect(e13)
	local e14=Effect.CreateEffect(c)
	e14:SetType(EFFECT_TYPE_FIELD)
	e14:SetCode(EFFECT_CANNOT_SSET)
	e14:SetRange(LOCATION_FZONE)
	e14:SetProperty(EFFECT_FLAG_PLAYER_TARGET+EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e14:SetTargetRange(1,0)
	e14:SetTarget(s.sfilter)
	c:RegisterEffect(e14)
	-- Real back-row monster placements require native Orichalcos support.
	-- Do not register an effect that would move a monster into ordinary
	-- Spell/Trap zones where the Core cannot attack with it.
	if has_orica_core then
	local e15=Effect.CreateEffect(c)
	e15:SetDescription(aux.Stringid(827,0))
	e15:SetType(EFFECT_TYPE_IGNITION)
	e15:SetRange(LOCATION_FZONE)
	e15:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e15:SetTarget(s.tg)
	e15:SetOperation(s.op)
	c:RegisterEffect(e15)
	local e16=Effect.CreateEffect(c)
	e16:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e16:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e16:SetCode(EVENT_LEAVE_FIELD_P)
	e16:SetOperation(s.leaveop)
	c:RegisterEffect(e16)
	local e17=Effect.CreateEffect(c)
	e17:SetType(EFFECT_TYPE_FIELD)
	e17:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e17:SetCode(EFFECT_ORICA)
	e17:SetRange(LOCATION_FZONE)
	e17:SetTargetRange(1,0)
	c:RegisterEffect(e17)
	end
end
function s.actcost(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e1:SetCode(EFFECT_CANNOT_ACTIVATE)
	e1:SetTargetRange(1,0)
	e1:SetValue(function(e,re,tp) return re:GetHandler():IsCode(355,110000100) end)
	e1:SetReset(RESET_PHASE+PHASE_END)
	Duel.RegisterEffect(e1,tp)
	local e2=Effect.CreateEffect(e:GetHandler())
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e2:SetCode(EFFECT_CANNOT_SSET)
	e2:SetTargetRange(1,0)
	e2:SetTarget(function(e,c,tp) return c:IsCode(355,110000100) end)
	e2:SetReset(RESET_PHASE+PHASE_END)
	Duel.RegisterEffect(e2,tp)
end
s.listed_series={0x900}
function s.atktgfilter(c)
	return c:IsType(TYPE_MONSTER) and not c:IsHasEffect(EFFECT_SANCT_MZONE)
end
function s.atktg(e)
	return Duel.IsExistingMatchingCard(s.atktgfilter,e:GetHandlerPlayer(),LOCATION_RMZONE,0,1,nil)
end
function s.atkcon(e)
	local tp=e:GetHandlerPlayer()
	if Duel.GetCurrentChain()>0 then
		local p=Duel.GetChainInfo(0,CHAININFO_TRIGGERING_PLAYER)
		if p==tp then return false end
		if p==1-tp then return s.atktg(e) end
	end
	local a=Duel.GetAttacker()
	local at=Duel.GetAttackTarget()
	if a and a:IsControler(1-tp) and at and at:IsOnField() and at:IsControler(tp) then return false end
	return s.atktg(e)
end
function s.attg(e,c)
	return c:IsLocation(LOCATION_RSZONE) and c:IsHasEffect(EFFECT_ORICA_SZONE)
end
function s.freezonemask(tp,loc)
	local zone=0
	local checkloc=LOCATION_MZONE
	if loc==LOCATION_RSZONE then
		checkloc=LOCATION_SZONE
	end
	for i=0,4 do
		if Duel.CheckLocation(tp,checkloc,i) then
			zone=zone|(0x1<<i)
		end
	end
	return zone
end
function s.freezonecount(tp,loc)
	local zone=s.freezonemask(tp,loc)
	local ct=0
	for i=0,4 do
		if (zone&(0x1<<i))~=0 then
			ct=ct+1
		end
	end
	return ct
end
function s.ttfilter1(c,tp)
	if c:GetTurnID()==Duel.GetTurnCount() or c:GetFlagEffect(13)>0 or c:GetSequence()>4 then return false end
	if c:IsLocation(LOCATION_RMZONE) then
		return s.freezonemask(tp,LOCATION_RSZONE)>0
	elseif c:IsLocation(LOCATION_RSZONE) then
		return c:IsHasEffect(EFFECT_ORICA_SZONE) and s.freezonemask(tp,LOCATION_RMZONE)>0
	end
	return false
end
function s.ttfilter2(c,tp)
	return c:IsHasEffect(EFFECT_ORICA_SZONE) and s.freezonemask(tp,LOCATION_RMZONE)>0
end
function s.monfilter(c)
	return c:IsType(TYPE_MONSTER) and not c:IsHasEffect(EFFECT_SANCT_MZONE)
end
function s.tg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.IsExistingMatchingCard(s.ttfilter1,tp,LOCATION_RMZONE,0,1,nil,tp) or Duel.IsExistingMatchingCard(s.ttfilter1,tp,LOCATION_RSZONE,0,1,nil,tp) end
end
function s.op(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	if not c:IsRelateToEffect(e) then return end
	local a=Duel.IsExistingMatchingCard(s.ttfilter1,tp,LOCATION_RMZONE,0,1,nil,tp)
	local b=Duel.IsExistingMatchingCard(s.ttfilter1,tp,LOCATION_RSZONE,0,1,nil,tp)
	local looc=0
	if a and not b then looc=LOCATION_RMZONE end
	if b and not a then looc=LOCATION_RSZONE end
	if b and a then looc=LOCATION_ONFIELD end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOFIELD)
	local tc=Duel.SelectMatchingCard(tp,s.ttfilter1,tp,looc,0,1,1,nil,tp):GetFirst()
	if tc then
		local loc=LOCATION_RMZONE
		if tc:IsLocation(LOCATION_RMZONE) then
			loc=LOCATION_RSZONE
		end
		local zone=s.freezonemask(tp,loc)
		if zone==0 then return end
		-- Register the rear-monster marker AFTER moving physical zones.
		-- Otherwise RESET_MSCHANGE can erase it during MoveToField.
		if not Duel.MoveToField(tc,tp,tp,loc,tc:GetPosition(),true,zone) then return end
		if loc==LOCATION_RSZONE and not tc:IsHasEffect(EFFECT_ORICA_SZONE) then
			local e1=Effect.CreateEffect(e:GetOwner())
			e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_UNCOPYABLE)
			e1:SetType(EFFECT_TYPE_SINGLE)
			e1:SetCode(EFFECT_ORICA_SZONE)
			e1:SetReset(RESET_EVENT+0x1fe0000+RESET_CONTROL-RESET_TURN_SET)
			tc:RegisterEffect(e1,true)
		end
		tc:RegisterFlagEffect(13,RESET_EVENT+0x1fe0000+RESET_CONTROL-RESET_TURN_SET+RESET_PHASE+PHASE_END,0,1)
	end
end
function s.leavefilter(c)
	return c:IsHasEffect(EFFECT_ORICA_SZONE)
end
function s.leaveop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local p=c:GetControler()
	local ag=Duel.GetMatchingGroup(s.leavefilter,p,LOCATION_RSZONE,0,nil)
	if ag:GetCount()<1 then return end
	local ft=s.freezonecount(p,LOCATION_RMZONE)
	if ft<=0 then
		Duel.SendtoGrave(ag,REASON_RULE+REASON_EFFECT)
		return
	end
	local sg=nil
	if ag:GetCount()>ft then
		Duel.Hint(HINT_SELECTMSG,p,HINTMSG_TOFIELD)
		sg=ag:Select(p,ft,ft,nil)
	else
		sg=ag
	end
	local tempg=Group.CreateGroup()
	local tc=sg:GetFirst()
	while tc do
		local zone=s.freezonemask(p,LOCATION_RMZONE)
		if zone>0 and Duel.MoveToField(tc,p,p,LOCATION_RMZONE,tc:GetPosition(),true,zone) then
			tc:RegisterFlagEffect(13,RESET_EVENT+0x1fe0000-RESET_TURN_SET+RESET_PHASE+PHASE_END,0,1)
			tempg:AddCard(tc)
		end
		tc=sg:GetNext()
	end
	ag:Sub(tempg)
	if ag:GetCount()>0 then
		Duel.SendtoGrave(ag,REASON_RULE+REASON_EFFECT)
	end
end
function s.actg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return true end
	Duel.SetChainLimit(aux.FALSE)
end
function s.distg(e,te,tp)
	if not (te:IsHasType(EFFECT_TYPE_ACTIVATE) and te:IsActiveType(TYPE_FIELD)) then return false end
	local c=te:GetHandler()
	local oc=c:GetOriginalCode()
	return not c:IsSetCard(0x900) and oc~=355 and oc~=356
end
function s.sfilter(e,c,tp)
	local oc=c:GetOriginalCode()
	return c:IsType(TYPE_FIELD) and not c:IsSetCard(0x900) and oc~=355 and oc~=356
end
function s.efilterr(e,te)
	return te and not (te:GetOwner()==e:GetOwner() or te:GetOwner():IsSetCard(0x900) or te:GetOwner():IsOriginalCode(357))
end

-- Legendary Dragon fusions must be reversed when the Seal resolves. The
-- materials are real cards already recorded by the Fusion/Equip scripts;
-- only return those still available in GY/Banish and with room on field.
-- Ordinary Fusion Monsters (no Legendary Dragon material) are untouched.
s.legendary_dragon_codes={[1784686]=true,[46232525]=true,[11082056]=true}
function s.is_legendary_dragon(c)
	return c and s.legendary_dragon_codes[c:GetOriginalCode()] or false
end
function s.is_legendary_fusion(c)
	if not c:IsFaceup() or not (c:IsType(TYPE_FUSION) or c:IsType(TYPE_EQUIP)) then
		return false
	end
	local materials=c:GetMaterial()
	return materials and materials:IsExists(s.is_legendary_dragon,1,nil) or false
end
function s.restore_original_forms(e,tp,eg,ep,ev,re,r,rp)
	local combined=Duel.GetMatchingGroup(s.is_legendary_fusion,tp,
		LOCATION_MZONE|LOCATION_SZONE,LOCATION_MZONE|LOCATION_SZONE,nil)
	for tc in combined:Iter() do
		local controller=tc:GetControler()
		local materials=tc:GetMaterial()
		if materials and #materials>0 then
			local originals=materials:Filter(function(mc)
				return not s.is_legendary_dragon(mc)
			end,nil)
			-- Remove the combination and restore its real constituent cards.
			-- This does not clone a card or invent an original card ID.
			if Duel.SendtoGrave(tc,REASON_EFFECT)>0 then
				for mc in originals:Iter() do
					if mc:IsLocation(LOCATION_GRAVE|LOCATION_REMOVED) then
						local monster=mc:IsMonster()
						local destination=monster and LOCATION_MZONE or LOCATION_SZONE
						if Duel.GetLocationCount(controller,destination)>0 then
							Duel.MoveToField(mc,controller,controller,destination,
								monster and POS_FACEUP_ATTACK or POS_FACEDOWN,true)
						end
					end
				end
			end
		end
	end
end

