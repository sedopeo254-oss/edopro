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
