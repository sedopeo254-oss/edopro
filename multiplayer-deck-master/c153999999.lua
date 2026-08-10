--Virtual World
--Independent logical-player Deck Master support
local s,id=GetID()
function s.initial_effect(c)
	aux.EnableExtraRules(c,s,s.VirtualWorldStart)
end
function s.VirtualWorldStart()
	--Face-up Defense Position is allowed.
	local e1=Effect.GlobalEffect()
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_LIGHT_OF_INTERVENTION)
	e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET+EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
	e1:SetTargetRange(1,1)
	Duel.RegisterEffect(e1,0)
	--Monsters Special Summoned from the Extra Deck, or DIVINE monsters revived
	--from the GY, cannot attack that turn unless explicitly exempted.
	local e2=Effect.GlobalEffect()
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_CANNOT_ATTACK)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e2:SetTarget(function(e,c)
		return c:IsStatus(STATUS_SPSUMMON_TURN)
			and (c:IsSummonLocation(LOCATION_EXTRA)
				or (c:IsAttribute(ATTRIBUTE_DIVINE) and c:IsSummonLocation(LOCATION_GRAVE)))
			and not c:IsHasEffect(511004016)
	end)
	Duel.RegisterEffect(e2,0)

	--Creating this token loads the Deck Master System script.
	local dm=Duel.CreateToken(0,153000000)
	Duel.ConfirmCards(1,dm)
	if Duel.GetActiveLogicalPlayerMask()~=0 then
		--In multiplayer the rule is enabled directly and every active logical player
		--receives an independent Deck Master selection.
		DeckMaster.RegisterRules(dm)
		return
	end
	--Keep the original two-player agreement flow outside multiplayer.
	if Duel.SelectYesNo(0,aux.Stringid(id,0))
		and Duel.SelectYesNo(1,aux.Stringid(id,0)) then
		Duel.Hint(HINT_CARD,0,153000000)
		Duel.Hint(HINT_OPSELECTED,0,aux.Stringid(id,1))
		Duel.Hint(HINT_OPSELECTED,1,aux.Stringid(id,1))
		DeckMaster.RegisterRules(dm)
	else
		Duel.Hint(HINT_OPSELECTED,0,aux.Stringid(id,2))
		Duel.Hint(HINT_OPSELECTED,1,aux.Stringid(id,2))
	end
end
