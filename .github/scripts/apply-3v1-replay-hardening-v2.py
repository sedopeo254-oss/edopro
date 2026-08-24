from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one patch site, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


client_field = ROOT / "gframe" / "client_field.cpp"

# Keep ClientCard identity stable when an authoritative replay snapshot changes.
# Only cards actually removed from a private pile are detached/deleted. Existing
# hand/GY/Extra cards stay alive so chain targets, textures and hover state do
# not get destroyed every time one card is drawn or moved.
old_match = '''\tauto match_pile = [&detach_card, &reset_card](auto& pile, size_t count, uint8_t location) {
\t\twhile(pile.size() > count) {
\t\t\tauto* pcard = pile.back();
\t\t\tdetach_card(pcard);
\t\t\tdelete pcard;
\t\t\tpile.pop_back();
\t\t}
\t\twhile(pile.size() < count)
\t\t\tpile.push_back(new ClientCard{});
\t\tfor(size_t sequence = 0; sequence < pile.size(); ++sequence) {
\t\t\tdetach_card(pile[sequence]);
\t\t\treset_card(pile[sequence], location, static_cast<uint32_t>(sequence));
\t\t}
\t};
\tauto apply_visible_cards = [](auto& pile, const auto& cards) {
\t\tfor(size_t i = 0; i < pile.size() && i < cards.size(); ++i) {
\t\t\tpile[i]->code = cards[i].code;
\t\t\tpile[i]->position = cards[i].position;
\t\t}
\t};
'''
new_match = '''\tauto match_pile = [player, &detach_card, &reset_card](auto& pile, size_t count, uint8_t location) {
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
\tauto apply_visible_cards = [](auto& pile, const auto& cards) {
\t\tfor(size_t i = 0; i < pile.size() && i < cards.size(); ++i) {
\t\t\tif(pile[i]->code != cards[i].code)
\t\t\t\tpile[i]->SetCode(cards[i].code);
\t\t\tpile[i]->position = cards[i].position;
\t\t}
\t};
'''
replace_once(client_field, old_match, new_match)

# Resetting/reusing a private-pile placeholder must also invalidate its cached
# card texture/data. Directly assigning code=0 leaves stale card art behind.
old_reset_code = '''\t\tpcard->position = POS_FACEDOWN_DEFENSE;
\t\tpcard->code = 0;
\t\tpcard->cover = 0;
'''
new_reset_code = '''\t\tpcard->position = POS_FACEDOWN_DEFENSE;
\t\tif(pcard->code)
\t\t\tpcard->SetCode(0);
\t\tpcard->cover = 0;
'''
replace_once(client_field, old_reset_code, new_reset_code)

# The visible top card and all public replay cards must use SetCode(), otherwise
# a card such as Super Roboyarou can have the correct numeric code but no image.
old_top = '''\tif(!deck[player].empty())
\t\tdeck[player].back()->code = snapshot.top_code;
\tapply_visible_cards(hand[player], snapshot.hand);
'''
new_top = '''\tif(!deck[player].empty() && deck[player].back()->code != snapshot.top_code)
\t\tdeck[player].back()->SetCode(snapshot.top_code);
\tapply_visible_cards(hand[player], snapshot.hand);
'''
replace_once(client_field, old_top, new_top)

# Updating one private pile must not refresh every monster/spell on the duel
# field. Refresh only the private piles whose card coordinates can have changed.
old_refresh = '''\tapply_visible_cards(extra[player], snapshot.extra);
\tapply_visible_cards(grave[player], snapshot.grave);
\tapply_visible_cards(remove[player], snapshot.removed);
\tRefreshAllCards();
}
void ClientField::CacheMultiplayerPrivatePiles'''
new_refresh = '''\tapply_visible_cards(extra[player], snapshot.extra);
\tapply_visible_cards(grave[player], snapshot.grave);
\tapply_visible_cards(remove[player], snapshot.removed);
\tauto refresh_private = [](auto& pile) {
\t\tfor(auto* pcard : pile) {
\t\t\tif(!pcard)
\t\t\t\tcontinue;
\t\t\tpcard->UpdateDrawCoordinates(true);
\t\t\tpcard->is_moving = false;
\t\t\tpcard->refresh_on_stop = false;
\t\t\tpcard->aniFrame = 0;
\t\t}
\t};
\trefresh_private(deck[player]);
\trefresh_private(hand[player]);
\trefresh_private(extra[player]);
\trefresh_private(grave[player]);
\trefresh_private(remove[player]);
\tRefreshHandHitboxes();
\tmainGame->should_refresh_hands = true;
}
void ClientField::CacheMultiplayerPrivatePiles'''
replace_once(client_field, old_refresh, new_refresh)


duelclient = ROOT / "gframe" / "duelclient.cpp"

# Standard MSG_DRAW is emitted for whichever logical duelist is currently active
# on a core side. During Card of Sanctity the replay may deliberately be showing
# another teammate. Never put the active duelist's cards directly into the
# displayed teammate's physical hand; update the logical cache first and only
# project it when that exact logical player is on screen.
old_draw_head = '''\tcase MSG_DRAW: {
\t\tconst auto core_player = BufferIO::Read<uint8_t>(pbuf);
\t\tconst auto logical_player = mainGame->dInfo.GetLogicalPlayer(core_player);
\t\tconst auto private_display = GetActivePrivateDisplaySide(core_player);
\t\tconst auto player = private_display < 2
\t\t\t? private_display : mainGame->LocalPlayer(core_player);
\t\tconst auto count = CompatRead<uint8_t, uint32_t>(pbuf);
\t\tconst bool hidden_battle_royale_pile =
'''
new_draw_head = '''\tcase MSG_DRAW: {
\t\tconst auto core_player = BufferIO::Read<uint8_t>(pbuf);
\t\tconst auto logical_player = mainGame->dInfo.GetLogicalPlayer(core_player);
\t\tconst auto private_display = GetActivePrivateDisplaySide(core_player);
\t\tconst auto player = private_display < 2
\t\t\t? private_display : mainGame->LocalPlayer(core_player);
\t\tconst auto count = CompatRead<uint8_t, uint32_t>(pbuf);
\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t&& logical_player < mainGame->dField.multiplayer_private_piles_valid.size()
\t\t\t\t&& mainGame->dField.multiplayer_private_piles_valid[logical_player]) {
\t\t\tstd::vector<MultiplayerPrivatePileCard> drawn_cards;
\t\t\tdrawn_cards.reserve(count);
\t\t\tfor(uint32_t i = 0; i < count; ++i) {
\t\t\t\tauto code = BufferIO::Read<uint32_t>(pbuf);
\t\t\t\tuint32_t position = POS_FACEDOWN_DEFENSE;
\t\t\t\tif(!mainGame->dInfo.compat_mode)
\t\t\t\t\tposition = BufferIO::Read<uint32_t>(pbuf);
\t\t\t\telse {
\t\t\t\t\tposition = code & 0x80000000 ? POS_FACEUP : POS_FACEDOWN;
\t\t\t\t\tcode &= 0x7fffffff;
\t\t\t\t}
\t\t\t\tdrawn_cards.push_back({ code, static_cast<uint8_t>(position) });
\t\t\t}
\t\t\tauto& deck_count = mainGame->dInfo.logical_deck_count[logical_player];
\t\t\tdeck_count = deck_count > count ? deck_count - count : 0;
\t\t\tmainGame->dInfo.logical_hand_count[logical_player] += count;
\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
\t\t\tif(mainGame->dField.IsThreeVsOneReplayPrivatePileDisplayed(logical_player))
\t\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\t\tfor(uint32_t i = 0; i < count; ++i)
\t\t\t\tPlay(SoundManager::SFX::DRAW);
\t\t\treturn true;
\t\t}
\t\tconst bool hidden_battle_royale_pile =
'''
replace_once(duelclient, old_draw_head, new_draw_head)

# When a Deck Master is Special Summoned face-up, make it explicitly public.
# This complements SetCode() and prevents a hidden/private-pile rendering flag
# from surviving after the card has entered the monster zone.
old_sp_public = '''\t\t\t\tif(code && pcard->code != code)
\t\t\t\t\tpcard->SetCode(code);
\t\t\t\tpcard->position = info.position;
\t\t\t\tpcard->UpdateDrawCoordinates(true);
'''
new_sp_public = '''\t\t\t\tif(code && pcard->code != code)
\t\t\t\t\tpcard->SetCode(code);
\t\t\t\tpcard->position = info.position;
\t\t\t\tpcard->is_public = true;
\t\t\t\tpcard->UpdateDrawCoordinates(true);
'''
replace_once(duelclient, old_sp_public, new_sp_public)

print("Applied 3v1 replay hardening v2: logical draws, stable card identity, SetCode images and lightweight pile refresh")
