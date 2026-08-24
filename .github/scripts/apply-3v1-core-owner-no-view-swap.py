from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one patch site, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


field = ROOT / "ocgcore" / "field.cpp"
old_field = '''\tuint8_t preplayer = pcard->current.controler;
\tuint8_t presequence = pcard->current.sequence;
\tconst auto target_duelist = static_cast<uint8_t>((location & LOCATION_ONFIELD)
\t\t? ((pcard->current.location & LOCATION_ONFIELD) && preplayer == playerid
\t\t\t? pcard->current.duelist : player[playerid].current_duelist)
\t\t: (playerid == pcard->owner ? pcard->owner_duelist : player[playerid].current_duelist));
\tif(location == LOCATION_MZONE || location == LOCATION_SZONE)
\t\tsequence = static_cast<uint8_t>(get_zone_sequence(playerid, location, sequence, target_duelist));
'''
new_field = '''\tuint8_t preplayer = pcard->current.controler;
\tuint8_t presequence = pcard->current.sequence;
\t// Preserve a logical player's private-pile identity when moving to the
\t// field. This assigns P2's Deck Master to P2's encoded field slots without
\t// changing current_duelist / replay camera to whichever ally owns the card.
\tconst bool preserve_private_duelist = multiplayer.enabled() && preplayer == playerid
\t\t&& (pcard->current.location & (LOCATION_DECK | LOCATION_HAND | LOCATION_GRAVE
\t\t\t| LOCATION_REMOVED | LOCATION_EXTRA))
\t\t&& pcard->current.duelist < multiplayer.field_count(playerid);
\tconst auto target_duelist = static_cast<uint8_t>((location & LOCATION_ONFIELD)
\t\t? ((((pcard->current.location & LOCATION_ONFIELD) && preplayer == playerid)
\t\t\t|| preserve_private_duelist)
\t\t\t? pcard->current.duelist : player[playerid].current_duelist)
\t\t: (playerid == pcard->owner ? pcard->owner_duelist : player[playerid].current_duelist));
\tif(location == LOCATION_MZONE || location == LOCATION_SZONE)
\t\tsequence = static_cast<uint8_t>(get_zone_sequence(playerid, location, sequence, target_duelist));
'''
replace_once(field, old_field, new_field)

old_add = '''\tadd_card(playerid, pcard, location, sequence, pzone);
\treturn true;
}
void field::swap_card(card* pcard1, card* pcard2, uint8_t new_sequence1, uint8_t new_sequence2) {
'''
new_add = '''\t// Keep the authoritative logical duelist chosen above all the way through
\t// add_card(). Do not fall back to the currently displayed teammate.
\tadd_card(playerid, pcard, location, sequence, pzone, target_duelist);
\treturn true;
}
void field::swap_card(card* pcard1, card* pcard2, uint8_t new_sequence1, uint8_t new_sequence2) {
'''
replace_once(field, old_add, new_add)

# Regression: P3 remains the focused ally while a P2 Deck Master enters P2's
# field, receives battle damage as P2, and later appears in P2's Graveyard.
test = ROOT / "ocgcore" / "tests" / "multiplayer_field_tests.cpp"
needle = '''\texpect(field.get_logical_list(0, LOCATION_GRAVE, 1).size() == 2
\t\t\t&& field.get_logical_list(0, LOCATION_GRAVE, 1).back() == controlled_ally,
\t\t"a temporarily controlled card must return to its original logical owner's Graveyard");

\tconst auto tristan_hand_count = field.get_logical_list(0, LOCATION_HAND, 1).size();
'''
insert = '''\texpect(field.get_logical_list(0, LOCATION_GRAVE, 1).size() == 2
\t\t\t&& field.get_logical_list(0, LOCATION_GRAVE, 1).back() == controlled_ally,
\t\t"a temporarily controlled card must return to its original logical owner's Graveyard");

\t// Replay-safe Deck Master regression: leave Duke/P3 focused. Moving a card
\t// from Tristan/P2's private pile must not TagSwap/focus P2; the card itself
\t// carries duelist=1 into P2's encoded field and through battle/Graveyard.
\tconst auto tristan_grave_before_dm = field.get_logical_list(0, LOCATION_GRAVE, 1).size();
\texpect(field.tag_swap_to(0, 2), "P3 must be focused before the replay-safe Deck Master regression");
\texpect(field.player[0].current_duelist == 2,
\t\t"the regression must begin and remain with P3 focused");
\tauto* tristan_deck_master = game.new_card(2007);
\ttristan_deck_master->owner = 0;
\ttristan_deck_master->owner_duelist = 1;
\tfield.add_card(0, tristan_deck_master, LOCATION_DECK, 0, false, 1);
\texpect(tristan_deck_master->current.duelist == 1,
\t\t"the P2 Deck Master stand-in must begin in P2's private pile");
\texpect(field.move_card(0, tristan_deck_master, LOCATION_MZONE, 1),
\t\t"the P2 Deck Master stand-in must enter a monster zone while P3 stays focused");
\texpect(field.player[0].current_duelist == 2,
\t\t"moving P2's Deck Master must not change the P3 replay/view focus");
\texpect(tristan_deck_master->current.duelist == 1
\t\t\t&& tristan_deck_master->current.sequence == 8
\t\t\t&& field.player[0].list_mzone[8] == tristan_deck_master,
\t\t"a P2 Deck Master must enter P2's encoded field while P3 remains focused");
\tauto* deck_master_attacker = game.new_card(3007);
\tdeck_master_attacker->owner = 1;
\tdeck_master_attacker->owner_duelist = 0;
\tfield.add_card(1, deck_master_attacker, LOCATION_MZONE, 1);
\tfield.core.attacker = deck_master_attacker;
\tfield.core.attack_target = tristan_deck_master;
\tfield.core.attack_target_duelist = tristan_deck_master->current.duelist;
\tfield.core.attack_target_logical = 1;
\tfield.core.subunits.clear();
\tfield.damage(nullptr, REASON_BATTLE, 1, deck_master_attacker, 0, 500);
\tauto* owner_locked_damage = Processors::get_opt_variant<Processors::Damage>(field.core.subunits.back());
\texpect(owner_locked_damage && owner_locked_damage->duelist == 1,
\t\t"battle damage redirected to P2's Deck Master must be charged to P2, never P3");
\tfield.core.subunits.clear();
\texpect(field.move_card(0, tristan_deck_master, LOCATION_GRAVE, 0),
\t\t"the summoned P2 Deck Master must move to its owner's Graveyard");
\texpect(field.get_logical_list(0, LOCATION_GRAVE, 1).size() == tristan_grave_before_dm + 1
\t\t\t&& field.get_logical_list(0, LOCATION_GRAVE, 1).back() == tristan_deck_master
\t\t\t&& tristan_deck_master->current.duelist == 1,
\t\t"the summoned P2 Deck Master must appear in P2's logical Graveyard");
\texpect(field.player[0].current_duelist == 2,
\t\t"P3 must still be focused after P2's Deck Master reaches the Graveyard");

\tconst auto tristan_hand_count = field.get_logical_list(0, LOCATION_HAND, 1).size();
'''
replace_once(test, needle, insert)

print("Applied replay-safe P2 Deck Master ownership without any view swap")
