--機械仕掛けの夜－クロック・ワーク・ナイト－ (Anime)
--Clockwork Night (Anime)
--Snapshot version: only monsters that are already on the field when this card resolves are affected.
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCountLimit(1)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
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
function s.isopponent(owner,other)
	if owner==nil or other==nil or owner==other then return false end
	if s.is3v1() then
		return (owner<3 and other==3) or (owner==3 and other<3)
	end
	return owner~=other
end
function s.clockactive(e)
	local sc=e:GetLabelObject()
	return sc and sc:IsFaceup() and sc:IsLocation(LOCATION_SZONE) and not sc:IsDisabled()
end
function s.apply(sc,tc,atkchange,make_machine)
	if make_machine then
		local e1=Effect.CreateEffect(sc)
		e1:SetType(EFFECT_TYPE_SINGLE)
		e1:SetCode(EFFECT_CHANGE_RACE)
		e1:SetCondition(s.clockactive)
		e1:SetValue(RACE_MACHINE)
		e1:SetReset(RESET_EVENT|RESETS_STANDARD)
		e1:SetLabelObject(sc)
		tc:RegisterEffect(e1)
	end
	local e2=Effect.CreateEffect(sc)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(EFFECT_UPDATE_ATTACK)
	e2:SetCondition(s.clockactive)
	e2:SetValue(atkchange)
	e2:SetReset(RESET_EVENT|RESETS_STANDARD)
	e2:SetLabelObject(sc)
	tc:RegisterEffect(e2)
end
function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local sc=e:GetHandler()
	if not sc:IsRelateToEffect(e) then return end
	local mask=Duel.GetActiveLogicalPlayerMask()
	if mask~=0 then
		local owner=s.logical(sc)
		for p=0,3 do
			if mask&(1<<p)~=0 then
				local g=Duel.GetPlayerFieldGroup(p,LOCATION_MZONE)
				if p==owner then
					for tc in aux.Next(g) do
						s.apply(sc,tc,500,false)
					end
				elseif s.isopponent(owner,p) then
					for tc in aux.Next(g) do
						s.apply(sc,tc,-500,true)
					end
				end
			end
		end
		return
	end
	--Normal 1v1 duel fallback.
	for tc in aux.Next(Duel.GetFieldGroup(tp,LOCATION_MZONE,0)) do
		s.apply(sc,tc,500,false)
	end
	for tc in aux.Next(Duel.GetFieldGroup(tp,0,LOCATION_MZONE)) do
		s.apply(sc,tc,-500,true)
	end
end
