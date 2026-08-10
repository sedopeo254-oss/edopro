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

## 3v1 card targeting without global rule changes

Anime 3v1 keeps the normal meaning of `tp` and `1-tp` for every existing card
script. A card that is explicitly allowed to interact with another teammate's
field should opt in with the logical-target helpers instead of changing the
engine-wide controller rules:

- `Duel.IsThreeVsOne()` checks the exact legacy 3v1 mode.
- `Duel.GetLogicalPlayerMask(tp, include_self, include_teammates, include_opponents)` returns the eligible logical seats relative to the activating card's owner.
- `Duel.IsExistingTargetLogical(filter, tp, mask, locations, count, exception, ...)` checks eligible cards across those seats.
- `Duel.SelectTargetLogical(tp, filter, mask, locations, min, max, exception, ...)` selects and registers the card target while preserving its exact logical owner and replay view.

`c25880422.lua` is the ready-to-use Block Attack example. Outside 3v1 it is
identical to the original script; inside 3v1 it can target an eligible monster
on either teammate's field or Nezbitt's field.
