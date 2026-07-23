# 3v1 effect expansion

The 3v1 core exposes these Lua helpers:

- `Duel.SelectEffectPlayers(tp, include_self, include_opponents)` returns a logical-player bitmask and a Boolean indicating whether the player chose the expanded scope.
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

Outside 3v1, or when the player chooses **No**, keep the original card operation. This preserves normal EDOPro behavior exactly.

