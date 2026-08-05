# Universal multiplayer effect expansion

The multiplayer core supports up to 26 independent logical players and exposes
these Lua helpers:

- `Duel.SelectEffectPlayers(tp, include_self, include_opponents)` returns a 32-bit logical-player mask and a Boolean indicating whether the player chose the expanded scope. In Teams mode, the self scope contains every active teammate and the opponent scope contains only active enemy teams.
- `Duel.GetActiveLogicalPlayerMask()` returns the active logical-player bitmask.
- `Duel.GetPlayerFieldGroupCount(logical_player, locations)` counts cards belonging to one logical player.
- `Duel.IsPlayerCanDrawPlayer(logical_player, count)` checks whether that logical player can draw.
- `Duel.DrawPlayer(logical_player, count, reason)` draws from that player's private Deck into that player's private hand.
- `Duel.DamagePlayer(logical_player, amount, reason, is_step, reason_player, allow_interception)` damages one logical player. Set the last argument to `false` for a batch that must hit every selected player without "Let me take it" redirecting each hit.
- `Duel.RecoverPlayer(logical_player, amount, reason, is_step, reason_player)` recovers one logical player's LP.

Scope combinations:

| Natural effect scope | `include_self` | `include_opponents` |
| --- | --- | --- |
| Activating player/team | `true` | `false` |
| Opponent(s) | `false` | `true` |
| Both sides/all players | `true` | `true` |

Outside a multiplayer Duel, when the natural and expanded scopes are identical,
or when the player chooses **No**, keep the original card operation. This
preserves normal EDOPro behavior exactly.

Logical player IDs range from `0` through `25`. Iterate over that complete range
and test the returned mask; do not hard-code the original four-player range.

The multiplayer build packages this directory so the examples can be copied into the matching card-script repository.
