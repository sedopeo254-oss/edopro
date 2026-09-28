--黒炎の騎士－ブラック・フレア・ナイト－
--Dark Flare Knight
local s,id=GetID()
local MIRAGE_KNIGHT_ANIME=120000336
local MIRAGE_KNIGHT_ORIGINAL=49217579
function s.initial_effect(c)
	c:EnableReviveLimit()
	--Fusion Materials
	Fusion.AddProcMix(c,true,true,CARD_DARK_MAGICIAN,CARD_FLAME_SWORDSMAN)
	--You take no Battle Damage from battles involving this card
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_AVOID_BATTLE_DAMAGE)
	e1:SetValue(1)
	c:RegisterEffect(e1)
	--Battle City / Virtual World: this Fusion Monster can attack the turn it is Special Summoned
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE)
	e2:SetCode(511004016)
	e2:SetProperty(EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE+EFFECT_FLAG_IGNORE_IMMUNE)
	c:RegisterEffect(e2)
	--Special Summon 1 "Mirage Knight" from your hand or Deck
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e3:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_F)
	e3:SetCode(EVENT_BATTLE_DESTROYED)
	e3:SetCondition(function(e) return e:GetHandler():IsLocation(LOCATION_GRAVE) end)
	e3:SetTarget(s.sptg)
	e3:SetOperation(s.spop)
	c:RegisterEffect(e3)
end
s.material_setcode=SET_DARK_MAGICIAN
s.listed_names={CARD_DARK_MAGICIAN,CARD_FLAME_SWORDSMAN,MIRAGE_KNIGHT_ANIME,MIRAGE_KNIGHT_ORIGINAL}
function s.spfilter(c,e,tp)
	return c:IsCode(MIRAGE_KNIGHT_ANIME,MIRAGE_KNIGHT_ORIGINAL)
		and c:IsCanBeSpecialSummoned(e,0,tp,true,false)
end
function s.sptg(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then
		return Duel.GetLocationCount(tp,LOCATION_MZONE)>0
			and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_HAND|LOCATION_DECK,0,1,nil,e,tp)
	end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND|LOCATION_DECK)
end
function s.spop(e,tp,eg,ep,ev,re,r,rp)
	if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local sc=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_HAND|LOCATION_DECK,0,1,1,nil,e,tp):GetFirst()
	if sc and Duel.SpecialSummon(sc,0,tp,tp,true,false,POS_FACEUP)>0 then
		sc:CompleteProcedure()
	end
end
