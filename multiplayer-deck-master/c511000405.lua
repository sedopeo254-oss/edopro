--機械仕掛けの夜－クロック・ワーク・ナイト－ (Anime)
--Clockwork Night (Anime)
--Opponent effect is a snapshot at activation; newly Summoned opponent monsters are not affected.
--The controller's monsters already on the field get +500 ATK, and Machine monsters Summoned later
--by that same logical player also get +500 ATK while this card remains active.
local s,id=GetID()
function s.initial_effect(c)
	--Activate
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetCountLimit(1)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
	--Machine monsters the controller Summons after activation also gain 500 ATK.
	--Monsters that were already present are marked and use the snapshot bonus instead,
	--preventing an existing Machine from receiving +1000 by accident.
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_UPDATE_ATTACK)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTargetRange(LOCATION_MZONE,LOCATION_MZONE)
	e2:SetTarget(s.machineboosttarget)
	e2:SetValue(500)
	c:RegisterEffect(e2)
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
function s.machineboosttarget(e,c)
	local sc=e:GetHandler()
	if not sc or not sc:IsFaceup() or sc:IsDisabled() then return false end
	local owner=s.logical(sc)
	return s.logical(c)==owner and c:IsRace(RACE_MACHINE)
		and c:GetFlagEffect(id)==0
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
function s.markownsnapshot(tc)
	--Marks only the controller's monsters that existed when Clockwork Night resolved.
	--If one leaves the field and returns later, the flag resets and a Machine version can
	--receive the live +500 bonus normally.
	tc:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1)
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
						s.markownsnapshot(tc)
						s.apply(sc,tc,500,false)
					end
				elseif s.isopponent(owner,p) then
					--Snapshot only: every opposing monster currently on the field,
					--including Defense Position monsters, becomes Machine and loses 500 ATK.
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
		s.markownsnapshot(tc)
		s.apply(sc,tc,500,false)
	end
	for tc in aux.Next(Duel.GetFieldGroup(tp,0,LOCATION_MZONE)) do
		s.apply(sc,tc,-500,true)
	end
end
