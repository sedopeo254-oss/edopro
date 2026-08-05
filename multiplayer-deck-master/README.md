# Virtual World Deck Masters in Multiplayer

Replace the matching card scripts with:

- `c153999999.lua` — Virtual World rule.
- `c153000000.lua` — Deck Master system.

The multiplayer core adds these Lua helpers:

- `Duel.GetLogicalPlayer(tp)`
- `Duel.GetLogicalPlayerSide(logical_player)`
- `Duel.GetActiveLogicalPlayerMask()`
- `Duel.IsLogicalPlayerActive(logical_player)`
- `Duel.SelectCardsFromCodesPlayer(logical_player, ...)`
- `Duel.SelectYesNoPlayer(logical_player, description)`
- `Duel.CreateTokenPlayer(logical_player, code)`
- `Duel.SetDeckMasterPlayerState(logical_player, code, visible)`
- `Duel.GetPlayerFieldGroup(logical_player, locations)`
- `Duel.EliminatePlayer(logical_player, reason, win_reason)`
- `Card.GetLogicalOwner()`
- `Card.GetLogicalControler()`

In 3v1 and Universal Multiplayer, every active logical player chooses and owns
an independent Deck Master. Effects registered through
`DeckMaster.RegisterAbilities` retain the Deck Master token as their handler, so
chain prompts and selections are routed to the correct logical owner even when
it is another player's turn. Losing a Deck Master eliminates only its owner;
the selected Solo, Teams, or Battle Royal win condition then decides whether
the Duel continues.

Outside multiplayer, the scripts keep the original two-player agreement and
Deck Master behavior.
