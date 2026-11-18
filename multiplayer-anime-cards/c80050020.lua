-- Custom Polymerization V2 (experimental, opt-in card only)
-- ID: 80050020. No duel mode or global rule changes.
local s,id=GetID()
local FUSION_ID=80050021
local REVIVAL_SLIME_CODE=31709826 -- Official Revival Jam / anime Revival Slime

-- Kept by card object, not FieldID (which can change on re-entry).
s.profiles=s.profiles or {}
s.generated=s.generated or setmetatable({}, {__mode="k"})

-- Do not inherit summon procedures, the source's revive limit, or stat setters.
-- Material ATK/DEF already includes active stat changes when sampled.
local function make_code_set(...)
    local result={}
    for index=1,select("#",...) do
        local code=select(index,...)
        if code then result[code]=true end
    end
    return result
end
local excluded_codes=make_code_set(
    EFFECT_REVIVE_LIMIT,EFFECT_FUSION_MATERIAL,EFFECT_SPSUMMON_PROC,
    EFFECT_SPSUMMON_PROC_G,EFFECT_SET_ATTACK,EFFECT_SET_ATTACK_FINAL,
    EFFECT_SET_BASE_ATTACK,EFFECT_UPDATE_ATTACK,EFFECT_SET_DEFENSE,
    EFFECT_SET_DEFENSE_FINAL,EFFECT_SET_BASE_DEFENSE,EFFECT_UPDATE_DEFENSE,
    EFFECT_CHANGE_LEVEL,EFFECT_CHANGE_RACE,EFFECT_CHANGE_ATTRIBUTE,
    EFFECT_CHANGE_CODE,EFFECT_CHANGE_TYPE,EFFECT_ADD_TYPE,EFFECT_REMOVE_TYPE
)

-- Only simple, numeric external grants can be detached from an Equip/aura.
-- Other external auras still require a core-level inheritance adapter.
local safe_external=make_code_set(
    EFFECT_EXTRA_ATTACK,EFFECT_EXTRA_ATTACK_MONSTER,
    EFFECT_INDESTRUCTABLE_BATTLE,EFFECT_INDESTRUCTABLE_EFFECT,
    EFFECT_CANNOT_BE_EFFECT_TARGET,EFFECT_CANNOT_BE_BATTLE_TARGET
)

local function positive(v)
    if type(v)~="number" or v<0 then return 0 end
    return v
end
local function material_level(c)
    local lv=c:GetLevel()
    if lv and lv>0 then return lv end
    if c:IsType(TYPE_XYZ) then return positive(c:GetRank()) end
    if c:IsType(TYPE_LINK) then return positive(c:GetLink()) end
    return 0
end

function s.matfilter(c,e)
    return c:IsType(TYPE_MONSTER) and c:IsAbleToGrave()
        and c:IsCanBeFusionMaterial(nil,SUMMON_TYPE_FUSION)
        and not c:IsImmuneToEffect(e)
end

function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
    if chk==0 then
        local mg=Duel.GetMatchingGroup(s.matfilter,tp,LOCATION_HAND+LOCATION_MZONE,0,nil,e)
        if #mg<2 then return false end
        if Duel.GetLocationCount(tp,LOCATION_MZONE)>0 then return true end
        -- A full field is legal if one of the materials will vacate a zone.
        local fg=mg:Filter(Card.IsLocation,nil,LOCATION_MZONE)
        return #fg>0 and Duel.GetMZoneCount(tp,fg)>0
    end
    Duel.SetOperationInfo(0,CATEGORY_TOGRAVE,nil,2,tp,LOCATION_HAND+LOCATION_MZONE)
    Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_MZONE)
end

local function collect_properties(ef)
    local type_,code=ef:GetType(),ef:GetCode()
    if not type_ or not code or excluded_codes[code] then return nil end
    -- LabelObject often embeds source-specific card/group state, which cannot
    -- be transferred safely just by re-registering the callback.
    if ef:GetLabelObject()~=nil then return nil end
    local p1,p2=ef:GetProperty()
    p1,p2=p1 or 0,p2 or 0
    if (p1 & EFFECT_FLAG_UNCOPYABLE)~=0 or (p1 & EFFECT_FLAG_FIELD_ONLY)~=0 then
        return nil
    end
    if (type_ & (EFFECT_TYPE_EQUIP|EFFECT_TYPE_TARGET|EFFECT_TYPE_XMATERIAL))~=0 then
        return nil
    end
    if (type_ & (EFFECT_TYPE_SINGLE|EFFECT_TYPE_FIELD))==0 then return nil end
    local max_count,count_code,count_flag,count_index
    if (p1 & EFFECT_FLAG_COUNT_LIMIT)~=0 then
        local current,max,cc,cf,ci=ef:GetCountLimit()
        max_count,count_code,count_flag,count_index=max,cc,cf,ci
    end
    local reset,reset_count=ef:GetReset()
    local sr,orr=ef:GetTargetRange()
    local labels={ef:GetLabel()}
    return {
        type=type_,code=code,property=p1 & ~EFFECT_FLAG_COUNT_LIMIT,property2=p2,
        range=ef:GetRange(),self_range=sr,other_range=orr,
        category=ef:GetCategory(),description=ef:GetDescription(),
        condition=ef:GetCondition(),cost=ef:GetCost(),target=ef:GetTarget(),
        operation=ef:GetOperation(),value=ef:GetValue(),
        count_limit=max_count,count_code=count_code,count_flag=count_flag,
        count_index=count_index,labels=labels,
        label_object=ef:GetLabelObject(),source_reset=reset,source_reset_count=reset_count,
        source_code=ef:GetOwner() and ef:GetOwner():GetOriginalCode() or 0
    }
end

-- Read actual registered effects before materials leave the field.
-- This captures effects registered directly by third-party cards, too.
function s.capture_material(tc)
    local all={}
    local recorded={}
    local previous=s.profiles[tc]
    if previous then
        for _,desc in ipairs(previous.effects) do all[#all+1]=desc end
    end
    if tc.GetOwnEffects then
        for _,ef in ipairs({tc:GetOwnEffects()}) do
            if ef and not s.generated[ef] and ef:GetHandler()==tc then
                local desc=collect_properties(ef)
                if desc then all[#all+1]=desc end
                recorded[ef]=true
            end
        end
    end
    if tc.GetCardEffect then
        for _,ef in ipairs({tc:GetCardEffect(0)}) do
            if ef and not recorded[ef] and ef:GetHandler()~=tc
                    and safe_external[ef:GetCode()] then
                local value=ef:GetValue()
                if type(value)=="number" then
                    all[#all+1]={
                        type=EFFECT_TYPE_SINGLE,code=ef:GetCode(),property=0,
                        property2=0,range=LOCATION_MZONE,value=value,
                        source_code=tc:GetOriginalCode(),external=true
                    }
                end
            end
        end
    end
    return all
end

local function mark_effect(fc,ef)
    s.generated[ef]=true
    fc:RegisterEffect(ef)
    return ef
end

local function put_scalar(fc,code,value,range)
    if value==nil then return end
    local e=Effect.CreateEffect(fc)
    e:SetType(EFFECT_TYPE_SINGLE)
    e:SetCode(code)
    e:SetValue(value)
    if range then e:SetProperty(EFFECT_FLAG_SINGLE_RANGE);e:SetRange(range) end
    e:SetReset(0)
    mark_effect(fc,e)
end

function s.add_effect(fc,desc)
    local e=Effect.CreateEffect(fc)
    e:SetType(desc.type)
    e:SetCode(desc.code)
    local flags=desc.property or 0
    -- The new owner is the Fusion, so drop owner-relative semantics.
    flags=flags & ~(EFFECT_FLAG_OWNER_RELATE|EFFECT_FLAG_COPY_INHERIT|EFFECT_FLAG_INITIAL)
    e:SetProperty(flags,desc.property2 or 0)
    if desc.range and desc.range~=0 then e:SetRange(desc.range) end
    if desc.self_range and desc.other_range then
        e:SetTargetRange(desc.self_range,desc.other_range)
    end
    if desc.category then e:SetCategory(desc.category) end
    if desc.description and desc.description~=0 then e:SetDescription(desc.description) end
    if desc.condition then e:SetCondition(desc.condition) end
    if desc.cost then e:SetCost(desc.cost) end
    if desc.target then e:SetTarget(desc.target) end
    if desc.operation then e:SetOperation(desc.operation) end
    if desc.value~=nil then e:SetValue(desc.value) end
    if desc.labels and #desc.labels>0 then e:SetLabel(table.unpack(desc.labels)) end
    -- A source label object may refer to a material which is now in the GY.
    -- Only portable scalar descriptors are copied automatically.
    if desc.count_limit and desc.count_limit>0 then
        local code=desc.count_code or 0
        local flag=desc.count_flag or 0
        local idx=desc.count_index or 0
        if code~=0 and idx~=0 then
            e:SetCountLimit(desc.count_limit,{code,idx},flag)
        else
            e:SetCountLimit(desc.count_limit,code,flag)
        end
    end
    -- No RESET_EVENT here: inheritance follows this SAME card across zones.
    e:SetReset(0)
    return mark_effect(fc,e)
end

local function effect_score(d)
    local score=0
    local action=d.type & (EFFECT_TYPE_IGNITION|EFFECT_TYPE_QUICK_O|
        EFFECT_TYPE_TRIGGER_O|EFFECT_TYPE_TRIGGER_F)
    if action~=0 then score=score+4 end
    if d.code==EFFECT_EXTRA_ATTACK or d.code==EFFECT_INDESTRUCTABLE_EFFECT
            or d.code==EFFECT_INDESTRUCTABLE_BATTLE then score=score+4 end
    if d.category then
        local cat=(CATEGORY_DESTROY or 0)|(CATEGORY_SPECIAL_SUMMON or 0)|
            (CATEGORY_RECOVER or 0)|(CATEGORY_SEARCH or 0)
        if (d.category & cat)~=0 then score=score+3 end
    end
    if d.external then score=score+1 end
    return score
end

function s.choose_effects(tp,descriptors)
    if #descriptors==0 then return {},0 end
    -- Labels str1-str3 in the included CDB patch.
    local mode=Duel.SelectOption(tp,aux.Stringid(id,0),aux.Stringid(id,1),aux.Stringid(id,2))
    if mode==0 then return descriptors,mode end
    local selected={}
    if mode==1 then
        for _,desc in ipairs(descriptors) do
            if desc.source_code and desc.source_code>0 then
                Duel.Hint(HINT_CARD,tp,desc.source_code)
            end
            local prompt=(desc.description and desc.description~=0)
                and desc.description or aux.Stringid(id,5)
            if Duel.SelectYesNo(tp,prompt) then selected[#selected+1]=desc end
        end
    else
        -- Deterministic local heuristic, not an online/LLM-based AI.
        local scored={}
        for i,desc in ipairs(descriptors) do
            scored[i]={desc=desc,score=effect_score(desc),index=i}
        end
        table.sort(scored,function(a,b)
            if a.score==b.score then return a.index<b.index end
            return a.score>b.score
        end)
        local target=math.max(1,math.ceil(#scored*0.6))
        for i=1,target do selected[#selected+1]=scored[i].desc end
    end
    return selected,mode
end

function s.revive_condition(e,tp,eg,ep,ev,re,r,rp)
    local c=e:GetHandler()
    local profile=s.profiles[c]
    return profile and profile.has_slime and c:IsLocation(LOCATION_GRAVE)
        and c:IsReason(REASON_DESTROY) and c:IsPreviousLocation(LOCATION_MZONE)
        and not c:IsReason(REASON_MATERIAL)
end
function s.revive_target(e,tp,eg,ep,ev,re,r,rp,chk)
    local c=e:GetHandler()
    if chk==0 then
        return c:IsLocation(LOCATION_GRAVE) and Duel.GetLocationCount(tp,LOCATION_MZONE)>0
            and c:IsCanBeSpecialSummoned(e,0,tp,false,false,POS_FACEUP_DEFENSE)
    end
    Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,c,1,tp,LOCATION_GRAVE)
end
function s.revive_operation(e,tp,eg,ep,ev,re,r,rp)
    local c=e:GetHandler()
    if c:IsRelateToEffect(e) and c:IsLocation(LOCATION_GRAVE)
            and Duel.GetLocationCount(tp,LOCATION_MZONE)>0 then
        -- Same card, never a new Token 535. The original Fusion procedure is complete.
        Duel.SpecialSummon(c,0,tp,tp,false,false,POS_FACEUP_DEFENSE)
    end
end
function s.register_revival(fc)
    local e=Effect.CreateEffect(fc)
    e:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
    e:SetCode(EVENT_TO_GRAVE)
    e:SetProperty(EFFECT_FLAG_DELAY)
    e:SetCondition(s.revive_condition)
    e:SetTarget(s.revive_target)
    e:SetOperation(s.revive_operation)
    e:SetCountLimit(1,id)
    e:SetReset(0)
    mark_effect(fc,e)
end

function s.initial_effect(c)
    local e=Effect.CreateEffect(c)
    e:SetCategory(CATEGORY_TOGRAVE+CATEGORY_SPECIAL_SUMMON)
    e:SetType(EFFECT_TYPE_ACTIVATE)
    e:SetCode(EVENT_FREE_CHAIN)
    e:SetTarget(s.target)
    e:SetOperation(s.activate)
    c:RegisterEffect(e)
end

function s.activate(e,tp,eg,ep,ev,re,r,rp)
    local mg=Duel.GetMatchingGroup(s.matfilter,tp,LOCATION_HAND+LOCATION_MZONE,0,nil,e)
    if #mg<2 then return end
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_FMATERIAL)
    local g=Duel.SelectMatchingCard(tp,s.matfilter,tp,LOCATION_HAND+LOCATION_MZONE,0,2,#mg,nil,e)
    if not g or #g<2 then return end
    if Duel.GetMZoneCount(tp,g)<=0 then return end

    local atk,def,level,race,attribute=0,0,0,0,0
    local candidates={}
    local has_slime=false
    for tc in aux.Next(g) do
        atk=atk+positive(tc:GetAttack())
        def=def+positive(tc:GetDefense())
        level=level+material_level(tc)
        race=race|tc:GetRace()
        attribute=attribute|tc:GetAttribute()
        has_slime=has_slime or tc:GetOriginalCode()==REVIVAL_SLIME_CODE
            or (s.profiles[tc] and s.profiles[tc].has_slime) or false
        for _,desc in ipairs(s.capture_material(tc)) do
            -- Replace ONLY Revival Slime's original replacement ability.
            if not (tc:GetOriginalCode()==REVIVAL_SLIME_CODE
                    and desc.code==EFFECT_DESTROY_REPLACE) then
                candidates[#candidates+1]=desc
            end
        end
    end
    local selected,choice=s.choose_effects(tp,candidates)
    local attributes={
        atk=math.floor(atk/2),def=math.floor(def/2),
        level=math.max(1,math.floor(level/2)),race=race,attribute=attribute,
        effects=selected,has_slime=has_slime,effect_choice=choice,
        material_count=#g
    }
    local fc=Duel.CreateToken(tp,FUSION_ID)
    if not fc then return end
    -- The card must be non-TOKEN and type 97 in its custom CDB.
    if not fc:IsType(TYPE_FUSION) or fc:IsType(TYPE_TOKEN) then return end
    local pos=Duel.SelectPosition(tp,fc,POS_FACEUP_ATTACK+POS_FACEUP_DEFENSE)
    local material_count=#g
    fc:SetMaterial(g)
    if Duel.SendtoGrave(g,REASON_EFFECT|REASON_MATERIAL|REASON_FUSION)<material_count then return end
    if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end

    s.profiles[fc]=attributes
    put_scalar(fc,EFFECT_SET_BASE_ATTACK,attributes.atk,LOCATION_MZONE)
    put_scalar(fc,EFFECT_SET_BASE_DEFENSE,attributes.def,LOCATION_MZONE)
    put_scalar(fc,EFFECT_CHANGE_LEVEL,attributes.level,LOCATION_MZONE)
    if race~=0 then put_scalar(fc,EFFECT_CHANGE_RACE,race,LOCATION_MZONE) end
    if attribute~=0 then put_scalar(fc,EFFECT_CHANGE_ATTRIBUTE,attribute,LOCATION_MZONE) end
    for _,desc in ipairs(selected) do s.add_effect(fc,desc) end
    if has_slime then s.register_revival(fc) end

    if Duel.SpecialSummon(fc,SUMMON_TYPE_FUSION,tp,tp,false,false,pos)>0 then
        fc:CompleteProcedure()
    end
end
