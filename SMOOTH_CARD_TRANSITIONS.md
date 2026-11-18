# EDOPro Quick Card Animation and Card Motion Reliability

Experiment branch: `feature/smooth-card-transitions-20261118`.
Stable five-mode branch: `feature/inherited-duel-succession-v1-20261105` (untouched).

## Changes

- Eased motion is applied to the existing visual MoveCard path on a per-card
  basis, independent of network packets, duel rules and the running turn.
- Repeated movements resume from the card's current position; frame hitches
  cannot overshoot the destination. The final position is set exactly.
- Existing manual reveal/shuffle velocities still use the original path.
- MSG_DRAW now animates hand updates instead of teleporting all cards.
- MSG_MULTIPLAYER_DRAW animates only its own visible hand, preserving private
  teammate data and the other field's existing transitions.
- MSG_SPSUMMONING no longer overrides an in-flight MSG_MOVE with an immediate
  UpdateDrawCoordinates(true) while Special Summon resolves.
- MSG_SET and MSG_POS_CHANGE continue through existing move/flip code and use
  the new interpolator when MoveCard is scheduled.
- Fast Special Summon preview now fades in and out and its elapsed timer is
  reset for every new preview. Timing does not delay actual duel events.
- All instant RefreshAllCards calls required by replay catch-up, field switch
  and private pile rebuilding remain authoritative and instant.

## Validation

- Pure C++ interpolation tests: endpoints, rapid animation, frame hitches,
  monotonic movement, zero-duration and preview fade-in/out.
- Packet path guards for draw, private draw, summoning, flip, activation, set.
- Inherited Duel, Battle Royale, 3v1, 2v1 and Standard preserved via the
  unified Windows workflow and Core regression suites.
- Full functionality in each of these five game modes and complex chain
  interactions still requires in-game multiplayer and replay acceptance tests;
  build/test success is NOT a 100% correctness guarantee.

## Target scenarios to test in Windows

1. Draw 1 and Draw 5 in Standard, all four multiplayer modes, and replay.
2. Normal/Special/Flip/Ritual/Fusion/Synchro/Xyz summons with and without
   Quick Card Animation; chained effects and face-down spell/trap Set/Flip.
3. Repeated movement of the same card while it is still animating.
4. Replay seek/rewind and field switches, with hidden-card identities intact.
5. Mid-duel 2v1 teammate switch and Inherited Duel Kaiba/Noah successors.
6. Multiple attacks and field display focusing in 3v1 and Battle Royale.
