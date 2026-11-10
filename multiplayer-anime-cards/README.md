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

- `c120000016.lua` — Dragon Revival Ritual (fully rebuilt, standalone)
  - exact ritual materials: 153000020 Jinzo, 153000021 Deepsea Warrior,
    153000022 Nightmare Penguin, 153000023 Judge Man and
    153000024 Robotic Knight (no legacy-ID substitutes);
  - each material's source priority is the real card in the caster's Deck
    Master Zone, then an eligible identical card already on their own field,
    otherwise a new token created from outside the Duel;
  - summons only missing monsters, requires only that many free Monster
    Zones, then Tributes exactly five materials and Ritual Summons the
    original Five-Headed Dragon (511013020) from the caster's own
    Hand or Deck, without any five-attribute or five-turn accumulation;
  - the script no longer delegates token creation or the Ritual sequence
    to the legacy DeckMaster.CallDragonRevivalMasters helper;
  - the existing Deck Master System handles only temporary inheritance
    suppression and registers the real Five-Headed Dragon on the field
    at completion; it never creates an FHD token or Deck Master Zone copy;
  - Five-Headed Dragon's original anime card script is unchanged.


- `c5494820.lua` — Cyclon Laser (supplied original)
  - equips to Gradius, grants +300 ATK and piercing damage; unchanged.

- `c511000219.lua` — Matter Leveller (Gradius anime effect fix)
  - on attacks against Defense Position monsters, sets Gradius' **final** ATK
    to exactly the target's DEF + 100 for Damage Calculation only;
  - uses `EFFECT_SET_ATTACK_FINAL`, so Cyclon Laser's +300 is not added twice;
  - example from the supplied YRPX: Different Dimension Dragon DEF 1500
    yields Gradius ATK **1600**, not 1900;
  - Gradius still has 1500 ATK from Cyclon Laser outside this calculation.

- `c14291024.lua` — Gradius' Option (anime)
  - may only summon from its hand with face-up Gradius on its owner's field;
  - sets its attack and defense from the selected Gradius' printed card stats
    (`GetTextAttack` / `GetTextDefense`), rather than current boosted stats;
  - dynamically mirrors applicable continuous Equip effects on that Gradius;
    in particular, Cyclon Laser grants +300 ATK and piercing while Matter
    Leveller sets Option's final ATK to the defending monster's DEF + 100 only
    when Option attacks during Damage Calculation;
  - stops granting an Equip effect when the source Equip leaves or is disabled;
  - destroys itself if the specifically selected Gradius leaves the field;
  - does not independently activate arbitrary one-shot Equip effects.
  - updated card text is in `Gradius_Option_Card_Text.txt` for manual CDB editing.
