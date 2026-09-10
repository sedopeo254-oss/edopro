--Graverobber (Anime)

local s,id=GetID()
function s.initial_effect(c)
    local e1=Effect.CreateEffect(c)
    e1:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOHAND)
    e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
    e1:SetType(EFFECT_TYPE_ACTIVATE)
    e1:SetCode(EVENT_FREE_CHAIN)
    e1:SetTarget(s.target)
    e1:SetOperation(s.operation)
    c:RegisterEffect(e1)
    local e2=Effect.CreateEffect(c)
    e2:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOHAND)
    e2:SetProperty(EFFECT_FLAG_CARD_TARGET)
    e2:SetType(EFFECT_TYPE_ACTIVATE)
    e2:SetCode(EVENT_BATTLE_DESTROYED)
    e2:SetTarget(s.target)
    e2:SetOperation(s.operation)
    c:RegisterEffect(e2)
    local e3=Effect.CreateEffect(c)
    e3:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOHAND)
    e3:SetProperty(EFFECT_FLAG_CARD_TARGET)
    e3:SetType(EFFECT_TYPE_ACTIVATE)
    e3:SetCode(EVENT_PRE_DAMAGE_CALCULATE)
    e3:SetTarget(s.target)
    e3:SetOperation(s.operation)
    c:RegisterEffect(e3) 
    local e4=Effect.CreateEffect(c)
    e4:SetCategory(CATEGORY_SPECIAL_SUMMON+CATEGORY_TOHAND)
    e4:SetProperty(EFFECT_FLAG_CARD_TARGET)
    e4:SetType(EFFECT_TYPE_ACTIVATE)
    e4:SetCode(EVENT_BATTLED)
    e4:SetTarget(s.target)
    e4:SetOperation(s.operation)
    c:RegisterEffect(e4)
    local e5=Effect.CreateEffect(c)
    e5:SetType(EFFECT_TYPE_SINGLE)
    e5:SetProperty(EFFECT_FLAG_IGNORE_IMMUNE+EFFECT_FLAG_SET_AVAILABLE+EFFECT_FLAG_CANNOT_DISABLE)
    e5:SetCode(511001408)
    c:RegisterEffect(e5)
end
function s.cfilter(c,e,tp,eg,ep,ev,re,r,rp,chain)
    if not c:IsMonster() and c:GetActivateEffect() and (c:IsHasEffect(511001283) or c:IsHasEffect(511001408)) then return false end
    return s.filter(c,e,tp,eg,ep,ev,re,r,rp,chain)
end
function s.filter(c,e,tp,eg,ep,ev,re,r,rp,chain)
    if c:IsMonster() then
        if c:IsCanBeSpecialSummoned(e,0,tp,false,false) then
            return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
        else
            return c:IsAbleToHand()
        end
    else
        if not c:IsType(TYPE_FIELD) and Duel.GetLocationCount(tp,LOCATION_SZONE)<=0 then return false end
        local te=c:GetActivateEffect()
        if c:IsHasEffect(EFFECT_CANNOT_TRIGGER) then return false end
        local pre={Duel.GetPlayerEffect(tp,EFFECT_CANNOT_ACTIVATE)}
        if pre[1] then
            for i,eff in ipairs(pre) do
                local prev=eff:GetValue()
                if type(prev)~='function' or prev(eff,te,tp) then return false end
            end
        end
        if te then
            local condition=te:GetCondition()
            local cost=te:GetCost()
            local target=te:GetTarget()
            if te:GetCode()==EVENT_CHAINING then
                if chain<=0 then return false end
                local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
                local tc=te2:GetHandler()
                local g=Group.FromCards(tc)
                local p=tc:GetControler()
                return (not condition or condition(te,tp,g,p,chain,te2,REASON_EFFECT,p)) and (not cost or cost(te,tp,g,p,chain,te2,REASON_EFFECT,p,0)) 
                    and (not target or target(te,tp,g,p,chain,te2,REASON_EFFECT,p,0))
            elseif te:GetCode()==EVENT_FREE_CHAIN then
                return (not condition or condition(te,tp,eg,ep,ev,re,r,rp)) and (not cost or cost(te,tp,eg,ep,ev,re,r,rp,0))
                    and (not target or target(te,tp,eg,ep,ev,re,r,rp,0))
            else
                local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
                return res and (not condition or condition(te,tp,teg,tep,tev,tre,tr,trp)) and (not cost or cost(te,tp,teg,tep,tev,tre,tr,trp,0))
                    and (not target or target(te,tp,teg,tep,tev,tre,tr,trp,0))
            end
        else
            return c:IsSSetable()
        end
    end
end
s.lock_ids={[190]=true,[323]=true,[366]=true,[1029]=true}
local MP_PLAYER_BASE=-68719476736 -- signed form of 0xfffffff000000000
local MP_MAX_PLAYERS=26
function s.ismulti()
    return Duel.GetActiveLogicalPlayerMask and Duel.GetActiveLogicalPlayerMask()~=0
end
function s.selectplayer(tp,mask)
    local players,options={},{}
    for p=0,MP_MAX_PLAYERS-1 do
        if (mask&(1<<p))~=0 and Duel.IsLogicalPlayerActive(p) then
            players[#players+1]=p
            options[#options+1]=MP_PLAYER_BASE+p
        end
    end
    if #players==0 then return nil end
    if #players==1 then return players[1] end
    local op=Duel.SelectOption(tp,table.unpack(options))
    return players[op+1]
end
function s.playerhascard(logical,e,tp,eg,ep,ev,re,r,rp,chain)
    local g=Duel.GetPlayerFieldGroup(logical,LOCATION_GRAVE)
    return g and g:IsExists(s.cfilter,1,nil,e,tp,eg,ep,ev,re,r,rp,chain)
end
function s.candidatemask(e,tp,eg,ep,ev,re,r,rp,chain)
    local opponents=Duel.GetLogicalPlayerMask(tp,false,false,true)
    local mask=0
    for p=0,MP_MAX_PLAYERS-1 do
        if (opponents&(1<<p))~=0 and Duel.IsLogicalPlayerActive(p)
            and s.playerhascard(p,e,tp,eg,ep,ev,re,r,rp,chain) then
            mask=mask|(1<<p)
        end
    end
    return mask
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
    local chain=Duel.GetCurrentChain()
    if not s.ismulti() then
        if chkc then return chkc:IsLocation(LOCATION_GRAVE) and chkc:IsControler(1-tp)
            and s.filter(chkc,e,tp,eg,ep,ev,re,r,rp,chain) end
        if chk==0 then return Duel.IsExistingTarget(s.cfilter,tp,0,LOCATION_GRAVE,1,nil,e,tp,eg,ep,ev,re,r,rp,chain) end
        chain=chain-1
        Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
        local g=Duel.SelectTarget(tp,s.filter,tp,0,LOCATION_GRAVE,1,1,nil,e,tp,eg,ep,ev,re,r,rp,chain)
        local tc=g:GetFirst()
        if tc and Duel.GetLP(tp)==0 and s.lock_ids[tc:GetOriginalCode()] then
            Duel.SetChainLimit(s.chainlimit)
        end
        return
    end
    local pmask=s.candidatemask(e,tp,eg,ep,ev,re,r,rp,chain)
    if chkc then
        local logical=chkc:GetLogicalControler()
        return chkc:IsLocation(LOCATION_GRAVE) and logical~=nil
            and (pmask&(1<<logical))~=0
            and s.filter(chkc,e,tp,eg,ep,ev,re,r,rp,chain)
    end
    if chk==0 then return pmask~=0 end
    local owner=Duel.GetLogicalPlayer(tp)
    local logical=s.selectplayer(tp,pmask)
    if logical==nil then return end
    e:SetLabel(logical)
    Duel.FocusLogicalPlayer(logical)
    chain=math.max(0,chain-1)
    local g=Duel.GetPlayerFieldGroup(logical,LOCATION_GRAVE)
    g=g:Filter(s.filter,nil,e,tp,eg,ep,ev,re,r,rp,chain)
    Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
    local sg=g:Select(tp,1,1,nil)
    Duel.SetTargetCard(sg)
    if owner~=nil then Duel.FocusLogicalPlayer(owner) end
    local tc=sg:GetFirst()
    if tc and Duel.GetLP(tp)==0 and s.lock_ids[tc:GetOriginalCode()] then
        Duel.SetChainLimit(s.chainlimit)
    end
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	local chain=Duel.GetCurrentChain()-1
	if s.ismulti() then
		local owner=Duel.GetLogicalPlayer(tp)
		if owner~=nil then Duel.FocusLogicalPlayer(owner) end
	end
	local tc=Duel.GetFirstTarget()
	if not tc or not tc:IsRelateToEffect(e) then return end
	local tpe=tc:GetType()
	if tc:IsMonster() then
		if tc:IsCanBeSpecialSummoned(e,0,tp,false,false) and Duel.GetLocationCount(tp,LOCATION_MZONE)>0 then
			Duel.SpecialSummon(tc,0,tp,tp,false,false,POS_FACEUP)
		else
			Duel.SendtoHand(tc,tp,REASON_EFFECT)
			if s.ismulti() then
			Duel.ConfirmCards(0,tc)
			Duel.ConfirmCards(1,tc)
		else
			Duel.ConfirmCards(1-tp,tc)
		end
		end
	else
		if not tc:IsType(TYPE_FIELD) and Duel.GetLocationCount(tp,LOCATION_SZONE)<=0 then return end
		local tpe=tc:GetType()
		local te=tc:GetActivateEffect()
		if not s.cfilter(tc,e,tp,eg,ep,ev,re,r,rp,chain) then return end
		if te then
			local tg=te:GetTarget()
			local co=te:GetCost()
			local op=te:GetOperation()
			e:SetCategory(te:GetCategory())
			e:SetProperty(te:GetProperty())
			Duel.ClearTargetCard()
			local loc=LOCATION_SZONE
			if (tpe&TYPE_FIELD)~=0 then
				loc=LOCATION_FZONE
				local fc=s.ismulti() and Duel.GetFieldCard(tp,LOCATION_FZONE,0) or Duel.GetFieldCard(1-tp,LOCATION_FZONE,0)
				if Duel.IsDuelType(DUEL_1_FIELD) and not s.ismulti() then
					if fc then Duel.Destroy(fc,REASON_RULE) end
					fc=Duel.GetFieldCard(tp,LOCATION_FZONE,0)
					if fc and Duel.Destroy(fc,REASON_RULE)==0 then Duel.SendtoGrave(tc,REASON_RULE) end
				else
					fc=Duel.GetFieldCard(tp,LOCATION_FZONE,0)
					if fc and Duel.SendtoGrave(fc,REASON_RULE)==0 then Duel.SendtoGrave(tc,REASON_RULE) end
				end
			end
			Duel.MoveToField(tc,tp,tp,loc,POS_FACEUP,true)
			if tc:IsType(TYPE_FIELD) and tc:GetSequence()~=5 then
				Duel.MoveSequence(tc,5)
			end
			Duel.Hint(HINT_CARD,0,tc:GetOriginalCode())
			tc:CreateEffectRelation(te)
			if (tpe&(TYPE_EQUIP+TYPE_CONTINUOUS+TYPE_FIELD))==0 and not tc:IsHasEffect(EFFECT_REMAIN_FIELD)
            and not (te and te:IsHasCategory(CATEGORY_EQUIP)) and tc:GetOriginalCode()~=37390589 then
            tc:CancelToGrave(false)
            end
			if te:GetCode()==EVENT_CHAINING then
				local chain=Duel.GetCurrentChain()-1
				local te2=Duel.GetChainInfo(chain,CHAININFO_TRIGGERING_EFFECT)
				local tc=te2:GetHandler()
				local g=Group.FromCards(tc)
				local p=tc:GetControler()
				if co then co(te,tp,g,p,chain,te2,REASON_EFFECT,p,1) end
				if tg then tg(te,tp,g,p,chain,te2,REASON_EFFECT,p,1) end
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
					local tc=te2:GetHandler()
					local g=Group.FromCards(tc)
					local p=tc:GetControler()
					if op then op(te,tp,g,p,chain,te2,REASON_EFFECT,p) end
				elseif te:GetCode()==EVENT_FREE_CHAIN then
					if op then op(te,tp,eg,ep,ev,re,r,rp) end
				else
					local res,teg,tep,tev,tre,tr,trp=Duel.CheckEvent(te:GetCode(),true)
					if op then op(te,tp,teg,tep,tev,tre,tr,trp) end
				end
			else
			end
			Duel.RaiseEvent(Group.CreateGroup(tc),EVENT_CHAIN_SOLVED,te,0,tp,tp,Duel.GetCurrentChain())
			if g and tc:IsType(TYPE_EQUIP) and not tc:GetEquipTarget() then
				Duel.Equip(tp,tc,g:GetFirst())
			end
			tc:ReleaseEffectRelation(te)
			if etc then
				etc=g:GetFirst()
				while etc do
					etc:ReleaseEffectRelation(te)
					etc=g:GetNext()
				end
			end
		else
			Duel.SSet(tp,tc)
		end
	end
end
function s.chainlimit(e,rp,tp)
    return false
end
