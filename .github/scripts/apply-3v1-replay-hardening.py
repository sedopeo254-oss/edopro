from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one patch site, found {count}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


client_field = ROOT / "gframe" / "client_field.cpp"

# 1) Do not destructively rebuild a replay hand/GY/Extra snapshot when the
# visible pile already matches it. Rebuilding identical snapshots used to clear
# transient pointers, refresh every card and make allied hands visibly flicker.
old_replace = '''void ClientField::ReplaceMultiplayerPrivatePiles(uint8_t player,
		const MultiplayerPrivatePileSnapshot& snapshot, bool clear_transient) {
	if(player > 1)
		return;
	if(clear_transient) {
'''
new_replace = '''void ClientField::ReplaceMultiplayerPrivatePiles(uint8_t player,
		const MultiplayerPrivatePileSnapshot& snapshot, bool clear_transient) {
	if(player > 1)
		return;
	// Streamed 3v1 replays can publish the same private-pile snapshot several
	// times around an attack/target event. Never tear down and recreate an
	// already-identical hand/GY/Extra state: it causes visible hand shuffling,
	// clears chain pointers and adds needless refresh work.
	auto same_cards = [](const auto& pile, const auto& cards) {
		if(pile.size() != cards.size())
			return false;
		for(size_t i = 0; i < pile.size(); ++i) {
			const auto* pcard = pile[i];
			if(!pcard || pcard->code != cards[i].code
					|| static_cast<uint8_t>(pcard->position) != cards[i].position)
				return false;
		}
		return true;
	};
	const auto visible_top = deck[player].empty() || !deck[player].back()
		? 0u : deck[player].back()->code;
	const auto wanted_extra_p = static_cast<int>(std::min<size_t>(
		snapshot.extra_p_count, snapshot.extra.size()));
	const bool same_snapshot = deck[player].size() == snapshot.deck_count
		&& visible_top == snapshot.top_code
		&& extra_p_count[player] == wanted_extra_p
		&& same_cards(hand[player], snapshot.hand)
		&& same_cards(extra[player], snapshot.extra)
		&& same_cards(grave[player], snapshot.grave)
		&& same_cards(remove[player], snapshot.removed);
	if(same_snapshot)
		return;
	if(clear_transient) {
'''
replace_once(client_field, old_replace, new_replace)

# 2) Once an authoritative MSG_MULTIPLAYER_PRIVATE_PILES snapshot has been
# received, never overwrite it by recapturing whichever teammate happens to be
# projected on screen. This was the main source of mixed P1/P2/P3 hands.
old_capture = '''	for(uint8_t display_side = 0; display_side < 2; ++display_side) {
		const auto core_side = mainGame->LocalPlayer(display_side);
		const auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
		if(logical >= multiplayer_private_piles.size())
			continue;
		MultiplayerPrivatePileSnapshot snapshot;
'''
new_capture = '''	for(uint8_t display_side = 0; display_side < 2; ++display_side) {
		const auto core_side = mainGame->LocalPlayer(display_side);
		const auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
		if(logical >= multiplayer_private_piles.size())
			continue;
		// Authoritative replay snapshots beat visual recapture. Capture is only
		// a compatibility fallback for old streamed replays that did not carry
		// MSG_MULTIPLAYER_PRIVATE_PILES.
		if(multiplayer_private_piles_valid[logical])
			continue;
		MultiplayerPrivatePileSnapshot snapshot;
'''
replace_once(client_field, old_capture, new_capture)

# 3) Replacing displayed replay piles must not clear the currently resolving
# chain/target. A P2 effect targeting P1 is allowed to change the view to P1
# while the activation and selected target remain visible until CHAIN_END.
old_apply = '''void ClientField::ApplyThreeVsOneReplayPrivatePiles() {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
		return;
	bool clear_transient = true;
'''
new_apply = '''void ClientField::ApplyThreeVsOneReplayPrivatePiles() {
	if(!mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
		return;
	// Replay view changes are visual only. Never destroy live replay chain /
	// selection pointers while changing which teammate's private piles are shown.
	bool clear_transient = false;
'''
replace_once(client_field, old_apply, new_apply)


duelclient = ROOT / "gframe" / "duelclient.cpp"

# 4) A repeated identical 3v1 replay-view message is a no-op. Previously every
# duplicate captured and re-applied both private-pile snapshots even when the
# same teammate was already displayed.
old_view = '''	auto SetThreeVsOneView = [&](uint8_t perspective,
			uint8_t opponent = 0xff) {
		if(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
				|| mainGame->dInfo.team1 == 0
				|| mainGame->dInfo.team2 == 0)
			return false;
		if(mainGame->dInfo.isReplay)
			mainGame->dField.CaptureThreeVsOneReplayPrivatePiles();
		uint8_t allied_logical = 0xff;
		for(const auto logical : { perspective, opponent,
				mainGame->dInfo.logical_turn_player }) {
			if(logical < mainGame->dInfo.team1
					&& (mainGame->dInfo.active_player_mask & (1u << logical))) {
				allied_logical = logical;
				break;
			}
		}
		if(allied_logical >= mainGame->dInfo.team1) {
			for(uint8_t logical = 0; logical < mainGame->dInfo.team1; ++logical) {
				if(mainGame->dInfo.active_player_mask & (1u << logical)) {
					allied_logical = logical;
					break;
				}
			}
		}
		if(allied_logical >= mainGame->dInfo.team1)
			return false;
		const auto allied_duelist =
			mainGame->dInfo.GetLogicalDuelist(allied_logical);
		const bool changed = mainGame->dInfo.field_focus[0] != allied_duelist
			|| mainGame->dInfo.field_focus[1] != 0;
		mainGame->dInfo.SetFieldFocus(0, allied_duelist);
		mainGame->dInfo.SetFieldFocus(1, 0);
		if(mainGame->dInfo.isReplay)
			mainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
		if(changed)
			mainGame->dField.RefreshAllCards();
		return changed;
	};
'''
new_view = '''	auto SetThreeVsOneView = [&](uint8_t perspective,
			uint8_t opponent = 0xff) {
		if(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
				|| mainGame->dInfo.team1 == 0
				|| mainGame->dInfo.team2 == 0)
			return false;
		uint8_t allied_logical = 0xff;
		for(const auto logical : { perspective, opponent,
				mainGame->dInfo.logical_turn_player }) {
			if(logical < mainGame->dInfo.team1
					&& (mainGame->dInfo.active_player_mask & (1u << logical))) {
				allied_logical = logical;
				break;
			}
		}
		if(allied_logical >= mainGame->dInfo.team1) {
			for(uint8_t logical = 0; logical < mainGame->dInfo.team1; ++logical) {
				if(mainGame->dInfo.active_player_mask & (1u << logical)) {
					allied_logical = logical;
					break;
				}
			}
		}
		if(allied_logical >= mainGame->dInfo.team1)
			return false;
		const auto allied_duelist =
			mainGame->dInfo.GetLogicalDuelist(allied_logical);
		const bool changed = mainGame->dInfo.field_focus[0] != allied_duelist
			|| mainGame->dInfo.field_focus[1] != 0;
		// Identical view hints are common in attack/target sequences. Do not
		// re-capture or re-apply hands when nothing on screen actually changes.
		if(!changed)
			return false;
		if(mainGame->dInfo.isReplay)
			mainGame->dField.CaptureThreeVsOneReplayPrivatePiles();
		mainGame->dInfo.SetFieldFocus(0, allied_duelist);
		mainGame->dInfo.SetFieldFocus(1, 0);
		if(mainGame->dInfo.isReplay)
			mainGame->dField.ApplyThreeVsOneReplayPrivatePiles();
		mainGame->dField.RefreshAllCards();
		return true;
	};
'''
replace_once(duelclient, old_view, new_view)

# 5) Streamed 3v1 replay state is driven by MSG_MULTIPLAYER_NEW_TURN,
# MSG_MULTIPLAYER_REPLAY_VIEW and MSG_MULTIPLAYER_PRIVATE_PILES. The legacy
# TAG_SWAP packet is already redundant there and rebuilding its hand a second
# time is what makes team hands jump/flicker and adds animation delay.
old_tag_anchor = '''		const auto logical_core_side = logical_player < player_count
			? mainGame->dInfo.GetLogicalCoreSide(logical_player) : core_player;
'''
new_tag_anchor = '''		if(mainGame->dInfo.isReplay
				&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
			// Authoritative streamed replay packets already carry the exact
			// logical private piles. Never replay TAG_SWAP's destructive pile
			// animation a second time.
			return true;
		}
		const auto logical_core_side = logical_player < player_count
			? mainGame->dInfo.GetLogicalCoreSide(logical_player) : core_player;
'''
replace_once(duelclient, old_tag_anchor, new_tag_anchor)

# 6) A cross-teammate target is itself an authoritative replay camera cue.
# Focus the selected target's logical field before highlighting it, so P2's
# Stop/Block Attack on P1 is visible even if that chain is later negated.
old_target = '''		for(uint32_t i = 0; i < count; ++i) {
			CoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
			if(!MapLocationDisplay(info))
				continue;
'''
new_target = '''		for(uint32_t i = 0; i < count; ++i) {
			CoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
			const auto target_core_player = info.controler;
			if(mainGame->dInfo.curMsg == MSG_BECOME_TARGET
					&& mainGame->dInfo.isReplay
					&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
					&& target_core_player < 2
					&& (info.location & LOCATION_ONFIELD)) {
				const auto target_logical = mainGame->dInfo.GetLogicalPlayer(
					target_core_player, info.duelist);
				if(target_logical < mainGame->dInfo.team1 + mainGame->dInfo.team2)
					SetThreeVsOneView(target_logical);
			}
			if(!MapLocationDisplay(info))
				continue;
'''
replace_once(duelclient, old_target, new_target)

# 7) Re-bind the public card code/location on face-up Special Summon. A Deck
# Master originates outside ordinary public piles, so without this the client
# can retain a code-0 placeholder (stats visible but image missing).
old_sp = '''	case MSG_SPSUMMONING: {
		const auto code = BufferIO::Read<uint32_t>(pbuf);
		/*CoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);*/
		if(!code || !PlayChant(SoundManager::CHANT::SUMMON, code))
			Play(SoundManager::SFX::SPECIAL_SUMMON);
'''
new_sp = '''	case MSG_SPSUMMONING: {
		const auto code = BufferIO::Read<uint32_t>(pbuf);
		CoreUtils::loc_info info = CoreUtils::ReadLocInfo(pbuf, mainGame->dInfo.compat_mode);
		// A face-up Special Summon is public information. Re-bind the code to
		// the encoded logical-field card so Deck Masters can never remain a
		// code-0/invisible placeholder in duel or replay.
		if(MapLocationDisplay(info)) {
			if(auto* pcard = mainGame->dField.GetCard(info.controler, info.location,
					info.sequence, info.position); pcard) {
				if(code && pcard->code != code)
					pcard->SetCode(code);
				pcard->position = info.position;
				pcard->UpdateDrawCoordinates(true);
			}
		}
		if(!code || !PlayChant(SoundManager::CHANT::SUMMON, code))
			Play(SoundManager::SFX::SPECIAL_SUMMON);
'''
replace_once(duelclient, old_sp, new_sp)

print("Applied 3v1 replay hardening: stable hands, deduped views, target visibility and Deck Master images")
