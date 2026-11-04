--はたき落とし
--Drop Off (Custom Anime): all monsters gain 0 ATK and 0 DEF.
-- Intentionally NO longer reacts to the Draw Phase or any draw effect.
local s,id=GetID()

function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCategory(CATEGORY_ATKCHANGE+CATEGORY_DEFCHANGE)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end

function s.monsters(tp)
	local g=Group.CreateGroup()
	local mask=Duel.GetActiveLogicalPlayerMask
		and Duel.GetActiveLogicalPlayerMask() or 0
	if mask~=0 then
		-- 2v1/3v1 have independent monster fields for each logical player.
		for p=0,3 do
			if (mask&(1<<p))~=0 then
				g:Merge(Duel.GetPlayerFieldGroup(p,LOCATION_MZONE))
			end
		end
	else
		g:Merge(Duel.GetFieldGroup(tp,LOCATION_MZONE,LOCATION_MZONE))
	end
	return g
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	local g=s.monsters(tp)
	if chk==0 then return #g>0 end
	Duel.SetOperationInfo(0,CATEGORY_ATKCHANGE,g,#g,0,0)
	Duel.SetOperationInfo(0,CATEGORY_DEFCHANGE,g,#g,0,0)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local g=s.monsters(tp)
	for tc in aux.Next(g) do
		if not tc:IsImmuneToEffect(e) then
			local atk=Effect.CreateEffect(e:GetHandler())
			atk:SetType(EFFECT_TYPE_SINGLE)
			atk:SetCode(EFFECT_UPDATE_ATTACK)
			atk:SetValue(0)
			atk:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_END)
			tc:RegisterEffect(atk)

			local def=atk:Clone()
			def:SetCode(EFFECT_UPDATE_DEFENSE)
			tc:RegisterEffect(def)
		end
	end
end
