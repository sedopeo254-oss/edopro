--ジャッジ・マン (Deck Master)
--Judge Man (Deck Master)
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
-- Dedicated 2 vs 1 mode; do not change Standard, 3v1 or Battle Royale.
local TWO_VS_ONE_FLAG=0x8000000000

function s.is_two_vs_one()
	return Duel.IsDuelType(TWO_VS_ONE_FLAG)
end

function s.team_monsters()
	-- These groups refer to the actual, independent P1 and P2 fields,
	-- regardless of whose field is currently projected on screen.
	local p1=Duel.GetPlayerFieldGroup(0,LOCATION_MZONE):Filter(Card.IsAbleToRemove,nil)
	local p2=Duel.GetPlayerFieldGroup(1,LOCATION_MZONE):Filter(Card.IsAbleToRemove,nil)
	return p1,p2
end

function s.con(e,tp,eg,ep,ev,re,r,rp)
	if s.is_two_vs_one() then
		if not Duel.CheckLPCost(tp,1000) or not Duel.IsDeckMaster(tp,id) then
			return false
		end
		local p1,p2=s.team_monsters()
		return #p1+#p2>0
	end
	-- Preserve the original condition verbatim outside the 2v1 mode.
	return Duel.IsExistingMatchingCard(Card.IsAbleToRemove,tp,0,LOCATION_MZONE,1,nil)
		and Duel.CheckLPCost(tp,1000) and Duel.IsDeckMaster(tp,id)
end
function s.op(e,tp,eg,ep,ev,re,r,rp)
	local two_vs_one=s.is_two_vs_one()
	if two_vs_one then
		-- Only Big Five (the Deck Master owner) answers this prompt.
		if not Duel.SelectYesNoPlayer(e:GetOwner():GetLogicalOwner(),aux.Stringid(id,0)) then return end
	elseif not Duel.SelectYesNo(tp,aux.Stringid(id,0)) then
		return
	end
	Duel.PayLPCost(tp,1000)
	Duel.Hint(HINT_CARD,tp,id)
	Duel.Hint(HINT_CARD,1-tp,id)
	Duel.BreakEffect()

	if two_vs_one then
		local p1,p2=s.team_monsters()
		local all=Group.CreateGroup()
		all:Merge(p1)
		all:Merge(p2)
		if #all==0 or Duel.Remove(all,POS_FACEUP,REASON_EFFECT)==0 then return end

		-- Count cards actually banished, separated by their pre-banish field.
		-- Do not assign combined team damage to only one logical player.
		local removed=Duel.GetOperatedGroup()
		for player=0,1 do
			local field_group=(player==0) and p1 or p2
			local count=removed:FilterCount(function(tc,g)
				return tc:IsLocation(LOCATION_REMOVED) and g:IsContains(tc)
			end,nil,field_group)
			if count>0 and Duel.IsLogicalPlayerActive(player) then
				-- Last 'false' disables Let Me Take It redirection:
				-- damage belongs strictly to this monster's controller.
				Duel.DamagePlayer(player,count*500,REASON_EFFECT,false,tp,false)
			end
		end
		return
	end

	-- Original effect is completely unchanged outside 2 vs 1.
	local g=Duel.GetMatchingGroup(Card.IsAbleToRemove,tp,0,LOCATION_MZONE,nil)
	if Duel.Remove(g,POS_FACEUP,REASON_EFFECT)>0 then
		local og=Duel.GetOperatedGroup()
		local ct=og:FilterCount(Card.IsLocation,nil,LOCATION_REMOVED)
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
    local DeckMasters={153000019,153000020,153000021,153000023,153000024}
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
