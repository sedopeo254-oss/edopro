--F・G・D
--Five-Headed Dragon
--Dragon Revival Ritual compatibility added
local s,id=GetID()
function s.initial_effect(c)
	c:EnableReviveLimit()
	Fusion.AddProcMixN(c,true,true,aux.FilterBoolFunctionEx(Card.IsRace,RACE_DRAGON),5)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_INDESTRUCTABLE_BATTLE)
	e2:SetValue(s.batfilter)
	c:RegisterEffect(e2)
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE)
	e3:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e3:SetCode(EFFECT_SPSUMMON_CONDITION)
	e3:SetValue(s.splimit)
	c:RegisterEffect(e3)
end
function s.batfilter(e,c)
	return c:IsAttribute(
		ATTRIBUTE_DARK|ATTRIBUTE_WIND|ATTRIBUTE_FIRE|ATTRIBUTE_WATER|ATTRIBUTE_EARTH)
end
function s.splimit(e,se,sp,st)
	if se and se:GetHandler() and se:GetHandler():IsCode(120000016) then
		return true
	end
	return aux.fuslimit(e,se,sp,st)
end
