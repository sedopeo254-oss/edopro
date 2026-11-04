# Independent Deck Master system for Multiplayer

This folder contains the Virtual World rule and Deck Master support used by the
stable 3v1 client.

## Runtime scripts

Copy all `c*.lua` files from this directory into `expansions/script/`.
The bundled CI packages them automatically.

## Updated Deck Masters

- `c153000009.lua` — **Robotic Knight**: every discarded Machine assigns exactly
  500 damage to one opponent. Three discarded Machines against three opponents
  deal 500 to each opponent, not 1500 to every opponent.
- `c153000022.lua` — **Judge Man**: in 2v1, Big Five pays the original
  1000 LP to banish all removable monsters on the two allied fields.
  Each active teammate takes 500 damage for each of their own monsters
  actually banished (two for P1 = 1000 damage, three for P2 = 1500).
  Damage is sent to each logical player directly, without damage interception.
  The original effect for Standard, 3v1, and Battle Royale and the existing
  Big Five Deck Master-merger selection are unchanged.
- `c153000012.lua` — **Super Roboyarou**: when an opponent declares an attack,
  it can be Special Summoned from the Deck Master zone in Attack Position and
  redirect that attack to itself. Afterward, its controller Sets one Spell/Trap
  from their hand if possible.

The multiplayer-aware **Block Attack** script remains in
`multiplayer-effect-examples/c25880422.lua`; in anime 3v1 its expanded target
selection can include eligible monsters controlled by allied duelists as well
as the opponent.

Setting a Spell/Trap through Super Roboyarou does not override that card's
normal activation timing or activation conditions.

## Deck Master phase-boundary and succession rules (2v1 and 3v1)

- The first eligible monster Summoned after losing a Deck Master inherits its
  status; when several are Summoned simultaneously, the logical owner chooses.
- A monster Special Summoned using Deck Master material also inherits the status.
- Dragon Revival Ritual transfers Big Five's Deck Master status to the real
  Five-Headed Dragon, rather than permanently protecting the player. If that
  dragon leaves and Berserk Dragon is Summoned next, Berserk becomes the
  replacement; if Berserk is destroyed, Big Five loses at the next phase
  boundary unless another replacement exists.
- All active logical players are checked independently at the boundary between
  phases, including the final End Phase; simultaneous loss on both sides draws.
- A Deck Master can be Special Summoned from its zone in its owner's personal
  Main Phase only. The anime-specific shared Dark Flare Knight/Mirage Knight
  team protection and all five Big Five switch abilities remain unchanged.

