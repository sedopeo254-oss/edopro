--はたき落とし
--Drop Off (Anime / fast draw response / multiplayer)
local s,id=GetID()

function s.initial_effect(c)
    -- Quick Trap activation after an opponent's draw event.
    -- EFFECT_FLAG_DELAY prevents effect-based draws in a resolving Chain
    -- from missing their activation window.
    local e1=Effect.CreateEffect(c)
    e1:SetType(EFFECT_TYPE_ACTIVATE)
    e1:SetProperty(EFFECT_FLAG_DELAY)
    e1:SetCategory(CATEGORY_TOGRAVE+CATEGORY_HANDES)
    e1:SetCode(EVENT_DRAW)
    e1:SetCondition(s.condition)
    e1:SetTarget(s.target)
    e1:SetOperation(s.activate)
    c:RegisterEffect(e1)
end

-- Activate after either:
-- 1) a draw during the opponent's own Draw Phase (including normal draw);
-- 2) a draw caused by an effect, in ANY phase or on either player's turn.
-- A normal/rule-based draw outside those windows is not a valid trigger.
function s.condition(e,tp,eg,ep,ev,re,r,rp)
    if ep==tp or not eg or #eg==0 then return false end
    local their_draw_phase=Duel.GetTurnPlayer()==ep
        and Duel.GetCurrentPhase()==PHASE_DRAW
    local effect_draw=(r and (r&REASON_EFFECT)~=0) or re~=nil
    return their_draw_phase or effect_draw
end

-- Never touch another card previously held by the opponent.
function s.drawn_filter(c,ep)
    return c:IsLocation(LOCATION_HAND) and c:IsControler(ep)
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
    local drawn=eg:Filter(s.drawn_filter,nil,ep)
    if chk==0 then return #drawn>0 end
    -- Remember the exact cards from this EVENT_DRAW across the Chain.
    Duel.SetTargetCard(drawn)
    Duel.SetOperationInfo(0,CATEGORY_TOGRAVE,drawn,#drawn,ep,LOCATION_HAND)
    Duel.SetOperationInfo(0,CATEGORY_HANDES,drawn,#drawn,ep,LOCATION_HAND)
end

function s.relate_filter(c,e,ep)
    return c:IsRelateToEffect(e) and s.drawn_filter(c,ep)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
    -- If 1 was drawn, discard 1; if 3 were drawn, discard all 3.
    -- Do not allow a selection from the opponent's pre-existing hand.
    local drawn=eg:Filter(s.relate_filter,nil,e,ep)
    if #drawn>0 then
        Duel.SendtoGrave(drawn,REASON_EFFECT|REASON_DISCARD)
    end
end
