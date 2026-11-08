-- Last Turn (anime / Deck Master succession variant)
-- This override is isolated to Inherited Duel Mode. Outside that mode,
-- the user's uploaded Last Turn behavior is kept unchanged.
local s,id=GetID()
local DUEL_INHERITED_DUEL=0x8000000000

local function is_inherited_duel()
    return Duel.IsDuelType(DUEL_INHERITED_DUEL)
end

function s.initial_effect(c)
    local e1=Effect.CreateEffect(c)
    e1:SetType(EFFECT_TYPE_ACTIVATE)
    e1:SetCategory(CATEGORY_SPECIAL_SUMMON)
    e1:SetCode(EVENT_FREE_CHAIN)
    e1:SetHintTiming(0,TIMING_STANDBY_PHASE)
    e1:SetCondition(s.condition)
    e1:SetTarget(s.target)
    e1:SetOperation(s.operation)
    c:RegisterEffect(e1)
end

-- Both versions require an opponent's turn and 1000 or fewer LP.
function s.condition(e,tp,eg,ep,ev,re,r,rp)
    return Duel.GetLP(tp)<=1000 and Duel.GetTurnPlayer()~=tp
end

local function get_zone_master(p)
    -- DeckMasterZone contains actual Deck Masters set aside by the
    -- custom Deck Master rule; it is NOT the normal Deck.
    return DeckMasterZone and DeckMasterZone[p] or nil
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
    if chk==0 then
        if not Duel.IsExistingMatchingCard(nil,tp,LOCATION_MZONE,0,1,nil) then
            return false
        end
        if is_inherited_duel() then
            -- Unlike Duel.GetDeckMasterPlayer, this rejects Deck Masters
            -- already on the field; the text specifically says "from zone".
            local master=get_zone_master(1-tp)
            if not master or not Duel.SummonDeckMasterPlayer then return false end
            local ignore_condition=DeckMaster and DeckMaster.IsTeamSharedDeckMasterCode
                and DeckMaster.IsTeamSharedDeckMasterCode(master:GetOriginalCode()) or false
            return master:IsCanBeSpecialSummoned(e,0,1-tp,ignore_condition,false)
        end
        return true
    end
    if is_inherited_duel() then
        -- The Deck Master Zone is virtual, not LOCATION_DECK.
        Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,1-tp,0)
    else
        -- Preserve the user's uploaded standard/non-inherited script.
        Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,1-tp,LOCATION_DECK)
    end
end

function s.spfilter(c,e,tp)
    return c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end

local function register_no_battle_damage(e,tp)
    local prevent=Effect.CreateEffect(e:GetHandler())
    prevent:SetType(EFFECT_TYPE_FIELD)
    prevent:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
    prevent:SetCode(EFFECT_AVOID_BATTLE_DAMAGE)
    prevent:SetTargetRange(1,1)
    -- Remain active through the forced battle and its Damage Step.
    prevent:SetReset(RESET_PHASE|PHASE_END)
    Duel.RegisterEffect(prevent,tp)
end

local function register_end_phase_check(e,tp)
    local check=Effect.CreateEffect(e:GetHandler())
    check:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
    check:SetCode(EVENT_PHASE+PHASE_END)
    check:SetCountLimit(1)
    if Duel.IsPhase(PHASE_END) then
        check:SetReset(RESET_PHASE|PHASE_END,2)
    else
        check:SetReset(RESET_PHASE|PHASE_END)
    end
    check:SetOperation(is_inherited_duel() and s.checkop_inherited or s.checkop_legacy)
    Duel.RegisterEffect(check,tp)
end

function s.operation(e,tp,eg,ep,ev,re,r,rp)
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FACEUP)
    local group=Duel.SelectMatchingCard(tp,nil,tp,LOCATION_MZONE,0,1,1,nil)
    local selected=group:GetFirst()
    -- Resolve the original selection before collecting both hands / fields.
    local all_cards=Duel.GetFieldGroup(tp,LOCATION_HAND|LOCATION_ONFIELD,
        LOCATION_HAND|LOCATION_ONFIELD)
    if selected then all_cards:RemoveCard(selected) end
    Duel.SendtoGrave(all_cards,REASON_EFFECT)

    local opponent=1-tp
    if is_inherited_duel() then
        -- Only this mode: select the single genuine Deck Master in the
        -- opponent's reserved Deck Master Zone, not a regular Deck monster.
        local master=get_zone_master(opponent)
        if master and Duel.SummonDeckMasterPlayer then
            Duel.Hint(HINT_SELECTMSG,opponent,HINTMSG_SPSUMMON)
            Duel.BreakEffect()
            -- The helper preserves the Deck Master flag and its abilities.
            local result=Duel.SummonDeckMasterPlayer(opponent,POS_FACEUP_ATTACK)
            if result and result>0 and selected
                and selected:IsLocation(LOCATION_MZONE)
                and master:IsLocation(LOCATION_MZONE) then
                register_no_battle_damage(e,tp)
                Duel.ForceAttack(master,selected)
            end
        end
    else
        -- Original uploaded behavior for every other duel mode.
        Duel.Hint(HINT_SELECTMSG,opponent,HINTMSG_SPSUMMON)
        local g=Duel.SelectMatchingCard(opponent,s.spfilter,opponent,
            LOCATION_DECK,0,1,1,nil,e,tp)
        local sc=g:GetFirst()
        if sc then
            Duel.BreakEffect()
            Duel.SpecialSummon(sc,0,opponent,opponent,false,false,POS_FACEUP_ATTACK)
            local avoid=Effect.CreateEffect(e:GetHandler())
            avoid:SetType(EFFECT_TYPE_FIELD)
            avoid:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
            avoid:SetCode(EFFECT_AVOID_BATTLE_DAMAGE)
            avoid:SetTargetRange(1,1)
            avoid:SetReset(RESET_PHASE|PHASE_DAMAGE)
            Duel.RegisterEffect(avoid,tp)
            if selected then Duel.ForceAttack(sc,selected) end
        end
    end
    register_end_phase_check(e,tp)
end

-- NEW: exactly ONE monster may remain anywhere on the field.
-- No monster, two or more monsters (even on one side), or one on each => DRAW.
function s.checkop_inherited(e,tp,eg,ep,ev,re,r,rp)
    local a=Duel.GetFieldGroupCount(0,LOCATION_MZONE,0)
    local b=Duel.GetFieldGroupCount(1,LOCATION_MZONE,0)
    if a==1 and b==0 then
        Duel.Win(0,WIN_REASON_LAST_TURN)
    elseif a==0 and b==1 then
        Duel.Win(1,WIN_REASON_LAST_TURN)
    else
        Duel.Win(PLAYER_NONE,WIN_REASON_LAST_TURN)
    end
end

-- Original uploaded End Phase rule is retained outside Inherited Duel.
function s.checkop_legacy(e,tp,eg,ep,ev,re,r,rp)
    local a=Duel.GetFieldGroupCount(0,LOCATION_MZONE,0)
    local b=Duel.GetFieldGroupCount(1,LOCATION_MZONE,0)
    if a>0 and b==0 then
        Duel.Win(0,WIN_REASON_LAST_TURN)
    elseif b>0 and a==0 then
        Duel.Win(1,WIN_REASON_LAST_TURN)
    else
        Duel.Win(PLAYER_NONE,WIN_REASON_LAST_TURN)
    end
end
