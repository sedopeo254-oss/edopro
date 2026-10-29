--はたき落とし
--Drop Off (Anime / multiplayer-compatible)
local s,id=GetID()

function s.initial_effect(c)
    local e1=Effect.CreateEffect(c)
    e1:SetType(EFFECT_TYPE_ACTIVATE)
    e1:SetCategory(CATEGORY_TOGRAVE+CATEGORY_HANDES)
    e1:SetCode(EVENT_DRAW)
    e1:SetCondition(s.condition)
    e1:SetTarget(s.target)
    e1:SetOperation(s.activate)
    c:RegisterEffect(e1)
end

-- The drawn card must come from the current opponent during THEIR Draw Phase.
-- Do not require REASON_RULE: an additional draw by an effect during the
-- opponent's Draw Phase is still a card drawn during that phase.
function s.condition(e,tp,eg,ep,ev,re,r,rp)
    return ep~=tp
        and Duel.GetTurnPlayer()==ep
        and Duel.GetCurrentPhase()==PHASE_DRAW
        and eg and #eg>0
end

function s.drawn_filter(c,ep)
    return c:IsLocation(LOCATION_HAND) and c:IsControler(ep)
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
    local drawn=eg:Filter(s.drawn_filter,nil,ep)
    if chk==0 then return #drawn>0 end
    -- Target only cards from this exact Draw event, not another card the
    -- opponent already held. The engine tracks their relation through Chain.
    Duel.SetTargetCard(drawn)
    Duel.SetOperationInfo(0,CATEGORY_HANDES,drawn,1,ep,LOCATION_HAND)
end

function s.relate_filter(c,e,ep)
    return c:IsRelateToEffect(e) and s.drawn_filter(c,ep)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
    local drawn=eg:Filter(s.relate_filter,nil,e,ep)
    if #drawn==0 then return end
    -- If an effect drew multiple cards at once during Draw Phase,
    -- the opponent chooses one of those drawn cards, not any old hand card.
    local chosen=drawn
    if #drawn>1 then
        Duel.Hint(HINT_SELECTMSG,ep,HINTMSG_TOGRAVE)
        chosen=drawn:Select(ep,1,1,nil)
    end
    Duel.SendtoGrave(chosen,REASON_EFFECT|REASON_DISCARD)
end
