# Inherited Duel Mode — playable handoff implementation (experimental)

**Branch:** `feature/inherited-duel-live-handoff-20261105`

**Isolation:** This feature is enabled only by `DUEL_INHERITED_DUEL`.
Existing `Standard`, `2 vs 1`, `3 vs 1`, `Battle Royale` and
`Custom Anime Duels` remain separate. Their scripts and branches were
not edited. Build the client with the matching `ocgcore` submodule.

## Lobby / role assignment

Choose **Inherited Duel Mode** in the room settings. Three people join:

| Seat | Role | Field |
| --- | --- | --- |
| Home seat 0 | Kaiba — initial duelist | Side 0 |
| Home seat 1 | Yugi — successor, not active yet | Inactive Deck and Extra Deck |
| Opposing seat 2 | Noah — original opponent | Side 1 |

All three prepare their own decks. **Only two physical boards are created.**
Yugi's deck is instantiated in the core as inactive real card objects, not
copied into Kaiba's active hand or deck at the beginning.

## Live one-time takeover

The anime Last Turn card's script calls `Duel.Win(1, WIN_REASON_LAST_TURN)`
when Noah defeats Kaiba. In **Inherited Duel only**, and only when the
original side-0 controller is active:

1. The engine intercepts that specific Last Turn result and records the
   provisional loss. All other win reasons work normally.
2. The current turn finishes; EDOPro's terminal `MSG_WIN` is suppressed
   for the preliminary loss only.
3. Before the next Draw Phase, core validates and adopts Yugi's already
   loaded Deck and Extra Deck **card instances** into Kaiba's live piles.
   Existing physical card objects are never duplicated.
4. Kaiba's current hand, remaining Deck, Monster/Spell zones, Graveyard,
   banished pile, LP and Deck Master remain in the game and are NOT reset.
   Noah's resources are untouched.
5. The engine emits `MSG_DUEL_SUCCESSION` (10-byte event), preserving
   the preliminary-loss turn and successor-start turn for YRPX replay.
6. The server changes side 0's **authorized responder** from Kaiba to Yugi.
   The outgoing controller may no longer submit duel responses or surrender
   for Yugi. Their departure does not end the inherited duel.
7. The client updates the displayed duelist name and presents the
   succession notice. The existing field, LP and counters stay visible.

If adoption fails validation, the engine sends the original
`WIN_REASON_LAST_TURN` victory to Noah. It does not import a partial deck.

## Known constraints

- Requires a Last Turn script that actually calls `Duel.Win(1, 0x16)`.
  A custom anime script with another ending needs its own explicit mapping.
- The takeover is for **one successive handoff** (not repeated tag swaps).
- Side 0 is initially Kaiba, Yugi is home seat 1 and Noah is opposing.
  The room's two physical boards should not be confused with the three
  connected people.
- Visual portrait/character-voice switching is not included yet.
- The mode does not fake the anime's exact LP totals (400 / 7400). Those
  totals must result from the actual duel and card play.
- Core state and previous multiplayer regression tests are automated.
  Full Windows compilation and 42-turn anime replay acceptance remain
  separate requirements. Do not claim 100% anime accuracy until tested.

## Scripts and preservation

Copy your existing anime card scripts, deck databases, image archives,
sounds and mods into a **new test installation** rather than replacing an
existing EDOPro directory. Continue using the matching modified core.
No existing Big 5 scripts were overwritten by this change.

## Source & validation

- Client: `gframe/game.cpp`, `gframe/netserver.cpp`,
  `gframe/generic_duel.cpp`, `gframe/duelclient.cpp`
- Engine: `ocgcore/field.cpp`, `ocgcore/processor.cpp`,
  `ocgcore/libduel.cpp`, `ocgcore/duel_succession.h`
- Automated tests:
  `.github/tests/test_inherited_live_handoff.py`;
  `ocgcore/tests/run_duel_succession_tests.sh`,
  `ocgcore/tests/run_duel_succession_transfer_tests.sh`,
  `ocgcore/tests/run_multiplayer_state_tests.sh`,
  `ocgcore/tests/run_multiplayer_field_tests.sh`.
