--機械軍曹機械軍曹
--Robotic Knight (Deck Master)
--Scripted by Larry126
local s,id=GetID()
function s.initial_effect(c)
	if not DeckMaster then
		return
	end
	--Deck Master Effect
	local dme1=Effect.CreateEffect(c)
	dme1:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_FIELD)
	dme1:SetCode(EVENT_FREE_CHAIN)
	dme1:SetCondition(s.con)
	dme1:SetOperation(s.op)
	local dme2=dme1:Clone()
	dme2:SetCode(EVENT_CHAIN_END)
	--Merger Effect
	local dme3=Effect.CreateEffect(c)
	dme3:SetDescription(aux.Stringid(id,1))
	dme3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	dme3:SetCode(EVENT_PREDRAW)
	dme3:SetCountLimit(1)
	dme3:SetTarget(s.target)
	dme3:SetCondition(s.dmcon)
	dme3:SetOperation(s.dmop)
	DeckMaster.RegisterAbilities(c,dme1,dme2,dme3)
end
function s.costfilter(c)
	return c:IsRace(RACE_MACHINE) and c:IsDiscardable(REASON_EFFECT)
end
function s.con(e,tp,eg,ep,ev,re,r,rp)
	return Duel.IsExistingMatchingCard(s.costfilter,tp,LOCATION_HAND,0,1,nil) and Duel.IsDeckMaster(tp,id)
end
function s.op(e,tp,eg,ep,ev,re,r,rp)
	if not Duel.SelectYesNo(tp,aux.Stringid(id,0)) then return end
	Duel.Hint(HINT_CARD,tp,id)
	Duel.Hint(HINT_CARD,1-tp,id)
	local ct=Duel.DiscardHand(tp,s.costfilter,1,99,REASON_EFFECT+REASON_DISCARD)
	if ct>0 then
		Duel.Damage(1-tp,ct*500,REASON_EFFECT)
	end
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
if chk==0 then return true end
	Duel.SetChainLimit(aux.FALSE)
end
function s.dmcon(e,tp,eg,ep,ev,re,r,rp)
    local c=e:GetOwner()
    local logical=c:GetLogicalOwner()
    local mask=Duel.GetActiveLogicalPlayerMask()
    if mask==0 then
        return Duel.IsTurnPlayer(tp) and Duel.IsDeckMaster(tp,id)
    end
    -- The merger belongs exclusively to Big Five: check the actual
    -- physical turn player, not the registering effect's callback tp.
    return Duel.IsLogicalPlayerActive(logical)
        and Duel.GetLogicalPlayerSide(logical)==1
        and Duel.GetTurnPlayer()==1
        and Duel.GetLogicalPlayer(1)==logical
        and Duel.IsDeckMasterPlayer(logical,id)
end

function s.dmop(e,tp,eg,ep,ev,re,r,rp)
    local dm=e:GetOwner()
    local logical=dm:GetLogicalOwner()
    local multiplayer=Duel.GetActiveLogicalPlayerMask()~=0
    local ask=multiplayer and Duel.SelectYesNoPlayer or Duel.SelectYesNo
    if not ask(logical,aux.Stringid(id,1)) then return end
    Duel.Hint(HINT_SELECTMSG,tp,aux.Stringid(id,2))
    local DeckMasters={153000019,153000020,153000021,153000022,153000024}
    local chosen
    if multiplayer then
        chosen=Duel.SelectCardsFromCodesPlayer(
            logical,1,1,false,false,table.unpack(DeckMasters))
    else
        chosen=Duel.SelectCardsFromCodes(
            tp,1,1,nil,false,table.unpack(DeckMasters))
    end
    if not chosen then return end
    local card=multiplayer and Duel.GetDeckMasterPlayer(logical)
        or Duel.GetDeckMaster(tp)
    if not card or card~=dm then return end
    local old=card:GetOriginalCode()
    if chosen==old then return end
    Duel.Hint(HINT_CARD,tp,old)
    Duel.Hint(HINT_CARD,tp,chosen)
    local in_zone=not card:IsLocation(LOCATION_ONFIELD)
    if in_zone and multiplayer then
        Duel.SetDeckMasterPlayerState(logical,old,false)
    end
    card:Recreate(chosen,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,true)
    if in_zone then
        if multiplayer then
            Duel.SetDeckMasterPlayerState(logical,chosen,true)
        else
            Duel.Hint(HINT_SKILL,tp,chosen)
        end
    end
end
