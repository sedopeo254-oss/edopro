# Multiplayer anime card overrides

These scripts are packaged into `expansions/script/` by the clean 2v1 Windows workflow.

- `c13722870.lua` — Dark Flare Knight
  - retains its Fusion materials and battle-damage protection;
  - carries the `511004016` exemption used by Battle City and Virtual World, so it can attack on the turn it is Special Summoned from the Extra Deck;
  - can summon either the anime custom Mirage Knight (`120000336`) or the original Mirage Knight (`49217579`).

- `c120000336.lua` — Mirage Knight (anime custom)
  - its End of Battle Phase transformation is optional;
  - if it battled, it can banish itself and revive Dark Magician and Flame Swordsman from the allied team's Graveyards;
  - each revived monster returns to its own logical owner's field in multiplayer.

- `c99900043.lua` — A Deal with Dark Ruler (anime custom)
  - costs half of the activating logical player's LP;
  - works when that player's Level 8+ monster is destroyed;
  - for battle destruction, it activates before battle damage is applied, changes that battle damage to 0, then waits for the monster to actually be battle-destroyed before summoning Berserk Dragon;
  - effect destruction summons Berserk Dragon after the destruction event.

Dark Flare Knight and both supported Mirage Knight codes are also selectable as Deck Masters. When one is selected by the allied side in multiplayer, Deck Master loss is disabled for the entire allied team for that duel.
