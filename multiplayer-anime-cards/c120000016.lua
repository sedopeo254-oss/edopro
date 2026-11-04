--邪龍復活の儀式
-- Dragon Revival Ritual (Anime) - independent Big Five Ritual implementation.
-- Uses the actual Deck Master Zone card first; creates tokens only for
-- monsters absent from that Zone and from the caster's field.
local s,id=GetID()
local FHD=511013020
local FIVE={153000020,153000021,153000022,153000023,153000024}
s.listed_names={FHD,table.unpack(FIVE)}

function s.initial_effect(c)
    local e1=Effect.CreateEffect(c)
    e1:SetDescription(aux.Stringid(id,0))
    e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_RELEASE)
    e1:SetType(EFFECT_TYPE_ACTIVATE)
    e1:SetCode(EVENT_FREE_CHAIN)
    e1:SetTarget(s.target)
    e1:SetOperation(s.activate)
    c:RegisterEffect(e1)
end

function s.multiplayer()
    return Duel.GetActiveLogicalPlayerMask
        and Duel.GetActiveLogicalPlayerMask()~=0
end

function s.owner(e,tp)
    if not s.multiplayer() then return tp end
    local handler=e and e.GetHandler and e:GetHandler()
    return handler and handler:GetLogicalOwner()
        or Duel.GetLogicalPlayer(tp) or tp
end

function s.side(p)
    return Duel.GetLogicalPlayerSide and Duel.GetLogicalPlayerSide(p) or p
end

function s.owner_cards(p,tp,location)
    if s.multiplayer() then
        return Duel.GetPlayerFieldGroup(p,location)
    end
    return Duel.GetFieldGroup(tp,location,0)
end

function s.dragon_cards(p,tp)
    return s.owner_cards(p,tp,LOCATION_HAND|LOCATION_DECK)
        :Filter(Card.IsCode,nil,FHD)
end

function s.find_on_field(p,tp,code,e)
    local g=s.owner_cards(p,tp,LOCATION_MZONE)
    return g:Filter(function(c,card_code,effect,side)
        return c:IsOriginalCode(card_code)
            and c:IsReleasableByEffect(effect,side)
    end,nil,code,e,tp):GetFirst()
end

-- Decide all five sources without creating or moving any cards.
-- Priority: the real matching card in the player's Deck Master Zone,
-- then an already-controlled matching monster, otherwise outside-Duel token.
function s.plan(e,tp,p)
    if not DeckMaster or not DeckMaster.FinishDragonRevival
        or not DeckMasterZone then return nil end
    if Duel.GetActiveLogicalPlayerMask and s.multiplayer()
        and not Duel.IsLogicalPlayerActive(p) then return nil end
    local side=s.side(p)
    if side~=0 and side~=1 then return nil end
    local result={}
    local missing=0
    for _,code in ipairs(FIVE) do
        local origin,tc
        local zone=DeckMasterZone[p]
        if zone and zone:IsOriginalCode(code) then
            origin,tc="zone",zone
        else
            tc=s.find_on_field(p,tp,code,e)
            if tc then origin="field" else origin="token" end
        end
        result[#result+1]={code=code,origin=origin,card=tc}
        if origin~="field" then missing=missing+1 end
    end
    if Duel.GetLocationCount(tp,LOCATION_MZONE)<missing then return nil end
    return result
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
    local p=s.owner(e,tp)
    if chk==0 then
        return #s.dragon_cards(p,tp)>0 and s.plan(e,tp,p)~=nil
    end
    Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,6,tp,
        LOCATION_HAND|LOCATION_DECK)
    Duel.SetOperationInfo(0,CATEGORY_RELEASE,nil,5,tp,LOCATION_MZONE)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
    local p=s.owner(e,tp)
    local choices=s.dragon_cards(p,tp)
    local plan=s.plan(e,tp,p)
    if #choices==0 or not plan then return end

    -- Select the real Five-Headed Dragon from this player's hand or Deck.
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
    local dragon=choices:Select(tp,1,1,nil):GetFirst()
    if not dragon then return end

    local all=Group.CreateGroup()
    local new=Group.CreateGroup()
    local consume={}
    local side=s.side(p)
    for _,source in ipairs(plan) do
        local tc=source.card
        if source.origin=="token" then
            tc=s.multiplayer() and Duel.CreateTokenPlayer(p,source.code)
                or Duel.CreateToken(tp,source.code)
        elseif source.origin=="zone" then
            -- Only the actual Zone card is used, never a token duplicate.
            consume[p]=tc
        end
        if not tc then return end
        all:AddCard(tc)
        if source.origin~="field" then new:AddCard(tc) end
    end
    if #all~=5 then return end

    -- Keep the ordinary Deck Master succession rule from marking any of the
    -- temporary materials or creating a second FHD in Deck Master Zone.
    DeckMaster.DragonRevivalResolving[side]=true
    DeckMaster.DragonRevivalConsumed[side]={}
    for owner,tc in pairs(consume) do
        if DeckMasterZone[owner]==tc then
            Duel.ClearDeckMasterZonePlayer(owner)
            DeckMaster.DragonRevivalConsumed[side][owner]=true
        end
    end

    if #new>0 then
        local count=Duel.SpecialSummon(new,0,tp,tp,true,false,POS_FACEUP_ATTACK)
        if count~=#new then
            DeckMaster.FinishDragonRevival(p,false)
            return
        end
    end
    local materials=all:Filter(Card.IsLocation,nil,LOCATION_MZONE)
    if #materials~=5 then
        DeckMaster.FinishDragonRevival(p,false)
        return
    end

    dragon:SetMaterial(materials)
    local released=Duel.Release(materials,
        REASON_EFFECT|REASON_MATERIAL|REASON_RITUAL)
    if released~=5 then
        DeckMaster.FinishDragonRevival(p,false)
        return
    end

    local summoned=Duel.SpecialSummon(
        dragon,SUMMON_TYPE_RITUAL,tp,tp,true,true,POS_FACEUP_ATTACK)
    if summoned>0 then dragon:CompleteProcedure() end
    -- Successor is this actual monster on the field: never create an FHD
    -- token and never call MoveToDeckMasterZone for Five-Headed Dragon.
    DeckMaster.FinishDragonRevival(
        p,summoned>0,summoned>0 and dragon or nil)
end
