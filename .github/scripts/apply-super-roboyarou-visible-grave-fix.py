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

old_add_card = '''\tadd_card(playerid, pcard, location, sequence, pzone);
\treturn true;
}
void field::swap_card(card* pcard1, card* pcard2, uint8_t new_sequence1, uint8_t new_sequence2) {
'''
new_add_card = '''\t// target_duelist is authoritative for both the encoded field slot and the
\t// card state. Passing it here prevents add_card() from replacing P2 with the
\t// currently focused P3 after the correct P2 slot was already selected.
\tadd_card(playerid, pcard, location, sequence, pzone, target_duelist);
\treturn true;
}
void field::swap_card(card* pcard1, card* pcard2, uint8_t new_sequence1, uint8_t new_sequence2) {
'''
replace_once(field, old_add_card, new_add_card)

# Expose an exact logical-player focus primitive to Lua. Unlike Duel.TagSwap,
# this does not guess or cycle blindly: P2 always resolves to side 0 / duelist 1.
libduel = ROOT / "ocgcore" / "libduel.cpp"
old_tag_swap = '''LUA_STATIC_FUNCTION(TagSwap) {
\tcheck_action_permission(L);
\tcheck_param_count(L, 1);
\tauto playerid = lua_get<uint8_t>(L, 1);
\tif (playerid != 0 && playerid != 1)
\t\treturn 0;
\tpduel->game_field->tag_swap(playerid);
\treturn yield();
}
LUA_STATIC_FUNCTION(GetPlayersCount) {
'''
new_tag_swap = '''LUA_STATIC_FUNCTION(TagSwap) {
\tcheck_action_permission(L);
\tcheck_param_count(L, 1);
\tauto playerid = lua_get<uint8_t>(L, 1);
\tif (playerid != 0 && playerid != 1)
\t\treturn 0;
\tpduel->game_field->tag_swap(playerid);
\treturn yield();
}
LUA_STATIC_FUNCTION(FocusLogicalPlayer) {
\tcheck_action_permission(L);
\tcheck_param_count(L, 1);
\tconst auto logical_player = lua_get<uint8_t>(L, 1);
\tauto* game_field = pduel->game_field;
\tif(!game_field->multiplayer.enabled()) {
\t\tlua_pushboolean(L, logical_player < 2);
\t\treturn 1;
\t}
\tif(logical_player >= MultiplayerState::MAX_PLAYERS
\t\t\t|| !game_field->multiplayer.is_active(logical_player)) {
\t\tlua_pushboolean(L, false);
\t\treturn 1;
\t}
\tconst auto side = game_field->multiplayer.field_side_of(logical_player);
\tconst auto duelist = game_field->multiplayer.duelist_index_of(logical_player);
\tconst bool focused = side < 2 && duelist != MultiplayerState::NO_PLAYER
\t\t&& game_field->tag_swap_to(side, duelist);
\tlua_pushboolean(L, focused);
\treturn 1;
}
LUA_STATIC_FUNCTION(GetPlayersCount) {
'''
replace_once(libduel, old_tag_swap, new_tag_swap)

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

\t// Regression: while Duke/P3 is focused, a P2/Tristan Deck Master must stay
\t// attached to P2 through field entry, battle targeting/damage, and Graveyard.
\tconst auto tristan_grave_before_dm = field.get_logical_list(0, LOCATION_GRAVE, 1).size();
\texpect(field.tag_swap_to(0, 2), "P3 must be focused before the Deck Master owner-lock regression");
\texpect(field.player[0].current_duelist == 2,
\t\t"the regression must really begin with P3 focused");
\t// FocusLogicalPlayer(1) is a Lua wrapper around this exact primitive.
\texpect(field.tag_swap_to(0, 1), "exact logical focus must switch directly from P3 to P2");
\texpect(field.player[0].current_duelist == 1,
\t\t"P2 must be the active allied field before its Deck Master is Summoned");
\tauto* tristan_deck_master = game.new_card(2007);
\ttristan_deck_master->owner = 0;
\ttristan_deck_master->owner_duelist = 1;
\tfield.add_card(0, tristan_deck_master, LOCATION_DECK, 0, false, 1);
\texpect(tristan_deck_master->current.duelist == 1,
\t\t"the P2 Deck Master stand-in must begin in P2's logical private pile");
\texpect(field.move_card(0, tristan_deck_master, LOCATION_MZONE, 1),
\t\t"the P2 Deck Master stand-in must enter a monster zone after exact focus");
\texpect(tristan_deck_master->current.duelist == 1
\t\t\t&& tristan_deck_master->current.sequence == 8
\t\t\t&& field.player[0].list_mzone[8] == tristan_deck_master,
\t\t"a P2 Deck Master must enter P2's field, never P3's field");
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
\t\t"the summoned P2 Deck Master must be able to move to its owner's Graveyard");
\texpect(field.get_logical_list(0, LOCATION_GRAVE, 1).size() == tristan_grave_before_dm + 1
\t\t\t&& field.get_logical_list(0, LOCATION_GRAVE, 1).back() == tristan_deck_master
\t\t\t&& tristan_deck_master->current.duelist == 1,
\t\t"the summoned P2 Deck Master must appear in P2's logical Graveyard");
\texpect(field.tag_swap_to(0, 1), "the active allied resources must remain on P2 after the regression test");

\tconst auto tristan_hand_count = field.get_logical_list(0, LOCATION_HAND, 1).size();
'''
replace_once(test, needle, insert)

print("Applied exact Deck Master owner focus, visible summon, damage, and Graveyard fix")
