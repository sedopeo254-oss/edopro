--機械仕掛けの夜－クロック・ワーク・ナイト－ (Anime)
--Clockwork Night (Anime)
--Anime multiplayer: only opponents become Machines; controller +500 ATK, opponents -500 ATK.
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCountLimit(1)
	c:RegisterEffect(e1)
	--All opponent monsters become Machine, including monsters Summoned in Defense Position
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_CHANGE_RACE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e2:SetTarget(s.isopponent)
	e2:SetValue(RACE_MACHINE)
	c:RegisterEffect(e2)
	--My monsters gain 500 ATK; opponent monsters lose 500 ATK
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_FIELD)
	e3:SetCode(EFFECT_UPDATE_ATTACK)
	e3:SetRange(LOCATION_SZONE)
	e3:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e3:SetTarget(s.atktg)
	e3:SetValue(s.atkval)
	c:RegisterEffect(e3)
end
function s.logical(c)
	local p=c:GetLogicalControler()
	return p~=nil and p or c:GetControler()
end
function s.is3v1()
	if Duel.GetActiveLogicalPlayerMask()==0 then return false end
	return Duel.GetLogicalPlayerSide(0)==0
		and Duel.GetLogicalPlayerSide(1)==0
		and Duel.GetLogicalPlayerSide(2)==0
		and Duel.GetLogicalPlayerSide(3)==1
end
function s.ismine(e,c)
	return s.logical(c)==s.logical(e:GetHandler())
end
function s.isopponent(e,c)
	local hp=s.logical(e:GetHandler())
	local cp=s.logical(c)
	if hp==nil or cp==nil or hp==cp then return false end
	if s.is3v1() then
		return (hp<3 and cp==3) or (hp==3 and cp<3)
	end
	--Normal Duel and Battle Royale: every other logical player is an opponent.
	return hp~=cp
end
function s.atktg(e,c)
	return s.ismine(e,c) or s.isopponent(e,c)
end
function s.atkval(e,c)
	return s.ismine(e,c) and 500 or -500
end
