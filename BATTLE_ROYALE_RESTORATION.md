# 4-Way Battle Royale restoration

This branch restores and audits **Battle Royale 1v1v1v1** without changing the completed 3v1 mode.

## Frozen reference points

- Battle Royale client baseline: `ec2d962dc471abaea24cb1eba8371018ac17c952`
- Battle Royale core baseline used by that client: `7bb48dc41d8cd21cd8d9d574d3ef5ec40841b792`
- Protected 3v1 client baseline: `ef0b3f205cfd97b5fae6a181e1164c737affc896`
- Protected 3v1 core baseline: `bb0c48e455857156b55a223d1766d416e16dbf10`

Exact archive branches:

- `archive/4way-battle-royale-ec2d962`
- `backup/3v1-balanced-final-before-battle-royale-20260829`

## Battle Royale behavior to preserve from ec2d962 and its parents

1. Four independent LP values, fields, hands, Decks, Extra Decks, Graveyards and banished piles.
2. Turn order `A1 -> B1 -> A2 -> B2`, skipping eliminated players.
3. FFA victory: no team-sharing of cards, effects, usage limits or alternate-win pieces.
4. Attack target selection among all legal opponents without changing the attacker's field.
5. Correct direct-attack target, damage recipient and attack arrow direction.
6. Hidden hands, facedown cards and private piles stay private.
7. `Let me take it` supports eligible attack and effect-damage interception.
8. Replay records the real attacker, target, interceptor, field focus and private piles.
9. Replay switches to the selected defender and returns cleanly after the event.
10. Monster ATK/DEF/Level labels and Pendulum scales remain upright after replay view changes.
11. Each player's Deck Master remains independent.
12. Eliminated players are skipped cleanly and cannot cause stale-pointer or repeated-end crashes.

## 3v1 invariants that must not regress

1. During P4's turn the team view stays on P1 except for a real attack or target involving P2/P3.
2. P1/P2/P3 private piles never mix.
3. Replay draw and summon pacing remains balanced (`22 / 8 / 8`, draw movement `12`).
4. P2/P3 Deck Master images remain visible and private choices remain hidden.
5. Super Roboyarou stays with its logical owner, receives its Deck Master bonus, redirects damage correctly and appears in the owner's Graveyard.
6. The corrected 3v1 attack arrow and target-selection behavior remains unchanged.
7. Standard mode remains unchanged.

## Isolation rule

Production changes must be guarded by the exact mode:

- Battle Royale-only behavior: `DUEL_BATTLE_ROYALE`
- 3v1-only behavior: `DUEL_3_V_1`
- Shared helpers may be changed only when both modes have explicit regression coverage.

No Battle Royale repair may be implemented by resetting the client or core to the old baseline wholesale. Proven Battle Royale behavior will be selectively backported onto the protected 3v1 baseline.

## Validation gate

Every Battle Royale change must pass:

- Multiplayer state tests
- Multiplayer field tests
- attack-arrow tests
- 3v1 replay policy tests
- 3v1 replay animation tests
- Windows bundled build
- manual four-client Battle Royale smoke test when a test package is produced
