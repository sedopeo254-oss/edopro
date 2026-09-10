-- Attack Guidance Armor (Anime)

local s,id=GetID()
local MP_PLAYER_BASE=-68719476736 -- signed 0xfffffff000000000
local MP_MAX_PLAYERS=26

local function is_multiplayer()
    return Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0
end

local function get_logical_monsters(logical)
    if not Duel.GetPlayerFieldGroup then return Group.CreateGroup() end
    local g=Duel.GetPlayerFieldGroup(logical,LOCATION_MZONE)
    if not g then return Group.CreateGroup() end
    return g:Filter(function(c) return c:IsLocation(LOCATION_MZONE) end,nil)
end

local function get_candidate_player_mask()
    local active=Duel.GetActiveLogicalPlayerMask()
    local mask=0
    for p=0,MP_MAX_PLAYERS-1 do
        if (active&(1<<p))~=0 and Duel.IsLogicalPlayerActive(p) then
            local g=get_logical_monsters(p)
            if g:GetCount()>0 then
                mask=mask|(1<<p)
            end
        end
    end
    return mask
end

local function select_logical_player(tp,mask)
    local players,options={},{}
    for p=0,MP_MAX_PLAYERS-1 do
        if (mask&(1<<p))~=0 then
            players[#players+1]=p
            options[#options+1]=MP_PLAYER_BASE+p
        end
    end
    if #players==0 then return nil end
    if #players==1 then return players[1] end
    local op=Duel.SelectOption(tp,table.unpack(options))
    return players[op+1]
end

local function is_opponent_monster(tp,c)
    if not c then return false end
    if not is_multiplayer() then
        return c:IsControler(1-tp)
    end
    local logical=c:GetLogicalControler()
    if logical==nil then return false end
    local mask=Duel.GetLogicalPlayerMask(tp,false,false,true)
    return (mask&(1<<logical))~=0
end
function s.initial_effect(c)
    local e1=Effect.CreateEffect(c)
    e1:SetDescription(aux.Stringid(412,0))
    e1:SetType(EFFECT_TYPE_ACTIVATE)
    e1:SetCode(EVENT_ATTACK_ANNOUNCE)
    e1:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_CARD_TARGET)
    e1:SetCondition(s.condition)
    e1:SetTarget(s.target)
    e1:SetOperation(s.operation)
    c:RegisterEffect(e1)
end
local function get_code_482_monster(tp)
    if is_multiplayer() and Duel.GetLogicalPlayer and Duel.GetPlayerFieldGroup then
        local logical=Duel.GetLogicalPlayer(tp)
        if logical~=nil then
            local g=get_logical_monsters(logical)
            local sg=g:Filter(function(c)
                return c:IsFaceup() and c:IsCode(33066139)
            end,nil)
            return sg:GetFirst()
        end
    end
    return Duel.GetFirstMatchingCard(function(c)
        return c:IsFaceup() and c:IsCode(33066139)
    end,tp,0,LOCATION_MZONE,nil)
end
function s.condition(e,tp,eg,ep,ev,re,r,rp)
    local att = Duel.GetAttacker()
    if not att then return false end
    if is_multiplayer() and Duel.GetLogicalPlayerMask then
        return is_opponent_monster(tp,att)
    end
    return att:IsControler(1-tp)
end
function s.filter(c)
    return c:IsLocation(LOCATION_MZONE)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
    local att = Duel.GetAttacker()
    local val
    if att then
        val = att:IsDefensePos() and att:GetDefense() or att:GetAttack()
    else
        local ref = get_code_482_monster(tp)
        if not ref then
            if chk==0 then return false end
            return
        end
        val = ref:IsDefensePos() and ref:GetDefense() or ref:GetAttack()
    end
    if is_multiplayer() and Duel.GetPlayerFieldGroup then
        local mask=get_candidate_player_mask()
        if chk==0 then return mask~=0 end
        local logical=select_logical_player(tp,mask)
        if logical==nil then return end
        local g=get_logical_monsters(logical)
        Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
        local sg=g:Select(tp,1,1,nil)
        e:SetLabel(val)
        if #sg>0 then
            Duel.SetTargetCard(sg)
        end
        return
    end
    if chk==0 then
        return Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_MZONE,LOCATION_MZONE,1,nil)
    end
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
    local g = Duel.SelectMatchingCard(tp,s.filter,tp,LOCATION_MZONE,LOCATION_MZONE,1,1,nil)
    e:SetLabel(val)
    if #g > 0 then
        Duel.SetTargetCard(g)
    end
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
    local val = e:GetLabel()
    local tc = Duel.GetFirstTarget()
    local real_attacker = Duel.GetAttacker()
    if not tc or not tc:IsRelateToEffect(e) then return end
    local reaper = get_code_482_monster(tp)
    if not real_attacker and reaper and tc~=reaper then
        local g=Group.CreateGroup()
        g:AddCard(tc)
        g:AddCard(reaper)
        Duel.SetTargetCard(g)
        Duel.CalculateDamage(reaper,tc)
        return
    end
    local attacker = real_attacker
    if not attacker and reaper then
        attacker = reaper
    end
    if not attacker then
        return
    end
    if tc==attacker then
        Duel.NegateAttack()
    end
    if tc==attacker and tc:GetOriginalCode()==511000497 then
        local ez=Effect.CreateEffect(tc)
        ez:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
        ez:SetCode(EVENT_LEAVE_FIELD)
        ez:SetProperty(EFFECT_FLAG_DAMAGE_STEP)
        ez:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_BATTLE&~(RESET_LEAVE|RESET_TOGRAVE|RESET_REMOVE))
        ez:SetCondition(s.damcon)
        ez:SetCost(s.ez_cost)
        ez:SetTarget(s.ez_tg)
        ez:SetOperation(s.ez_op)
        tc:RegisterEffect(ez)
    end
    if tc==attacker and tc:GetOriginalCode()==718 then
        local ez2=Effect.CreateEffect(tc)
        ez2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
        ez2:SetCode(EVENT_LEAVE_FIELD)
        ez2:SetProperty(EFFECT_FLAG_DAMAGE_STEP)
        ez2:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_PHASE+PHASE_BATTLE&~(RESET_LEAVE|RESET_TOGRAVE))
        ez2:SetCondition(s.damcon)
        ez2:SetTarget(s.ez_tg2)
        ez2:SetOperation(s.ez_op2)
        tc:RegisterEffect(ez2)
    end
    local skip_destroy = false
    if tc == attacker and tc:IsDefensePos() and tc:GetDefense() == val then
        skip_destroy = true
    end
    if tc ~= attacker then
        local e1=Effect.CreateEffect(e:GetHandler())
        e1:SetType(EFFECT_TYPE_FIELD)
        e1:SetRange(LOCATION_SZONE)
        e1:SetCode(EFFECT_SELF_ATTACK)
        e1:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
        e1:SetReset(RESET_PHASE+PHASE_DAMAGE)
        e1:SetTargetRange(1,1)
        Duel.RegisterEffect(e1,tp)
        Duel.ChangeAttackTarget(tc,true)
        return
    end
    Duel.NegateAttack()
    local valid_ids = {
        [513000134]=true,
        [513000135]=true,
        [513000136]=true,
        [513000137]=true,
        [513000138]=true,
        [513000139]=true
    }
    local set_stats_ids = {
        [513000134]=true,
        [513000136]=true,
        [513000138]=true,
        [513000139]=true
    }
    if set_stats_ids[tc:GetOriginalCode()] and tc == attacker then
        local e1=Effect.CreateEffect(e:GetHandler())
        e1:SetType(EFFECT_TYPE_SINGLE)
        e1:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
        e1:SetCode(EFFECT_SET_ATTACK_FINAL)
        e1:SetValue(val)
        e1:SetReset(RESET_EVENT|RESETS_STANDARD)
        tc:RegisterEffect(e1)
        local e2=e1:Clone()
        e2:SetCode(EFFECT_SET_DEFENSE_FINAL)
        e2:SetValue(val)
        tc:RegisterEffect(e2)
    end
    local avoid_battle_damage = tc:IsHasEffect(EFFECT_AVOID_BATTLE_DAMAGE) or tc:IsHasEffect(EFFECT_NO_BATTLE_DAMAGE)
    local opponent_protected = Duel.IsPlayerAffectedByEffect(1-tp, EFFECT_AVOID_BATTLE_DAMAGE) or Duel.IsPlayerAffectedByEffect(1-tp, EFFECT_NO_BATTLE_DAMAGE)
    local change_battle_damage = tc:IsHasEffect(EFFECT_CHANGE_BATTLE_DAMAGE)
    local opponent_change_battle_damage = Duel.IsPlayerAffectedByEffect(1-tp, EFFECT_CHANGE_BATTLE_DAMAGE)
    local damage = 0
    local current_val
    if tc:IsAttackPos() then
        current_val = tc:GetAttack()
    else
        current_val = tc:GetDefense()
    end
    if current_val and current_val ~= val then
        if tc:IsDefensePos() and current_val < val then
            local has_pierce = tc:IsHasEffect(EFFECT_PIERCE)
            local disabled = tc:IsDisabled()
            local has_pierce_self = false
            if has_pierce then
                local effs = {tc:GetCardEffect(EFFECT_PIERCE)}
                for _,eff in ipairs(effs) do
                    if eff:GetOwner()==tc then
                        has_pierce_self = true
                        break
                    end
                end
            end
            local has_pierce_external = has_pierce and not has_pierce_self
            if (has_pierce_self and not disabled) or has_pierce_external then
                damage = math.abs(current_val - val)
            else
                damage = 0
            end
        else
            damage = math.abs(current_val - val)
        end
    end
    local skip_damage = false
    local gain_atk = false
    local half_damage_effect = false
    local eqg = tc:GetEquipGroup()
    for ec in aux.Next(eqg) do
        if not ec:IsDisabled() then
            local code = ec:GetOriginalCode()
            if code == 810000069 or code == 358 then
                skip_damage = true
            end
            if code == 95784434 then
                gain_atk = true
            end
            if code == 511001616 then
                if Duel.IsExistingMatchingCard(function(c)
                    return c:IsSetCard(SET_RANK_UP_MAGIC) and c:IsSpell() and c:IsAbleToHand()
                end, 1-tp, LOCATION_DECK, 0, 1, nil) then
                    if Duel.SelectYesNo(1-tp, aux.Stringid(412,1)) then
                        Duel.Hint(HINT_SELECTMSG, 1-tp, HINTMSG_ATOHAND)
                        local g = Duel.SelectMatchingCard(1-tp, function(c)
                            return c:IsSetCard(SET_RANK_UP_MAGIC) and c:IsSpell() and c:IsAbleToHand()
                        end, 1-tp, LOCATION_DECK, 0, 1, 1, nil)
                        if #g > 0 then
                            Duel.SendtoHand(g, nil, REASON_EFFECT)
                            Duel.ConfirmCards(tp, g)
                            skip_damage = true
                        end
                    end
                end
            end
            if code == 511001621 then
                half_damage_effect = true
            end
        end
    end
    if tc == attacker and tc:IsHasEffect(EFFECT_INDESTRUCTABLE_BATTLE)
        and not tc:IsSetCard(0x48)
        and not tc:IsDisabled() then
        local blocked_ids_group1 = { [36472900]=true, [20700531]=true, [52077741]=true }
        local has_ind_battle_from_other = false
        local effs = {tc:GetCardEffect(EFFECT_INDESTRUCTABLE_BATTLE)}
        for _,eff in ipairs(effs) do
            if eff:GetOwner() ~= tc then
                has_ind_battle_from_other = true
                break
            end
        end
        local code = tc:GetCode()
        local atk = tc:GetAttack()
        local val_saved = val
        local block_group1 = blocked_ids_group1[code] and atk <= 1900
        local block_group2 = (code == 50939127) and atk >= 1900
        local block_group3 = ((code == 23770284) or (code == 52824910)) and atk ~= val_saved
        local block_ie = (block_group1 or block_group2 or block_group3) and not has_ind_battle_from_other
        if not block_ie then
            local e1=Effect.CreateEffect(tc)
            e1:SetType(EFFECT_TYPE_SINGLE)
            e1:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
            e1:SetValue(1)
            e1:SetReset(RESET_CHAIN)
            tc:RegisterEffect(e1)
            tc:RegisterFlagEffect(id+300, RESET_CHAIN, 0, 1)
        end
    end
    if tc == attacker and tc:IsHasEffect(EFFECT_INDESTRUCTABLE_BATTLE) and tc:IsDisabled() and not tc:IsSetCard(0x48) then
        local e2=Effect.CreateEffect(tc)
        e2:SetType(EFFECT_TYPE_SINGLE)
        e2:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
        e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
        e2:SetValue(1)
        e2:SetReset(RESET_CHAIN)
        tc:RegisterEffect(e2)
        tc:RegisterFlagEffect(id+300, RESET_CHAIN, 0, 1)
    end
    function HasIndBattagliaDaAltraCarta(tc)
        local te = tc:IsHasEffect(EFFECT_INDESTRUCTABLE_BATTLE)
        if not te then return false end
        local effs = {tc:GetCardEffect(EFFECT_INDESTRUCTABLE_BATTLE)}
        for _,eff in ipairs(effs) do
            if eff:GetOwner() ~= tc then return true end
        end
        return false
    end
    if tc == attacker and tc:IsSetCard(0x48) and tc:IsDisabled()
        and HasIndBattagliaDaAltraCarta(tc) then
        local e3=Effect.CreateEffect(tc)
        e3:SetType(EFFECT_TYPE_SINGLE)
        e3:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
        e3:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
        e3:SetValue(1)
        e3:SetReset(RESET_CHAIN)
        tc:RegisterEffect(e3)
        tc:RegisterFlagEffect(id+300, RESET_CHAIN, 0, 1)
    end
    function HasIndBattagliaDaAltraCarta2(tc)
        local te = tc:IsHasEffect(EFFECT_INDESTRUCTABLE_BATTLE)
        if not te then return false end
        local effs = {tc:GetCardEffect(EFFECT_INDESTRUCTABLE_BATTLE)}
        for _,eff in ipairs(effs) do
            if eff:GetOwner() ~= tc then return true end
        end
        return false
    end
    if tc == attacker and tc:IsSetCard(0x48) and not tc:IsDisabled()
        and HasIndBattagliaDaAltraCarta2(tc) then
        local e4=Effect.CreateEffect(tc)
        e4:SetType(EFFECT_TYPE_SINGLE)
        e4:SetCode(EFFECT_INDESTRUCTABLE_EFFECT)
        e4:SetProperty(EFFECT_FLAG_CANNOT_DISABLE)
        e4:SetValue(1)
        e4:SetReset(RESET_CHAIN)
        tc:RegisterEffect(e4)
        tc:RegisterFlagEffect(id+300, RESET_CHAIN, 0, 1)
    end
    local has_indestructable_effect = tc:IsHasEffect(EFFECT_INDESTRUCTABLE_EFFECT)
    local has_indestructable_battle = tc:IsHasEffect(EFFECT_INDESTRUCTABLE_BATTLE) and not tc:IsSetCard(0x48)
    local is_disabled = tc:IsDisabled()
    local reflect_battle_damage = tc:IsHasEffect(EFFECT_REFLECT_BATTLE_DAMAGE)
    local was_disabled = tc:IsDisabled()
    if not (
        (
            (tc:IsHasEffect(EFFECT_AVOID_BATTLE_DAMAGE) or tc:IsHasEffect(EFFECT_NO_BATTLE_DAMAGE))
            and not tc:IsDisabled()
        )
        or opponent_protected
        or (tc:GetOriginalCode()==989 and not tc:IsDisabled())
        or (tc:GetOriginalCode()==511002935 and not tc:IsDisabled())
    ) then
        local prevent_damage = Duel.IsExistingMatchingCard(function(c)
            return c:IsFaceup() and c:GetOriginalCode() == 513000092 and not c:IsDisabled()
        end, 1-tp, LOCATION_SZONE, 0, 1, nil)
        local eqg2 = tc:GetEquipGroup()
        for ec in aux.Next(eqg2) do
            if ec:GetOriginalCode() == 513000092 then
                prevent_damage = false
                break
            end
        end
        local candidates = Group.CreateGroup()
        local g1 = Duel.GetMatchingGroup(function(c)
            return c:IsFaceup()
                and (c:GetOriginalCode()==511018013 or c:GetOriginalCode()==511013006)
                and not c:IsDisabled()
        end, 1-tp, LOCATION_ONFIELD, 0, nil)
        if #g1 > 0 then
            candidates:Merge(g1)
        end
        local halve_damage_by_choice = false
        if #candidates > 0 then
            Duel.Hint(HINT_SELECTMSG,tp,aux.Stringid(412,1))
            local sg = candidates:Select(tp,1,1,nil)
            if #sg > 0 and Duel.SelectYesNo(tp, aux.Stringid(412,2)) then
                Duel.SendtoGrave(sg:GetFirst(),REASON_EFFECT)
                halve_damage_by_choice = true
            end
        end
        if (change_battle_damage or opponent_change_battle_damage) and damage > 0 then
            damage = math.floor(damage / 2)
        end
        if half_damage_effect and damage > 0 then
            damage = math.floor(damage / 2)
        end
        if halve_damage_by_choice and damage > 0 then
            damage = math.floor(damage / 2)
        end
        if damage > 0 and not skip_damage and not prevent_damage then
            if (tc == attacker and reflect_battle_damage and not was_disabled)
                or (tc:GetCode() == 50916353 and not tc:IsDisabled()) then
                Duel.Damage(tp, damage, REASON_BATTLE)
            else
                Duel.Damage(1-tp, damage, REASON_BATTLE)
            end
        end
        if half_damage_effect then
            local atk = tc:GetPreviousAttackOnField()
            if atk < 0 then atk = 0 end
            Duel.Damage(1-tp, atk, REASON_BATTLE)
        end
    end
    if not skip_destroy then
    if has_indestructable_effect and not has_indestructable_battle and not is_disabled then
        Duel.Destroy(tc, REASON_RULE+REASON_BATTLE)
    else
        local has_equip = tc:GetEquipCount() > 0
        if has_equip then
            Duel.Destroy(tc, REASON_BATTLE)
        else
            Duel.Destroy(tc, REASON_EFFECT)
        end
      end
    end
    if gain_atk and tc:IsLocation(LOCATION_MZONE) and tc:IsFaceup() then
        local e2=Effect.CreateEffect(e:GetHandler())
        e2:SetType(EFFECT_TYPE_SINGLE)
        e2:SetCode(EFFECT_UPDATE_ATTACK)
        e2:SetValue(300)
        e2:SetReset(RESET_EVENT+RESETS_STANDARD)
        tc:RegisterEffect(e2)
    end
    local function hasExternalIndestructibleBattle(mc)
        local effs={mc:GetCardEffect(EFFECT_INDESTRUCTABLE_BATTLE)}
        for _,eff in ipairs(effs) do
            if eff and eff:GetOwner()~=mc then
                return true
            end
        end
        return false
    end
    local cleanup_group=Group.CreateGroup()
    if tc and is_opponent_monster(tp,tc) and tc:IsFaceup() and tc:IsMonster()
        and tc:IsHasEffect(EFFECT_INDESTRUCTABLE_EFFECT)
        and tc:GetFlagEffect(id+300)==0
        and not hasExternalIndestructibleBattle(tc)
    then
        cleanup_group:AddCard(tc)
    end
    if #cleanup_group>0 then
        Duel.Destroy(cleanup_group, REASON_RULE+REASON_BATTLE)
    end
end
function s.damcon(e,tp,eg,ep,ev,re,r,rp)
    local c=e:GetHandler()
    if not (c:IsReason(REASON_DESTROY) and c:GetPreviousLocation()==LOCATION_MZONE) then return false end
    local rc = re and re:GetHandler()
    return rc and rc:GetOriginalCode()==412
end
function s.costfilter(c)
    return c:IsSetCard(0x19d) and c:IsMonster() and c:IsAbleToRemoveAsCost()
end
function s.ez_cost(e,tp,eg,ep,ev,re,r,rp,chk)
    if chk==0 then
        return Duel.IsExistingMatchingCard(s.costfilter,tp,LOCATION_GRAVE,0,1,nil)
    end
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
    local g=Duel.SelectMatchingCard(tp,s.costfilter,tp,LOCATION_GRAVE,0,1,1,nil)
    Duel.Remove(g,POS_FACEUP,REASON_COST)
end
function s.neosfilter(c,e,tp)
    return c:IsCode(CARD_NEOS) and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
function s.ez_tg(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
    if chkc then
        return chkc:IsLocation(LOCATION_GRAVE) and chkc:IsControler(tp) and s.neosfilter(chkc,e,tp)
    end
    if chk==0 then
        return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
            and Duel.IsExistingTarget(s.neosfilter,tp,LOCATION_GRAVE,0,1,nil,e,tp)
    end
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
    local g=Duel.SelectTarget(tp,s.neosfilter,tp,LOCATION_GRAVE,0,1,1,nil,e,tp)
    Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,g,#g,0,0)
end
function s.ez_op(e,tp,eg,ep,ev,re,r,rp)
    if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
    local tc=Duel.GetFirstTarget()
    if tc and tc:IsRelateToEffect(e) then
        Duel.SpecialSummon(tc,0,tp,tp,false,false,POS_FACEUP)
    end
end
function s.ez_filter2(c)
	return c:IsType(TYPE_SPELL+TYPE_TRAP)
end
function s.ez_tg2(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsOnField() and chkc:IsControler(tp) and s.ez_filter2(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.ez_filter2,tp,LOCATION_ONFIELD,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
	local g=Duel.SelectTarget(tp,s.ez_filter2,tp,LOCATION_ONFIELD,0,1,1,nil)
	Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,g:GetCount(),0,0)
end
function s.ez_op2(e,tp,eg,ep,ev,re,r,rp)
	local tc=Duel.GetFirstTarget()
	if tc:IsRelateToEffect(e) then
		Duel.Destroy(tc,REASON_EFFECT)
	end
end
