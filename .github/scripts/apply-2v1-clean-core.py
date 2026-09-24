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

print("Applied clean generic 2 vs 1 Core mode")
