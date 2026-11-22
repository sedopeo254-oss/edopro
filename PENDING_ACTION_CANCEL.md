# EDOPro — safe Cancel / Confirm for uncommitted actions

Branch: `feature/pending-action-cancel-20261122`
Stable base: `feature/smooth-card-transitions-20261118` at commit
`6e0606055ab209afe3f31040fa67d88ba75c6b4a`.

## Supported actions

The live client stages the existing four-byte command before the Core receives
it. **Cancel** discards it; **Confirm** sends the same command using the
original response-handling code. No rollback or rewinding of duel state occurs.

- Main Phase: Normal Summon, Special Summon, monster face-down Set,
  Spell/Trap Set, activation from hand/field/piles/options.
- Battle Phase: voluntary card activation (not attack/phase change).
- Optional Chain: activating a selected effect is staged. Cancel declines
  the chain using its legal -1 response. Forced chains bypass staging.
- All existing duel modes use one common client path. No mode, Core, script,
  protocol, network packet or replay-format modifications are required.

The Cancel/Confirm buttons appear in the red-marked area to the right of
the Chain controls. Both are hidden when idle, during Replay, for spectators
or eliminated local players, and on catch-up.

**Not a post-commit Undo:** If you have already confirmed Summon/Set/Activate
and the Core is requesting a zone/position/tribute, that action cannot safely
be undone merely by sending -1. This avoids desynchronizing multiplayer.

## Validation

1. Run `.github/tests/pending_action_confirm_test.cpp` (action classifier).
2. Run the existing five-mode client/Core compatibility pipeline.
3. Manually test Cancel/Confirm for each listed action in all five modes,
   with Quick Card Animation on/off, optional/forced chain prompts,
   replay playback and disconnection mid-prompt.
