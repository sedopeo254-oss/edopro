-- Custom Fusion body. CDB type must be 97 (FUSION + EFFECT + MONSTER).
local s,id=GetID()
function s.initial_effect(c)
    -- Once properly Fusion Summoned, this same monster can be revived.
    c:EnableReviveLimit()
end
