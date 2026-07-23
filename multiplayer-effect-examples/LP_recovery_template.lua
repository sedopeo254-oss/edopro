--Template: expand an effect that normally recovers only the activating player.
--Replace `amount` with the card's actual recovery value.
local function recover_with_3v1_choice(tp,amount)
	local players,expanded=Duel.SelectEffectPlayers(tp,true,false)
	if not expanded then
		Duel.Recover(tp,amount,REASON_EFFECT)
		return
	end
	for player=0,3 do
		if players&(1<<player)~=0 then
			Duel.RecoverPlayer(player,amount,REASON_EFFECT,false,tp)
		end
	end
end
