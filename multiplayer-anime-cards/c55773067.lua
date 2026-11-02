--はたき落とし
--Drop Off (Anime / multiplayer-compatible)
-- The NORMAL Draw Phase response intentionally matches the canonical
-- Project Ignis/EDOPro card script. The separate delayed activation below
-- supports the requested additional effect-draw rule without interfering.
local s,id=GetID()

function s.initial_effect(c)
    -- Original response to the opponent's normal draw in Draw Phase.
    -- IMPORTANT: no EFFECT_FLAG_DELAY and no extra target-side legality
    -- check here. Both can interfere with the standard draw window.
    local e1=Effect.CreateEffect(c)
    e1:SetType(EFFECT_TYPE_ACTIVATE)
    e1:SetCategory(CATEGORY_TOGRAVE+CATEGORY_HANDES)
    e1:SetCode(EVENT_DRAW)
    e1:SetCondition(s.normal_draw)
    e1:SetTarget(s.target)
    e1:SetOperation(s.activate)
    c:RegisterEffect(e1)

    -- Custom anime extension: respond to cards drawn by effects, including
    -- effect draws during another phase or during your own turn.
    local e2=e1:Clone()
    e2:SetProperty(EFFECT_FLAG_DELAY)
    e2:SetCondition(s.effect_draw)
    c:RegisterEffect(e2)
end

function s.normal_draw(e,tp,eg,ep,ev,re,r,rp)
    -- Identical event condition to the original EDOPro Drop Off script.
    return ep~=tp and (r&REASON_RULE)~=0
end

function s.effect_draw(e,tp,eg,ep,ev,re,r,rp)
    -- The rule-based draw is handled exclusively by the original activation.
    -- Never present duplicate prompts on the normal Draw Phase draw.
    return ep~=tp and (r&REASON_RULE)==0
        and ((r&REASON_EFFECT)~=0 or re~=nil)
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
    -- Original activation check returns true: the Draw event provides
    -- the target group, even if its cards are not visible to this player.
    if chk==0 then return true end
    Duel.SetTargetCard(eg)
    Duel.SetOperationInfo(0,CATEGORY_HANDES,nil,0,1-tp,1)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
    -- Only cards from THIS draw event and still related to this activation.
    -- Never discard unrelated cards that were already in the opponent's hand.
    local drawn=eg:Filter(Card.IsRelateToEffect,nil,e)
    if #drawn==0 then return end
    local hand=drawn:Filter(Card.IsLocation,nil,LOCATION_HAND)
    if #hand>0 then
        -- Custom anime behavior: if multiple cards were drawn at once,
        -- discard all of the drawn cards; standard draw discards one.
        Duel.SendtoGrave(hand,REASON_EFFECT|REASON_DISCARD)
    end
end
