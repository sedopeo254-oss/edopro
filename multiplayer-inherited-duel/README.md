# Last Turn — Inherited Duel Mode variant (card 28566710)

This is a mode-gated override of the user's supplied `c28566710.lua`.
It only applies the new effect when `Duel.IsDuelType(0x8000000000)`
reports **Inherited Duel Mode**. In every other mode it follows the
previously uploaded Last Turn effect (select 1 monster from the normal Deck
and use the previously uploaded >=1 surviving-monster End Phase rule).

## Effect in Inherited Duel

* Can activate during **opponent's turn** with the activator at **1000 LP or less**.
* Activator selects 1 monster they control; all other cards from both hands
  and both fields go to their respective Graveyards by effect.
* The **opponent** summons their **actual Deck Master Zone card** in
  face-up Attack Position via `Duel.SummonDeckMasterPlayer`, retaining that
  card's Deck Master identity and abilities.
* `Duel.ForceAttack` forces that monster to attack the selected monster,
  with battle damage prevented during the forced Damage Step.
* At the same turn's End Phase, exactly **one** monster remaining anywhere
  on the field wins for its controller. All other cases are a draw.
* Uses `WIN_REASON_LAST_TURN` as before. The Inherited Duel core already
  recognizes the special Noah-win handoff case without making a new duel.

## Installation

A Windows CI build copies `c28566710.lua` to
`deploy/expansions/script/c28566710.lua`, so the patched card script
is installed alongside the mode's existing Deck Master scripts.

To install just the patch into a compatible Inherited Duel EDOPro client,
copy `c28566710.lua` to `expansions/script/c28566710.lua` inside a **copy**
of your EDOPro installation. Use the matching branch's updated
`multiplayer-deck-master/c153000000.lua` for the optional face-up Attack
position parameter. Do not mix with an unrelated old EDOPro executable.

The text shown in EDOPro's card information panel is stored in a CDB file,
not in this Lua script. `Card_Text.txt` contains the requested wording
for optional insertion into the user's private anime/custom card database.

## Notes

* This script does not create additional Deck Masters.
* If the opponent has no Deck Master in their zone, the activation check
  rejects the effect rather than selecting a normal Deck monster.
* An engine-driven forced attack can be restricted by other game rules;
  syntax/mock tests alone do **not** prove an entire anime replay works.
* Replays already recorded remain unchanged; the script affects **new duels**
  played after installing the override.
