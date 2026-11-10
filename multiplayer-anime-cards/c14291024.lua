--オプション
--Gradius' Option (anime Equip inheritance)
local s,id=GetID()
s.listed_names={10992251}

-- Keep one independent list of inherited effects for every physical Option.
-- The entries are the original Equip effect objects, not just card codes.
s.copied=setmetatable({},{__mode="k"})

function s.initial_effect(c)
	c:EnableUnsummonable()
	c:EnableReviveLimit()
	-- It can only be Special Summoned with its own hand procedure.
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC)
	e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetRange(LOCATION_HAND)
	e1:SetCondition(s.spcon)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_SPSUMMON_CONDITION)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e2:SetValue(function() return false end)
	c:RegisterEffect(e2)
	-- Choose one particular face-up Gradius when this Option is Summoned.
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e3:SetCode(EVENT_SPSUMMON_SUCCESS)
	e3:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
	e3:SetOperation(s.linkop)
	c:RegisterEffect(e3)
	-- Use Gradius' printed (original) stats, not its modified ATK/DEF.
	-- Do not use SET_ATTACK_FINAL here: that would overwrite bonuses gained
	-- from the Equip Cards mirrored onto Option below.
	local e4=Effect.CreateEffect(c)
	e4:SetType(EFFECT_TYPE_SINGLE)
	e4:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e4:SetRange(LOCATION_MZONE)
	e4:SetCode(EFFECT_SET_ATTACK)
	e4:SetCondition(s.haslink)
	e4:SetValue(s.atkval)
	c:RegisterEffect(e4)
	local e5=e4:Clone()
	e5:SetCode(EFFECT_SET_DEFENSE)
	e5:SetValue(s.defval)
	c:RegisterEffect(e5)
	-- The linked Gradius leaving the Monster Zone destroys Option.
	local e6=Effect.CreateEffect(c)
	e6:SetType(EFFECT_TYPE_SINGLE)
	e6:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e6:SetRange(LOCATION_MZONE)
	e6:SetCode(EFFECT_SELF_DESTROY)
	e6:SetCondition(s.destroycon)
	c:RegisterEffect(e6)
	-- Mirror the continuous effects of Equip Cards attached to Gradius.
	-- EVENT_ADJUST also notices Equip Cards added after Option was Summoned.
	local e7=Effect.CreateEffect(c)
	-- EVENT_ADJUST is a field event; a SINGLE continuous effect would not
	-- receive global Adjust events for newly equipped cards.
	e7:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e7:SetCode(EVENT_ADJUST)
	e7:SetRange(LOCATION_MZONE)
	e7:SetOperation(s.sync_equips)
	c:RegisterEffect(e7)
end

function s.gradiusfilter(c)
	return c:IsFaceup() and c:IsCode(10992251)
end
function s.spcon(e,c)
	if c==nil then return true end
	local tp=c:GetControler()
	return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
		and Duel.IsExistingMatchingCard(s.gradiusfilter,tp,LOCATION_MZONE,0,1,nil)
end
function s.linkop(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
	local g=Duel.SelectMatchingCard(tp,s.gradiusfilter,tp,LOCATION_MZONE,0,1,1,nil)
	local tc=g:GetFirst()
	if not tc then return end
	Duel.HintSelection(g)
	c:SetCardTarget(tc)
	c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1)
	s.copied[c]={}
	s.sync_equips(e,tp,eg,ep,ev,re,r,rp)
end
function s.linked(c)
	local tc=c:GetFirstCardTarget()
	if tc and tc:IsLocation(LOCATION_MZONE) and tc:IsCode(10992251) then
		return tc
	end
	return nil
end
function s.haslink(e)
	return s.linked(e:GetHandler())~=nil
end
function s.atkval(e,c)
	local tc=s.linked(c)
	return tc and math.max(0,tc:GetTextAttack()) or 0
end
function s.defval(e,c)
	local tc=s.linked(c)
	return tc and math.max(0,tc:GetTextDefense()) or 0
end
function s.destroycon(e)
	local c=e:GetHandler()
	return c:GetFlagEffect(id)>0 and not s.linked(c)
end

-- Only inherit an Equip's effects while it is actually attached and active.
-- Each inherited effect retains its original Equip source as its value context.
function s.equip_active(c,eq,source_effect)
	local tc=s.linked(c)
	if not tc or not eq or not eq:IsFaceup()
		or eq:IsDisabled() or eq:GetEquipTarget()~=tc then return false end
	for _,current in ipairs({eq:GetOwnEffects()}) do
		if current==source_effect then return true end
	end
	return false
end
function s.mirror(c,eq,source_effect)
	local code=source_effect:GetCode()
	local copied=Effect.CreateEffect(c)
	copied:SetType(EFFECT_TYPE_SINGLE)
	copied:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	copied:SetRange(LOCATION_MZONE)
	copied:SetCode(code)
	copied:SetReset(RESET_EVENT+RESETS_STANDARD)
	copied:SetCondition(function(e)
		if not s.equip_active(c,eq,source_effect) then return false end
		if eq:IsCode(511000219) and code==EFFECT_SET_ATTACK_FINAL then
			-- Matter Leveller acts when OPTION attacks a DEF-position monster.
			local target=Duel.GetAttackTarget()
			return Duel.GetCurrentPhase()==PHASE_DAMAGE_CAL
				and Duel.GetAttacker()==c and target and target:IsDefensePos()
		end
		local source_condition=source_effect:GetCondition()
		return source_condition==nil or source_condition(source_effect)
	end)
	local value=source_effect:GetValue()
	if type(value)=="function" then
		copied:SetValue(function(e,affected,...)
			return value(source_effect,affected,...)
		end)
	elseif value~=nil then
		copied:SetValue(value)
	end
	c:RegisterEffect(copied)
end
function s.sync_equips(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local tc=s.linked(c)
	if not tc then return end
	local known=s.copied[c]
	if not known then
		known={}
		s.copied[c]=known
	end
	for eq in tc:GetEquipGroup():Iter() do
		if eq:IsFaceup() then
			for _,eff in ipairs({eq:GetOwnEffects()}) do
				if eff:IsHasType(EFFECT_TYPE_EQUIP) and not known[eff] then
					known[eff]=true
					s.mirror(c,eq,eff)
				end
			end
		end
	end
end
