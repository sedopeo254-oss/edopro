from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "ocgcore"

def read(path):
    return (CORE / path).read_text(encoding="utf-8")

def write(path, text):
    (CORE / path).write_text(text, encoding="utf-8")

def replace_once(path, old, new):
    text = read(path)
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"ocgcore/{path}: expected one replacement site, found {count}")
    write(path, text.replace(old, new, 1))

# Completely independent mode flag. Existing Standard / BR / 3v1 branches are not changed.
replace_once(
    "ocgapi_constants.h",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n#define DUEL_2_V_1             0x8000000000ULL\n",
)

replace_once(
    "multiplayer.h",
    "\tNONE = 0,\n\tBATTLE_ROYALE,\n\tTHREE_V_ONE\n",
    "\tNONE = 0,\n\tBATTLE_ROYALE,\n\tTHREE_V_ONE,\n\tTWO_V_ONE\n",
)

# Three real logical players:
# P1 = team player 1, P2 = team player 2, P3 = solo opponent.
# Turn order is exactly P3 -> P1 -> P2 -> P3.
replace_once(
    "multiplayer.cpp",
    "\t} else if(new_mode == MultiplayerMode::THREE_V_ONE) {\n",
    "\t} else if(new_mode == MultiplayerMode::TWO_V_ONE) {\n"
    "\t\tplayers_mask = 0x07;\n"
    "\t\tteams = { 0, 0, 1, NO_TEAM };\n"
    "\t\tturn_order = { 2, 0, 1, 3 };\n"
    "\t\tturn_player = 2;\n"
    "\t} else if(new_mode == MultiplayerMode::THREE_V_ONE) {\n",
)

replace_once(
    "multiplayer.cpp",
    "uint8_t MultiplayerState::field_side_of(uint8_t player) const {\n"
    "\tif(player >= MAX_PLAYERS || !enabled())\n"
    "\t\treturn NO_PLAYER;\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n"
    "\t\treturn player < 2 ? 0 : 1;\n"
    "\treturn player < 3 ? 0 : 1;\n"
    "}\n",
    "uint8_t MultiplayerState::field_side_of(uint8_t player) const {\n"
    "\tif(player >= MAX_PLAYERS || !enabled())\n"
    "\t\treturn NO_PLAYER;\n"
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE) {\n"
    "\t\tif(player < 2) return 0;\n"
    "\t\treturn player == 2 ? 1 : NO_PLAYER;\n"
    "\t}\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n"
    "\t\treturn player < 2 ? 0 : 1;\n"
    "\treturn player < 3 ? 0 : 1;\n"
    "}\n",
)

replace_once(
    "multiplayer.cpp",
    "\tif(duel_mode == MultiplayerMode::THREE_V_ONE)\n\t\treturn field_side == 0 ? 3 : 1;\n",
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE)\n"
    "\t\treturn field_side == 0 ? 2 : 1;\n"
    "\tif(duel_mode == MultiplayerMode::THREE_V_ONE)\n\t\treturn field_side == 0 ? 3 : 1;\n",
)

replace_once(
    "multiplayer.cpp",
    "uint8_t MultiplayerState::duelist_index_of(uint8_t player) const {\n"
    "\tif(player >= MAX_PLAYERS || !enabled())\n"
    "\t\treturn NO_PLAYER;\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n"
    "\t\treturn player & 1u;\n"
    "\treturn player < 3 ? player : 0;\n"
    "}\n",
    "uint8_t MultiplayerState::duelist_index_of(uint8_t player) const {\n"
    "\tif(player >= MAX_PLAYERS || !enabled())\n"
    "\t\treturn NO_PLAYER;\n"
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE) {\n"
    "\t\tif(player < 2) return player;\n"
    "\t\treturn player == 2 ? 0 : NO_PLAYER;\n"
    "\t}\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n"
    "\t\treturn player & 1u;\n"
    "\treturn player < 3 ? player : 0;\n"
    "}\n",
)

replace_once(
    "multiplayer.cpp",
    "uint8_t MultiplayerState::logical_player(uint8_t field_side, uint8_t duelist_index) const {\n"
    "\tif(!enabled() || field_side > 1)\n"
    "\t\treturn NO_PLAYER;\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE) {\n",
    "uint8_t MultiplayerState::logical_player(uint8_t field_side, uint8_t duelist_index) const {\n"
    "\tif(!enabled() || field_side > 1)\n"
    "\t\treturn NO_PLAYER;\n"
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE) {\n"
    "\t\tif(field_side == 0) return duelist_index < 2 ? duelist_index : NO_PLAYER;\n"
    "\t\treturn duelist_index == 0 ? 2 : NO_PLAYER;\n"
    "\t}\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE) {\n",
)

replace_once(
    "multiplayer.cpp",
    "uint8_t MultiplayerState::prompt_player_of(uint8_t player) const {\n"
    "\tif(player >= MAX_PLAYERS || !enabled())\n"
    "\t\treturn NO_PLAYER;\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n",
    "uint8_t MultiplayerState::prompt_player_of(uint8_t player) const {\n"
    "\tif(player >= MAX_PLAYERS || !enabled())\n"
    "\t\treturn NO_PLAYER;\n"
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE) {\n"
    "\t\tif(player < 2) return static_cast<uint8_t>(player + 2);\n"
    "\t\treturn player == 2 ? 1 : NO_PLAYER;\n"
    "\t}\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n",
)

replace_once(
    "multiplayer.cpp",
    "\tif(duel_mode == MultiplayerMode::THREE_V_ONE) {\n"
    "\t\tconst uint8_t team_mask = active_teams_mask();\n",
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE || duel_mode == MultiplayerMode::THREE_V_ONE) {\n"
    "\t\tconst uint8_t team_mask = active_teams_mask();\n",
)

replace_once(
    "multiplayer.cpp",
    "\t\t\t\tif(team == 1 && is_active(3))\n\t\t\t\t\twinning_player = 3;\n",
    "\t\t\t\tif(team == 1) {\n"
    "\t\t\t\t\tconst auto solo = static_cast<uint8_t>(duel_mode == MultiplayerMode::TWO_V_ONE ? 2 : 3);\n"
    "\t\t\t\t\tif(is_active(solo)) winning_player = solo;\n"
    "\t\t\t\t}\n",
)

# Two allied physical fields are flattened on side 0. Solo P3 owns side 1.
replace_once(
    "field.cpp",
    "\t} else if(options.flags & DUEL_3_V_1) {\n",
    "\t} else if(options.flags & DUEL_2_V_1) {\n"
    "\t\tmultiplayer.configure(MultiplayerMode::TWO_V_ONE);\n"
    "\t\tplayer[0].list_mzone.resize(14, nullptr);\n"
    "\t\tplayer[0].list_szone.resize(16, nullptr);\n"
    "\t\tplayer[0].extra_used_location.resize(1, 0);\n"
    "\t\tplayer[0].extra_disabled_location.resize(1, 0);\n"
    "\t} else if(options.flags & DUEL_3_V_1) {\n",
)

# P3 must actually take the first physical turn. Standard and other modes preserve
# their existing startup branches exactly.
replace_once(
    "processor.cpp",
    "\t\templace_process<Processors::Turn>(0);\n\t\treturn TRUE;\n",
    "\t\tif(multiplayer.mode() == MultiplayerMode::TWO_V_ONE) {\n"
    "\t\t\tconst auto first_logical = multiplayer.current_player();\n"
    "\t\t\templace_process<Processors::Turn>(multiplayer.field_side_of(first_logical));\n"
    "\t\t} else {\n"
    "\t\t\templace_process<Processors::Turn>(0);\n"
    "\t\t}\n"
    "\t\treturn TRUE;\n",
)

# Shared team field semantics. Private resources remain logical-owner specific.
replace_once(
    "libduel.cpp",
    "\tif(game_field->multiplayer.mode() != MultiplayerMode::THREE_V_ONE || playerid > 1)\n"
    "\t\treturn { 0, 0 };\n",
    "\tif((game_field->multiplayer.mode() != MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t&& game_field->multiplayer.mode() != MultiplayerMode::TWO_V_ONE) || playerid > 1)\n"
    "\t\treturn { 0, 0 };\n",
)

# Direct/battle damage is attributed to the selected logical teammate.
replace_once(
    "operations.cpp",
    "\t\telse if((reason & REASON_BATTLE) && !core.attack_target\n"
    "\t\t\t\t&& multiplayer.mode() == MultiplayerMode::THREE_V_ONE && playerid == 0\n",
    "\t\telse if((reason & REASON_BATTLE) && !core.attack_target\n"
    "\t\t\t\t&& (multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE) && playerid == 0\n",
)

# Fixed four-slot resource message: only an unmapped slot (P4 in 2v1)
# is zeroed. Eliminated real players keep their exact LP/Deck/Hand/Extra/GY/
# Banish snapshot so OUT does not erase their cards from replay/Swap Team.
replace_once(
    "processor.cpp",
    "\t\t\t\tfor(uint8_t logical = 0; logical < MultiplayerState::MAX_PLAYERS; ++logical) {\n"
    "\t\t\t\t\tconst auto side = multiplayer.field_side_of(logical);\n"
    "\t\t\t\t\tconst auto duelist = multiplayer.duelist_index_of(logical);\n"
    "\t\t\t\t\tconst auto logical_lp = get_logical_lp(side, duelist);\n",
    "\t\t\t\tfor(uint8_t logical = 0; logical < MultiplayerState::MAX_PLAYERS; ++logical) {\n"
    "\t\t\t\t\tconst auto side = multiplayer.field_side_of(logical);\n"
    "\t\t\t\t\tconst auto duelist = multiplayer.duelist_index_of(logical);\n"
    "\t\t\t\t\tif(side == MultiplayerState::NO_PLAYER || duelist == MultiplayerState::NO_PLAYER) {\n"
    "\t\t\t\t\t\tfor(uint8_t field = 0; field < 6; ++field) logical_message->write<uint32_t>(0);\n"
    "\t\t\t\t\t\tcontinue;\n"
    "\t\t\t\t\t}\n"
    "\t\t\t\t\tconst auto logical_lp = get_logical_lp(side, duelist);\n",
)

replace_once(
    "ocgapi.cpp",
    "\t\t\twinner = game_field.multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t? game_field.multiplayer.winner_team()\n",
    "\t\t\twinner = (game_field.multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t|| game_field.multiplayer.mode() == MultiplayerMode::TWO_V_ONE)\n"
    "\t\t\t\t? game_field.multiplayer.winner_team()\n",
)




# Cross-field team attacks must keep an authoritative solo logical target.
# The supplied replay contains P2 using a monster from P1's field. Without this,
# MSG_ATTACK encoded 0xff for the target and replay stayed focused on P2 instead
# of switching to the actual P1 attacker field. P3 is the only solo opponent.
replace_once(
    "processor.cpp",
    "\t\tif(arg.forced_attack) {\n"
    "\t\t\targ.step = 6;\n"
    "\t\t\treturn FALSE;\n"
    "\t\t}\n"
    "\t\tif(multiplayer.mode() == MultiplayerMode::BATTLE_ROYALE) {\n",
    "\t\tif(multiplayer.mode() == MultiplayerMode::TWO_V_ONE && infos.turn_player == 0\n"
    "\t\t\t\t&& multiplayer.is_active(2)) {\n"
    "\t\t\tcore.attack_target_logical = 2;\n"
    "\t\t\tcore.attack_target_duelist = multiplayer.duelist_index_of(2);\n"
    "\t\t}\n"
    "\t\tif(arg.forced_attack) {\n"
    "\t\t\targ.step = 6;\n"
    "\t\t\treturn FALSE;\n"
    "\t\t}\n"
    "\t\tif(multiplayer.mode() == MultiplayerMode::BATTLE_ROYALE) {\n",
)

# The solo opponent must choose which allied logical field to attack.
replace_once(
    "processor.cpp",
    "\t\t} else if(multiplayer.mode() == MultiplayerMode::THREE_V_ONE && infos.turn_player == 1) {\n",
    "\t\t} else if((multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE) && infos.turn_player == 1) {\n",
)
replace_once(
    "processor.cpp",
    "\t\t} else if(multiplayer.mode() == MultiplayerMode::THREE_V_ONE && infos.turn_player == 1\n"
    "\t\t\t\t&& arg.attack_target_duelists.size() > 1) {\n",
    "\t\t} else if((multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE) && infos.turn_player == 1\n"
    "\t\t\t\t&& arg.attack_target_duelists.size() > 1) {\n",
)
replace_once(
    "processor.cpp",
    "\t\t\t} else if(multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t\t&& core.attack_target->current.controler == 0) {\n",
    "\t\t\t} else if((multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE)\n"
    "\t\t\t\t\t&& core.attack_target->current.controler == 0) {\n",
)

# Restrict target enumeration to the chosen P1/P2 field.
replace_once(
    "field.cpp",
    "\t\treturn multiplayer.mode() == MultiplayerMode::THREE_V_ONE && p == 1\n"
    "\t\t\t&& target_duelist < multiplayer.field_count(0)\n",
    "\t\treturn (multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE) && p == 1\n"
    "\t\t\t&& target_duelist < multiplayer.field_count(0)\n",
)

# Chain responses on the allied physical side are routed to the logical owner.
replace_once(
    "playerop.cpp",
    "\tconst bool split_logical_prompt = !forced\n"
    "\t\t&& ((multiplayer.mode() == MultiplayerMode::THREE_V_ONE && playerid == 0)\n"
    "\t\t\t|| multiplayer.mode() == MultiplayerMode::BATTLE_ROYALE);\n",
    "\tconst bool split_logical_prompt = !forced\n"
    "\t\t&& (((multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE) && playerid == 0)\n"
    "\t\t\t|| multiplayer.mode() == MultiplayerMode::BATTLE_ROYALE);\n",
)


# An OUT allied player still owns optional chain prompts from cards/effects that
# remain legally usable. OUT removes turns/damage participation, not card
# ownership. Keep BR/3v1 behavior unchanged and relax only the new 2v1 mode.
replace_once(
    "playerop.cpp",
    "\t\t\t\t\tif(!multiplayer.is_active(logical_player)\n"
    "\t\t\t\t\t\t\t|| multiplayer.field_side_of(logical_player) != playerid)\n"
    "\t\t\t\t\t\tcontinue;\n",
    "\t\t\t\t\tif((multiplayer.mode() != MultiplayerMode::TWO_V_ONE\n"
    "\t\t\t\t\t\t\t&& !multiplayer.is_active(logical_player))\n"
    "\t\t\t\t\t\t\t|| multiplayer.field_side_of(logical_player) != playerid)\n"
    "\t\t\t\t\t\tcontinue;\n",
)

# Team winner messages use winner_team just like 3v1.
replace_once(
    "processor.cpp",
    "\t\t\t\t\twinner = multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t\t\t? multiplayer.winner_team()\n",
    "\t\t\t\t\twinner = (multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE)\n"
    "\t\t\t\t\t\t? multiplayer.winner_team()\n",
)
replace_once(
    "libduel.cpp",
    "\t\t\twinner = pduel->game_field->multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t? pduel->game_field->multiplayer.winner_team()\n",
    "\t\t\twinner = (pduel->game_field->multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t|| pduel->game_field->multiplayer.mode() == MultiplayerMode::TWO_V_ONE)\n"
    "\t\t\t\t? pduel->game_field->multiplayer.winner_team()\n",
)


# 2v1 inherits the 3v1 "Let me take it" interception rules.
# The only difference is that the allied side has two logical players instead of three.
replace_once(
    "processor.cpp",
    "\t\tconst bool three_vs_one_interception = multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t&& infos.turn_player == 1;\n",
    "\t\tconst bool three_vs_one_interception = (multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE) && infos.turn_player == 1;\n",
)
replace_once(
    "processor.cpp",
    "\t\t\tif(three_vs_one_interception) {\n"
    "\t\t\t\tfor(uint8_t logical_player = 0; logical_player < 3; ++logical_player) {\n",
    "\t\t\tif(three_vs_one_interception) {\n"
    "\t\t\t\tconst auto team_count = static_cast<uint8_t>(\n"
    "\t\t\t\t\tmultiplayer.mode() == MultiplayerMode::TWO_V_ONE ? 2 : 3);\n"
    "\t\t\t\tfor(uint8_t logical_player = 0; logical_player < team_count; ++logical_player) {\n",
)
replace_once(
    "operations.cpp",
    "\t\tconst bool three_vs_one_interception = multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t&& playerid == 0;\n",
    "\t\tconst bool three_vs_one_interception = (multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE) && playerid == 0;\n",
)
replace_once(
    "operations.cpp",
    "\t\t\tconst auto last = three_vs_one_interception ? 3u : MultiplayerState::MAX_PLAYERS;\n",
    "\t\t\tconst auto last = multiplayer.mode() == MultiplayerMode::TWO_V_ONE ? 2u\n"
    "\t\t\t\t: three_vs_one_interception ? 3u : MultiplayerState::MAX_PLAYERS;\n",
)

print("Applied 2 vs 1 target routing, chain routing and team winner rules")


# Prevent duplicate MSG_WIN in 2v1. After the final elimination the multiplayer
# state remains finished, so later Adjust passes must not publish another win
# unless that pass actually eliminated someone. Existing BR/3v1 behavior stays
# byte-for-byte unchanged.
replace_once(
    "processor.cpp",
    "\t\t\tif(multiplayer.is_finished()) {\n",
    "\t\t\tif(multiplayer.is_finished()\n"
    "\t\t\t\t\t&& (multiplayer.mode() != MultiplayerMode::TWO_V_ONE || eliminated)) {\n",
)


# Preserve logical owner when an unplaced multiplayer card (notably a Deck
# Master in the virtual Deck Master zone, location 0) enters the field.
# CreateToken now records the logical/effect owner too, so ordinary generated
# cards still follow the correct logical teammate instead of being pinned to P1.
replace_once(
    "libduel.cpp",
    '''	auto code = lua_get<uint32_t>(L, 2);
	card* pcard = pduel->new_card(code);
	pcard->owner = playerid;
	pcard->current.location = 0;
	pcard->current.controler = playerid;
	interpreter::pushobject(L, pcard);
''',
    '''	auto code = lua_get<uint32_t>(L, 2);
	card* pcard = pduel->new_card(code);
	pcard->owner = playerid;
	if(pduel->game_field->multiplayer.enabled() && playerid < 2) {
		const auto duelist = pduel->game_field->get_effect_duelist(playerid);
		pcard->owner_duelist = duelist;
		pcard->current.duelist = duelist;
	}
	pcard->current.location = 0;
	pcard->current.controler = playerid;
	interpreter::pushobject(L, pcard);
''',
)

replace_once(
    "field.cpp",
    '''	const bool preserve_private_duelist = multiplayer.enabled() && preplayer == playerid
		&& (pcard->current.location & (LOCATION_DECK | LOCATION_HAND | LOCATION_GRAVE
			| LOCATION_REMOVED | LOCATION_EXTRA))
		&& pcard->current.duelist < multiplayer.field_count(playerid);
	const auto target_duelist = static_cast<uint8_t>((location & LOCATION_ONFIELD)
		? ((((pcard->current.location & LOCATION_ONFIELD) && preplayer == playerid)
			|| preserve_private_duelist)
			? pcard->current.duelist : player[playerid].current_duelist)
''',
    '''	const bool preserve_private_duelist = multiplayer.enabled() && preplayer == playerid
		&& (pcard->current.location & (LOCATION_DECK | LOCATION_HAND | LOCATION_GRAVE
			| LOCATION_REMOVED | LOCATION_EXTRA))
		&& pcard->current.duelist < multiplayer.field_count(playerid);
	const bool preserve_unplaced_duelist = multiplayer.enabled()
		&& preplayer == playerid && pcard->current.location == 0
		&& pcard->owner == playerid
		&& pcard->current.duelist == pcard->owner_duelist
		&& pcard->current.duelist < multiplayer.field_count(playerid);
	const auto target_duelist = static_cast<uint8_t>((location & LOCATION_ONFIELD)
		? ((((pcard->current.location & LOCATION_ONFIELD) && preplayer == playerid)
			|| preserve_private_duelist || preserve_unplaced_duelist)
			? pcard->current.duelist : player[playerid].current_duelist)
''',
)

# Cards/effects owned by an OUT 2v1 teammate remain legal shared-field resources.
# Replay camera hints must therefore preserve that logical source/target field
# even though the player no longer receives turns or LP damage.
replace_once(
    "field.cpp",
    '''	if(source_logical == MultiplayerState::NO_PLAYER
			|| target_logical == MultiplayerState::NO_PLAYER
			|| source_logical == target_logical
			|| !multiplayer.is_active(source_logical)
			|| !multiplayer.is_active(target_logical))
		return;
''',
    '''	const bool allow_inactive_shared_cards =
		multiplayer.mode() == MultiplayerMode::TWO_V_ONE;
	if(source_logical == MultiplayerState::NO_PLAYER
			|| target_logical == MultiplayerState::NO_PLAYER
			|| source_logical == target_logical
			|| (!allow_inactive_shared_cards
				&& (!multiplayer.is_active(source_logical)
					|| !multiplayer.is_active(target_logical))))
		return;
''',
)



# Multiplayer to-field availability must be checked against the card's logical
# field, not whichever teammate is currently active on the shared physical side.
# This matters for Deck Masters/free-chain summons outside their owner's turn.
replace_once(
    "field.cpp",
    '''int32_t field::get_tofield_count(card* pcard, uint8_t playerid, uint8_t location, uint32_t uplayer, uint32_t reason, uint32_t zone, uint32_t* list) {
	if (location != LOCATION_MZONE && location != LOCATION_SZONE)
		return 0;
	uint32_t flag = player[playerid].disabled_location | player[playerid].used_location;
''',
    '''int32_t field::get_tofield_count(card* pcard, uint8_t playerid, uint8_t location, uint32_t uplayer, uint32_t reason, uint32_t zone, uint32_t* list) {
	if (location != LOCATION_MZONE && location != LOCATION_SZONE)
		return 0;
	uint8_t logical_duelist = player[playerid].current_duelist;
	if(multiplayer.enabled() && pcard && playerid < 2) {
		if(pcard->current.controler == playerid
				&& pcard->current.duelist < multiplayer.field_count(playerid))
			logical_duelist = pcard->current.duelist;
		else if(pcard->owner == playerid
				&& pcard->owner_duelist < multiplayer.field_count(playerid))
			logical_duelist = pcard->owner_duelist;
	}
	uint32_t flag = get_logical_disabled_location(playerid, logical_duelist)
		| get_logical_used_location(playerid, logical_duelist);
''',
)



# add_card must validate an explicitly requested logical duelist's encoded zone.
# Previously it checked the current teammate's local slot first and encoded the
# requested P2/P3 duelist only afterward, so an occupied P1 slot could
# incorrectly reject an otherwise free P2 slot.
replace_once(
    "field.cpp",
    '''void field::add_card(uint8_t playerid, card* pcard, uint8_t location, uint8_t sequence, bool pzone, uint8_t duelist) {
	if (pcard->current.location != 0)
		return;
	if (!is_location_useable(playerid, location, sequence))
		return;
	// explicitly allow fusion spell cards to start in the extra
''',
    '''void field::add_card(uint8_t playerid, card* pcard, uint8_t location, uint8_t sequence, bool pzone, uint8_t duelist) {
	if (pcard->current.location != 0)
		return;
	const auto logical_duelist = duelist != 0xff ? duelist : static_cast<uint8_t>((location & LOCATION_ONFIELD)
		? player[playerid].current_duelist
		: (playerid == pcard->owner ? pcard->owner_duelist : player[playerid].current_duelist));
	const auto availability_sequence = (location & LOCATION_ONFIELD)
		? get_zone_sequence(playerid, location, sequence, logical_duelist) : sequence;
	if (!is_location_useable(playerid, location, availability_sequence))
		return;
	// explicitly allow fusion spell cards to start in the extra
''',
)
replace_once(
    "field.cpp",
    '''	pcard->current.controler = playerid;
	pcard->current.location = location;
	const auto logical_duelist = duelist != 0xff ? duelist : static_cast<uint8_t>((location & LOCATION_ONFIELD)
		? player[playerid].current_duelist
		: (playerid == pcard->owner ? pcard->owner_duelist : player[playerid].current_duelist));
	pcard->current.duelist = logical_duelist;
''',
    '''	pcard->current.controler = playerid;
	pcard->current.location = location;
	pcard->current.duelist = logical_duelist;
''',
)


print("Applied clean generic 2 vs 1 Core mode")
