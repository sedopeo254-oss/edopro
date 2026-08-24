# Ai Duel v0.1.0

Ai Duel is a Windows desktop foundation for collecting Yu-Gi-Oh duel evidence and turning it into structured tactical knowledge.

## v0.1
- Dashboard, Replay Library, Live Duel, Knowledge Core, AI Training and Settings.
- Imports and preserves replay / duel-data files locally.
- Creates live observer sessions and stores events as JSONL.
- Test bridge verifies the event pipeline before a game-specific decoder is connected.
- Imports card knowledge JSON and infers basic tactical roles.
- Game adapters are separated from the AI core for Master Duel, EDOPro and future games.

## Important limitation
The Master Duel decoder is not faked. v0.1 has the adapter boundary and safe bridge; the next milestone is the real Master Duel data adapter and duel-state reconstruction.

## Build
`npm install` then `npm run build:win`.
