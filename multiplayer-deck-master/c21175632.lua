--聖女ジャンヌ
--St. Joan
local s,id=GetID()
function s.initial_effect(c)
	--fusion material
	c:EnableReviveLimit()
	Fusion.AddProcMix(c,true,true,84080938,57579381)
	--Battle City / Virtual World Quick Attack exemption.
	--Those rule cards block newly Extra-Deck-Summoned monsters unless they
	--carry effect code 511004016, so St. Joan can attack that same turn.
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(511004016)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	c:RegisterEffect(e1)
end
s.material_setcode=SET_DARKLORD
