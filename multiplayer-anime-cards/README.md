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

- `c8050010.lua` — Card Destruction (Anime / Tag)
  - in 2v1, discards every active logical duelist's entire hand into their own Graveyard, then draws exactly the number actually discarded from their own Deck;
  - P1, P2 and solo P3 are processed independently, with no `TagSwap` or private-pile mixing;
  - checks each active player's ability to draw before activation, skips empty and eliminated hands, and excludes the activating card if still in hand;
  - uses the original script's non-multiplayer Tag/Standard path without modifying other anime card effects.

- `c55773067.lua` — Drop Off (custom zero-stat ability)
  - replaces its previous draw/discard effect entirely;
  - when activated, every monster across all active logical fields gains
    exactly +0 ATK and +0 DEF until the End Phase, without changing stats;
  - uses independent P1/P2/P3/P4 monster groups in 2v1/3v1/Battle Royale
    and both physical monster fields in Standard duels;
  - unaffected monsters do not receive the temporary effects.

- `c120000016.lua` — Dragon Revival Ritual (restored Oct 30 version)
  - the card script is preserved exactly from commit
    `2fceee298ccde23d89cb26555ac9f92fff9df12d`;
  - it activates using the original EDOPro matching-card mechanism,
    summons the Big Five Deck Masters through the restored backup Deck Master
    System, Tributes all five, and summons anime Five-Headed Dragon
    (`511013020`) from the Hand/Deck;
  - the latest backed-up Deck Master System, including its modern 2v1 and
    3v1 improvements, remains in place without script-level alterations;
  - `c511013020.lua` is also preserved byte-for-byte with its original
    anime destruction, battle-protection and attack-restriction abilities.

## Backup restoration
All project files are restored from `backup/pre-35a46160-rollback-20261104`
except `c120000016.lua` (the user-selected Oct 30 working Ritual), the
documentation and compatibility tests. `c511013020.lua` was already identical
to the selected older version. This keeps the Magical Hats Warrior fix,
Card Destruction, Drop Off +0, Judge Man, Deck Master and 2v1/3v1 protections.
