# Virtual World Deck Masters in 3v1

Replace the matching card scripts with:

- `c153999999.lua` — Virtual World rule.
- `c153000000.lua` — Deck Master system.

The multiplayer core adds these Lua helpers:

- `Duel.GetLogicalPlayer(tp)`
- `Duel.GetLogicalPlayerSide(logical_player)`
- `Duel.GetActiveLogicalPlayerMask()`
- `Duel.IsLogicalPlayerActive(logical_player)`
- `Duel.SelectCardsFromCodesPlayer(logical_player, ...)`
- `Duel.CreateTokenPlayer(logical_player, code)`
- `Duel.SetDeckMasterPlayerState(logical_player, code, visible)`
- `Duel.GetPlayerFieldGroup(logical_player, locations)`
- `Duel.EliminatePlayer(logical_player, reason, win_reason)`
- `Card.GetLogicalOwner()`
- `Card.GetLogicalControler()`

In 3v1 each of Serenity, Tristan, Duke, and Nezbitt chooses and owns an
independent Deck Master. Effects registered through
`DeckMaster.RegisterAbilities` retain the Deck Master token as their handler, so
chain prompts and selections are routed to the correct logical owner even when
it is another teammate's turn.

Outside multiplayer, the scripts keep the original two-player agreement and
Deck Master behavior.
