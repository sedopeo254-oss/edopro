from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

def write(path, text):
    (ROOT / path).write_text(text, encoding="utf-8")

def replace_once(path, old, new):
    text = read(path)
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one replacement site, found {count}")
    write(path, text.replace(old, new, 1))

def replace_all(path, old, new, minimum=1):
    text = read(path)
    if new in text and old not in text:
        return
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f"{path}: expected at least {minimum} replacement site(s), found {count}")
    write(path, text.replace(old, new))

def function_block(text, signature):
    start = text.index(signature)
    brace = text.index("{", start)
    depth = 0
    for i in range(brace, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return start, i + 1
    raise SystemExit(f"unclosed function {signature}")

# Client-side flag.
replace_once(
    "gframe/ocgapi_constants.h",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n#define DUEL_2_V_1             0x8000000000ULL\n",
)

# Host UI: clean fourth mode, no special LP override and no mutation of existing modes.
replace_once(
    "gframe/game.cpp",
    '''		cbMultiplayerMode->addItem(L"Standard");
		cbMultiplayerMode->addItem(L"Battle Royale");
		cbMultiplayerMode->addItem(L"3 vs 1");
		cbMultiplayerMode->setSelected((duel_param & DUEL_BATTLE_ROYALE) ? 1 : ((duel_param & DUEL_3_V_1) ? 2 : 0));
''',
    '''		cbMultiplayerMode->addItem(L"Standard");
		cbMultiplayerMode->addItem(L"Battle Royale");
		cbMultiplayerMode->addItem(L"3 vs 1");
		cbMultiplayerMode->addItem(L"2 vs 1");
		cbMultiplayerMode->setSelected((duel_param & DUEL_2_V_1) ? 3
			: (duel_param & DUEL_BATTLE_ROYALE) ? 1 : ((duel_param & DUEL_3_V_1) ? 2 : 0));
''',
)
replace_once(
    "gframe/game.cpp",
    "	const auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "	const auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1);\n",
)
replace_once(
    "gframe/game.cpp",
    '''void Game::UpdateMultiplayerMode() {
	duel_param &= ~(DUEL_BATTLE_ROYALE | DUEL_3_V_1);
	const auto mode = cbMultiplayerMode->getSelected();
	if(mode == 1) {
		duel_param |= DUEL_BATTLE_ROYALE;
		ebTeam1->setText(L"2");
		ebTeam2->setText(L"2");
	} else if(mode == 2) {
		duel_param |= DUEL_3_V_1;
		ebTeam1->setText(L"1");
		ebTeam2->setText(L"3");
	}
''',
    '''void Game::UpdateMultiplayerMode() {
	duel_param &= ~(DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1);
	const auto mode = cbMultiplayerMode->getSelected();
	if(mode == 1) {
		duel_param |= DUEL_BATTLE_ROYALE;
		ebTeam1->setText(L"2");
		ebTeam2->setText(L"2");
	} else if(mode == 2) {
		duel_param |= DUEL_3_V_1;
		ebTeam1->setText(L"1");
		ebTeam2->setText(L"3");
	} else if(mode == 3) {
		duel_param |= DUEL_2_V_1;
		ebTeam1->setText(L"2");
		ebTeam2->setText(L"1");
	}
''',
)

# Logical prompts 2/3 are the two team members.
replace_once(
    "gframe/game.h",
    '''		if((duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1))
				&& selecting_player >= 2 && selecting_player < 6) {
''',
    '''		if((duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1))
				&& selecting_player >= 2 && selecting_player < 6) {
''',
)

# Local/LAN topology = 2 vs 1, relay disabled only in this mode exactly like BR/3v1.
replace_once(
    "gframe/duelclient.cpp",
    '''			if(mainGame->duel_param & DUEL_BATTLE_ROYALE) {
				cscg.info.team1 = 2;
				cscg.info.team2 = 2;
				cscg.info.duel_flag_low &= ~DUEL_RELAY;
			} else if(mainGame->duel_param & DUEL_3_V_1) {
''',
    '''			if(mainGame->duel_param & DUEL_2_V_1) {
				cscg.info.team1 = 2;
				cscg.info.team2 = 1;
				cscg.info.duel_flag_low &= ~DUEL_RELAY;
			} else if(mainGame->duel_param & DUEL_BATTLE_ROYALE) {
				cscg.info.team1 = 2;
				cscg.info.team2 = 2;
				cscg.info.duel_flag_low &= ~DUEL_RELAY;
			} else if(mainGame->duel_param & DUEL_3_V_1) {
''',
)
replace_once(
    "gframe/duelclient.cpp",
    '''			if(mainGame->btnRelayMode->isPressed()
					&& !(mainGame->duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)))
''',
    '''			if(mainGame->btnRelayMode->isPressed()
					&& !(mainGame->duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1)))
''',
)

# Start state: three logical players, two allied encoded fields.
replace_once(
    "gframe/duelclient.cpp",
    "		mainGame->dInfo.active_player_mask = (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
    "		mainGame->dInfo.active_player_mask = mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) ? 0x07\n"
    "			: (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
)
replace_once(
    "gframe/duelclient.cpp",
    '''		if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
			const auto team_side = mainGame->LocalPlayer(0);
			mainGame->dField.mzone[team_side].resize(21, nullptr);
			mainGame->dField.szone[team_side].resize(24, nullptr);
		} else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
''',
    '''		if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)) {
			const auto team_side = mainGame->LocalPlayer(0);
			mainGame->dField.mzone[team_side].resize(14, nullptr);
			mainGame->dField.szone[team_side].resize(16, nullptr);
			const auto local_logical = mainGame->dInfo.GetLocalLogicalPlayer();
			if(local_logical < 2)
				mainGame->dInfo.field_focus[0] = local_logical;
		} else if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {
			const auto team_side = mainGame->LocalPlayer(0);
			mainGame->dField.mzone[team_side].resize(21, nullptr);
			mainGame->dField.szone[team_side].resize(24, nullptr);
		} else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
''',
)

# All logical LP / damage / recovery packets recognize 2v1.
replace_all(
    "gframe/duelclient.cpp",
    "(DUEL_BATTLE_ROYALE | DUEL_3_V_1)) && len >= 6",
    "(DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1)) && len >= 6",
    minimum=3,
)

# New-turn resource snapshot understands the new mode.
replace_once(
    "gframe/duelclient.cpp",
    '''		if((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
				|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
				&& len >= 2 + 4 * 6 * sizeof(uint32_t)) {
''',
    '''		if((mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)
				|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
				|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
				&& len >= 2 + 4 * 6 * sizeof(uint32_t)) {
''',
)

# Do not steal a team member's own screen on every turn. The solo client follows
# whichever allied player is currently acting; team clients stay on their chosen
# P1/P2 view until Swap Team is pressed.
old='''		if(logical_player < mainGame->dInfo.team1 + mainGame->dInfo.team2) {
			if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
					&& logical_player != mainGame->dInfo.GetLocalLogicalPlayer())
				mainGame->dInfo.SetBattleRoyaleOpponent(logical_player);
			else
				mainGame->dInfo.SetFieldFocus(field_side, field_duelist);
		}
'''
new='''		if(logical_player < mainGame->dInfo.team1 + mainGame->dInfo.team2) {
			if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)
					&& logical_player != mainGame->dInfo.GetLocalLogicalPlayer())
				mainGame->dInfo.SetBattleRoyaleOpponent(logical_player);
			else if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)) {
				const auto local_logical = mainGame->dInfo.GetLocalLogicalPlayer();
				if(local_logical >= 2 && field_side == 0)
					mainGame->dInfo.SetFieldFocus(field_side, field_duelist);
			} else
				mainGame->dInfo.SetFieldFocus(field_side, field_duelist);
		}
'''
replace_once("gframe/duelclient.cpp", old, new)

# 2v1 uses the normal public-field refresh when the active seat changes.
replace_once(
    "gframe/duelclient.cpp",
    '''		if((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
				|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
				&& active_seat_changed) {
''',
    '''		if((mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)
				|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
				|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
				&& active_seat_changed) {
''',
)
replace_once(
    "gframe/duelclient.cpp",
    '''			else if(!(mainGame->dInfo.isReplay
					&& (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
						|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))))
				mainGame->dField.RefreshAllCards();
''',
    '''			else if(!(mainGame->dInfo.isReplay
					&& (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
						|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))))
				mainGame->dField.RefreshAllCards();
''',
)

# Swap Team button is visible only to the two allied players.
replace_once(
    "gframe/duelclient.cpp",
    '''			mainGame->btnSpectatorSwap->setVisible(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
				|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE));
			if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
				mainGame->btnSpectatorSwap->setText(L"Swap the Team");
			else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
''',
    '''			mainGame->btnSpectatorSwap->setVisible(
				(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)
					&& mainGame->dInfo.GetLocalLogicalPlayer() < 2)
				|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
				|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE));
			if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1))
				mainGame->btnSpectatorSwap->setText(L"Swap Team");
			else if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
				mainGame->btnSpectatorSwap->setText(L"Swap the Team");
			else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
''',
)

# Client field API for atomic P1/P2 private-resource projection.
replace_once(
    "gframe/client_field.h",
    "	void CycleBattleRoyaleOpponent();\n\tvoid CycleTeamField();\n",
    "	void CycleBattleRoyaleOpponent();\n\tvoid CycleTeamField();\n"
    "	bool ApplyTwoVsOnePrivatePile(uint8_t logical_player, bool clear_transient = false);\n",
)

cf = read("gframe/client_field.cpp")
marker = "void ClientField::RefreshLogicalDeckMasters() {"
if "bool ClientField::ApplyTwoVsOnePrivatePile(" not in cf:
    helper = r'''bool ClientField::ApplyTwoVsOnePrivatePile(uint8_t logical_player, bool clear_transient) {
	if(mainGame->dInfo.isReplay
			|| !mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)
			|| logical_player >= 3
			|| logical_player >= multiplayer_private_piles.size()
			|| !multiplayer_private_piles_valid[logical_player])
		return false;
	const auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);
	if(core_side > 1)
		return false;
	const auto display_side = mainGame->LocalPlayer(core_side);
	const bool changed = ReplaceMultiplayerPrivatePiles(
		display_side, multiplayer_private_piles[logical_player], clear_transient);
	multiplayer_displayed_field_logical[display_side] = logical_player;
	multiplayer_displayed_hand_logical[display_side] = logical_player;
	return changed;
}
'''
    cf = cf.replace(marker, helper + marker, 1)
    write("gframe/client_field.cpp", cf)

# Deck Master shown for the focused logical player in 2v1 too.
replace_once(
    "gframe/client_field.cpp",
    '''void ClientField::RefreshLogicalDeckMasters() {
	if(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
			|| !mainGame->dInfo.logical_deck_master_enabled)
		return;
''',
    '''void ClientField::RefreshLogicalDeckMasters() {
	if(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)
			|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
			|| !mainGame->dInfo.logical_deck_master_enabled)
		return;
''',
)

# Clean Swap Team: changes P1/P2 field focus and their Deck/Hand/Extra/GY/Banish/Deck Master.
cf = read("gframe/client_field.cpp")
s,e = function_block(cf, "void ClientField::CycleTeamField()")
new_cycle = r'''void ClientField::CycleTeamField() {
	if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)) {
		if(mainGame->dInfo.team1 != 2 || mainGame->dInfo.GetLocalLogicalPlayer() >= 2)
			return;
		mainGame->dInfo.field_focus[0] = static_cast<uint8_t>(
			(mainGame->dInfo.field_focus[0] + 1) % 2);
		const auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(0);
		hovered_card = nullptr;
		clicked_card = nullptr;
		command_card = nullptr;
		hovered_location = 0;
		hovered_sequence = 0;
		ClearSelect();
		ClearChainSelect();
		ClearCommandFlag();
		selectable_cards.clear();
		selected_cards.clear();
		ApplyTwoVsOnePrivatePile(logical, false);
		RefreshLogicalDeckMasters();
		RefreshAllCards();
		RefreshHandHitboxes();
		return;
	}
	if(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) || mainGame->dInfo.team1 < 2)
		return;
	mainGame->dInfo.field_focus[0] = static_cast<uint8_t>(
		(mainGame->dInfo.field_focus[0] + 1) % mainGame->dInfo.team1);
	hovered_card = nullptr;
	hovered_location = 0;
	hovered_sequence = 0;
	RefreshAllCards();
}'''
write("gframe/client_field.cpp", cf[:s]+new_cycle+cf[e:])

# Rendering and chain positions project the focused P1/P2 encoded field.
replace_all(
    "gframe/client_field.cpp",
    '''	if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
			|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
''',
    '''	if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)
			|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)
			|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {
''',
    minimum=2,
)

# Hover/click hit testing must map the visible team field back to its encoded storage.
eh = read("gframe/event_handler.cpp")
s,e = function_block(eh, "void ClientField::GetHoverField(")
block = eh[s:e]
block = block.replace(
    "mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)",
    "(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))",
)
eh = eh[:s] + block + eh[e:]
write("gframe/event_handler.cpp", eh)

# Swap button action.
replace_once(
    "gframe/event_handler.cpp",
    '''				else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
					mainGame->dField.CycleBattleRoyaleOpponent();
				else if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
					mainGame->dField.CycleTeamField();
''',
    '''				else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))
					mainGame->dField.CycleBattleRoyaleOpponent();
				else if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1))
					mainGame->dField.CycleTeamField();
				else if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
					mainGame->dField.CycleTeamField();
''',
)

# Cache authoritative logical private piles for live 2v1 and display the focused one.
dc = read("gframe/duelclient.cpp")
snapshot_anchor = "		if(multiplayer_battle_royale_live::ShouldCacheSnapshot(\n"
idx = dc.index(snapshot_anchor, dc.index("case MSG_MULTIPLAYER_PRIVATE_PILES:"))
insert = '''		if(!mainGame->dInfo.isReplay && mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)) {
			mainGame->dField.CacheMultiplayerPrivatePiles(logical_player, snapshot);
			const auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);
			if(core_side < 2
					&& mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player)
				mainGame->dField.ApplyTwoVsOnePrivatePile(logical_player, false);
			return true;
		}
'''
if insert not in dc:
    dc = dc[:idx] + insert + dc[idx:]

# Draws update the snapshot first, then re-project only when that logical player is visible.
draw_anchor = "		uint32_t sounds = count;\n\t\tif(mainGame->dInfo.isReplay) {"
draw_repl = '''		uint32_t sounds = count;
		if(!mainGame->dInfo.isReplay && mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)) {
			if(logical_player < mainGame->dField.multiplayer_private_piles_valid.size()
					&& mainGame->dField.multiplayer_private_piles_valid[logical_player]) {
				mainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);
				const auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);
				if(core_side < 2
						&& mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player)
					mainGame->dField.ApplyTwoVsOnePrivatePile(logical_player, false);
			}
		} else if(mainGame->dInfo.isReplay) {'''
if draw_repl not in dc:
    if draw_anchor not in dc:
        raise SystemExit("duelclient.cpp: draw branch anchor missing")
    dc = dc.replace(draw_anchor, draw_repl, 1)

write("gframe/duelclient.cpp", dc)

# Server-side multiplayer recognition and snapshot routing.
replace_once(
    "gframe/generic_duel.cpp",
    "	return duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "	return duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1);\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    "		if(duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) {\n",
    "		if(duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1)) {\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    '''		const bool three_vs_one = (duel_flags & DUEL_3_V_1) != 0;
		if(multiplayer_battle_royale_private_snapshot::
				ShouldBroadcastMaskedSnapshot(battle_royale, three_vs_one)) {
''',
    '''		const bool three_vs_one = (duel_flags & DUEL_3_V_1) != 0;
		const bool two_vs_one = (duel_flags & DUEL_2_V_1) != 0;
		if(multiplayer_battle_royale_private_snapshot::
				ShouldBroadcastMaskedSnapshot(battle_royale, three_vs_one || two_vs_one)) {
''',
)
replace_once(
    "gframe/generic_duel.cpp",
    '''	const bool logical_selector = playerid >= 2 && logical_player < players.home_size + players.opposing_size
		&& (((duel_flags & DUEL_3_V_1) && playerid < 5)
			|| ((duel_flags & DUEL_BATTLE_ROYALE) && playerid < 6));
''',
    '''	const bool logical_selector = playerid >= 2 && logical_player < players.home_size + players.opposing_size
		&& (((duel_flags & DUEL_3_V_1) && playerid < 5)
			|| ((duel_flags & DUEL_2_V_1) && playerid < 4)
			|| ((duel_flags & DUEL_BATTLE_ROYALE) && playerid < 6));
''',
)

# Selection privacy: P1/P2 may select each other's ON-FIELD cards, but not private
# Hand/Deck/Extra/GY/Banish unless explicitly shown/selected by a card effect.
gd = read("gframe/generic_duel.cpp")
visible = '''		const uint8_t visible_side = logical_selector
			? static_cast<uint8_t>(logical_player < players.home_size ? 0 : 1) : player;'''
for signature in ["case MSG_SELECT_CARD: {", "case MSG_SELECT_UNSELECT_CARD: {"]:
    start = gd.index(signature)
    end = gd.index("\n\tcase ", start + len(signature))
    block = gd[start:end]
    if "shared_two_v_one_field" not in block:
        block = block.replace(
            visible,
            visible + '''
		const uint64_t select_flags = static_cast<uint64_t>(host_info.duel_flag_low)
			| (static_cast<uint64_t>(host_info.duel_flag_high) << 32);
		const bool shared_two_v_one_field = (select_flags & DUEL_2_V_1)
			&& visible_side == 0;''',
            1,
        )
    old = '''if(info.controler != visible_side
					|| (logical_selector && info_logical != logical_player))'''
    new = '''const bool ally_on_field = shared_two_v_one_field
					&& info.controler == 0
					&& (info.location & LOCATION_ONFIELD);
				if(info.controler != visible_side
					|| (logical_selector && info_logical != logical_player && !ally_on_field))'''
    block = block.replace(old, new)
    gd = gd[:start] + block + gd[end:]
write("gframe/generic_duel.cpp", gd)


# ---------------------------------------------------------------------------
# Inherit the mature 3v1 Team-vs-Solo presentation/replay behavior.
# 2v1 differs only in topology (P1+P2 vs P3), not in these interaction rules.
# ---------------------------------------------------------------------------

# Keep the 2v1 mode bit when duel-rule UI controls are changed.
replace_once(
    "gframe/menu_handler.cpp",
    "\t\t\t\t\tconst auto retained_flags = mainGame->duel_param\n"
    "\t\t\t\t\t\t& (DUEL_TCG_SEGOC_NONPUBLIC | DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "\t\t\t\t\tconst auto retained_flags = mainGame->duel_param\n"
    "\t\t\t\t\t\t& (DUEL_TCG_SEGOC_NONPUBLIC | DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1);\n",
)
replace_once(
    "gframe/menu_handler.cpp",
    "\t\t\t\tconst auto multiplayer_mode = mainGame->duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "\t\t\t\tconst auto multiplayer_mode = mainGame->duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1);\n",
)

# The replay hand-visibility policy is topology-generic: team side + solo side.
replace_once(
    "gframe/game.h",
    "\t\tif(!isReplay || !HasFieldFlag(DUEL_3_V_1) || core_side > 1)\n",
    "\t\tif(!isReplay || !(HasFieldFlag(DUEL_2_V_1) || HasFieldFlag(DUEL_3_V_1)) || core_side > 1)\n",
)
replace_once(
    "gframe/game.h",
    "\t\tif(!isReplay || !HasFieldFlag(DUEL_3_V_1))\n",
    "\t\tif(!isReplay || !(HasFieldFlag(DUEL_2_V_1) || HasFieldFlag(DUEL_3_V_1)))\n",
)

# Reuse the exact 3v1 replay private-pile machinery for 2v1.
cf = read("gframe/client_field.cpp")
for signature in [
    "void ClientField::CaptureThreeVsOneReplayPrivatePiles()",
    "bool ClientField::IsThreeVsOneReplayPrivatePileDisplayed(",
    "bool ClientField::IsThreeVsOneReplayHandDisplayed(",
    "void ClientField::ApplyThreeVsOneReplayPrivatePiles()",
    "bool ClientField::ApplyThreeVsOneReplayPrivateDraw(",
    "void ClientField::UpdateMultiplayerPrivateMove(",
]:
    start, end = function_block(cf, signature)
    part = cf[start:end]
    old_flag = "mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)"
    new_flag = "(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))"
    if "DUEL_2_V_1" not in part:
        part = part.replace(old_flag, new_flag)
    cf = cf[:start] + part + cf[end:]
write("gframe/client_field.cpp", cf)

# Replay movement/summon animations should have the same stable timing as 3v1.
replace_all(
    "gframe/client_field.cpp",
    "mainGame->dInfo.isReplay,\n\t\t\t\t\tmainGame->dInfo.HasFieldFlag(DUEL_3_V_1))",
    "mainGame->dInfo.isReplay,\n\t\t\t\t\t(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))",
    minimum=1,
)
replace_all(
    "gframe/duelclient.cpp",
    "mainGame->dInfo.isReplay, mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))",
    "mainGame->dInfo.isReplay, (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))",
    minimum=3,
)

# Selecting/placing cards on the projected allied field must map back to the
# encoded P1/P2 field exactly like 3v1.
replace_once(
    "gframe/event_handler.cpp",
    "\t\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
    "\t\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
)
eh = read("gframe/event_handler.cpp")
start, end = function_block(eh, "void ClientField::SetResponseSelectedOption() const")
part = eh[start:end]
old = "mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)"
new = "(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))"
if "DUEL_2_V_1" not in part:
    part = part.replace(old, new)
eh = eh[:start] + part + eh[end:]
write("gframe/event_handler.cpp", eh)

# Extend the existing 3v1 replay camera/private-resource policy to 2v1.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif(!mainGame->dInfo.isReplay\n"
    "\t\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| core_side > 1\n",
    "\t\tif(!mainGame->dInfo.isReplay\n"
    "\t\t\t\t|| !(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\t|| core_side > 1\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.team1 == 0\n",
    "\t\tif(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\t|| mainGame->dInfo.team1 == 0\n",
)
replace_all(
    "gframe/duelclient.cpp",
    "\t\tif(!mainGame->dInfo.isReplay\n\t\t\t\t|| !mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)",
    "\t\tif(!mainGame->dInfo.isReplay\n\t\t\t\t|| !(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))",
    minimum=2,
)

# New-turn replay projection and public/private refresh suppression.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\tSetThreeVsOneView(logical_player);\n",
    "\t\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\tSetThreeVsOneView(logical_player);\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\t\t\t&& !(mainGame->dInfo.isReplay\n"
    "\t\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n",
    "\t\t\t\t\t&& !(mainGame->dInfo.isReplay\n"
    "\t\t\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)))\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\telse if(!(mainGame->dInfo.isReplay\n"
    "\t\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))))\n",
    "\t\t\telse if(!(mainGame->dInfo.isReplay\n"
    "\t\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))))\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t&& !mainGame->dInfo.isReplay)\n"
    "\t\t\tSetThreeVsOneView(perspective, opponent);\n",
    "\t\telse if((mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\t&& !mainGame->dInfo.isReplay)\n"
    "\t\t\tSetThreeVsOneView(perspective, opponent);\n",
)

# UPDATE/selection/chain/private-location paths use the same projected encoded field.
replace_all(
    "gframe/duelclient.cpp",
    "(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))",
    "(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))",
    minimum=2,
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(!(mainGame->dInfo.duel_params\n"
    "\t\t\t\t\t& (DUEL_BATTLE_ROYALE | DUEL_3_V_1))\n",
    "\t\t\tif(!(mainGame->dInfo.duel_params\n"
    "\t\t\t\t\t& (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1))\n",
)

# All replay-only 3v1 private-pile guards are valid for 2v1 as well.
replace_all(
    "gframe/duelclient.cpp",
    "mainGame->dInfo.isReplay\n\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)",
    "mainGame->dInfo.isReplay\n\t\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))",
    minimum=5,
)

# The streamed replay carries authoritative snapshots for 2v1 too.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif(mainGame->dInfo.isReplay\n"
    "\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {\n",
    "\t\tif(mainGame->dInfo.isReplay\n"
    "\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_2_V_1))) {\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tif(mainGame->dField.IsThreeVsOneReplayPrivatePileDisplayed(logical_player))\n",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tif(mainGame->dField.IsThreeVsOneReplayPrivatePileDisplayed(logical_player))\n",
)

# Draws in a replay update the exact logical hand for 2v1.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tconst bool displayed =\n"
    "\t\t\t\t\tmainGame->dField.IsThreeVsOneReplayHandDisplayed(logical_player);\n",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tconst bool displayed =\n"
    "\t\t\t\t\tmainGame->dField.IsThreeVsOneReplayHandDisplayed(logical_player);\n",
)

# Damage/attack/target view changes use the same Team-vs-Solo camera policy.
replace_once(
    "gframe/duelclient.cpp",
    "\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t&& logical_player < mainGame->dInfo.team1 + mainGame->dInfo.team2)\n"
    "\t\t\tSetThreeVsOneView(mainGame->dInfo.logical_turn_player, logical_player);\n",
    "\t\telse if((mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\t&& logical_player < mainGame->dInfo.team1 + mainGame->dInfo.team2)\n"
    "\t\t\tSetThreeVsOneView(mainGame->dInfo.logical_turn_player, logical_player);\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\tconst bool has_three_vs_one_target =\n"
    "\t\t\t!mainGame->dInfo.compat_mode\n"
    "\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t&& len >= 21;\n",
    "\t\tconst bool has_three_vs_one_target =\n"
    "\t\t\t!mainGame->dInfo.compat_mode\n"
    "\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t&& len >= 21;\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t&& valid_logical_attack) {\n",
    "\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\t&& valid_logical_attack) {\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tif(logical >= player_count)\n",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tif(logical >= player_count)\n",
)

# Target effects in replay switch to the affected logical field just like 3v1.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->dInfo.curMsg == MSG_BECOME_TARGET\n"
    "\t\t\t\t\t&& mainGame->dInfo.isReplay\n"
    "\t\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n",
    "\t\t\tif(mainGame->dInfo.curMsg == MSG_BECOME_TARGET\n"
    "\t\t\t\t\t&& mainGame->dInfo.isReplay\n"
    "\t\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n",
)

# TAG_SWAP is only a transport detail in Team-vs-Solo replay. Authoritative
# logical snapshots own Hand/Deck/Extra/GY/Banish and must not be overwritten.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tconst bool is_multiplayer =\n"
    "\t\t\t(mainGame->dInfo.duel_params\n"
    "\t\t\t\t& (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) != 0;\n",
    "\t\tconst bool is_multiplayer =\n"
    "\t\t\t(mainGame->dInfo.duel_params\n"
    "\t\t\t\t& (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1)) != 0;\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif(mainGame->dInfo.isReplay\n"
    "\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t// Replay snapshots already carry exact logical Hand/Deck/Extra/GY/Banish.\n",
    "\t\tif(mainGame->dInfo.isReplay\n"
    "\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {\n"
    "\t\t\t// Replay snapshots already carry exact logical Hand/Deck/Extra/GY/Banish.\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n"
    "\t\t\tmainGame->dField.ClearSelect();\n",
    "\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n"
    "\t\t\tmainGame->dField.ClearSelect();\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif(!(mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1))) {\n",
    "\t\tif(!(mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1))) {\n",
)

# RELOAD_FIELD must allocate the encoded two-field allied side (14/16), not the
# normal 7/8 field and not the 3v1 21/24 field.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tconst int mzone_count = mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t? 14 : (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) && i == 0 ? 21 : 7);\n"
    "\t\t\tconst int szone_count = mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t? 16 : (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) && i == 0 ? 24 : 8);\n",
    "\t\t\tconst int mzone_count = mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t? 14 : (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) && i == 0 ? 14\n"
    "\t\t\t\t\t: (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) && i == 0 ? 21 : 7));\n"
    "\t\t\tconst int szone_count = mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t? 16 : (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1) && i == 0 ? 16\n"
    "\t\t\t\t\t: (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) && i == 0 ? 24 : 8));\n",
)

print("Applied clean generic 2 vs 1 client/server mode")
