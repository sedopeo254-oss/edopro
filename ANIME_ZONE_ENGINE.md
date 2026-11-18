# Independent Native Anime Field Zones — experimental branch

This extension is authored directly against the custom 5-mode ygopro-core,
not merged from, linked against, or replaced by KCG's ocgcore.dll.

## Stable API and modular rules
- Native anime_zone_rules.h provides extensible Field Spell rule profiles:
  rear-row monsters, front-row shields, row movement, rear summons, ATK
  modifiers and future custom/novel effects.
- Virtual location constants map to existing physical MZONE/SZONE;
  no new network packet or pile owner is needed.
- Engine hooks recognize explicitly marked rear monsters for stat calculation,
  normal Field Spell effects, attack announcements and attack targeting.
- Rear monsters are protected behind a nonempty physical front-row monster
  line when selecting battle targets. Ordinary S/T cards never attack.
- Existing duel modes retain their independent flags and private piles.

## Not released / acceptance gate
Duel.SupportsOrichalcosZones() deliberately returns false until all missing
mechanics are implemented and validated: card movement/summoning to rear slots,
virtual zone queries, card targeting, battle/replay client display and
restore-on-Seal-leave behavior. The stable card c291.lua remains gated.
This branch must not be represented as anime-complete before that validation.

## Next native integration tasks
1. Duel.MoveToField with virtual zones and persistent marker.
2. Card.IsLocation, GetMatchingGroup and GetLocationCount logical row semantics.
3. Real special summons into the rear row, with independent resources.
4. Client zone visuals, replay, attack arrows and spectator sync.
5. Enable native capability only when full-duel tests pass.

KCG binaries are unnecessary.

## Second stage completed in experimental source
- Script requests for LOCATION_RMZONE / LOCATION_RSZONE are converted to
  physical MZONE/SZONE in Duel.MoveToField, CheckLocation and GetLocationCount.
- Lua Card.IsLocation and field matching/group queries recognize virtual rows.
- Physical privacy and owner/duelist state are still managed by the original
  custom engine: no KCG code is included in this branch.
- These APIs are not automatically enabled in c291 until the complete
  summon, permanent rear-zone marker and UI/replay path is tested.
