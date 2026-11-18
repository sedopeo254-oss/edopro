# Custom Polymerization V2 — isolated experimental card feature

**Spell ID:** `80050020` · **Fusion body ID:** `80050021` · **CDB type of 80050021:** `97` (Monster + Effect + Fusion; **not Token**)

This package changes neither duel modes nor network messages. It is an opt-in experiment replacing only the two scripts for these two card IDs. It has a runnable Lua test harness, a safe updater for existing card-text option strings, and a standalone offline cosmetic studio.

## Installation (test copy only)

1. Create a **separate copy** of your working EDOPro installation. Keep the stable EDOPro Smooth installation untouched.
2. Ensure your custom CDB already defines `80050020` as a Spell and `80050021` as a **Fusion Effect Monster (type 97)**. Do not use the `TYPE_TOKEN` bit in card `80050021`.
3. Copy `scripts/c80050020.lua` and `scripts/c80050021.lua` to your test installation's `expansions/script/`, replacing only those two card scripts.
4. Optionally run `python tools/patch_custom_cdb.py PATH/TO/YOUR/CUSTOM.cdb` **with EDOPro closed** to populate the three ability mode options and confirmation text. This tool verifies the two card records and makes a timestamped backup first. It does not alter card types, IDs, names, artwork or scripts.
5. Run a **new duel**, select at least two monsters in your Hand/field, and choose **All compatible**, **Choose individually**, or **Smart (offline rule-based)**. Choose the monster's Attack/Defense position as before.
6. For an optional shared card image, run `python tools/fusion_studio.py` (Python + Pillow). Select card images you have rights to use and **a separate test game folder**. The output `pics/80050021.jpg` changes the artwork of **all** `80050021` cards in that installation, not individual copies.

The spell's options depend on CDB `texts.str1`, `str2`, `str3` and `str6` being populated as above. Without them the client may show question marks instead of descriptive labels.

## What V2 actually implements

- Materials: **2 or more** eligible monsters in your Hand/MZONE, without `MAX_COPY = 6`; no fixed script-imposed effect-count limit, only engine/performance/card pool limits.
- Allows a **full Monster Zone** if chosen on-field materials free a usable zone; confirms the zone is free before summoning.
- Reads the source monsters' **registered effect objects before sending them to the GY**, using `GetOwnEffects`; catches effects another script directly registered on those monsters. Tries to flatten a few portable external, numeric grants exposed through `GetCardEffect(0)`.
- Builds new effect objects with the Fusion as their owner, preserves callback references, categories, count limits, and explicitly lets applicable effects survive field-to-grave-and-back via `SetReset(0)`.
- Three inheritance choices in a normal duel prompt: **all compatible**, **manual selection of individual eligible effects**, and **automatic rule-based ranking**. **Smart mode is not generative AI.**
- Maintains **half summed ATK/DEF**, **half summed Level** (Xyz Rank/Link Rating fallback), bitwise-unioned **Race/Attribute**; calculated at the time of Fusion.
- Uses `Duel.SpecialSummon(fc, SUMMON_TYPE_FUSION, ...)`, `fc:SetMaterial(g)` and `fc:CompleteProcedure()` on success. `80050021` enables its normal Fusion revival restriction.
- Replaces **only** Revival Slime's old `EFFECT_DESTROY_REPLACE` if material code is `31709826`. Uses a pre-registered `EVENT_TO_GRAVE` trigger to **Special Summon the very same Fusion card from the GY** following a legal destruction; no new 535 token. Revive is subject to limits, free zones, negations, prohibition effects and the regular game's constraints.
- When using a previous `80050021` fusion as material, the previously selected descriptor list is carried forward without re-copying the wrapper effects.

## Critical limits (do not interpret as 100% behavior)

1. **Effect copying is not universally safe or complete.** Script functions may depend on the original card's owner, on a `LabelObject`, on resources that cease to exist, or on special engine-internal procedures. V2 deliberately omits uncopiable, summon-procedure, and nonportable effect classes. Global continuous auras, equip effects with function values and ambiguous overlaps are not universally portable. The original `EFFECT_DESTROY_REPLACE` is substituted only when the source has `31709826`; any other Revival Slime effects remain candidates.
2. **Destroy/return is a trigger, not destroy replacement.** The Fusion really gets destroyed and goes to the Graveyard first. If legal when the trigger resolves, it Special Summons itself again. This is intentional to make Graveyard effects see the destruction. The separate native Revival Jam script is not changed.
3. **Same card and persistent bonuses** are maintained in Lua for the card object as long as the duel Core retains that object. The underlying client/card DB may not serialize this profile across replays, card-instance reconstruction, or arbitrary deck shuffles. Real multiplayer/replay tests remain essential.
4. **Free names and per-instance images DURING the duel are NOT implemented here.** EDOPro's stock client resolves names and textures by numeric card ID. `EFFECT_CHANGE_CODE` would change gameplay identity and is not used. The Studio saves a manual or generated *suggestion* as JSON metadata and can create a **shared static 80050021 artwork**, but the current client cannot display a unique name/image on each Fusion card simultaneously.
5. **Real AI naming/image synthesis** from material artwork is not integrated. It would require an explicitly permissioned AI image/text provider, a client UI for proposals, and a synchronized, validated per-instance cosmetic ID embedded in multiplayer/replay protocol. No API keys or unlicensed card art are uploaded by this package.
6. **No mode changes:** no edits to `gframe`, `ocgcore`, `WindBot`, `server`, multiplayer scripts or gameplay flags. The GitHub branch changes only the two custom-card scripts and this document; standalone tooling and tests are in the downloadable experimental ZIP. There are no workflow changes.

## Suggested in-duel acceptance cases

- Standard Duel: fuse Revival Slime (`31709826`) + Gandora + Dark Jeroid; inspect material count, Level, ATK/DEF, Attribute/Race, and Fusion Summon status.
- Enable double attacks on a material with an external script and check the resulting Fusion's extra attacks.
- Choose all/manual/smart and confirm that excluded effects are not present; verify no unexpected loops.
- Destroy and revive the Fusion five times on separate turns, observe the same card ID, the same selected powers and exact LP/position effects.
- Chain-fuse that Fusion with a fourth monster and inspect the entire effect lineage.
- Attempt the spell when all zones are full, with an on-field material that will free a zone, then repeat selecting only hand monsters (which must be rejected).
- Graveyard triggering on destruction versus sending as cost, banish/return, Deck/Extra transitions, view swaps, three/four-player games and replays.

## Tests

The included tests are **mocked contracts** (not real duel acceptance). Locally, a Lua 5.4 runtime can run:

```sh
lua5.4 tests/test_custom_polymerization.lua scripts/c80050020.lua scripts/c80050021.lua
```

In this ChatGPT environment, `tests/run_lua.py` runs the same Lua test using the installed Lua 5.4 dynamic library. The CDB and Studio smoke tests use Pillow/SQLite in Python.

## Architecture needed for true in-game designer and AI

- Keep game **rules** independent: the Core provides a per-instance `CustomFusionBlueprint` containing original material IDs, chosen transferable effect descriptors, summon status, stats and a unique cosmetic profile ID.
- UI: a new, *optional* client-only `CustomFusionDesigner` panel triggered for `80050020` to select abilities (All/Manual/AI), enter a UTF-8 custom name or accept AI suggestions, choose uploaded/AI-generated images, inspect proposals and confirm.
- Network/replay: clients share only an immutable validated manifest ID and safe cosmetic media hash/URL, never raw arbitrary executable scripts; hide material identities where rules require. If a client has no media, display the normal `80050021` art.
- Persistence: scope the blueprint per **physical card identity**, across zone changes and revive, with replay serialization. Add safeguards for double-copy, ordering, conflicts, limits, asset size, prompt cancellation, AI timeouts and a deterministic offline fallback.
- AI: server/desktop helper on explicit opt-in only, with owner-provided assets and licensing checks. **Do not block the duel engine** while generating content.

## Scope protection

Stable source branch: `feature/smooth-card-transitions-20261118`. Development on separate `feature/custom-polymerization-v2-20261118`. Revert by switching back to your stable build or copying back the backed-up two Lua scripts.