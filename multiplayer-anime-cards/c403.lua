--Magical Hats (Anime)

local c403,id=GetID()
if not MagicalHatsAnime_HatTokenFidList then MagicalHatsAnime_HatTokenFidList = {} end

if not c403.copy_mode then c403.copy_mode=setmetatable({}, {__mode="k"}) end
if not c403.copy_for_logical then c403.copy_for_logical={} end

function c403.is_multiplayer()
    return Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0
end
function c403.logical_player_of(card,tp)
    if c403.is_multiplayer() then return card:GetLogicalOwner() end
    return tp or card:GetControler()
end
function c403.logical_side(logical,tp)
    if c403.is_multiplayer() then return Duel.GetLogicalPlayerSide(logical) end
    return tp
end
function c403.logical_mzone(card,tp)
    local logical=c403.logical_player_of(card,tp)
    if c403.is_multiplayer() then return Duel.GetPlayerFieldGroup(logical,LOCATION_MZONE) end
    return Duel.GetFieldGroup(tp,LOCATION_MZONE,0)
end
function c403.primary_filter(c,handler)
    if c403.copy_mode[handler] then return c:IsFaceup() and c:IsType(TYPE_MONSTER) end
    return c403.spellcaster_filter(c)
end
function c403.primary_group(handler,tp)
    return c403.logical_mzone(handler,tp):Filter(c403.primary_filter,nil,handler)
end
function c403.make_hat_token(handler,tp)
    if c403.is_multiplayer() then
        return Duel.CreateTokenPlayer(c403.logical_player_of(handler,tp),511005062)
    end
    return Duel.CreateToken(tp,511005062)
end
function c403.move_hat_to_owner(hat,handler,tp)
    local logical=c403.logical_player_of(handler,tp)
    local side=c403.logical_side(logical,tp)
    return Duel.MoveToField(hat,side,side,LOCATION_MZONE,POS_FACEDOWN_DEFENSE,true)
end
function c403.preferred_copy_monster(g)
    local fg=g:Filter(Card.IsCode,nil,153000007,45231177)
    return fg:GetFirst() or g:GetFirst()
end
function c403.find_copy_teammate(source)
    if not c403.is_multiplayer() or not source then return nil end
    local owner=source:GetLogicalOwner()
    local side=Duel.GetLogicalPlayerSide(owner)
    local fallback=nil
    for p=0,3 do
        if p~=owner and Duel.IsLogicalPlayerActive(p)
            and Duel.GetLogicalPlayerSide(p)==side then
            local g=Duel.GetPlayerFieldGroup(p,LOCATION_MZONE):Filter(
                function(c) return c:IsFaceup() and c:IsType(TYPE_MONSTER) end,nil)
            if #g>0 and #Duel.GetPlayerFieldGroup(p,LOCATION_MZONE)<=4 then
                if g:IsExists(Card.IsCode,1,nil,153000007,45231177) then return p end
                fallback=fallback or p
            end
        end
    end
    return fallback
end
function MagicalHatsAnime_CanDeckMasterCopy(tp,hats_card)
    if not hats_card or not hats_card:IsCode(403) or not hats_card:IsOnField() then return false end
    local source=DeckMaster and DeckMaster.AbilityContextCard or nil
    local teammate=c403.find_copy_teammate(source)
    if teammate==nil then return false end
    local old=c403.copy_for_logical[teammate]
    return not old or not old:IsOnField()
end
function MagicalHatsAnime_DeckMasterCopy(tp,source,hats_card)
    local teammate=c403.find_copy_teammate(source)
    if teammate==nil then return false end
    local side=Duel.GetLogicalPlayerSide(teammate)
    if side==nil then return false end
    local copy=Duel.CreateTokenPlayer(teammate,403)
    if not copy then return false end
    c403.copy_mode[copy]=true
    c403.copy_for_logical[teammate]=copy
    if not Duel.MoveToField(copy,side,side,LOCATION_SZONE,POS_FACEUP,true) then
        c403.copy_mode[copy]=nil
        c403.copy_for_logical[teammate]=nil
        return false
    end
    local ce=Effect.CreateEffect(copy)
    c403.activate(ce,side,nil,nil,nil,nil,nil,nil)
    if copy:GetFlagEffect(403)==0 then
        c403.copy_mode[copy]=nil
        c403.copy_for_logical[teammate]=nil
        if copy:IsOnField() then Duel.SendtoGrave(copy,REASON_RULE) end
        return false
    end
    copy:SetStatus(STATUS_ACTIVATED,true)
    return true
end

if not c403.gl_chk then
    c403.gl_chk=true
    local regeff=Card.RegisterEffect
    Card.RegisterEffect=function(c,e,f)
        local tc=e:GetOwner()
        if tc then
            local tg=e:GetTarget()
            if tg then
                if c35803249 and tg==c35803249.distg then 
                    e:SetTargetRange(LOCATION_ONFIELD,LOCATION_ONFIELD)
                elseif c51452091 and tg==c51452091.distarget then 
                    e:SetTargetRange(LOCATION_ONFIELD,LOCATION_ONFIELD)
                elseif c77585513 and tg==c77585513.distg then 
                    e:SetTargetRange(LOCATION_ONFIELD,LOCATION_ONFIELD)
                elseif c84636823 and tg==c84636823.distg then 
                    e:SetTargetRange(LOCATION_ONFIELD,LOCATION_ONFIELD)
                end
            end
        end
        return regeff(c,e,f)
    end
end
function c403.initial_effect(c)
    local e1=Effect.CreateEffect(c)
    e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOKEN)
    e1:SetType(EFFECT_TYPE_ACTIVATE)
    e1:SetCode(EVENT_FREE_CHAIN)
    e1:SetCondition(c403.condition)
    e1:SetTarget(c403.target)
    e1:SetOperation(c403.activate)
    c:RegisterEffect(e1)
    local e2=Effect.CreateEffect(c)
    e2:SetType(EFFECT_TYPE_SINGLE)
    e2:SetCode(EFFECT_REMAIN_FIELD)
    c:RegisterEffect(e2)
    local e3=Effect.CreateEffect(c)
    e3:SetType(EFFECT_TYPE_SINGLE)
    e3:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
    e3:SetRange(LOCATION_ONFIELD)
    e3:SetCode(EFFECT_SELF_DESTROY)
    e3:SetCondition(c403.descon)
    c:RegisterEffect(e3)
    local e4=Effect.CreateEffect(c)
    e4:SetType(EFFECT_TYPE_SINGLE)
    e4:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
    e4:SetRange(LOCATION_ONFIELD)
    e4:SetCode(EFFECT_IMMUNE_EFFECT)
    e4:SetValue(function(e,te)
    return te:GetOwner()~=e:GetOwner()
    end)
    c:RegisterEffect(e4)
    local e5=Effect.CreateEffect(c)
    e5:SetType(EFFECT_TYPE_SINGLE)
    e5:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
    e5:SetRange(LOCATION_ONFIELD)
    e5:SetCode(EFFECT_CANNOT_BE_EFFECT_TARGET)
    e5:SetValue(function(e,re,tp)
    return true
    end)
    c:RegisterEffect(e5)
    if not c403.global_monitor_10000020 then
        c403.global_monitor_10000020 = true
        local ge1=Effect.CreateEffect(c)
        ge1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
        ge1:SetCode(EVENT_CHAIN_SOLVING)
        ge1:SetOperation(c403.check_10000020_resolve)
        Duel.RegisterEffect(ge1,0)
    end
end
function c403.spellcaster_filter(c)
    return c:IsFaceup() and c:IsRace(RACE_SPELLCASTER) and not c:IsLocation(LOCATION_PZONE)
end
function c403.condition(e,tp,eg,ep,ev,re,r,rp)
    if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then return false end
    return #c403.primary_group(e:GetHandler(),tp)>0
end
function c403.tgfilter(c)
    return c:IsType(TYPE_MONSTER)
end
local c403_chain_with_10000020 = false
function c403.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
    local handler=e:GetHandler()
    local logical=c403.logical_player_of(handler,tp)
    if chkc then
        return chkc:IsLocation(LOCATION_MZONE)
            and (not c403.is_multiplayer() or chkc:GetLogicalControler()==logical)
            and c403.primary_filter(chkc,handler)
    end
    if chk==0 then
        return not Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT)
            and #c403.primary_group(handler,tp)>0
    end
    local ct=#c403.logical_mzone(handler,tp)
    Duel.SetOperationInfo(0,CATEGORY_POSITION,nil,ct,0,0)
    Duel.SetOperationInfo(0,CATEGORY_TOKEN,nil,3-ct,0,0)
    Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,3-ct,0,0)
    c403_chain_with_10000020 = false
    local ch = Duel.GetCurrentChain()
    if ch > 1 then
        local prev_re = Duel.GetChainInfo(ch-1,CHAININFO_TRIGGERING_EFFECT)
        if prev_re and prev_re:GetHandler():GetCode() == 10000020 then
            c403_chain_with_10000020 = true
        end
    end
end
function c403.activate(e,tp,eg,ep,ev,re,r,rp)
    local c=e:GetHandler()
    local fid=c:GetFieldID()
    local own_mzone=c403.logical_mzone(c,tp)
    local ft=7-#own_mzone
    if Duel.IsPlayerAffectedByEffect(tp,CARD_BLUEEYES_SPIRIT) then return end
        c:RegisterFlagEffect(403,RESET_EVENT+RESETS_STANDARD_DISABLE,0,0,fid)
        local primary=c403.primary_group(c,tp)
        local hatm1=nil
        local g1=Group.CreateGroup()
        if c403.copy_mode[c] then
            hatm1=c403.preferred_copy_monster(primary)
            if hatm1 then g1:AddCard(hatm1) end
        else
            Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_POSCHANGE)
            g1=primary:Select(tp,1,1,nil)
            hatm1=g1:GetFirst()
        end
        if not hatm1 then return end
        local others=own_mzone:Filter(Card.IsType,hatm1,TYPE_MONSTER)
        local ct=#others
        if not c403.copy_mode[c] and ct>0 and Duel.SelectYesNo(tp,aux.Stringid(403,0)) then
            Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_POSCHANGE)
            local g2=others:Select(tp,1,math.min(3,ct),nil)
            g1:Merge(g2)
            g1:KeepAlive()
            for hatma in aux.Next(g2) do
                Duel.ChangePosition(hatma,POS_FACEDOWN_DEFENSE)
                local e1=Effect.CreateEffect(c)
                e1:SetType(EFFECT_TYPE_SINGLE)
                e1:SetCode(EFFECT_CHANGE_TYPE)
                e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
                e1:SetValue(TYPE_TOKEN)
                e1:SetLabel(fid)
                e1:SetCondition(c403.econ)
                e1:SetReset(RESET_EVENT+RESETS_STANDARD)
                hatma:RegisterEffect(e1)
                local e2=e1:Clone()
                e2:SetCode(EFFECT_REMOVE_RACE)
                e2:SetValue(RACE_ALL)
                hatma:RegisterEffect(e2)
                local e3=e1:Clone()
                e3:SetCode(EFFECT_REMOVE_ATTRIBUTE)
                e3:SetValue(0xff)
                hatma:RegisterEffect(e3)
                local e4=e1:Clone()
                e4:SetCode(EFFECT_SET_BASE_ATTACK)
                e4:SetValue(0)
                hatma:RegisterEffect(e4)
                local e5=e1:Clone()
                e5:SetCode(EFFECT_SET_BASE_DEFENSE)
                e5:SetValue(0)
                hatma:RegisterEffect(e5)
                local e6=e1:Clone()
                e6:SetCode(EFFECT_CHANGE_LEVEL)
                e6:SetValue(0)
                hatma:RegisterEffect(e6)
                local e7=e1:Clone()
                e7:SetCode(EFFECT_UNRELEASABLE_SUM)
                e7:SetValue(1)
                e7:SetReset(RESET_EVENT+RESETS_STANDARD)
                hatma:RegisterEffect(e7)
                local e8=e7:Clone()
                e8:SetCode(EFFECT_UNRELEASABLE_NONSUM)
                hatma:RegisterEffect(e8)
                hatma:RegisterFlagEffect(403+2,RESET_EVENT+RESETS_STANDARD,0,0,fid)
        end	
    end
    local zone=4-#g1
    if ft<zone then
        Duel.Destroy(e:GetHandler(),REASON_EFFECT) 
    else	
        for i=1,zone do
            local hat=c403.make_hat_token(c,tp)
            c403.move_hat_to_owner(hat,c,tp)
            local e1=Effect.CreateEffect(c)
            e1:SetType(EFFECT_TYPE_SINGLE)
            e1:SetCode(EFFECT_CHANGE_TYPE)
            e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
            e1:SetValue(TYPE_TOKEN)
            e1:SetReset(RESET_EVENT+RESETS_STANDARD)
            hat:RegisterEffect(e1,true)
            local e2=e1:Clone()
            e2:SetCode(EFFECT_REMOVE_RACE)
            e2:SetValue(RACE_ALL)
            hat:RegisterEffect(e2,true)
            local e3=e1:Clone()
            e3:SetCode(EFFECT_REMOVE_ATTRIBUTE)
            e3:SetValue(0xff)
            hat:RegisterEffect(e3,true)
            local e4=e1:Clone()
            e4:SetCode(EFFECT_SET_BASE_ATTACK)
            e4:SetValue(0)
            hat:RegisterEffect(e4,true)
            local e5=e1:Clone()
            e5:SetCode(EFFECT_SET_BASE_DEFENSE)
            e5:SetValue(0)
            hat:RegisterEffect(e5,true)
            local e6=Effect.CreateEffect(c)
            e6:SetType(EFFECT_TYPE_SINGLE)
            e6:SetCode(EFFECT_CANNOT_CHANGE_POSITION)
            hat:RegisterEffect(e6,true)
            local e7=e1:Clone()
            e7:SetType(EFFECT_TYPE_SINGLE)
            e7:SetCode(EFFECT_CANNOT_ATTACK)
            hat:RegisterEffect(e7,true)
            local e8=e1:Clone()
            e8:SetType(EFFECT_TYPE_SINGLE)
            e8:SetCode(EFFECT_UNRELEASABLE_SUM)
            e8:SetValue(1)
            hat:RegisterEffect(e8,true)
            local e9=e8:Clone()
            e9:SetType(EFFECT_TYPE_SINGLE)
            e9:SetCode(EFFECT_UNRELEASABLE_NONSUM)
            e9:SetValue(1)
            hat:RegisterEffect(e9,true)
            local e10=e1:Clone()
            e10:SetType(EFFECT_TYPE_SINGLE)
            e10:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
            e10:SetCode(EFFECT_CANNOT_BE_SYNCHRO_MATERIAL)
            e10:SetValue(1)
            hat:RegisterEffect(e10,true)
            local e11=e1:Clone()
            e11:SetType(EFFECT_TYPE_SINGLE)
            e11:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE)
            e11:SetCode(EFFECT_CANNOT_BE_XYZ_MATERIAL)
            e11:SetValue(1)
            hat:RegisterEffect(e11,true)
            local e12=e1:Clone()
            e12:SetType(EFFECT_TYPE_SINGLE)
            e12:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE)
            e12:SetCode(EFFECT_AVOID_BATTLE_DAMAGE)
            e12:SetValue(1)
            hat:RegisterEffect(e12,true)
            local e13=Effect.CreateEffect(c)
            e13:SetCategory(CATEGORY_DESTROY)
            e13:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
            e13:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
            e13:SetCode(EVENT_FLIP)
            e13:SetOperation(c403.hatop)
            e13:SetReset(RESET_EVENT+RESETS_STANDARD)
            hat:RegisterEffect(e13)
            local e14=Effect.CreateEffect(c)
            e14:SetType(EFFECT_TYPE_SINGLE)
            e14:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL+EFFECT_FLAG_SET_AVAILABLE)
            e14:SetCode(EFFECT_SELF_DESTROY)
            e14:SetLabelObject(e:GetHandler())
            e14:SetLabel(fid)
            e14:SetCondition(c403.hdescon)
            e14:SetReset(RESET_EVENT+RESETS_STANDARD)
            hat:RegisterEffect(e14)
            hat:SetStatus(STATUS_NO_LEVEL,true)
            hat:RegisterFlagEffect(403+3,RESET_EVENT+RESETS_STANDARD,0,0,fid)
        end	
        Duel.ChangePosition(hatm1,POS_FACEDOWN_DEFENSE)
        local e1=Effect.CreateEffect(c)
        e1:SetType(EFFECT_TYPE_SINGLE)
        e1:SetCode(EFFECT_CHANGE_TYPE)
        e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
        e1:SetValue(TYPE_TOKEN)
        e1:SetLabel(fid)
        e1:SetCondition(c403.econ)
        e1:SetReset(RESET_EVENT+RESETS_STANDARD)
        hatm1:RegisterEffect(e1)
        local e2=e1:Clone()
        e2:SetCode(EFFECT_REMOVE_RACE)
        e2:SetValue(RACE_ALL)
        hatm1:RegisterEffect(e2)
        local e3=e1:Clone()
        e3:SetCode(EFFECT_REMOVE_ATTRIBUTE)
        e3:SetValue(0xff)
        hatm1:RegisterEffect(e3)
        local e4=e1:Clone()
        e4:SetCode(EFFECT_SET_BASE_ATTACK)
        e4:SetValue(0)
        hatm1:RegisterEffect(e4)
        local e5=e1:Clone()
        e5:SetCode(EFFECT_SET_BASE_DEFENSE)
        e5:SetValue(0)
        hatm1:RegisterEffect(e5)
        local e6=e1:Clone()
        e6:SetCode(EFFECT_CHANGE_LEVEL)
        e6:SetValue(0)
        hatm1:RegisterEffect(e6)
        local e7=e1:Clone()
        e7:SetCode(EFFECT_UNRELEASABLE_SUM)
        e7:SetValue(1)
        e7:SetReset(RESET_EVENT+RESETS_STANDARD)
        hatm1:RegisterEffect(e7)
        local e8=e7:Clone()
        e8:SetCode(EFFECT_UNRELEASABLE_NONSUM)
        hatm1:RegisterEffect(e8)
        hatm1:RegisterFlagEffect(403+1,RESET_EVENT+RESETS_STANDARD,0,0,fid)
        local gs1=Duel.GetMatchingGroup(c403.gsfilter,tp,LOCATION_ONFIELD,0,nil,fid)
        Duel.ChangePosition(gs1,POS_FACEDOWN_DEFENSE)
        Duel.ShuffleSetCard(gs1)
    end	
    if c403_chain_with_10000020 then
        table.insert(MagicalHatsAnime_HatTokenFidList, {fid=fid,player=tp})
        c403_chain_with_10000020 = false
    end
    local e1=Effect.CreateEffect(c)
    e1:SetCategory(CATEGORY_DESTROY)
    e1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
    e1:SetRange(LOCATION_ONFIELD)
    e1:SetCode(EVENT_BE_BATTLE_TARGET)
    e1:SetLabelObject(hatm1)
    e1:SetLabel(fid)
    e1:SetCondition(c403.descon3)
    e1:SetOperation(c403.desop2)
    e1:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(e1)
    local e2=Effect.CreateEffect(c)
    e2:SetCategory(CATEGORY_DESTROY)
    e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
    e2:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
    e2:SetRange(LOCATION_ONFIELD)
    e2:SetCode(EVENT_CHAINING)
    e2:SetLabelObject(hatm1)
    e2:SetLabel(fid)
    e2:SetCondition(c403.descon4)
    e2:SetOperation(c403.desop2)
    e2:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(e2)
    local e3=Effect.CreateEffect(c)
    e3:SetCategory(CATEGORY_DESTROY)
    e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
    e3:SetRange(LOCATION_ONFIELD)
    e3:SetCode(EVENT_LEAVE_FIELD)
    e3:SetLabelObject(hatm1)
    e3:SetLabel(fid)
    e3:SetCondition(c403.descon2)
    e3:SetOperation(c403.desop8)
    e3:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(e3)
    local e4=Effect.CreateEffect(c)
    e4:SetCategory(CATEGORY_DESTROY)
    e4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
    e4:SetRange(LOCATION_SZONE)
    e4:SetCode(EVENT_BATTLE_START)
    e4:SetLabel(fid)
    e4:SetCondition(c403.descon6)
    e4:SetOperation(c403.desop4)
    e4:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(e4)
    local e5=Effect.CreateEffect(c)
    e5:SetCategory(CATEGORY_DESTROY)
    e5:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
    e5:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
    e5:SetRange(LOCATION_ONFIELD)
    e5:SetCode(EVENT_CHAINING)
    e5:SetLabel(fid)
    e5:SetCondition(c403.descon7)
    e5:SetOperation(c403.desop5)
    e5:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(e5)
    local e6=Effect.CreateEffect(c)
    e6:SetCategory(CATEGORY_DESTROY)
    e6:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_SINGLE)
    e6:SetCode(EVENT_LEAVE_FIELD)
    e6:SetLabel(fid)
    e6:SetCondition(c403.descon6x)
    e6:SetOperation(c403.desop6)
    c:RegisterEffect(e6)
    local e7=Effect.CreateEffect(c)
    e7:SetCategory(CATEGORY_DESTROY)
    e7:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
    e7:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_REPEAT+EFFECT_FLAG_NO_TURN_RESET)
    e7:SetRange(LOCATION_ONFIELD)
    e7:SetCode(EVENT_ADJUST)
    e7:SetCountLimit(1,0,EFFECT_COUNT_CODE_SINGLE)
    e7:SetLabelObject(hatm1)
    e7:SetLabel(fid)
    e7:SetCondition(c403.retcon1)
    e7:SetOperation(c403.desop8)
    e7:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(e7)
    local e8=Effect.CreateEffect(c)
    e8:SetCategory(CATEGORY_DESTROY)
    e8:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_FIELD)
    e8:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_REPEAT+EFFECT_FLAG_NO_TURN_RESET)
    e8:SetRange(LOCATION_ONFIELD)
    e8:SetCode(EVENT_ADJUST)
    e8:SetLabel(fid)
    e8:SetOperation(c403.desop7)
    e8:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(e8)
    local e9=Effect.CreateEffect(c)
    e9:SetCategory(CATEGORY_SPECIAL_SUMMON)
    e9:SetProperty(EFFECT_FLAG_CARD_TARGET)
    e9:SetType(EFFECT_TYPE_IGNITION)
    e9:SetRange(LOCATION_ONFIELD)
    e9:SetCost(c403.stcost)
    e9:SetTarget(c403.sttar)
    e9:SetOperation(c403.stop)
    e9:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(e9)
end
function c403.check_10000020_resolve(e,tp,eg,ep,ev,re,r,rp)
    if re and re:GetHandler():GetCode()==10000020 then
        for idx=#MagicalHatsAnime_HatTokenFidList,1,-1 do
            local info = MagicalHatsAnime_HatTokenFidList[idx]
            local fid = info.fid
            local player = info.player
            local g = Duel.GetMatchingGroup(function(tc)
                return tc:IsFacedown() and tc:IsOnField() and
                    (tc:GetFlagEffectLabel(403+2)==fid or tc:GetFlagEffectLabel(403+3)==fid or tc:GetFlagEffectLabel(403+4)==fid)
            end, player, LOCATION_MZONE, 0, nil)
            if #g>0 then
                Duel.Hint(HINT_SELECTMSG,player,aux.Stringid(403,2))
                local sg = g:RandomSelect(player,1)
                Duel.Destroy(sg,REASON_EFFECT)
            end
            table.remove(MagicalHatsAnime_HatTokenFidList, idx)
        end
    end
end
function c403.econ(e,tp,eg,ep,ev,re,r,rp)
    return e:GetHandler():IsFacedown()
end	
function c403.hatop(e,tp,eg,ep,ev,re,r,rp)
    Duel.Destroy(e:GetHandler(),REASON_EFFECT)
end
function c403.tdfilter(c,fid)
    return c:IsFaceup() and c:GetFlagEffectLabel(403)==fid and not (c:IsStatus(STATUS_DISABLED) or c:IsDisabled()) 
end
function c403.hdescon(e)
    local fid=e:GetLabel()
    return not Duel.IsExistingMatchingCard(c403.tdfilter,e:GetHandlerPlayer(),LOCATION_ONFIELD,0,1,nil,fid)
end
function c403.gsfilter(c,fid)
    return c:IsFacedown() and (c:GetFlagEffectLabel(403+1)==fid or c:GetFlagEffectLabel(403+2)==fid or c:GetFlagEffectLabel(403+3)==fid or c:GetFlagEffectLabel(403+4)==fid)
end
function c403.descon2(e,tp,eg,ep,ev,re,r,rp)
    local tc=e:GetLabelObject()
    return tc and tc:GetFlagEffectLabel(403+1)==e:GetLabel() and eg:IsContains(tc)
end
function c403.retfilter(c,fid)
    return c:GetFlagEffectLabel(403+1)
end
function c403.no_flag4_in_mzone(tp, fid)
    return not Duel.IsExistingMatchingCard(
        function(c)
            return c:GetFlagEffectLabel(403+4) == fid and c:IsControler(tp)
        end,
        tp, LOCATION_MZONE, 0, 1, nil
    )
end
function c403.descon3(e,tp,eg,ep,ev,re,r,rp)
    local tc=e:GetLabelObject()
    return tc and tc==Duel.GetAttackTarget()
        and tc:GetFlagEffectLabel(403+1)==e:GetLabel()
        and c403.no_flag4_in_mzone(tp, e:GetLabel())
end
function c403.descon4(e,tp,eg,ep,ev,re,r,rp)
        local tc=e:GetLabelObject()
    if tc:IsStatus(STATUS_BATTLE_DESTROYED) or not re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) then return false end
    local tg=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
    return tg and tg:IsContains(tc) and c403.no_flag4_in_mzone(tp, e:GetLabel())
end
function c403.descon6(e,tp,eg,ep,ev,re,r,rp)
    local tc=Duel.GetAttackTarget() 
    return tc and tc:GetFlagEffectLabel(403+2)==e:GetLabel()
end
function c403.thfilter(c,tp,fid)
    return c:IsFacedown() and c:GetFlagEffectLabel(403+2)==fid and c:IsControler(tp) 
end
function c403.descon7(e,tp,eg,ep,ev,re,r,rp)
    local fid=e:GetLabel()
    if not re:IsHasProperty(EFFECT_FLAG_CARD_TARGET) then return false end
    local tg=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
    return tg and tg:IsExists(c403.thfilter,1,nil,tp,fid)
end
function c403.refilter(c,fid)
    return c:IsFacedown() and c:GetFlagEffectLabel(403+2)==fid or c:GetFlagEffectLabel(403+3)==fid  or c:GetFlagEffectLabel(403+4)==fid 
end
function c403.retcon1(e,tp,eg,ep,ev,re,r,rp)
    local tc=e:GetLabelObject()
    local fid=e:GetLabel()
    local has4034 = Duel.IsExistingMatchingCard(function(c)
        return c:IsFacedown() and c:GetFlagEffectLabel(403+4)==fid
    end, tp, LOCATION_MZONE, 0, 1, nil)
    if not has4034 then
        return not tc:IsPosition(POS_FACEDOWN_DEFENSE)
            or not Duel.IsExistingMatchingCard(c403.refilter,e:GetHandlerPlayer(),LOCATION_ONFIELD,0,1,nil,fid)
            or e:GetHandler():IsStatus(STATUS_DISABLED)
            or e:GetHandler():IsDisabled()
    end
    return false
end
function c403.refilter2(c,fid)
    return c:IsFaceup() and c:GetFlagEffectLabel(403+2)==fid  
end
function c403.desop7(e,tp,eg,ep,ev,re,r,rp)
    local fid=e:GetLabel()
    local g=Duel.GetMatchingGroup(c403.refilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,fid)
    local tc=g:GetFirst()
    for tc in aux.Next(g) do
        if tc:GetFlagEffectLabel(403+2)==fid then
            tc:ResetFlagEffect(403+2) 
        end
    end
end
function c403.desfilter1(c,fid)
    return c:IsFacedown() and c:GetFlagEffectLabel(403+2)==fid 
end
function c403.desfilter2(c,fid)
    return c:GetFlagEffectLabel(403+3)==fid 
end
function c403.desfilter5(c,fid)
    return c:IsFacedown() and c:GetFlagEffectLabel(403+3)==fid or c:GetFlagEffectLabel(403+4)==fid 
end
function c403.desop2(e,tp,eg,ep,ev,re,r,rp)
    local tc1=e:GetLabelObject()
    local fid=e:GetLabel()
    if tc1 and tc1:GetFlagEffectLabel(403+1)==fid then
        Duel.ChangePosition(tc1,tc1:GetPreviousPosition())
        if tc1:GetFlagEffectLabel(403+1)==fid then
            tc1:ResetFlagEffect(403+1)
        else 
            tc1:ResetFlagEffect(403+2) 
        end		
    end
    local g1=Duel.GetMatchingGroup(c403.desfilter1,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,fid)
    local tc2=g1:GetFirst()
    for tc2 in aux.Next(g1) do
        Duel.ChangePosition(tc2,tc2:GetPreviousPosition()) 
        if tc2:GetFlagEffectLabel(403+1)==fid then
            tc2:ResetFlagEffect(403+1)
        else 
            tc2:ResetFlagEffect(403+2) 
        end
    end
    local g2=Duel.GetMatchingGroup(c403.desfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,fid)
    if #g2>0 then
        Duel.Destroy(g2,REASON_EFFECT)
    end
    Duel.Destroy(e:GetHandler(),REASON_EFFECT)
end
function c403.desop4(e,tp,eg,ep,ev,re,r,rp)
    local tc=Duel.GetAttackTarget() 
    local fid=e:GetLabel()
    if tc and tc:GetFlagEffectLabel(403+2)==fid then
        Duel.ChangePosition(tc,tc:GetPreviousPosition())  
        if tc:GetFlagEffectLabel(403+1)==fid then
            tc:ResetFlagEffect(403+1)
        else 
            tc:ResetFlagEffect(403+2) 
        end	
    end
end
function c403.desfilter3(c,fid)
    return c:IsFacedown() and c:GetFlagEffectLabel(403+2)==fid
end
function c403.desop5(e,tp,eg,ep,ev,re,r,rp)
    local fid=e:GetLabel()
    local g=Duel.GetChainInfo(ev,CHAININFO_TARGET_CARDS)
    local tg=g:Filter(c403.desfilter3,nil,fid)
    local tc=tg:GetFirst()
    if tc then
        Duel.ChangePosition(tc,tc:GetPreviousPosition()) 
        if tc:GetFlagEffectLabel(403+1)==fid then
            tc:ResetFlagEffect(403+1)
        else 
            tc:ResetFlagEffect(403+2) 
        end	
    end
end
function c403.desfilter4(c,fid)
    return c:IsFacedown() and c:GetFlagEffectLabel(403+1)==fid or c:GetFlagEffectLabel(403+2)==fid 
end
function c403.descon6x(e,tp,eg,ep,ev,re,r,rp)
    return not Duel.IsExistingMatchingCard(
        function(c)
            return c:GetFlagEffectLabel(403+4) == e:GetLabel() and c:IsControler(tp)
        end,
        tp, LOCATION_MZONE, 0, 1, nil
    )
end
function c403.desop6(e,tp,eg,ep,ev,re,r,rp)
    local fid=e:GetLabel()
    local g1=Duel.GetMatchingGroup(c403.desfilter4,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,fid)
    local tc=g1:GetFirst()
    for tc in aux.Next(g1) do
        Duel.ChangePosition(tc,tc:GetPreviousPosition()) 
        if tc:GetFlagEffectLabel(403+1)==fid then
            tc:ResetFlagEffect(403+1)
        else 
            tc:ResetFlagEffect(403+2) 
        end
    end
    local g2=Duel.GetMatchingGroup(c403.desfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,fid)
    if #g2>0 then
        Duel.Destroy(g2,REASON_EFFECT)
    end
    e:GetHandler():ResetFlagEffect(403)
    Duel.Destroy(e:GetHandler(),REASON_EFFECT)
end
function c403.desop8(e,tp,eg,ep,ev,re,r,rp)
    local fid = e:GetLabel()
    local g1 = Duel.GetMatchingGroup(c403.desfilter4, tp, LOCATION_ONFIELD, LOCATION_ONFIELD, nil, fid)
    for tc in aux.Next(g1) do
        Duel.ChangePosition(tc, tc:GetPreviousPosition())
        if tc:GetFlagEffectLabel(403+1) == fid then
            tc:ResetFlagEffect(403+1)
        else
            tc:ResetFlagEffect(403+2)
        end
    end
    local g2 = Duel.GetMatchingGroup(c403.desfilter5, tp, LOCATION_ONFIELD, LOCATION_ONFIELD, nil, fid)
    if #g2 > 0 then
        Duel.Destroy(g2, REASON_EFFECT)
    end
    e:GetHandler():ResetFlagEffect(403)
    Duel.Destroy(e:GetHandler(), REASON_EFFECT)
end
function c403.costfilter(c)
    return c:GetFlagEffect(403+3)~=0 and c:IsType(TYPE_TOKEN) 
end
function c403.stcost(e,tp,eg,ep,ev,re,r,rp,chk)
    if chk==0 then return Duel.IsExistingMatchingCard(c403.costfilter,e:GetHandlerPlayer(),LOCATION_ONFIELD,0,1,nil) end
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOGRAVE)
    local g=Duel.SelectMatchingCard(tp,c403.costfilter,tp,LOCATION_ONFIELD,0,1,1,nil)
    Duel.SendtoGrave(g,REASON_COST)
end
function c403.stfilter(c)
    return c:IsType(TYPE_SPELL+TYPE_TRAP)
end
function c403.sttar(e,tp,eg,ep,ev,re,r,rp,chk)
    if chk==0 then return Duel.IsExistingMatchingCard(c403.stfilter,e:GetHandlerPlayer(),LOCATION_HAND,0,1,nil) end
    Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND)
end
function c403.GetOrderedSetCards(tp, fid)
    local g = Duel.GetMatchingGroup(function(c)
        return c:GetFlagEffectLabel(403+4) == fid and c:IsFacedown()
    end, tp, LOCATION_MZONE, 0, nil)
    local cards = {}
    for tc in aux.Next(g) do
        local ord = tc:GetFlagEffectLabel(403+10) or 99
        table.insert(cards, {card = tc, order = ord})
    end
    table.sort(cards, function(a, b) return a.order < b.order end)
    return cards
end
function c403.stop(e,tp,eg,ep,ev,re,r,rp)
    local c=e:GetHandler()
    local fid=c:GetFieldID()
    if Duel.GetLocationCount(tp,LOCATION_MZONE)<1 then return end
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TOFIELD)
    local g=Duel.SelectMatchingCard(tp,c403.stfilter,e:GetHandlerPlayer(),LOCATION_HAND,0,1,1,nil)
    local tc=g:GetFirst()
    if not c403.set_order then c403.set_order = 1 end
    if tc then
        Duel.MoveToField(tc,tp,tp,LOCATION_MZONE,POS_FACEDOWN_DEFENSE,true)
        local e1=Effect.CreateEffect(tc)
        e1:SetType(EFFECT_TYPE_SINGLE)
        e1:SetCode(EFFECT_CHANGE_TYPE)
        e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
        e1:SetValue(TYPE_TOKEN)
        e1:SetReset(RESET_EVENT|(RESETS_STANDARD|RESET_MSCHANGE|RESET_TOFIELD))
        tc:RegisterEffect(e1,true)
        local e2=e1:Clone()
        e2:SetCode(EFFECT_REMOVE_RACE)
        e2:SetValue(RACE_ALL)
        tc:RegisterEffect(e2,true)
        local e3=e1:Clone()
        e3:SetCode(EFFECT_REMOVE_ATTRIBUTE)
        e3:SetValue(0xff)
        tc:RegisterEffect(e3,true)
        local e4=e1:Clone()
        e4:SetCode(EFFECT_SET_BASE_ATTACK)
        e4:SetValue(0)
        tc:RegisterEffect(e4,true)
        local e5=e1:Clone()
        e5:SetCode(EFFECT_SET_BASE_DEFENSE)
        e5:SetValue(0)
        tc:RegisterEffect(e5,true)
        local e6=Effect.CreateEffect(tc)
        e6:SetType(EFFECT_TYPE_SINGLE)
        e6:SetCode(EFFECT_CANNOT_CHANGE_POSITION)
        tc:RegisterEffect(e6,true)
        local e7=e1:Clone()
        e7:SetType(EFFECT_TYPE_SINGLE)
        e7:SetCode(EFFECT_CANNOT_ATTACK)
        tc:RegisterEffect(e7,true)
        local e8=e1:Clone()
        e8:SetType(EFFECT_TYPE_SINGLE)
        e8:SetCode(EFFECT_UNRELEASABLE_SUM)
        e8:SetValue(1)
        tc:RegisterEffect(e8,true)
        local e9=e8:Clone()
        e9:SetType(EFFECT_TYPE_SINGLE)
        e9:SetCode(EFFECT_UNRELEASABLE_NONSUM)
        e9:SetValue(1)
        tc:RegisterEffect(e9,true)
        local e10=e1:Clone()
        e10:SetType(EFFECT_TYPE_SINGLE)
        e10:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
        e10:SetCode(EFFECT_CANNOT_BE_SYNCHRO_MATERIAL)
        e10:SetValue(1)
        tc:RegisterEffect(e10,true)
        local e11=e1:Clone()
        e11:SetType(EFFECT_TYPE_SINGLE)
        e11:SetProperty(EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_CANNOT_DISABLE)
        e11:SetCode(EFFECT_CANNOT_BE_XYZ_MATERIAL)
        e11:SetValue(1)
        tc:RegisterEffect(e11,true)
        tc:SetStatus(STATUS_NO_LEVEL,true)
        tc:RegisterFlagEffect(403+4,RESET_EVENT+0x17a0000,0,0,fid)
        tc:RegisterFlagEffect(403+10,RESET_EVENT+0x17a0000,0,0,c403.set_order)
        c403.set_order = c403.set_order + 1
    end	
    local ac1=Effect.CreateEffect(c)
    ac1:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
    ac1:SetCode(EVENT_BE_BATTLE_TARGET)
    ac1:SetRange(LOCATION_SZONE)
    ac1:SetLabelObject(tc)
    ac1:SetLabel(fid)
    ac1:SetCondition(c403.actcon1)
    ac1:SetOperation(c403.actop1)
    ac1:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(ac1)
    local ac2=Effect.CreateEffect(c)
    ac2:SetCategory(CATEGORY_DESTROY)
    ac2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
    ac2:SetProperty(EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
    ac2:SetRange(LOCATION_SZONE)
    ac2:SetCode(EVENT_BECOME_TARGET)
    ac2:SetLabelObject(tc)
    ac2:SetLabel(fid)
    ac2:SetCondition(c403.actcon2)
    ac2:SetOperation(c403.actop2)
    ac2:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(ac2)
    local ac3=Effect.CreateEffect(c)
    ac3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
    ac3:SetCode(EVENT_BE_BATTLE_TARGET)
    ac3:SetRange(LOCATION_ONFIELD)
    ac3:SetLabel(fid)
    ac3:SetCondition(c403.ac3con)
    ac3:SetTarget(c403.ac3target)
    ac3:SetOperation(c403.ac3op)
    ac3:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(ac3)
    local ac4=Effect.CreateEffect(c)
    ac4:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
    ac4:SetCode(EVENT_BECOME_TARGET)
    ac4:SetRange(LOCATION_ONFIELD)
    ac4:SetLabel(fid)
    ac4:SetCondition(c403.ac4con)
    ac4:SetTarget(c403.ac3target)
    ac4:SetOperation(c403.ac4op)
    ac4:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(ac4)
    local ac5=Effect.CreateEffect(c)
    ac5:SetCategory(CATEGORY_DESTROY)
    ac5:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_SINGLE)
    ac5:SetCode(EVENT_LEAVE_FIELD)
    ac5:SetLabel(fid)
    ac5:SetTarget(c403.ac3target)
    ac5:SetOperation(c403.ac5op)
    c:RegisterEffect(ac5)
    local ac6=Effect.CreateEffect(c)
    ac6:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_QUICK_F)
    ac6:SetCode(EVENT_CHANGE_POS)
    ac6:SetRange(LOCATION_ONFIELD)
    ac6:SetLabel(fid)
    ac6:SetCondition(c403.ac6con)
    ac6:SetTarget(c403.ac3target)
    ac6:SetOperation(c403.ac5op)
    ac6:SetReset(RESET_EVENT+RESETS_STANDARD)
    c:RegisterEffect(ac6)
    local gs1=Duel.GetMatchingGroup(c403.gsfilter,tp,LOCATION_ONFIELD,0,nil,fid)
    Duel.ChangePosition(gs1,POS_FACEDOWN_DEFENSE)
    Duel.ShuffleSetCard(gs1)
end
function c403.actcon1(e,tp,eg,ep,ev,re,r,rp)
    local d=Duel.GetAttackTarget()
    return d:IsControler(tp) and d==e:GetLabelObject()
end
function c403.actop1(e,tp,eg,ep,ev,re,r,rp)
    local tc=e:GetLabelObject()
    local te=tc:GetActivateEffect()
    if not te or not tc==Duel.GetAttackTarget() then return end
    local pre={Duel.GetPlayerEffect(tp,EFFECT_CANNOT_ACTIVATE)}
    if pre[1] then
        for i,eff in ipairs(pre) do
            local prev=eff:GetValue()
            if type(prev)~='function' or prev(eff,te,tp) then return false end
        end
    end
    if Duel.GetLocationCount(tp,LOCATION_SZONE)>0 and tc:IsRelateToBattle() and tc:CheckActivateEffect(false,false,false)~=nil and not tc:IsHasEffect(EFFECT_CANNOT_TRIGGER) then
        local tpe=tc:GetOriginalType()
        local tg=te:GetTarget()
        local co=te:GetCost()
        local op=te:GetOperation()
        e:SetCategory(te:GetCategory())
        e:SetProperty(te:GetProperty())
        Duel.ClearTargetCard()
        if (tpe&TYPE_FIELD)~=0 then
            local fc=Duel.GetFieldCard(1-tp,LOCATION_SZONE,5)
            if Duel.IsDuelType(DUEL_1_FIELD) then
                if fc then Duel.Destroy(fc,REASON_RULE) end
                fc=Duel.GetFieldCard(tp,LOCATION_SZONE,5)
                if fc and Duel.Destroy(fc,REASON_RULE)==0 then Duel.SendtoGrave(tc,REASON_RULE) end
            else
                fc=Duel.GetFieldCard(tp,LOCATION_SZONE,5)
                if fc and Duel.SendtoGrave(fc,REASON_RULE)==0 then Duel.SendtoGrave(tc,REASON_RULE) end
            end
        end
        if (tpe & TYPE_FIELD) ~= 0 then
            Duel.MoveToField(tc, tp, tp, LOCATION_FZONE, POS_FACEUP, true)
        else
            Duel.MoveToField(tc, tp, tp, LOCATION_SZONE, POS_FACEUP, true)
        end
        Duel.Hint(HINT_CARD,0,tc:GetCode())
        tc:CreateEffectRelation(te)
        if (tpe&(TYPE_EQUIP+TYPE_CONTINUOUS+TYPE_FIELD))==0 and not tc:IsHasEffect(EFFECT_REMAIN_FIELD) then
            tc:CancelToGrave(false)
        end
        if te:GetCode()==EVENT_CHAINING then
            local chain=Duel.GetCurrentChain()-1
            local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
            local tc2=te2:GetHandler()
            local g2=Group.FromCards(tc2)
            local p=tc2:GetControler()
            if co then co(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
            if tg then tg(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
        elseif te:GetCode()==EVENT_FREE_CHAIN then
            if co then co(te,tp,eg,ep,ev,re,r,rp,1) end
            if tg then tg(te,tp,eg,ep,ev,re,r,rp,1) end
        else
            local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
            if co then co(te,tp,teg,tep,tev,tre,tr,trp,1) end
            if tg then tg(te,tp,teg,tep,tev,tre,tr,trp,1) end
        end
        Duel.BreakEffect()
        local g=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
        if g then
            local etc=g:GetFirst()
            while etc do
                etc:CreateEffectRelation(te)
                etc=g:GetNext()
            end
        end
        tc:SetStatus(STATUS_ACTIVATED,true)
        if not tc:IsDisabled() then
            if te:GetCode()==EVENT_CHAINING then
                local chain=Duel.GetCurrentChain()-1
                local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
                local tc2=te2:GetHandler()
                local g2=Group.FromCards(tc2)
                local p=tc2:GetControler()
                if op then op(te,tp,g2,p,chain,te2,REASON_EFFECT,p) end
            elseif te:GetCode()==EVENT_FREE_CHAIN then
                if op then op(te,tp,eg,ep,ev,re,r,rp) end
            else
                local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
                if op then op(te,tp,teg,tep,tev,tre,tr,trp) end
            end
        end
        Duel.RaiseEvent(Group.CreateGroup(tc),EVENT_CHAIN_SOLVED,te,0,tp,tp,Duel.GetCurrentChain())
        if g and tc:IsType(TYPE_EQUIP) and not tc:GetEquipTarget() then
            Duel.Equip(tp,tc,g:GetFirst())
        end
        tc:ReleaseEffectRelation(te)
        if g then
            local etc=g:GetFirst()
            while etc do
                etc:ReleaseEffectRelation(te)
                etc=g:GetNext()
            end
        end
    end
end
function c403.actcon2(e,tp,eg,ep,ev,re,r,rp)
    return rp~=tp and eg:IsContains(e:GetLabelObject()) 
end
function c403.actop2(e,tp,eg,ep,ev,re,r,rp)
    local tc=eg:GetFirst()
    local te=tc:GetActivateEffect()
    if not te then return end
    local pre={Duel.GetPlayerEffect(tp,EFFECT_CANNOT_ACTIVATE)}
    if pre[1] then
        for i,eff in ipairs(pre) do
            local prev=eff:GetValue()
            if type(prev)~='function' or prev(eff,te,tp) then return false end
        end
    end
    if Duel.GetLocationCount(tp,LOCATION_SZONE)>0 and tc:CheckActivateEffect(false,false,false)~=nil and not tc:IsHasEffect(EFFECT_CANNOT_TRIGGER) then
        local tpe=tc:GetOriginalType()
        local tg=te:GetTarget()
        local co=te:GetCost()
        local op=te:GetOperation()
        e:SetCategory(te:GetCategory())
        e:SetProperty(te:GetProperty())
        Duel.ClearTargetCard()
        if (tpe&TYPE_FIELD)~=0 then
            local fc=Duel.GetFieldCard(1-tp,LOCATION_SZONE,5)
            if Duel.IsDuelType(DUEL_1_FIELD) then
                if fc then Duel.Destroy(fc,REASON_RULE) end
                fc=Duel.GetFieldCard(tp,LOCATION_SZONE,5)
                if fc and Duel.Destroy(fc,REASON_RULE)==0 then Duel.SendtoGrave(tc,REASON_RULE) end
            else
                fc=Duel.GetFieldCard(tp,LOCATION_SZONE,5)
                if fc and Duel.SendtoGrave(fc,REASON_RULE)==0 then Duel.SendtoGrave(tc,REASON_RULE) end
            end
        end
        if (tpe & TYPE_FIELD) ~= 0 then
            Duel.MoveToField(tc, tp, tp, LOCATION_FZONE, POS_FACEUP, true)
        else
            Duel.MoveToField(tc, tp, tp, LOCATION_SZONE, POS_FACEUP, true)
        end
        Duel.Hint(HINT_CARD,0,tc:GetCode())
        tc:CreateEffectRelation(te)
        if (tpe&(TYPE_EQUIP+TYPE_CONTINUOUS+TYPE_FIELD))==0 and not tc:IsHasEffect(EFFECT_REMAIN_FIELD) then
            tc:CancelToGrave(false)
        end
        if te:GetCode()==EVENT_CHAINING then
            local chain=Duel.GetCurrentChain()-1
            local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
            local tc2=te2:GetHandler()
            local g2=Group.FromCards(tc2)
            local p=tc2:GetControler()
            if co then co(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
            if tg then tg(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
        elseif te:GetCode()==EVENT_FREE_CHAIN then
            if co then co(te,tp,eg,ep,ev,re,r,rp,1) end
            if tg then tg(te,tp,eg,ep,ev,re,r,rp,1) end
        else
            local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
            if co then co(te,tp,teg,tep,tev,tre,tr,trp,1) end
            if tg then tg(te,tp,teg,tep,tev,tre,tr,trp,1) end
        end
        Duel.BreakEffect()
        local g=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
        if g then
            local etc=g:GetFirst()
            while etc do
                etc:CreateEffectRelation(te)
                etc=g:GetNext()
            end
        end
        tc:SetStatus(STATUS_ACTIVATED,true)
        if not tc:IsDisabled() then
            if te:GetCode()==EVENT_CHAINING then
                local chain=Duel.GetCurrentChain()-1
                local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
                local tc2=te2:GetHandler()
                local g2=Group.FromCards(tc2)
                local p=tc2:GetControler()
                if op then op(te,tp,g2,p,chain,te2,REASON_EFFECT,p) end
            elseif te:GetCode()==EVENT_FREE_CHAIN then
                if op then op(te,tp,eg,ep,ev,re,r,rp) end
            else
                local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
                if op then op(te,tp,teg,tep,tev,tre,tr,trp) end
            end
        end
        Duel.RaiseEvent(Group.CreateGroup(tc),EVENT_CHAIN_SOLVED,te,0,tp,tp,Duel.GetCurrentChain())
        if g and tc:IsType(TYPE_EQUIP) and not tc:GetEquipTarget() then
            Duel.Equip(tp,tc,g:GetFirst())
        end
        tc:ReleaseEffectRelation(te)
        if g then
            local etc=g:GetFirst()
            while etc do
                etc:ReleaseEffectRelation(te)
                etc=g:GetNext()
            end
        end
    end
end
function c403.ac3con(e,tp,eg,ep,ev,re,r,rp)
    local d=Duel.GetAttackTarget()
    return d and d:IsControler(tp) and d:GetFlagEffectLabel(403+1)==e:GetLabel()
end
function c403.ac3target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
    if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and chkc:GetFlagEffectLabel(403+4)==e:GetLabel() end
    if chk==0 then 
        return Duel.IsExistingMatchingCard(
            function(c) return c:GetFlagEffectLabel(403+4)==e:GetLabel() and c:IsFacedown() end, 
            tp, LOCATION_MZONE, 0, 1, nil
        ) 
    end
    local g=Duel.GetMatchingGroup(
        function(c) return c:GetFlagEffectLabel(403+4)==e:GetLabel() and c:IsFacedown() end, 
        tp, LOCATION_MZONE, 0, nil
    )
    Duel.SetTargetCard(g)
end
function c403.ac3op(e,tp,eg,ep,ev,re,r,rp)
    local atk_target = Duel.GetAttackTarget()
    local fid = e:GetLabel()
    if atk_target and atk_target:IsFacedown() and atk_target:GetFlagEffectLabel(403+1)==fid then
        Duel.ChangePosition(atk_target, atk_target:GetPreviousPosition())
        if atk_target:GetFlagEffectLabel(403+1)==fid then
            atk_target:ResetFlagEffect(403+1)
        else
            atk_target:ResetFlagEffect(403+2)
        end
    end
    local g1 = Duel.GetMatchingGroup(c403.desfilter1, tp, LOCATION_ONFIELD, LOCATION_ONFIELD, nil, fid)
    for tc2 in aux.Next(g1) do
        Duel.ChangePosition(tc2, tc2:GetPreviousPosition()) 
        if tc2:GetFlagEffectLabel(403+1)==fid then
            tc2:ResetFlagEffect(403+1)
        else 
            tc2:ResetFlagEffect(403+2)
        end
    end
    local g=Duel.GetChainInfo(0, CHAININFO_TARGET_CARDS)
    if not g or g:GetCount()==0 then return end
    local ordered_cards = c403.GetOrderedSetCards(tp, fid)
    for i, info in ipairs(ordered_cards) do
        local tc = info.card
        if g:IsContains(tc) and tc:IsRelateToEffect(e) and tc:IsLocation(LOCATION_MZONE) and tc:IsFacedown() then
            if (tc:GetOriginalType() & TYPE_FIELD) ~= 0 then
                Duel.MoveToField(tc,tp,tp,LOCATION_FZONE,POS_FACEUP,true)
            else
                Duel.MoveToField(tc,tp,tp,LOCATION_SZONE,POS_FACEUP,true)
            end
            if tc:IsType(TYPE_SPELL+TYPE_TRAP) and tc:GetActivateEffect() then
                local te=tc:GetActivateEffect()
                local tpe=tc:GetType()
                local tg_func=te:GetTarget()
                local co_func=te:GetCost()
                local op_func=te:GetOperation()
                e:SetCategory(te:GetCategory())
                e:SetProperty(te:GetProperty())
                Duel.ClearTargetCard()
                Duel.Hint(HINT_CARD,0,tc:GetCode())
                tc:CreateEffectRelation(te)
                if (tpe&(TYPE_EQUIP+TYPE_CONTINUOUS+TYPE_FIELD))==0 and not tc:IsHasEffect(EFFECT_REMAIN_FIELD) and not (te and te:IsHasCategory(CATEGORY_EQUIP)) then
                    tc:CancelToGrave(false)
                end
                if te:GetCode()==EVENT_CHAINING then
                    local chain=Duel.GetCurrentChain()-1
                    local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
                    local tc2=te2:GetHandler()
                    local g2=Group.FromCards(tc2)
                    local p=tc2:GetControler()
                    if co_func then co_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
                    if tg_func then tg_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
                elseif te:GetCode()==EVENT_FREE_CHAIN then
                    if co_func then co_func(te,tp,eg,ep,ev,re,r,rp,1) end
                    if tg_func then tg_func(te,tp,eg,ep,ev,re,r,rp,1) end
                else
                    local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
                    if co_func then co_func(te,tp,teg,tep,tev,tre,tr,trp,1) end
                    if tg_func then tg_func(te,tp,teg,tep,tev,tre,tr,trp,1) end
                end
                Duel.BreakEffect()
                local g3=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
                if g3 then
                    local etc=g3:GetFirst()
                    while etc do
                        etc:CreateEffectRelation(te)
                        etc=g3:GetNext()
                    end
                end
                tc:SetStatus(STATUS_ACTIVATED,true)
                if not tc:IsDisabled() then
                    if te:GetCode()==EVENT_CHAINING then
                        local chain=Duel.GetCurrentChain()-1
                        local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
                        local tc2=te2:GetHandler()
                        local g2=Group.FromCards(tc2)
                        local p=tc2:GetControler()
                        if op_func then op_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p) end
                    elseif te:GetCode()==EVENT_FREE_CHAIN then
                        if op_func then op_func(te,tp,eg,ep,ev,re,r,rp) end
                    else
                        local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
                        if op_func then op_func(te,tp,teg,tep,tev,tre,tr,trp) end
                    end
                end
                Duel.RaiseEvent(Group.CreateGroup(tc),EVENT_CHAIN_SOLVED,te,0,tp,tp,Duel.GetCurrentChain())
                if g3 and tc:IsType(TYPE_EQUIP) and not tc:GetEquipTarget() then
                    Duel.Equip(tp,tc,g3:GetFirst())
                end
                tc:ReleaseEffectRelation(te)
                if g3 then
                    local etc=g3:GetFirst()
                    while etc do
                        etc:ReleaseEffectRelation(te)
                        etc=g3:GetNext()
                    end
                end
            end
        end
    end
    local g2=Duel.GetMatchingGroup(c403.desfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,fid)
    if #g2>0 then
        Duel.Destroy(g2,REASON_EFFECT)
    end
    Duel.Destroy(e:GetHandler(),REASON_EFFECT)
end
function c403.descon(e)
    local c=e:GetHandler()
    if c403.copy_mode[c] and c:GetFlagEffect(403)==0 then return false end
    local fid=c:GetFieldID()
    return not Duel.IsExistingMatchingCard(c403.refilter,e:GetHandlerPlayer(),LOCATION_ONFIELD,0,1,nil,fid)
end
function c403.ac4con(e,tp,eg,ep,ev,re,r,rp)
    local fid = e:GetLabel()
    return eg:IsExists(function(c)
        return c:IsControler(tp) and c:GetFlagEffectLabel(403+1)==fid
    end, 1, nil)
end
function c403.ac4op(e,tp,eg,ep,ev,re,r,rp)
    local fid = e:GetLabel()
    local tc1 = eg:GetFirst()
    if tc1 and tc1:GetFlagEffectLabel(403+1)==fid then
        Duel.ChangePosition(tc1,tc1:GetPreviousPosition())
        if tc1:GetFlagEffectLabel(403+1)==fid then
            tc1:ResetFlagEffect(403+1)
        else 
            tc1:ResetFlagEffect(403+2)
        end		
    end
    local g1 = Duel.GetMatchingGroup(c403.desfilter1, tp, LOCATION_ONFIELD, LOCATION_ONFIELD, nil, fid)
    for tc2 in aux.Next(g1) do
        Duel.ChangePosition(tc2, tc2:GetPreviousPosition()) 
        if tc2:GetFlagEffectLabel(403+1)==fid then
            tc2:ResetFlagEffect(403+1)
        else 
            tc2:ResetFlagEffect(403+2)
        end
    end
    local g=Duel.GetChainInfo(0, CHAININFO_TARGET_CARDS)
    if not g or g:GetCount()==0 then return end
    local ordered_cards = c403.GetOrderedSetCards(tp, fid)
    for i, info in ipairs(ordered_cards) do
        local tc = info.card
        if g:IsContains(tc) and tc:IsRelateToEffect(e) and tc:IsLocation(LOCATION_MZONE) and tc:IsFacedown() then
            if (tc:GetOriginalType() & TYPE_FIELD) ~= 0 then
                Duel.MoveToField(tc,tp,tp,LOCATION_FZONE,POS_FACEUP,true)
            else
                Duel.MoveToField(tc,tp,tp,LOCATION_SZONE,POS_FACEUP,true)
            end
            if tc:IsType(TYPE_SPELL+TYPE_TRAP) and tc:GetActivateEffect() then
                local te=tc:GetActivateEffect()
                local tpe=tc:GetType()
                local tg_func=te:GetTarget()
                local co_func=te:GetCost()
                local op_func=te:GetOperation()
                e:SetCategory(te:GetCategory())
                e:SetProperty(te:GetProperty())
                Duel.ClearTargetCard()
                Duel.Hint(HINT_CARD,0,tc:GetCode())
                tc:CreateEffectRelation(te)
                if (tpe&(TYPE_EQUIP+TYPE_CONTINUOUS+TYPE_FIELD))==0 and not tc:IsHasEffect(EFFECT_REMAIN_FIELD) and not (te and te:IsHasCategory(CATEGORY_EQUIP)) then
                    tc:CancelToGrave(false)
                end
                if te:GetCode()==EVENT_CHAINING then
                    local chain=Duel.GetCurrentChain()-1
                    local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
                    local tc2=te2:GetHandler()
                    local g2=Group.FromCards(tc2)
                    local p=tc2:GetControler()
                    if co_func then co_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
                    if tg_func then tg_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
                elseif te:GetCode()==EVENT_FREE_CHAIN then
                    if co_func then co_func(te,tp,eg,ep,ev,re,r,rp,1) end
                    if tg_func then tg_func(te,tp,eg,ep,ev,re,r,rp,1) end
                else
                    local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
                    if co_func then co_func(te,tp,teg,tep,tev,tre,tr,trp,1) end
                    if tg_func then tg_func(te,tp,teg,tep,tev,tre,tr,trp,1) end
                end
                Duel.BreakEffect()
                local g3=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
                if g3 then
                    local etc=g3:GetFirst()
                    while etc do
                        etc:CreateEffectRelation(te)
                        etc=g3:GetNext()
                    end
                end
                tc:SetStatus(STATUS_ACTIVATED,true)
                if not tc:IsDisabled() then
                    if te:GetCode()==EVENT_CHAINING then
                        local chain=Duel.GetCurrentChain()-1
                        local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
                        local tc2=te2:GetHandler()
                        local g2=Group.FromCards(tc2)
                        local p=tc2:GetControler()
                        if op_func then op_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p) end
                    elseif te:GetCode()==EVENT_FREE_CHAIN then
                        if op_func then op_func(te,tp,eg,ep,ev,re,r,rp) end
                    else
                        local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
                        if op_func then op_func(te,tp,teg,tep,tev,tre,tr,trp) end
                    end
                end
                Duel.RaiseEvent(Group.CreateGroup(tc),EVENT_CHAIN_SOLVED,te,0,tp,tp,Duel.GetCurrentChain())
                if g3 and tc:IsType(TYPE_EQUIP) and not tc:GetEquipTarget() then
                    Duel.Equip(tp,tc,g3:GetFirst())
                end
                tc:ReleaseEffectRelation(te)
                if g3 then
                    local etc=g3:GetFirst()
                    while etc do
                        etc:ReleaseEffectRelation(te)
                        etc=g3:GetNext()
                    end
                end
            end
        end
    end
    local g2=Duel.GetMatchingGroup(c403.desfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,fid)
    if #g2>0 then
        Duel.Destroy(g2,REASON_EFFECT)
    end
    Duel.Destroy(e:GetHandler(),REASON_EFFECT)
end
function c403.ac5op(e,tp,eg,ep,ev,re,r,rp)
    local fid=e:GetLabel()
    local g1=Duel.GetMatchingGroup(c403.desfilter4,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,fid)
    for tc in aux.Next(g1) do
        Duel.ChangePosition(tc,tc:GetPreviousPosition()) 
        if tc:GetFlagEffectLabel(403+1)==fid then
            tc:ResetFlagEffect(403+1)
        else 
            tc:ResetFlagEffect(403+2) 
        end
    end
    local g=Duel.GetChainInfo(0, CHAININFO_TARGET_CARDS)
    if not g or g:GetCount()==0 then return end
    local ordered_cards = c403.GetOrderedSetCards(tp, fid)
    for i, info in ipairs(ordered_cards) do
        local tc = info.card
        if g:IsContains(tc) and tc:IsRelateToEffect(e) and tc:IsLocation(LOCATION_MZONE) and tc:IsFacedown() then
            if (tc:GetOriginalType() & TYPE_FIELD) ~= 0 then
                Duel.MoveToField(tc,tp,tp,LOCATION_FZONE,POS_FACEUP,true)
            else
                Duel.MoveToField(tc,tp,tp,LOCATION_SZONE,POS_FACEUP,true)
            end
            if tc:IsType(TYPE_SPELL+TYPE_TRAP) and tc:GetActivateEffect() then
                local te=tc:GetActivateEffect()
                local tpe=tc:GetType()
                local tg_func=te:GetTarget()
                local co_func=te:GetCost()
                local op_func=te:GetOperation()
                e:SetCategory(te:GetCategory())
                e:SetProperty(te:GetProperty())
                Duel.ClearTargetCard()
                Duel.Hint(HINT_CARD,0,tc:GetCode())
                tc:CreateEffectRelation(te)
                if (tpe&(TYPE_EQUIP+TYPE_CONTINUOUS+TYPE_FIELD))==0 and not tc:IsHasEffect(EFFECT_REMAIN_FIELD) and not (te and te:IsHasCategory(CATEGORY_EQUIP)) then
                    tc:CancelToGrave(false)
                end
                if te:GetCode()==EVENT_CHAINING then
                    local chain=Duel.GetCurrentChain()-1
                    local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
                    local tc2=te2:GetHandler()
                    local g2=Group.FromCards(tc2)
                    local p=tc2:GetControler()
                    if co_func then co_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
                    if tg_func then tg_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p,1) end
                elseif te:GetCode()==EVENT_FREE_CHAIN then
                    if co_func then co_func(te,tp,eg,ep,ev,re,r,rp,1) end
                    if tg_func then tg_func(te,tp,eg,ep,ev,re,r,rp,1) end
                else
                    local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
                    if co_func then co_func(te,tp,teg,tep,tev,tre,tr,trp,1) end
                    if tg_func then tg_func(te,tp,teg,tep,tev,tre,tr,trp,1) end
                end
                Duel.BreakEffect()
                local g3=Duel.GetChainInfo(0,CHAININFO_TARGET_CARDS)
                if g3 then
                    local etc=g3:GetFirst()
                    while etc do
                        etc:CreateEffectRelation(te)
                        etc=g3:GetNext()
                    end
                end
                tc:SetStatus(STATUS_ACTIVATED,true)
                if not tc:IsDisabled() then
                    if te:GetCode()==EVENT_CHAINING then
                        local chain=Duel.GetCurrentChain()-1
                        local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
                        local tc2=te2:GetHandler()
                        local g2=Group.FromCards(tc2)
                        local p=tc2:GetControler()
                        if op_func then op_func(te,tp,g2,p,chain,te2,REASON_EFFECT,p) end
                    elseif te:GetCode()==EVENT_FREE_CHAIN then
                        if op_func then op_func(te,tp,eg,ep,ev,re,r,rp) end
                    else
                        local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
                        if op_func then op_func(te,tp,teg,tep,tev,tre,tr,trp) end
                    end
                end
                Duel.RaiseEvent(Group.CreateGroup(tc),EVENT_CHAIN_SOLVED,te,0,tp,tp,Duel.GetCurrentChain())
                if g3 and tc:IsType(TYPE_EQUIP) and not tc:GetEquipTarget() then
                    Duel.Equip(tp,tc,g3:GetFirst())
                end
                tc:ReleaseEffectRelation(te)
                if g3 then
                    local etc=g3:GetFirst()
                    while etc do
                        etc:ReleaseEffectRelation(te)
                        etc=g3:GetNext()
                    end
                end
            end
        end
    end
    local g2=Duel.GetMatchingGroup(c403.desfilter2,tp,LOCATION_ONFIELD,LOCATION_ONFIELD,nil,fid)
    if #g2>0 then
        Duel.Destroy(g2,REASON_EFFECT)
    end
    e:GetHandler():ResetFlagEffect(403)
    Duel.Destroy(e:GetHandler(),REASON_EFFECT)
end
function c403.ac6con(e,tp,eg,ep,ev,re,r,rp)
local fid = e:GetLabel()
    return eg:IsExists(function(c)
        return c:GetFlagEffectLabel(403+1)==fid
            and c:IsPreviousPosition(POS_FACEDOWN)
            and c:IsFaceup()
    end, 1, nil)
end