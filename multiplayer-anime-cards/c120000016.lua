--邪龍復活の儀式
--Dragon Revival Ritual (Anime / Virtual World)
--Base ritual procedure updated from Project Ignis unofficial script.
--Multiplayer Big Five Deck Master call added for EDOPro 2v1/3v1.
local s,id=GetID()
local FIVE_HEADED_DRAGON=99267150
local FIVE_HEADED_DRAGON_ANIME=511013020
local REQUIRED_ATTRIBUTES=ATTRIBUTE_DARK|ATTRIBUTE_EARTH|ATTRIBUTE_FIRE|ATTRIBUTE_WATER|ATTRIBUTE_WIND
local BIG_FIVE_RITUAL_ATTRIBUTE={
	[153000020]=ATTRIBUTE_DARK, [153000013]=ATTRIBUTE_DARK,   --Jinzo
	[153000021]=ATTRIBUTE_WATER,[153000003]=ATTRIBUTE_WATER,  --Deepsea Warrior
	[153000022]=ATTRIBUTE_WIND, [153000005]=ATTRIBUTE_WIND,   --Nightmare Penguin: WIND only for this ritual
	[153000023]=ATTRIBUTE_EARTH,[153000008]=ATTRIBUTE_EARTH,  --Judge Man
	[153000024]=ATTRIBUTE_FIRE, [153000009]=ATTRIBUTE_FIRE    --Robotic Knight
}

function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetTarget(s.target)
	e1:SetOperation(s.activate)
	c:RegisterEffect(e1)
end
s.listed_names={FIVE_HEADED_DRAGON,FIVE_HEADED_DRAGON_ANIME,
	153000020,153000021,153000022,153000023,153000024,
	153000013,153000003,153000005,153000008,153000009}
s.fit_monster={FIVE_HEADED_DRAGON,FIVE_HEADED_DRAGON_ANIME}

function s.logical_player(tp)
	if Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0 then
		return Duel.GetLogicalPlayer(tp) or tp
	end
	return tp
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then
		if not e:IsHasType(EFFECT_TYPE_ACTIVATE) then return false end
		if DeckMaster and DeckMaster.DragonRevivalEnabled
			and DeckMaster.CanSummonDragonRevivalMasters then
			return DeckMaster.CanSummonDragonRevivalMasters(s.logical_player(tp),e)
		end
		return true
	end
	if DeckMaster and DeckMaster.DragonRevivalEnabled then
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,5,tp,0)
	end
end

function s.register_five_headed_deck_master(c,tp,logical)
	if not DeckMaster or not DeckMaster.MakeFieldDeckMaster then return end
	local ge=Effect.CreateEffect(c)
	ge:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	ge:SetCode(EVENT_SPSUMMON_SUCCESS)
	ge:SetLabel(logical)
	ge:SetOperation(s.dmop)
	ge:SetReset(RESET_PHASE+PHASE_END+RESET_SELF_TURN,5)
	Duel.RegisterEffect(ge,tp)
end

function s.dmfilter(c,logical)
	if not c:IsCode(FIVE_HEADED_DRAGON,FIVE_HEADED_DRAGON_ANIME)
		or not c:IsRitualSummoned() then return false end
	if Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0 then
		return c:GetLogicalControler()==logical
	end
	return c:IsControler(logical)
end

function s.dmop(e,tp,eg,ep,ev,re,r,rp)
	if not DeckMaster or not DeckMaster.MakeFieldDeckMaster then return end
	local logical=e:GetLabel()
	local tc=eg:Filter(s.dmfilter,nil,logical):GetFirst()
	if not tc then return end
	DeckMaster.MakeFieldDeckMaster(tc,logical,true)
	e:Reset()
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
	local c=e:GetHandler()
	local logical=s.logical_player(tp)
	if DeckMaster and DeckMaster.DragonRevivalEnabled
		and DeckMaster.SummonDragonRevivalMasters then
		local ct=DeckMaster.SummonDragonRevivalMasters(logical,e)
		if ct<5 then return end
		s.register_five_headed_deck_master(c,tp,logical)
	end

	local sg=Group.CreateGroup()
	sg:KeepAlive()
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_SPSUMMON_PROC_G)
	e1:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_SET_AVAILABLE)
	e1:SetRange(0xff)
	e1:SetLabel(REQUIRED_ATTRIBUTES)
	e1:SetLabelObject(sg)
	e1:SetCondition(s.spcon)
	e1:SetOperation(s.spop)
	e1:SetReset(RESET_PHASE+PHASE_END+RESET_SELF_TURN,5)
	e1:SetValue(SUMMON_TYPE_RITUAL)
	c:RegisterEffect(e1)
	local g=Duel.GetMatchingGroup(s.fhdcode,tp,0xff,0,nil)
	local tc=g:GetFirst()
	while tc do
		local e2=Effect.CreateEffect(c)
		e2:SetType(EFFECT_TYPE_FIELD)
		e2:SetCode(EFFECT_SPSUMMON_PROC_G)
		e2:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_SET_AVAILABLE)
		e2:SetRange(0xff)
		e2:SetLabelObject(e1)
		e2:SetCondition(s.spcon2)
		e2:SetOperation(s.spop2)
		e2:SetReset(RESET_PHASE+PHASE_END+RESET_SELF_TURN,5)
		e2:SetValue(SUMMON_TYPE_RITUAL)
		tc:RegisterEffect(e2)
		tc=g:GetNext()
	end
end

function s.ritual_attribute(c,att)
	local mapped=BIG_FIVE_RITUAL_ATTRIBUTE[c:GetOriginalCode()]
	local attribute=mapped or c:GetAttribute()
	return attribute&att~=0
end

function s.fhdcode(c)
	return c:IsCode(FIVE_HEADED_DRAGON,FIVE_HEADED_DRAGON_ANIME)
end
function s.filter(c,e,tp)
	return s.fhdcode(c) and c:IsCanBeSpecialSummoned(e,SUMMON_TYPE_RITUAL,tp,false,true)
end
function s.spcon(e,c,og)
	if c==nil then return true end
	local tp=e:GetHandlerPlayer()
	local label=e:GetLabel()
	if label<=0 then return false end
	local i=0x1
	local spchk=0
	while i<0x40 do
		if (label&i)==i then spchk=spchk+1 end
		i=i*2
	end
	if not Duel.GetRitualMaterial(tp):IsExists(s.ritual_attribute,1,nil,label) then return false end
	return spchk>1 or Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_HAND,0,1,nil,e,tp)
end
function s.spop(e,tp,eg,ep,ev,re,r,rp,c,og)
	Duel.Hint(HINT_CARD,0,id)
	local label=e:GetLabel()
	local g=e:GetLabelObject()
	if label<=0 then return false end
	local attchk=0
	local mg=Duel.GetRitualMaterial(tp)
	local i=0x1
	local spchk=0
	while i<0x40 do
		if (label&i)==i then
			spchk=spchk+1
			if mg:IsExists(s.ritual_attribute,1,nil,i) then attchk=attchk+i end
		end
		i=i*2
	end
	repeat
		local att=Duel.AnnounceAttribute(tp,1,attchk)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
		local mat=mg:FilterSelect(tp,s.ritual_attribute,1,1,nil,att)
		g:Merge(mat)
		mg:Sub(mat)
		Duel.ReleaseRitualMaterial(mat)
		label=label-att
		e:SetLabel(label)
		attchk=attchk-att
		spchk=spchk-1
	until not mg:IsExists(s.ritual_attribute,1,nil,attchk) or attchk==0 or spchk==0
		or (spchk==1 and not Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_HAND,0,1,nil,e,tp))
		or not Duel.SelectYesNo(tp,93)
	if spchk==0 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local tg=Duel.SelectMatchingCard(tp,s.filter,tp,LOCATION_HAND,0,1,1,nil,e,tp)
		local rc=tg:GetFirst()
		if rc then
			rc:SetMaterial(g)
			og:Merge(tg)
			g:DeleteGroup()
		end
	end
end
function s.spcon2(e,c,og)
	if c==nil then return true end
	local tp=e:GetHandlerPlayer()
	local label=e:GetLabelObject():GetLabel()
	if label<=0 then return false end
	local i=0x1
	local spchk=0
	while i<0x40 do
		if (label&i)==i then spchk=spchk+1 end
		i=i*2
	end
	if not Duel.GetRitualMaterial(tp):IsExists(s.ritual_attribute,1,nil,label) then return false end
	return spchk>1 or Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_HAND,0,1,nil,e,tp)
end
function s.spop2(e,tp,eg,ep,ev,re,r,rp,c,og)
	Duel.Hint(HINT_CARD,0,id)
	local label=e:GetLabelObject():GetLabel()
	local g=e:GetLabelObject():GetLabelObject()
	if label<=0 then return false end
	local attchk=0
	local mg=Duel.GetRitualMaterial(tp)
	local i=0x1
	local spchk=0
	while i<0x40 do
		if (label&i)==i then
			spchk=spchk+1
			if mg:IsExists(s.ritual_attribute,1,nil,i) then attchk=attchk+i end
		end
		i=i*2
	end
	repeat
		local att=Duel.AnnounceAttribute(tp,1,attchk)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
		local mat=mg:FilterSelect(tp,s.ritual_attribute,1,1,nil,att)
		g:Merge(mat)
		mg:Sub(mat)
		Duel.ReleaseRitualMaterial(mat)
		label=label-att
		e:GetLabelObject():SetLabel(label)
		attchk=attchk-att
		spchk=spchk-1
	until not mg:IsExists(s.ritual_attribute,1,nil,attchk) or attchk==0 or spchk==0
		or (spchk==1 and not Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_HAND,0,1,nil,e,tp))
		or not Duel.SelectYesNo(tp,93)
	if spchk==0 then
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
		local tg=Duel.SelectMatchingCard(tp,s.filter,tp,LOCATION_HAND,0,1,1,nil,e,tp)
		local rc=tg:GetFirst()
		if rc then
			rc:SetMaterial(g)
			og:Merge(tg)
			g:DeleteGroup()
		end
	end
end
