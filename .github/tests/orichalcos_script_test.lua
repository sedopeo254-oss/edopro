-- Validate the user's complete Orichalcos effect list and restoration hook.
local path=assert(arg[1])
local code=assert(io.open(path,"rb")):read("*a")
for _,fragment in ipairs({
 "EFFECT_FLAG_CANNOT_INACTIVATE","EFFECT_FLAG_CANNOT_NEGATE",
 "EFFECT_INDESTRUCTABLE_EFFECT","EFFECT_CANNOT_TO_GRAVE",
 "EFFECT_CANNOT_TO_HAND","EFFECT_CANNOT_TO_DECK","EFFECT_CANNOT_REMOVE",
 "EFFECT_CANNOT_SSET","EFFECT_CANNOT_ACTIVATE","EFFECT_ORICA",
 "EFFECT_ORICA_SZONE","EFFECT_CANNOT_BE_BATTLE_TARGET",
 "e3:SetValue(500)","s.freezonemask","Duel.MoveToField",
 "e1:SetOperation(s.restore_original_forms)",
 "s.legendary_dragon_codes"
}) do
 assert(code:find(fragment,1,true),"Missing Orichalcos source feature: "..fragment)
end
local source=assert(loadfile(path))()
print("Orichalcos source and Legendary Dragon hook: PASS (engine zone support separately required)")
