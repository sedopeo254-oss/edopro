-- Test the user's Yamata Dragon edit without changing its other abilities.
-- Usage: lua5.4 .github/tests/yamata_dragon_no_draw_test.lua multiplayer-anime-cards/c76862289.lua
local path=assert(arg[1],"Expected card script path")
local f=assert(io.open(path,"rb"))
local code=f:read("*a")
f:close()
assert(not code:find("EVENT_BATTLE_DAMAGE",1,true))
assert(not code:find("CATEGORY_DRAW",1,true))
assert(not code:find("Duel.Draw(",1,true))
assert(not code:find("s.drtg",1,true))
assert(not code:find("s.drop",1,true))
EVENT_SUMMON_SUCCESS=20
EVENT_FLIP=21
EFFECT_TYPE_SINGLE=1
EFFECT_FLAG_CANNOT_DISABLE=2
EFFECT_FLAG_UNCOPYABLE=4
EFFECT_SPSUMMON_CONDITION=45
local saved_s
function GetID()
	saved_s={}
	return saved_s,76862289
end
local proc_count=0
Spirit={AddProcedure=function(c,normal,flip)
	assert(normal==EVENT_SUMMON_SUCCESS and flip==EVENT_FLIP)
	proc_count=proc_count+1
end}
Effect={CreateEffect=function(c)
	local e={owner=c}
	function e:SetType(v) self.type=v end
	function e:SetProperty(v) self.property=v end
	function e:SetCode(v) self.code=v end
	return e
end}
assert(loadfile(path))()
assert(saved_s and type(saved_s.initial_effect)=="function")
local card={effects={}}
function card:RegisterEffect(e) self.effects[#self.effects+1]=e end
saved_s.initial_effect(card)
assert(proc_count==1,"Spirit procedure must remain")
assert(#card.effects==1,"No battle-damage draw trigger may remain")
local e=card.effects[1]
assert(e.owner==card)
assert(e.type==EFFECT_TYPE_SINGLE)
assert(e.property==EFFECT_FLAG_CANNOT_DISABLE+EFFECT_FLAG_UNCOPYABLE)
assert(e.code==EFFECT_SPSUMMON_CONDITION,"special summon restriction must remain")
print("Yamata Dragon no-draw anime override: PASS")
