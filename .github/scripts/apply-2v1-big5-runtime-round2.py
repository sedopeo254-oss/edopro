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
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"{path}: expected at least {minimum} replacement site(s), found 0")
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
    raise SystemExit(f"unclosed function: {signature}")

# 1) Exact first turn: Big Five(logical 2 / physical side 1) must really act first.
replace_once(
    "ocgcore/processor.cpp",
    "\t\templace_process<Processors::Turn>(0);\n\t\treturn TRUE;\n",
    "\t\tif(multiplayer.mode() == MultiplayerMode::TWO_V_ONE_BIG5) {\n"
    "\t\t\tconst auto first_logical = multiplayer.current_player();\n"
    "\t\t\templace_process<Processors::Turn>(multiplayer.field_side_of(first_logical));\n"
    "\t\t} else {\n"
    "\t\t\templace_process<Processors::Turn>(0);\n"
    "\t\t}\n"
    "\t\treturn TRUE;\n",
)

# 2) Deck Master is a real visible logical card in both team modes.
replace_once(
    "gframe/client_field.cpp",
    "void ClientField::RefreshLogicalDeckMasters() {\n"
    "\tif(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t|| !mainGame->dInfo.logical_deck_master_enabled)\n"
    "\t\treturn;\n",
    "void ClientField::RefreshLogicalDeckMasters() {\n"
    "\tif(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t|| !mainGame->dInfo.logical_deck_master_enabled)\n"
    "\t\treturn;\n",
)

# 3) Add a 2v1 private-pile projector. On-field arrays stay independent/flattened;
#    only Deck/Hand/Extra/GY/Banish are switched for the viewed teammate.
replace_once(
    "gframe/client_field.h",
    "\tvoid CycleBattleRoyaleOpponent();\n\tvoid CycleTeamField();\n",
    "\tvoid CycleBattleRoyaleOpponent();\n\tvoid CycleTeamField();\n"
    "\tbool ApplyTwoVsOnePrivatePile(uint8_t logical_player, bool clear_transient = false);\n",
)

cpp = read("gframe/client_field.cpp")
marker = "void ClientField::RefreshLogicalDeckMasters() {"
if "bool ClientField::ApplyTwoVsOnePrivatePile(" not in cpp:
    insert = r'''bool ClientField::ApplyTwoVsOnePrivatePile(uint8_t logical_player, bool clear_transient) {
    if(mainGame->dInfo.isReplay
            || !mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)
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
    cpp = cpp.replace(marker, insert + marker, 1)
    write("gframe/client_field.cpp", cpp)

# Replace CycleTeamField with a view-only, atomic Joey/Yugi swap.
cpp = read("gframe/client_field.cpp")
start, end = function_block(cpp, "void ClientField::CycleTeamField()")
new_cycle = r'''void ClientField::CycleTeamField() {
    if(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)
            || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))
            || mainGame->dInfo.team1 < 2)
        return;
    const auto core_side = static_cast<uint8_t>(0);
    const auto outgoing = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);
    if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) && outgoing < 2) {
        const auto local_side = mainGame->LocalPlayer(core_side);
        // Preserve the currently rendered authoritative private state if a newer
        // snapshot has not arrived yet.
        if(!multiplayer_private_piles_valid[outgoing]) {
            MultiplayerPrivatePileSnapshot snapshot;
            snapshot.deck_count = static_cast<uint32_t>(deck[local_side].size());
            snapshot.extra_p_count = extra_p_count[local_side] > 0
                ? static_cast<uint32_t>(extra_p_count[local_side]) : 0u;
            snapshot.top_code = deck[local_side].empty() || !deck[local_side].back()
                ? 0u : deck[local_side].back()->code;
            auto capture = [](const auto& source, auto& dest) {
                for(const auto* card : source)
                    if(card) dest.push_back({ card->code, static_cast<uint8_t>(card->position) });
            };
            capture(hand[local_side], snapshot.hand);
            capture(extra[local_side], snapshot.extra);
            capture(grave[local_side], snapshot.grave);
            capture(remove[local_side], snapshot.removed);
            CacheMultiplayerPrivatePiles(outgoing, snapshot);
        }
    }
    mainGame->dInfo.field_focus[core_side] = static_cast<uint8_t>(
        (mainGame->dInfo.field_focus[core_side] + 1) % mainGame->dInfo.team1);
    const auto incoming = mainGame->dInfo.GetFocusedLogicalPlayer(core_side);

    ClearSelect();
    ClearChainSelect();
    ClearCommandFlag();
    selectable_cards.clear();
    selected_cards.clear();
    must_select_cards.clear();
    selectsum_cards.clear();
    selectsum_all.clear();
    summonable_cards.clear();
    spsummonable_cards.clear();
    msetable_cards.clear();
    ssetable_cards.clear();
    reposable_cards.clear();
    activatable_cards.clear();
    attackable_cards.clear();
    command_card = nullptr;
    clicked_card = nullptr;
    hovered_card = nullptr;
    hovered_location = 0;
    hovered_sequence = 0;

    if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5))
        ApplyTwoVsOnePrivatePile(incoming, false);
    RefreshLogicalDeckMasters();
    RefreshAllCards();
    RefreshHandHitboxes();
}'''
write("gframe/client_field.cpp", cpp[:start] + new_cycle + cpp[end:])

# 4) Visual projection and hit-testing must use the same encoded field.
#    This is the main "ghost Yugi card" fix.
event = read("gframe/event_handler.cpp")
s, e = function_block(event, "void ClientField::GetHoverField(")
block = event[s:e]
block = block.replace(
    "mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)",
    "(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))"
)
event = event[:s] + block + event[e:]
# Select-place/disfield uses the same focused encoded segment.
event = event.replace(
    "if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {",
    "if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {"
)
write("gframe/event_handler.cpp", event)

# 5) Live 2v1 private resources: cache all three players and project the focused
#    teammate atomically. This fixes draw/add/Deck/Extra/GY/Banish desync.
duel = read("gframe/duelclient.cpp")

needle = r'''        uint32_t sounds = count;
        if(mainGame->dInfo.isReplay) {'''
if needle not in duel:
    needle = """\t\tuint32_t sounds = count;
\t\tif(mainGame->dInfo.isReplay) {"""
replacement = "		uint32_t sounds = count;\n"     "\t\tif(!mainGame->dInfo.isReplay && mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)) {\n"     "\t\t\tif(logical_player < mainGame->dField.multiplayer_private_piles_valid.size()\n"     "\t\t\t\t\t&& mainGame->dField.multiplayer_private_piles_valid[logical_player]) {\n"     "\t\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);\n"     "\t\t\t\tconst auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);\n"     "\t\t\t\tif(core_side < 2\n"     "\t\t\t\t\t\t&& mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player)\n"     "\t\t\t\t\tmainGame->dField.ApplyTwoVsOnePrivatePile(logical_player, false);\n"     "\t\t\t}\n"     "\t\t} else if(mainGame->dInfo.isReplay) {"
if replacement not in duel:
    if needle not in duel:
        raise SystemExit("duelclient.cpp: multiplayer draw insertion point not found")
    duel = duel.replace(needle, replacement, 1)

snapshot_anchor = "		const bool duplicate = logical_player < 4\n"
idx = duel.find(snapshot_anchor)
if idx < 0:
    raise SystemExit("duelclient.cpp: snapshot duplicate anchor missing")
# Insert live-2v1 handling immediately before Battle Royale live branch, after duplicate calculation block.
br_anchor = "		if(multiplayer_battle_royale_live::ShouldCacheSnapshot(\n"
br_idx = duel.find(br_anchor, idx)
if br_idx < 0:
    raise SystemExit("duelclient.cpp: BR snapshot branch missing")
insert = '''		if(!mainGame->dInfo.isReplay
				&& mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)) {
			mainGame->dField.CacheMultiplayerPrivatePiles(logical_player, snapshot);
			const auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);
			if(core_side < 2
					&& mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player)
				mainGame->dField.ApplyTwoVsOnePrivatePile(logical_player, false);
			return true;
		}
'''
if insert not in duel:
    duel = duel[:br_idx] + insert + duel[br_idx:]

# When the logical turn changes, switch both field focus and the private piles.
turn_anchor = '''		if(logical_player < mainGame->dInfo.team1 + mainGame->dInfo.team2) {
			const auto outgoing = mainGame->dInfo.logical_active[field_side];'''
turn_insert = '''		if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)
				&& logical_player < mainGame->dInfo.team1 + mainGame->dInfo.team2)
			mainGame->dField.ApplyTwoVsOnePrivatePile(logical_player, false);
'''
if turn_insert not in duel:
    if turn_anchor not in duel:
        raise SystemExit("duelclient.cpp: new-turn private-pile anchor missing")
    duel = duel.replace(turn_anchor, turn_insert + turn_anchor, 1)

# 6) Team attack packets use the same logical-target extension as 3v1.
duel = duel.replace(
    "const bool has_three_vs_one_target =\n"
    "\t\t\t!mainGame->dInfo.compat_mode\n"
    "\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t&& len >= 21;",
    "const bool has_three_vs_one_target =\n"
    "\t\t\t!mainGame->dInfo.compat_mode\n"
    "\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t&& len >= 21;"
)
duel = duel.replace(
    "if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t\t&& valid_logical_attack) {\n\t\t\tSetThreeVsOneView(attacker_logical, attack_target_logical);",
    "if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t&& valid_logical_attack) {\n"
    "\t\t\tconst auto team_logical = attacker_logical < 2 ? attacker_logical\n"
    "\t\t\t\t: attack_target_logical < 2 ? attack_target_logical : static_cast<uint8_t>(0xff);\n"
    "\t\t\tif(team_logical < 2) {\n"
    "\t\t\t\tmainGame->dInfo.SetFieldFocus(0, team_logical);\n"
    "\t\t\t\tmainGame->dField.ApplyTwoVsOnePrivatePile(team_logical, false);\n"
    "\t\t\t\tmainGame->dField.RefreshAllCards();\n"
    "\t\t\t}\n"
    "\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t&& valid_logical_attack) {\n"
    "\t\t\tSetThreeVsOneView(attacker_logical, attack_target_logical);"
)
duel = duel.replace(
    "if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tif(logical >= player_count)",
    "if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tif(logical >= player_count)"
)

write("gframe/duelclient.cpp", duel)

# 7) Server must not mask a teammate's on-field card in card/effect selection.
generic = read("gframe/generic_duel.cpp")
# Insert mode boolean in both SELECT_CARD and SELECT_UNSELECT_CARD blocks.
visible = '''		const uint8_t visible_side = logical_selector
			? static_cast<uint8_t>(logical_player < players.home_size ? 0 : 1) : player;'''
with_flag = visible + '''
		const uint64_t select_flags = static_cast<uint64_t>(host_info.duel_flag_low)
			| (static_cast<uint64_t>(host_info.duel_flag_high) << 32);
		const bool shared_two_v_one_field = (select_flags & DUEL_2_V_1_BIG5)
			&& visible_side == 0;'''
# exactly two blocks need this (SELECT_CARD + SELECT_UNSELECT_CARD); tribute may get it too if global.
count = generic.count(visible)
if count < 3:
    raise SystemExit(f"generic_duel.cpp: expected >=3 visible-side blocks, found {count}")
# Apply only first and third by block-local modification below.
for signature in ["case MSG_SELECT_CARD: {", "case MSG_SELECT_UNSELECT_CARD: {"]:
    st = generic.index(signature)
    en = generic.index("\n\tcase ", st + len(signature))
    block = generic[st:en]
    if "shared_two_v_one_field" not in block:
        block = block.replace(visible, with_flag, 1)
    old_cond = '''if(info.controler != visible_side
					|| (logical_selector && info_logical != logical_player))'''
    new_cond = '''const bool ally_on_field = shared_two_v_one_field
					&& info.controler == 0
					&& (info.location & LOCATION_ONFIELD);
				if(info.controler != visible_side
					|| (logical_selector && info_logical != logical_player && !ally_on_field))'''
    block = block.replace(old_cond, new_cond)
    generic = generic[:st] + block + generic[en:]
write("gframe/generic_duel.cpp", generic)

print("Applied 2v1 runtime round2: first turn, live resources, hit-test, Deck Master, ally selection and attack arrow")
