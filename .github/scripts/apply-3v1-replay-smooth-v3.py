from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one patch site, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")

client_field = ROOT / "gframe" / "client_field.cpp"
duelclient = ROOT / "gframe" / "duelclient.cpp"

# Pin Deck/Hand/Extra to logical_active. A temporary attack/effect camera focus
# must never replace the team's displayed private hand during the opponent turn.
old_capture = '''\tfor(uint8_t display_side = 0; display_side < 2; ++display_side) {
\t\tconst auto core_side = mainGame->LocalPlayer(display_side);
\t\tconst auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
\t\tif(logical >= multiplayer_private_piles.size())
\t\t\tcontinue;
\t\t// Once the replay supplied authoritative logical state, never overwrite
'''
new_capture = '''\tfor(uint8_t display_side = 0; display_side < 2; ++display_side) {
\t\tconst auto core_side = mainGame->LocalPlayer(display_side);
\t\tconst auto logical = mainGame->dInfo.GetLogicalPlayer(core_side);
\t\tif(logical >= multiplayer_private_piles.size())
\t\t\tcontinue;
\t\t// Once the replay supplied authoritative logical state, never overwrite
'''
replace_once(client_field, old_capture, new_capture)

old_is_displayed = '''bool ClientField::IsThreeVsOneReplayPrivatePileDisplayed(
\t\tuint8_t logical_player) const {
\tif(!mainGame->dInfo.isReplay
\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t|| logical_player >= mainGame->dInfo.team1 + mainGame->dInfo.team2)
\t\treturn false;
\tfor(uint8_t core_side = 0; core_side < 2; ++core_side) {
\t\tif(mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player)
\t\t\treturn true;
\t}
\treturn false;
}
'''
new_is_displayed = '''bool ClientField::IsThreeVsOneReplayPrivatePileDisplayed(
\t\tuint8_t logical_player) const {
\tif(!mainGame->dInfo.isReplay
\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t|| logical_player >= mainGame->dInfo.team1 + mainGame->dInfo.team2)
\t\treturn false;
\tfor(uint8_t core_side = 0; core_side < 2; ++core_side) {
\t\tif(mainGame->dInfo.GetLogicalPlayer(core_side) == logical_player
\t\t\t\t|| mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player)
\t\t\treturn true;
\t}
\treturn false;
}
'''
replace_once(client_field, old_is_displayed, new_is_displayed)

# Compose the displayed private zones: Deck/Hand/Extra remain pinned to the
# side's active logical seat, while Grave/Banish follow the public field focus.
old_apply_loop = '''\t// A replay camera change must never cancel/clear the chain or its selected
\t// target. Only the visual private piles change here.
\tbool clear_transient = false;
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
new_apply_loop = '''\t// A replay camera change must never cancel/clear the chain or its selected
\t// target. Deck/Hand/Extra stay pinned; only public Grave/Banish follow focus.
\tbool clear_transient = false;
\tfor(uint8_t core_side = 0; core_side < 2; ++core_side) {
\t\tconst auto display_side = mainGame->LocalPlayer(core_side);
\t\tif(display_side > 1)
\t\t\tcontinue;
\t\tconst auto private_logical = mainGame->dInfo.GetLogicalPlayer(core_side);
\t\tconst auto field_logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
\t\tMultiplayerPrivatePileSnapshot composed;
\t\tbool have_snapshot = false;
\t\tif(private_logical < multiplayer_private_piles.size()
\t\t\t\t&& multiplayer_private_piles_valid[private_logical]) {
\t\t\tcomposed = multiplayer_private_piles[private_logical];
\t\t\thave_snapshot = true;
\t\t}
\t\tif(field_logical < multiplayer_private_piles.size()
\t\t\t\t&& multiplayer_private_piles_valid[field_logical]) {
\t\t\tcomposed.grave = multiplayer_private_piles[field_logical].grave;
\t\t\tcomposed.removed = multiplayer_private_piles[field_logical].removed;
\t\t\thave_snapshot = true;
\t\t}
\t\tReplaceMultiplayerPrivatePiles(display_side,
\t\t\thave_snapshot ? composed : MultiplayerPrivatePileSnapshot{}, clear_transient);
\t\tclear_transient = false;
\t}
'''
replace_once(client_field, old_apply_loop, new_apply_loop)

# A temporary field view must not force a private hand switch.
old_view_private_apply = '''\t\tif(mainGame->dInfo.isReplay)
\t\t\tmainGame->dField.CaptureThreeVsOneReplayPrivatePiles();
\t\tmainGame->dInfo.SetFieldFocus(0, allied_duelist);
\t\tmainGame->dInfo.SetFieldFocus(1, 0);
\t\tif(mainGame->dInfo.isReplay)
\t\t\tmainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
\t\tmainGame->dField.RefreshAllCards();
'''
new_view_private_apply = '''\t\tif(mainGame->dInfo.isReplay)
\t\t\tmainGame->dField.CaptureThreeVsOneReplayPrivatePiles();
\t\tmainGame->dInfo.SetFieldFocus(0, allied_duelist);
\t\tmainGame->dInfo.SetFieldFocus(1, 0);
\t\t// Public field focus changed; pinned private hands do not.
\t\tmainGame->dField.RefreshAllCards();
'''
replace_once(duelclient, old_view_private_apply, new_view_private_apply)

# Incremental draw presentation is allowed only for the private logical player
# pinned to that side. Draws for another teammate update its cache silently.
old_draw_guard = '''\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| logical_player >= mainGame->dInfo.team1 + mainGame->dInfo.team2
\t\t\t\t|| !mainGame->dField.IsThreeVsOneReplayPrivatePileDisplayed(logical_player)
\t\t\t\t|| logical_player >= mainGame->dField.multiplayer_private_piles.size()
'''
new_draw_guard = '''\t\tif(!mainGame->dInfo.isReplay
\t\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t|| logical_player >= mainGame->dInfo.team1 + mainGame->dInfo.team2
\t\t\t\t|| logical_player != mainGame->dInfo.GetLogicalPlayer(
\t\t\t\t\tmainGame->dInfo.GetLogicalCoreSide(logical_player))
\t\t\t\t|| logical_player >= mainGame->dField.multiplayer_private_piles.size()
'''
replace_once(duelclient, old_draw_guard, new_draw_guard)

# Never overwrite a logical player's counters from whichever teammate happened
# to be visually focused at a turn transition.
old_outgoing = '''\t\t\tif(outgoing < 4) {
\t\t\t\tmainGame->dInfo.logical_deck_count[outgoing] = static_cast<uint32_t>(mainGame->dField.deck[local_side].size());
\t\t\t\tmainGame->dInfo.logical_hand_count[outgoing] = static_cast<uint32_t>(mainGame->dField.hand[local_side].size());
\t\t\t\tmainGame->dInfo.logical_extra_count[outgoing] = static_cast<uint32_t>(mainGame->dField.extra[local_side].size());
\t\t\t\tmainGame->dInfo.logical_grave_count[outgoing] = static_cast<uint32_t>(mainGame->dField.grave[local_side].size());
\t\t\t\tmainGame->dInfo.logical_banish_count[outgoing] = static_cast<uint32_t>(mainGame->dField.remove[local_side].size());
\t\t\t}
'''
new_outgoing = '''\t\t\tif(outgoing < 4
\t\t\t\t\t&& !(mainGame->dInfo.isReplay
\t\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
\t\t\t\tmainGame->dInfo.logical_deck_count[outgoing] = static_cast<uint32_t>(mainGame->dField.deck[local_side].size());
\t\t\t\tmainGame->dInfo.logical_hand_count[outgoing] = static_cast<uint32_t>(mainGame->dField.hand[local_side].size());
\t\t\t\tmainGame->dInfo.logical_extra_count[outgoing] = static_cast<uint32_t>(mainGame->dField.extra[local_side].size());
\t\t\t\tmainGame->dInfo.logical_grave_count[outgoing] = static_cast<uint32_t>(mainGame->dField.grave[local_side].size());
\t\t\t\tmainGame->dInfo.logical_banish_count[outgoing] = static_cast<uint32_t>(mainGame->dField.remove[local_side].size());
\t\t\t}
'''
replace_once(duelclient, old_outgoing, new_outgoing)

# Deduplicate repeated authoritative snapshots before rebuilding any visible pile.
old_private_cache = '''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
\t\t\tmainGame->dField.CacheMultiplayerPrivatePiles(logical_player, snapshot);
\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
'''
new_private_cache = '''\t\tif(mainGame->dInfo.isReplay
\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {
\t\t\tauto same_snapshot = [](const MultiplayerPrivatePileSnapshot& a,
\t\t\t\t\tconst MultiplayerPrivatePileSnapshot& b) {
\t\t\t\tif(a.deck_count != b.deck_count || a.extra_p_count != b.extra_p_count
\t\t\t\t\t\t|| a.top_code != b.top_code || a.hand.size() != b.hand.size()
\t\t\t\t\t\t|| a.extra.size() != b.extra.size() || a.grave.size() != b.grave.size()
\t\t\t\t\t\t|| a.removed.size() != b.removed.size())
\t\t\t\t\treturn false;
\t\t\t\tauto same_cards = [](const auto& x, const auto& y) {
\t\t\t\t\tfor(size_t i = 0; i < x.size(); ++i)
\t\t\t\t\t\tif(x[i].code != y[i].code || x[i].position != y[i].position)
\t\t\t\t\t\t\treturn false;
\t\t\t\t\treturn true;
\t\t\t\t};
\t\t\t\treturn same_cards(a.hand,b.hand) && same_cards(a.extra,b.extra)
\t\t\t\t\t&& same_cards(a.grave,b.grave) && same_cards(a.removed,b.removed);
\t\t\t};
\t\t\tconst bool duplicate = logical_player < 4
\t\t\t\t&& mainGame->dField.multiplayer_private_piles_valid[logical_player]
\t\t\t\t&& same_snapshot(mainGame->dField.multiplayer_private_piles[logical_player], snapshot);
\t\t\tmainGame->dField.CacheMultiplayerPrivatePiles(logical_player, snapshot);
\t\t\tif(duplicate)
\t\t\t\treturn true;
\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
'''
replace_once(duelclient, old_private_cache, new_private_cache)

# A Deck Master that Special Summons for P2/P3 must immediately bring that
# public field into view. The hand stays pinned by the rules above.
old_sp_info = '''\t\tCoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
\t\tif(MapLocationDisplay(info)) {
'''
new_sp_info = '''\t\tCoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
\t\tif(mainGame->dInfo.isReplay && mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
\t\t\t\t&& info.controler < 2 && (info.location & LOCATION_ONFIELD)) {
\t\t\tconst auto summon_logical = mainGame->dInfo.GetLogicalPlayer(info.controler, info.duelist);
\t\t\tif(summon_logical < mainGame->dInfo.team1 + mainGame->dInfo.team2)
\t\t\t\tSetThreeVsOneView(summon_logical);
\t\t}
\t\tif(MapLocationDisplay(info)) {
'''
replace_once(duelclient, old_sp_info, new_sp_info)

# Keep replay summon presentation short and smooth.
old_timing = '''\t\t\t\tmainGame->WaitFrameSignal(smooth_three_vs_one_replay ? 10 : 30, lock);
\t\t\t\tmainGame->showcard = 0;
\t\t\t\tmainGame->WaitFrameSignal(smooth_three_vs_one_replay ? 2 : 11, lock);
'''
new_timing = '''\t\t\t\tmainGame->WaitFrameSignal(smooth_three_vs_one_replay ? 4 : 30, lock);
\t\t\t\tmainGame->showcard = 0;
\t\t\t\tmainGame->WaitFrameSignal(smooth_three_vs_one_replay ? 1 : 11, lock);
'''
replace_once(duelclient, old_timing, new_timing)

print("Applied 3v1 replay v3: pinned hands, Card of Sanctity isolation, focused Grave/Banish and fast Deck Master Summons")
