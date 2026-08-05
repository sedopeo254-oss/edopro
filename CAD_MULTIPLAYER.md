# CaD — Custom Anime Duels

CaD supports between 2 and 26 logical players, with 1-13
seats on each transport side. The two transport sides are only used to carry
network traffic; every logical player owns an independent field, LP total,
Deck, hand, Extra Deck, Graveyard, and banished pile.

## Formats

- **Single Duel**: every player is independent. The final surviving player wins.
- **Teams**: choose two or more teams. Lobby seats are assigned round-robin
  (`P1 -> Team 1`, `P2 -> Team 2`, and so on) and the final active team wins.
- **Battle Royal**: every player is every other player's opponent. Players can
  cooperate, but no player can attack during their first personal turn. The
  ARC-V option also prevents the first personal draw.

Turns alternate between the two transport-side seat lists. Eliminated players
are skipped without merging their field or private piles into another player.
Room time limits are tracked per logical player, not per transport side. A
timeout or surrender eliminates only that player whenever the pending command
can be completed safely. If a disconnected/timed-out player owns a mandatory
private selection that cannot be transferred, the match ends as a no-contest
instead of eliminating every seat carried by the same transport side.

## Multiplayer-aware card scripts

Normal EDOPro scripts still use physical player IDs `0` and `1`. Effects that
must deliberately address all, one, or a subset of the logical players should
use the helpers documented in `multiplayer-effect-examples/README.md`.

The live intrusion state and the 2000 LP intrusion penalty are implemented in
the core rules model. Joining an already-running network Duel still requires a
future server/client join protocol; the current lobby starts all configured
seats together.
