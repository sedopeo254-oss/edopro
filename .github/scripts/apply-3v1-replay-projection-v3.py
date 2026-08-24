from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one patch site, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


header = ROOT / "gframe" / "client_field.h"
replace_once(header,
'''\tstd::array<MultiplayerPrivatePileSnapshot, 4> multiplayer_private_piles;
\tstd::array<bool, 4> multiplayer_private_piles_valid{};
''',
'''\tstd::array<MultiplayerPrivatePileSnapshot, 4> multiplayer_private_piles;
\tstd::array<bool, 4> multiplayer_private_piles_valid{};
\t// Which logical player's private piles are currently projected on each
\t// physical display side. This lets replay updates preserve ClientCard
\t// identity for repeated snapshots of the same player, while doing one clean
\t// identity reset when the view actually changes from e.g. P2 to P1.
\tstd::array<uint8_t, 2> multiplayer_projected_logical{{0xff, 0xff}};
''')
replace_once(header,
'''\tvoid ReplaceMultiplayerPrivatePiles(uint8_t player,
\t\tconst MultiplayerPrivatePileSnapshot& snapshot, bool clear_transient = true);
''',
'''\tvoid ReplaceMultiplayerPrivatePiles(uint8_t player,
\t\tconst MultiplayerPrivatePileSnapshot& snapshot, bool clear_transient = true,
\t\tbool reset_identity = false);
''')

field = ROOT / "gframe" / "client_field.cpp"
replace_once(field,
'''\tfor(size_t logical = 0; logical < multiplayer_private_piles.size(); ++logical) {
\t\tmultiplayer_private_piles[logical] = {};
\t\tmultiplayer_private_piles_valid[logical] = false;
\t}
}
''',
'''\tfor(size_t logical = 0; logical < multiplayer_private_piles.size(); ++logical) {
\t\tmultiplayer_private_piles[logical] = {};
\t\tmultiplayer_private_piles_valid[logical] = false;
\t}
\tmultiplayer_projected_logical = {{0xff, 0xff}};
}
''')
replace_once(field,
'''void ClientField::ReplaceMultiplayerPrivatePiles(uint8_t player,
\t\tconst MultiplayerPrivatePileSnapshot& snapshot, bool clear_transient) {
''',
'''void ClientField::ReplaceMultiplayerPrivatePiles(uint8_t player,
\t\tconst MultiplayerPrivatePileSnapshot& snapshot, bool clear_transient,
\t\tbool reset_identity) {
''')

old_match = '''\tauto match_pile = [player, &detach_card, &reset_card](auto& pile, size_t count, uint8_t location) {
\t\twhile(pile.size() > count) {
\t\t\tauto* pcard = pile.back();
\t\t\tdetach_card(pcard);
\t\t\tdelete pcard;
\t\t\tpile.pop_back();
\t\t}
\t\twhile(pile.size() < count) {
\t\t\tauto* pcard = new ClientCard{};
\t\t\treset_card(pcard, location, static_cast<uint32_t>(pile.size()));
\t\t\tpile.push_back(pcard);
\t\t}
\t\tfor(size_t sequence = 0; sequence < pile.size(); ++sequence) {
\t\t\tauto* pcard = pile[sequence];
\t\t\tif(!pcard)
\t\t\t\tcontinue;
\t\t\tpcard->owner = player;
\t\t\tpcard->controler = player;
\t\t\tpcard->location = location;
\t\t\tpcard->sequence = static_cast<uint32_t>(sequence);
\t\t}
\t};
'''
new_match = '''\tauto match_pile = [player, reset_identity, &detach_card, &reset_card](auto& pile, size_t count, uint8_t location) {
\t\twhile(pile.size() > count) {
\t\t\tauto* pcard = pile.back();
\t\t\tdetach_card(pcard);
\t\t\tdelete pcard;
\t\t\tpile.pop_back();
\t\t}
\t\twhile(pile.size() < count) {
\t\t\tauto* pcard = new ClientCard{};
\t\t\treset_card(pcard, location, static_cast<uint32_t>(pile.size()));
\t\t\tpile.push_back(pcard);
\t\t}
\t\tfor(size_t sequence = 0; sequence < pile.size(); ++sequence) {
\t\t\tauto* pcard = pile[sequence];
\t\t\tif(!pcard)
\t\t\t\tcontinue;
\t\t\tif(reset_identity) {
\t\t\t\tdetach_card(pcard);
\t\t\t\treset_card(pcard, location, static_cast<uint32_t>(sequence));
\t\t\t\tcontinue;
\t\t\t}
\t\t\tpcard->owner = player;
\t\t\tpcard->controler = player;
\t\t\tpcard->location = location;
\t\t\tpcard->sequence = static_cast<uint32_t>(sequence);
\t\t}
\t};
'''
replace_once(field, old_match, new_match)

old_br = '''\tfor(uint8_t display_side = 0; display_side < 2; ++display_side) {
\t\tconst auto logical =
\t\t\tmainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side);
\t\tif(logical < multiplayer_private_piles.size()
\t\t\t\t&& multiplayer_private_piles_valid[logical]) {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tmultiplayer_private_piles[logical], clear_transient);
\t\t} else {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tMultiplayerPrivatePileSnapshot{}, clear_transient);
\t\t}
\t\tclear_transient = false;
\t}
'''
new_br = '''\tfor(uint8_t display_side = 0; display_side < 2; ++display_side) {
\t\tconst auto logical =
\t\t\tmainGame->dInfo.GetBattleRoyaleDisplayLogical(display_side);
\t\tconst auto projected = logical < multiplayer_private_piles.size()
\t\t\t? logical : static_cast<uint8_t>(0xff);
\t\tconst bool reset_identity = multiplayer_projected_logical[display_side] != projected;
\t\tif(logical < multiplayer_private_piles.size()
\t\t\t\t&& multiplayer_private_piles_valid[logical]) {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tmultiplayer_private_piles[logical], clear_transient, reset_identity);
\t\t} else {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tMultiplayerPrivatePileSnapshot{}, clear_transient, reset_identity);
\t\t}
\t\tmultiplayer_projected_logical[display_side] = projected;
\t\tclear_transient = false;
\t}
'''
replace_once(field, old_br, new_br)

old_3v1 = '''\tbool clear_transient = false;
\tfor(uint8_t core_side = 0; core_side < 2; ++core_side) {
\t\tconst auto display_side = mainGame->LocalPlayer(core_side);
\t\tconst auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
\t\tif(display_side > 1)
\t\t\tcontinue;
\t\tif(logical < multiplayer_private_piles.size()
\t\t\t\t&& multiplayer_private_piles_valid[logical]) {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tmultiplayer_private_piles[logical], clear_transient);
\t\t} else {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tMultiplayerPrivatePileSnapshot{}, clear_transient);
\t\t}
\t\tclear_transient = false;
\t}
'''
new_3v1 = '''\tbool clear_transient = false;
\tfor(uint8_t core_side = 0; core_side < 2; ++core_side) {
\t\tconst auto display_side = mainGame->LocalPlayer(core_side);
\t\tconst auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
\t\tif(display_side > 1)
\t\t\tcontinue;
\t\tconst auto projected = logical < multiplayer_private_piles.size()
\t\t\t? logical : static_cast<uint8_t>(0xff);
\t\tconst bool reset_identity = multiplayer_projected_logical[display_side] != projected;
\t\tif(logical < multiplayer_private_piles.size()
\t\t\t\t&& multiplayer_private_piles_valid[logical]) {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tmultiplayer_private_piles[logical], clear_transient, reset_identity);
\t\t} else {
\t\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\t\tMultiplayerPrivatePileSnapshot{}, clear_transient, reset_identity);
\t\t}
\t\tmultiplayer_projected_logical[display_side] = projected;
\t\tclear_transient = false;
\t}
'''
replace_once(field, old_3v1, new_3v1)

print("Applied logical projection tracking: stable identity within one player, clean reset only when displayed logical player changes")
