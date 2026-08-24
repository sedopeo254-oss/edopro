from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one patch site, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# ---------------------------------------------------------------------------
# Core: keep a Deck Master's logical duelist when it leaves a logical/private
# location for an on-field slot. This fixes P2 -> P3 ownership without changing
# current_duelist / replay camera focus.
# ---------------------------------------------------------------------------
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
\t// Multiplayer logical ownership is independent from the field currently
\t// projected by the client. Preserve the card's own duelist when it enters
\t// an on-field zone; never switch current_duelist just to Summon a Deck Master.
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
new_add_card = '''\t// The encoded zone and the card state must agree on the same logical owner.
\tadd_card(playerid, pcard, location, sequence, pzone, target_duelist);
\treturn true;
}
void field::swap_card(card* pcard1, card* pcard2, uint8_t new_sequence1, uint8_t new_sequence2) {
'''
replace_once(field, old_add_card, new_add_card)


# ---------------------------------------------------------------------------
# ClientField: authoritative private-pile snapshots are persistent per logical
# player. Never recapture over them, never rebuild an identical hand, and use
# SetCode() when restoring cards so images/textures are refreshed correctly.
# ---------------------------------------------------------------------------
client_field = ROOT / "gframe" / "client_field.cpp"
old_replace = '''void ClientField::ReplaceMultiplayerPrivatePiles(uint8_t player,
\t\tconst MultiplayerPrivatePileSnapshot& snapshot, bool clear_transient) {
\tif(player > 1)
\t\treturn;
\tif(clear_transient) {
'''
new_replace = '''void ClientField::ReplaceMultiplayerPrivatePiles(uint8_t player,
\t\tconst MultiplayerPrivatePileSnapshot& snapshot, bool clear_transient) {
\tif(player > 1)
\t\treturn;
\t// Repeated snapshots are common in streamed 3v1 replays. Rebuilding an
\t// identical hand destroys card objects, clears chain pointers and makes the
\t// hand flicker. Treat identical authoritative state as a true no-op.
\tauto same_cards = [](const auto& pile, const auto& cards) {
\t\tif(pile.size() != cards.size())
\t\t\treturn false;
\t\tfor(size_t i = 0; i < pile.size(); ++i) {
\t\t\tconst auto* pcard = pile[i];
\t\t\tif(!pcard || pcard->code != cards[i].code
\t\t\t\t\t|| static_cast<uint8_t>(pcard->position) != cards[i].position)
\t\t\t\treturn false;
\t\t}
\t\treturn true;
\t};
\tconst auto visible_top = deck[player].empty() || !deck[player].back()
\t\t? 0u : deck[player].back()->code;
\tconst bool top_matches = snapshot.top_code == 0 || visible_top == snapshot.top_code;
\tconst auto wanted_extra_p = static_cast<int>(std::min<size_t>(
\t\tsnapshot.extra_p_count, snapshot.extra.size()));
\tconst bool same_snapshot = deck[player].size() == snapshot.deck_count
\t\t&& top_matches
\t\t&& extra_p_count[player] == wanted_extra_p
\t\t&& same_cards(hand[player], snapshot.hand)
\t\t&& same_cards(extra[player], snapshot.extra)
\t\t&& same_cards(grave[player], snapshot.grave)
\t\t&& same_cards(remove[player], snapshot.removed);
\tif(same_snapshot)
\t\treturn;
\tif(clear_transient) {
'''
replace_once(client_field, old_replace, new_replace)

old_apply_visible = '''\tauto apply_visible_cards = [](auto& pile, const auto& cards) {
\t\tfor(size_t i = 0; i < pile.size() && i < cards.size(); ++i) {
\t\t\tpile[i]->code = cards[i].code;
\t\t\tpile[i]->position = cards[i].position;
\t\t}
\t};
'''
new_apply_visible = '''\tauto apply_visible_cards = [](auto& pile, const auto& cards) {
\t\tfor(size_t i = 0; i < pile.size() && i < cards.size(); ++i) {
\t\t\tif(pile[i]->code != cards[i].code)
\t\t\t\tpile[i]->SetCode(cards[i].code);
\t\t\tpile[i]->position = cards[i].position;
\t\t\t// Grave/Banished/face-up Extra cards are public. Restoring this bit
\t\t\t// prevents a valid code from still rendering with the old card back.
\t\t\tpile[i]->is_public = (cards[i].position & POS_FACEUP)
\t\t\t\t&& pile[i]->location != LOCATION_HAND;
\t\t}
\t};
'''
replace_once(client_field, old_apply_visible, new_apply_visible)

old_top = '''\tif(!deck[player].empty())
\t\tdeck[player].back()->code = snapshot.top_code;
'''
new_top = '''\tif(!deck[player].empty() && deck[player].back()->code != snapshot.top_code)
\t\tdeck[player].back()->SetCode(snapshot.top_code);
'''
replace_once(client_field, old_top, new_top)

old_capture = '''\tfor(uint8_t display_side = 0; display_side < 2; ++display_side) {
\t\tconst auto core_side = mainGame->LocalPlayer(display_side);
\t\tconst auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
\t\tif(logical >= multiplayer_private_piles.size())
\t\t\tcontinue;
\t\tMultiplayerPrivatePileSnapshot snapshot;
'''
new_capture = '''\tfor(uint8_t display_side = 0; display_side < 2; ++display_side) {
\t\tconst auto core_side = mainGame->LocalPlayer(display_side);
\t\tconst auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
\t\tif(logical >= multiplayer_private_piles.size())
\t\t\tcontinue;
\t\t// Once the replay supplied authoritative logical state, never overwrite
\t\t// it with whichever teammate happens to be projected on screen.
\t\tif(multiplayer_private_piles_valid[logical])
\t\t\tcontinue;
\t\tMultiplayerPrivatePileSnapshot snapshot;
'''
replace_once(client_field, old_capture, new_capture)

old_apply = '''void ClientField::ApplyThreeVsOneReplayPrivatePiles() {
\tif(!mainGame->dInfo.isReplay
\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
\t\treturn;
\tbool clear_transient = true;
'''
new_apply = '''void ClientField::ApplyThreeVsOneReplayPrivatePiles() {
\tif(!mainGame->dInfo.isReplay
\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
\t\treturn;
\t// A replay camera change must never cancel/clear the chain or its selected
\t// target. Only the visual private piles change here.
\tbool clear_transient = false;
'''
replace_once(client_field, old_apply, new_apply)


# ---------------------------------------------------------------------------
# DuelClient replay camera + logical draw routing.
# ---------------------------------------------------------------------------
duelclient = ROOT / "gframe" / "duelclient.cpp"

# Add a no-animation incremental draw path for the exact logical player that is
# currently displayed. The cache is updated first, then this only adjusts the
# visible Deck/Hand if that logical player is actually on screen.
anchor = '''\tauto SetBattleRoyaleReplayView = [&](uint8_t perspective,
'''
helper = '''\tauto ApplyThreeVsOneReplayDraw = [&](uint8_t logical_player,
\t\t\tconst std::vector<MultiplayerPrivatePileCard>& drawn_cards) {
\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| logical_player >= mainGame->dInfo.team1 + mainGame->dInfo.team2
\t\t\t\t|| !mainGame->dField.IsThreeVsOneReplayPrivatePileDisplayed(logical_player)
\t\t\t\t|| logical_player >= mainGame->dField.multiplayer_private_piles.size()
\t\t\t\t|| !mainGame->dField.multiplayer_private_piles_valid[logical_player])
\t\t\treturn false;
\t\tconst auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);
\t\tconst auto display_side = mainGame->LocalPlayer(core_side);
\t\tif(display_side > 1)
\t\t\treturn false;
\t\tauto& snapshot = mainGame->dField.multiplayer_private_piles[logical_player];
\t\tauto& deck = mainGame->dField.deck[display_side];
\t\tauto& hand = mainGame->dField.hand[display_side];
\t\tconst auto old_hand_count = snapshot.hand.size() >= drawn_cards.size()
\t\t\t? snapshot.hand.size() - drawn_cards.size() : 0;
\t\tbool visible_state_matches = hand.size() == old_hand_count
\t\t\t&& deck.size() >= drawn_cards.size();
\t\tif(visible_state_matches) {
\t\t\tfor(size_t i = 0; i < old_hand_count; ++i) {
\t\t\t\tif(!hand[i] || hand[i]->code != snapshot.hand[i].code) {
\t\t\t\t\tvisible_state_matches = false;
\t\t\t\t\tbreak;
\t\t\t\t}
\t\t\t}
\t\t}
\t\tif(!visible_state_matches) {
\t\t\t// One deterministic repair is better than animating several wrong
\t\t\t// intermediate hands. This uses the already-updated authoritative cache.
\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\t\treturn true;
\t\t}
\t\tfor(const auto& drawn : drawn_cards) {
\t\t\tauto* pcard = deck.back();
\t\t\tdeck.pop_back();
\t\t\tif(pcard->code != drawn.code)
\t\t\t\tpcard->SetCode(drawn.code);
\t\t\tpcard->position = drawn.position;
\t\t\tmainGame->dField.AddCard(pcard, display_side, LOCATION_HAND, 0);
\t\t}
\t\tif(!deck.empty() && deck.back()->code != snapshot.top_code)
\t\t\tdeck.back()->SetCode(snapshot.top_code);
\t\tfor(auto* pcard : hand)
\t\t\tif(pcard)
\t\t\t\tpcard->UpdateDrawCoordinates(true);
\t\tmainGame->should_refresh_hands = true;
\t\treturn true;
\t};

'''
replace_once(duelclient, anchor, helper + anchor)

old_view = '''\tauto SetThreeVsOneView = [&](uint8_t perspective,
\t\t\tuint8_t opponent = 0xff) {
\t\tif(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| mainGame->dInfo.team1 == 0
\t\t\t\t|| mainGame->dInfo.team2 == 0)
\t\t\treturn false;
\t\tif(mainGame->dInfo.isReplay)
\t\t\tmainGame->dField.CaptureThreeVsOneReplayPrivatePiles();
\t\tuint8_t allied_logical = 0xff;
\t\tfor(const auto logical : { perspective, opponent,
\t\t\t\tmainGame->dInfo.logical_turn_player }) {
\t\t\tif(logical < mainGame->dInfo.team1
\t\t\t\t\t&& (mainGame->dInfo.active_player_mask & (1u << logical))) {
\t\t\t\tallied_logical = logical;
\t\t\t\tbreak;
\t\t\t}
\t\t}
\t\tif(allied_logical >= mainGame->dInfo.team1) {
\t\t\tfor(uint8_t logical = 0; logical < mainGame->dInfo.team1; ++logical) {
\t\t\t\tif(mainGame->dInfo.active_player_mask & (1u << logical)) {
\t\t\t\t\tallied_logical = logical;
\t\t\t\t\tbreak;
\t\t\t\t}
\t\t\t}
\t\t}
\t\tif(allied_logical >= mainGame->dInfo.team1)
\t\t\treturn false;
\t\tconst auto allied_duelist =
\t\t\tmainGame->dInfo.GetLogicalDuelist(allied_logical);
\t\tconst bool changed = mainGame->dInfo.field_focus[0] != allied_duelist
\t\t\t|| mainGame->dInfo.field_focus[1] != 0;
\t\tmainGame->dInfo.SetFieldFocus(0, allied_duelist);
\t\tmainGame->dInfo.SetFieldFocus(1, 0);
\t\tif(mainGame->dInfo.isReplay)
\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\tif(changed)
\t\t\tmainGame->dField.RefreshAllCards();
\t\treturn changed;
\t};
'''
new_view = '''\tauto SetThreeVsOneView = [&](uint8_t perspective,
\t\t\tuint8_t opponent = 0xff) {
\t\tif(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| mainGame->dInfo.team1 == 0
\t\t\t\t|| mainGame->dInfo.team2 == 0)
\t\t\treturn false;
\t\tuint8_t allied_logical = 0xff;
\t\tfor(const auto logical : { perspective, opponent,
\t\t\t\tmainGame->dInfo.logical_turn_player }) {
\t\t\tif(logical < mainGame->dInfo.team1
\t\t\t\t\t&& (mainGame->dInfo.active_player_mask & (1u << logical))) {
\t\t\t\tallied_logical = logical;
\t\t\t\tbreak;
\t\t\t}
\t\t}
\t\tif(allied_logical >= mainGame->dInfo.team1) {
\t\t\tfor(uint8_t logical = 0; logical < mainGame->dInfo.team1; ++logical) {
\t\t\t\tif(mainGame->dInfo.active_player_mask & (1u << logical)) {
\t\t\t\t\tallied_logical = logical;
\t\t\t\t\tbreak;
\t\t\t\t}
\t\t\t}
\t\t}
\t\tif(allied_logical >= mainGame->dInfo.team1)
\t\t\treturn false;
\t\tconst auto allied_duelist = mainGame->dInfo.GetLogicalDuelist(allied_logical);
\t\tconst bool changed = mainGame->dInfo.field_focus[0] != allied_duelist
\t\t\t|| mainGame->dInfo.field_focus[1] != 0;
\t\tif(!changed)
\t\t\treturn false;
\t\tif(mainGame->dInfo.isReplay)
\t\t\tmainGame->dField.CaptureThreeVsOneReplayPrivatePiles();
\t\tmainGame->dInfo.SetFieldFocus(0, allied_duelist);
\t\tmainGame->dInfo.SetFieldFocus(1, 0);
\t\tif(mainGame->dInfo.isReplay)
\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\tmainGame->dField.RefreshAllCards();
\t\treturn true;
\t};
'''
replace_once(duelclient, old_view, new_view)

# Legacy TAG_SWAP is metadata only in streamed 3v1 replay; the authoritative
# per-logical snapshots already carry exact hands/decks/graves.
old_tag_anchor = '''\t\tconst auto logical_core_side = logical_player < player_count
\t\t\t? mainGame->dInfo.GetLogicalCoreSide(logical_player) : core_player;
'''
new_tag_anchor = '''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
\t\t\t// Never replay TAG_SWAP's destructive hand animation. The logical
\t\t\t// player is already represented by MSG_MULTIPLAYER_PRIVATE_PILES.
\t\t\treturn true;
\t\t}
\t\tconst auto logical_core_side = logical_player < player_count
\t\t\t? mainGame->dInfo.GetLogicalCoreSide(logical_player) : core_player;
'''
replace_once(duelclient, old_tag_anchor, new_tag_anchor)

# Cross-teammate targets must visibly focus the selected player's field even if
# the chain is later negated.
old_target = '''\t\tfor(uint32_t i = 0; i < count; ++i) {
\t\t\tCoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
\t\t\tif(!MapLocationDisplay(info))
\t\t\t\tcontinue;
'''
new_target = '''\t\tfor(uint32_t i = 0; i < count; ++i) {
\t\t\tCoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
\t\t\tconst auto target_core_player = info.controler;
\t\t\tif(mainGame->dInfo.curMsg == MSG_BECOME_TARGET
\t\t\t\t\t&& mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t\t&& target_core_player < 2
\t\t\t\t\t&& (info.location & LOCATION_ONFIELD)) {
\t\t\t\tconst auto target_logical = mainGame->dInfo.GetLogicalPlayer(
\t\t\t\t\ttarget_core_player, info.duelist);
\t\t\t\tif(target_logical < mainGame->dInfo.team1 + mainGame->dInfo.team2)
\t\t\t\t\tSetThreeVsOneView(target_logical);
\t\t\t}
\t\t\tif(!MapLocationDisplay(info))
\t\t\t\tcontinue;
'''
replace_once(duelclient, old_target, new_target)

# Standard MSG_DRAW has only the physical core side. In 3v1 the authoritative
# logical owner is dInfo.logical_active[core_side]. If a different teammate is
# currently displayed, update only that logical player's cache and never touch
# the visible teammate's Hand. This is the Card of Sanctity corruption fix.
old_draw_anchor = '''\t\tconst auto count = CompatRead<uint8_t, uint32_t>(pbuf);
\t\tconst bool hidden_battle_royale_pile =
'''
new_draw_anchor = '''\t\tconst auto count = CompatRead<uint8_t, uint32_t>(pbuf);
\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t&& logical_player < mainGame->dField.multiplayer_private_piles.size()
\t\t\t\t&& mainGame->dField.multiplayer_private_piles_valid[logical_player]) {
\t\t\tstd::vector<MultiplayerPrivatePileCard> drawn_cards;
\t\t\tdrawn_cards.reserve(count);
\t\t\tfor(uint32_t i = 0; i < count; ++i) {
\t\t\t\tauto code = BufferIO::Read<uint32_t>(pbuf);
\t\t\t\tuint8_t position = POS_FACEDOWN_DEFENSE;
\t\t\t\tif(!mainGame->dInfo.compat_mode)
\t\t\t\t\tposition = static_cast<uint8_t>(BufferIO::Read<uint32_t>(pbuf));
\t\t\t\telse {
\t\t\t\t\tposition = code & 0x80000000 ? POS_FACEUP : POS_FACEDOWN;
\t\t\t\t\tcode &= 0x7fffffff;
\t\t\t\t}
\t\t\t\tdrawn_cards.push_back({ code, position });
\t\t\t}
\t\t\tauto& deck_count = mainGame->dInfo.logical_deck_count[logical_player];
\t\t\tdeck_count = deck_count > count ? deck_count - count : 0;
\t\t\tmainGame->dInfo.logical_hand_count[logical_player] += count;
\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
\t\t\tApplyThreeVsOneReplayDraw(logical_player, drawn_cards);
\t\t\tfor(uint32_t i = 0; i < count; ++i)
\t\t\t\tPlay(SoundManager::SFX::DRAW);
\t\t\treturn true;
\t\t}
\t\tconst bool hidden_battle_royale_pile =
'''
replace_once(duelclient, old_draw_anchor, new_draw_anchor)

old_mdraw = '''\t\tif(mainGame->dInfo.isReplay) {
\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(
\t\t\t\tlogical_player, drawn_cards);
\t\t\tif(mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2)
\t\t\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePiles();
\t\t\telse if(mainGame->dField.IsThreeVsOneReplayPrivatePileDisplayed(
\t\t\t\t\tlogical_player))
\t\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\t}
'''
new_mdraw = '''\t\tif(mainGame->dInfo.isReplay) {
\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
\t\t\t\tApplyThreeVsOneReplayDraw(logical_player, drawn_cards);
\t\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t\t&& mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2) {
\t\t\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePiles();
\t\t\t}
\t\t}
'''
replace_once(duelclient, old_mdraw, new_mdraw)

old_private_apply = '''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
\t\t\tmainGame->dField.CacheMultiplayerPrivatePiles(
\t\t\t\tlogical_player, snapshot);
\t\t\tif(mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2)
\t\t\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePiles();
\t\t\telse if(mainGame->dField.IsThreeVsOneReplayPrivatePileDisplayed(
\t\t\t\t\tlogical_player))
\t\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\t} else if(logical_player == mainGame->dInfo.GetLocalLogicalPlayer()) {
'''
new_private_apply = '''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
\t\t\tmainGame->dField.CacheMultiplayerPrivatePiles(logical_player, snapshot);
\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
\t\t\t\tif(mainGame->dField.IsThreeVsOneReplayPrivatePileDisplayed(logical_player))
\t\t\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t\t&& mainGame->dInfo.GetBattleRoyaleDisplaySide(logical_player) < 2) {
\t\t\t\tmainGame->dField.ApplyBattleRoyaleReplayPrivatePiles();
\t\t\t}
\t\t} else if(logical_player == mainGame->dInfo.GetLocalLogicalPlayer()) {
'''
replace_once(duelclient, old_private_apply, new_private_apply)

# Normal Summon overlay: retain the visual, but make 3v1 replay presentation
# short and non-blocking instead of pausing ~41 frames per Summon.
old_normal_wait = '''\t\t\tmainGame->showcard = 7;
\t\t\tmainGame->WaitFrameSignal(30, lock);
\t\t\tmainGame->showcard = 0;
\t\t\tmainGame->WaitFrameSignal(11, lock);
'''
new_normal_wait = '''\t\t\tmainGame->showcard = 7;
\t\t\tconst bool smooth_three_vs_one_replay = mainGame->dInfo.isReplay
\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1);
\t\t\tmainGame->WaitFrameSignal(smooth_three_vs_one_replay ? 10 : 30, lock);
\t\t\tmainGame->showcard = 0;
\t\t\tmainGame->WaitFrameSignal(smooth_three_vs_one_replay ? 2 : 11, lock);
'''
replace_once(duelclient, old_normal_wait, new_normal_wait)

# Special Summon: bind the actual on-field card code (Deck Masters included),
# mark it public and use the same short replay timing.
old_sp = '''\tcase MSG_SPSUMMONING: {
\t\tconst auto code = BufferIO::Read<uint32_t>(pbuf);
\t\t/*CoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);*/
\t\tif(!code || !PlayChant(SoundManager::CHANT::SUMMON, code))
\t\t\tPlay(SoundManager::SFX::SPECIAL_SUMMON);
\t\tif(!mainGame->dInfo.isCatchingUp) {
\t\t\tstd::unique_lock<epro::mutex> lock(mainGame->gMutex);
\t\t\tevent_string = epro::sprintf(gDataManager->GetSysString(1605), gDataManager->GetName(code));
\t\t\tif(code) {
\t\t\t\tmainGame->showcardcode = code;
\t\t\t\tmainGame->showcarddif = 1;
\t\t\t\tmainGame->showcard = 5;
\t\t\t\tmainGame->WaitFrameSignal(30, lock);
\t\t\t\tmainGame->showcard = 0;
\t\t\t\tmainGame->WaitFrameSignal(11, lock);
\t\t\t}
\t\t}
\t\treturn true;
\t}
'''
new_sp = '''\tcase MSG_SPSUMMONING: {
\t\tconst auto code = BufferIO::Read<uint32_t>(pbuf);
\t\tCoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
\t\tif(MapLocationDisplay(info)) {
\t\t\tif(auto* pcard = mainGame->dField.GetCard(info.controler, info.location,
\t\t\t\t\tinfo.sequence, info.position); pcard) {
\t\t\t\tif(code && pcard->code != code)
\t\t\t\t\tpcard->SetCode(code);
\t\t\t\tpcard->position = info.position;
\t\t\t\tpcard->is_public = true;
\t\t\t\tpcard->UpdateDrawCoordinates(true);
\t\t\t}
\t\t}
\t\tif(!code || !PlayChant(SoundManager::CHANT::SUMMON, code))
\t\t\tPlay(SoundManager::SFX::SPECIAL_SUMMON);
\t\tif(!mainGame->dInfo.isCatchingUp) {
\t\t\tstd::unique_lock<epro::mutex> lock(mainGame->gMutex);
\t\t\tevent_string = epro::sprintf(gDataManager->GetSysString(1605), gDataManager->GetName(code));
\t\t\tif(code) {
\t\t\t\tmainGame->showcardcode = code;
\t\t\t\tmainGame->showcarddif = 1;
\t\t\t\tmainGame->showcard = 5;
\t\t\t\tconst bool smooth_three_vs_one_replay = mainGame->dInfo.isReplay
\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1);
\t\t\t\tmainGame->WaitFrameSignal(smooth_three_vs_one_replay ? 10 : 30, lock);
\t\t\t\tmainGame->showcard = 0;
\t\t\t\tmainGame->WaitFrameSignal(smooth_three_vs_one_replay ? 2 : 11, lock);
\t\t\t}
\t\t}
\t\treturn true;
\t}
'''
replace_once(duelclient, old_sp, new_sp)

# Old replays may contain ConfirmCards packets for an already face-up Deck
# Master. They are redundant and each one used to stall replay for ~40 frames.
old_confirm_anchor = '''\t\tif (field_confirm.size() > 0) {
'''
new_confirm_anchor = '''\t\tif(mainGame->dInfo.isReplay && mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
\t\t\tfield_confirm.erase(std::remove_if(field_confirm.begin(), field_confirm.end(),
\t\t\t\t[](const auto* pcard) {
\t\t\t\t\treturn pcard && (pcard->location & LOCATION_ONFIELD)
\t\t\t\t\t\t&& (pcard->position & POS_FACEUP);
\t\t\t\t}), field_confirm.end());
\t\t}
\t\tif (field_confirm.size() > 0) {
'''
replace_once(duelclient, old_confirm_anchor, new_confirm_anchor)


# ---------------------------------------------------------------------------
# Super Roboyarou no longer needs explicit ConfirmCards: MSG_MOVE and
# MSG_SPSUMMONING now make the face-up Deck Master public. Removing these two
# packets also removes a large pause from existing/new replays.
# ---------------------------------------------------------------------------
super_script = ROOT / "multiplayer-deck-master" / "c153000012.lua"
old_confirm = '''\t--A Deck Master is public after being Summoned. Explicit confirmation also
\t--repairs clients that first knew this card only as a hidden private-pile card.
\tDuel.ConfirmCards(0,c)
\tDuel.ConfirmCards(1,c)
\treturn c,logical,side
'''
new_confirm = '''\t--The face-up Deck Master is public through MSG_MOVE/MSG_SPSUMMONING.
\t--Do not emit redundant ConfirmCards packets: in replay they add two long
\t--confirmation waits and can race with logical private-pile projection.
\treturn c,logical,side
'''
replace_once(super_script, old_confirm, new_confirm)

print("Applied deterministic 3v1 replay v2: logical draws, smooth summons, stable private piles and Deck Master images")
