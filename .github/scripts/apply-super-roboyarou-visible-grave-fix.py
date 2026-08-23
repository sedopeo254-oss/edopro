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
\t// In multiplayer, a card leaving one logical player's private pile for an
\t// on-field zone must keep that logical duelist. Using current_duelist here
\t// could put P2's Deck Master on P3's field when P3 happened to be displayed.
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

client = ROOT / "gframe" / "duelclient.cpp"
old_client = '''\tcase MSG_SPSUMMONING: {
\t\tconst auto code = BufferIO::Read<uint32_t>(pbuf);
\t\t/*CoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);*/
\t\tif(!code || !PlayChant(SoundManager::CHANT::SUMMON, code))
\t\t\tPlay(SoundManager::SFX::SPECIAL_SUMMON);
'''
new_client = '''\tcase MSG_SPSUMMONING: {
\t\tconst auto code = BufferIO::Read<uint32_t>(pbuf);
\t\tCoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
\t\t// A face-up Special Summon is public information. Re-bind the code to
\t\t// the visible ClientCard so cards originating in another logical private
\t\t// pile (notably a 3v1 Deck Master) cannot remain as an invisible code-0 card.
\t\tif(MapLocationDisplay(info)) {
\t\t\tif(auto* pcard = mainGame->dField.GetCard(info.controler, info.location,
\t\t\t\t\tinfo.sequence, info.position); pcard) {
\t\t\t\tif(code && pcard->code != code)
\t\t\t\t\tpcard->SetCode(code);
\t\t\t\tpcard->position = info.position;
\t\t\t\tpcard->UpdateDrawCoordinates(true);
\t\t\t}
\t\t}
\t\tif(!code || !PlayChant(SoundManager::CHANT::SUMMON, code))
\t\t\tPlay(SoundManager::SFX::SPECIAL_SUMMON);
'''
replace_once(client, old_client, new_client)

test = ROOT / "ocgcore" / "tests" / "multiplayer_field_tests.cpp"
needle = '''\texpect(field.get_logical_list(0, LOCATION_GRAVE, 1).size() == 2
\t\t\t&& field.get_logical_list(0, LOCATION_GRAVE, 1).back() == controlled_ally,
\t\t"a temporarily controlled card must return to its original logical owner's Graveyard");

\tconst auto tristan_hand_count = field.get_logical_list(0, LOCATION_HAND, 1).size();
'''
insert = '''\texpect(field.get_logical_list(0, LOCATION_GRAVE, 1).size() == 2
\t\t\t&& field.get_logical_list(0, LOCATION_GRAVE, 1).back() == controlled_ally,
\t\t"a temporarily controlled card must return to its original logical owner's Graveyard");

\t// Regression: while Duke is the focused allied field, a P2/Tristan card
\t// moving from Tristan's private pile to the field must still enter Tristan's
\t// field, remain face-up/public there, and later return to Tristan's Graveyard.
\tconst auto tristan_grave_before_dm = field.get_logical_list(0, LOCATION_GRAVE, 1).size();
\texpect(field.tag_swap_to(0, 2), "the display must switch to Duke for the Deck Master ownership regression");
\tauto* tristan_deck_master = game.new_card(2007);
\ttristan_deck_master->owner = 0;
\ttristan_deck_master->owner_duelist = 1;
\tfield.add_card(0, tristan_deck_master, LOCATION_DECK, 0, false, 1);
\texpect(tristan_deck_master->current.duelist == 1,
\t\t"the P2 Deck Master stand-in must begin in P2's logical private pile");
\texpect(field.move_card(0, tristan_deck_master, LOCATION_MZONE, 1),
\t\t"the P2 Deck Master stand-in must be able to enter a monster zone while P3 is focused");
\texpect(tristan_deck_master->current.duelist == 1
\t\t\t&& tristan_deck_master->current.sequence == 8
\t\t\t&& field.player[0].list_mzone[8] == tristan_deck_master,
\t\t"a P2 Deck Master must enter P2's field instead of the currently focused P3 field");
\texpect(field.move_card(0, tristan_deck_master, LOCATION_GRAVE, 0),
\t\t"the summoned P2 Deck Master must be able to move to its owner's Graveyard");
\texpect(field.get_logical_list(0, LOCATION_GRAVE, 1).size() == tristan_grave_before_dm + 1
\t\t\t&& field.get_logical_list(0, LOCATION_GRAVE, 1).back() == tristan_deck_master
\t\t\t&& tristan_deck_master->current.duelist == 1,
\t\t"the summoned P2 Deck Master must appear in P2's logical Graveyard");
\texpect(field.tag_swap_to(0, 1), "the active allied resources must return to Tristan after the regression test");

\tconst auto tristan_hand_count = field.get_logical_list(0, LOCATION_HAND, 1).size();
'''
replace_once(test, needle, insert)

print("Applied Super Roboyarou logical summon, visibility, and Graveyard regression fix")
