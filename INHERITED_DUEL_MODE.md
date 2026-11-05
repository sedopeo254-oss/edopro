# Inherited Duel Mode - Duel Succession System

> Status: **Stage 1 foundation / NOT a playable Noah-vs-Kaiba-to-Yugi handoff yet.**
> Changes are isolated on feature/inherited-duel-succession-v1-20261105.
> No existing duel mode, card script or replay has been overwritten.

## Goal

One physical duel between two field sides. When an eligible *preliminary* result
occurs, a successor takes control of one existing side without reconstructing
the duel. In the anime scenario, Kaiba fights Noah; after Last Turn resolves,
Yami Yugi inherits Kaiba's position and Noah continues opposite him.

The generic mode is **Inherited Duel Mode**; the underlying mechanism is
**Duel Succession System**. The first scenario profile is
**Noah vs Kaiba -> Noah vs Yugi**.

## Stage 1 (implemented)

- Dedicated flag DUEL_INHERITED_DUEL (0x8000000000ULL, core).
- New entry in room creation, forced to 1v1 with Relay disabled.
- Reject contradictory special-mode flags, preserving Battle Royale / 3v1.
- In-core DuelSuccessionState, disabled by default and active only under
  DUEL_INHERITED_DUEL without multiplayer flags.
- A three-stage safe one-time transaction: PRIMARY -> AWAITING_SUCCESSOR ->
  SUCCESSOR. A pending transition cannot commit without both network control
  transfer and deck migration being confirmed.
- Future event ID MSG_DUEL_SUCCESSION (197) reserved. Client/replay code can
  consume the 10-byte payload but the core does NOT emit it until handoff is
  fully atomic.
- Unit tests cover disabled mode, side authorization, turn-18 / turn-19
  handoff, repeated requests, incomplete transfer, rollback and reset.
- Existing 2v1 / 3v1 / Battle Royale scripts and card effects are untouched.

## Succession event protocol (future, core emits ONLY after transaction)

MSG_DUEL_SUCCESSION payload is exactly 10 bytes, little endian:
- uint8 inherited_side: physical side 0 or 1
- uint8 controller_generation: 1 at first successful handoff
- uint32 defeat_turn: last fully resolved turn of the outgoing player
- uint32 resume_turn: next surviving turn of the successor

An event cannot itself grant a new controller access to private information.
The server must change connection authorization and refresh the affected
client's permissible hand/deck view **before** recording this event.

## Stage 2 - atomic takeover (NOT implemented)

1. A verified match-specific preliminary loss (Last Turn) completes its
   entire chain. Any win interception must be limited to that scenario.
2. The engine records a *preliminary loss*, without sending a terminal MSG_WIN.
3. The server validates the connected successor, session and privacy.
4. Existing LP, hand, Graveyard, banished cards, field, chains, counters,
   continuous effects, Deck Master and turn history remain authoritative.
5. Move ONLY cards still belonging to the incoming successor's undeployed
   Deck and Extra Deck into the inherited side. Never copy card instances.
   Do not relocate previously used cards out of Kaiba's Graveyard or banish.
6. Replace control of the original network seat, re-send permitted private
   information, and preserve Noah's perspective.
7. Only after every step succeeds does the transaction commit, schedule
   turn 19 and emit MSG_DUEL_SUCCESSION for live clients and YRPX replays.
8. If any step fails, do NOT complete the handoff or forge victory. Abort
   safely, restore the previous controller, and report an explicit error.

## Noah scenario verification criteria

- Kaiba-vs-Noah first; Last Turn resolves at the end of the first segment.
- Yugi inherits Kaiba's field side and his remaining LP (400 in the
  referenced anime state); Noah remains at 7,400 LP.
- The inherited hand is NOT replaced with an arbitrary starting hand.
- Graveyard and banished card ownership are preserved and Blue-Eyes cards
  are never duplicated; Yugi must be able to use Kaiba's Graveyard.
- Kaiser Sea Horse keeps its Deck Master identity; Noah's Shinato retains
  its own already-resolved state and abilities.
- Turn count advances from the transition at turn 18 to the next turn 19.
- A single YRPX contains both segments and correctly identifies the
  controlling duelist after succession.
- Standard, 2v1 (Big 5), 3v1, Battle Royale and their replays remain intact.

## Stage 3 - controls and verification (NOT implemented)

- Explicit 3-player lobby with a *reserved* Yugi successor, but only two
  active physical fields. Secure spectator/standby authorization required.
- Deck Master, Last Turn script verification, and anime-specific ending.
- Replay sync, hand hiding, role exchange and full in-game UI presentation.
- GitHub CI builds on a matching EDOPro/ygopro-core pair plus real duel tests.

## Test execution

From ygopro-core: `sh tests/run_duel_succession_tests.sh`.

IMPORTANT: At this stage, creating an Inherited Duel lobby starts a two-player
duel with the new state tracked by the core. **It does not yet automatically
invite Yugi, intercept Last Turn, transfer decks or complete the story.**

## Stage 2 progress - transfer preflight (implemented, NOT yet live)

- Core now includes `duel_succession_transfer.h` with an immutable transfer
  preflight routine.
- Each physical card instance needs a distinct ID. Distinct physical copies
  with the same printed card ID are allowed, but the **same card instance**
  cannot appear twice in the merged duel.
- A successor may supply only undeployed Deck and Extra Deck entries.
  Graveyard, banished, hand, field and Deck Master cards already in the duel
  are retained unchanged by this validation procedure.
- Cards belonging to Noah's side are rejected as successor imports.
- Any bad identity, duplicate or oversized proposal fails as a whole.
  A partially valid deck proposal cannot be applied.
- Tests cover Kaiba's Blue-Eyes in GY, Kaiser Sea Horse in Deck Master,
  Noah's surviving resources, a Yugi deck/Extra Deck and invalid proposals.
- These are safe **preflight/data-model tests**, not a demonstration that
  on-field card migration or real network control transfer is finished.
- The EDOPro branch's `ocgcore` gitlink is pinned to the exact tested core
  version. Build/test must use recursive submodules.

Remaining blockers before end-to-end transition:
1. Reserve and authenticate Yugi as the only authorized successor in the lobby.
2. Obtain Yugi's Deck/Extra Deck with stable actual core card identities.
3. Add an engine transaction that MOVES card objects without cloning IDs.
4. Intercept only the verified Noah Last Turn preliminary result safely.
5. Atomically switch the network responder/hidden information rights and
   emit succession messages only after the transaction succeeds.
6. Complete full Windows build and a 42-turn replay acceptance test.
