# Ai Duel v0.2.0

Ai Duel is a Windows desktop foundation for building a universal Yu-Gi-Oh duel intelligence system.

## v0.2 highlights

- Semantic causality engine: understands structured sequences instead of storing isolated actions.
- Summon-method reconstruction: Normal / Tribute / Special / Fusion / Synchro / Xyz / Link / Ritual / Pendulum.
- Tribute material linkage (`consumed-by`).
- Card-text semantics: trigger, condition, cost/target, operation, once-per-turn signals.
- Effect enablement and result linkage (`enabled-by`, `caused-by`).
- Example supported chain: tribute two monsters -> Tribute Summon -> on-summon effect becomes enabled -> activate -> draw.
- Master Duel Steam integration page with read-only validation of:
  - game executable
  - `masterduel_Data`
  - `duel.dll`
  - `LocalData` / account asset stores
  - bootstrap AssetBundles
  - optional exported replay source folders
- Deep LocalData scan without writing to game files.
- Replay source watcher when an exported replay folder is available.
- Persistent semantic facts and causal links for later AI training.

## Important boundary

The Steam installation contains the Master Duel client and large downloaded asset stores, but it does not continuously expose every official online duel decision as a simple file stream. Ai Duel v0.2 therefore separates:

1. static Steam/client data discovery,
2. replay/export evidence,
3. the semantic reconstruction engine,
4. a future dedicated observer decoder for exact Master Duel duel-engine events.

The Master Duel integration in Ai Duel is read-only. It does not automate gameplay or expose hidden opponent information.

## Development

```bash
npm install
npm start
```

Build portable Windows x64:

```bash
npm run build:win
```
