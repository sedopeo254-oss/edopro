from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "ocgcore"


def replace_once(path, old, new):
    p = CORE / path
    text = p.read_text(encoding="utf-8")
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"ocgcore/{path}: expected one replacement site, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# Dedicated public flag. It is intentionally NOT composed with BR or 3v1.
replace_once(
    "ocgapi_constants.h",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n#define DUEL_2_V_1_BIG5        0x8000000000ULL\n",
)

replace_once(
    "multiplayer.h",
    "\tNONE = 0,\n\tBATTLE_ROYALE,\n\tTHREE_V_ONE\n",
    "\tNONE = 0,\n\tBATTLE_ROYALE,\n\tTHREE_V_ONE,\n\tTWO_V_ONE_BIG5\n",
)

# Configure exactly three logical players. Network/logical order stays natural:
# Joey=0, Yugi=1, Big Five=2. Slot 3 is never active.
replace_once(
    "multiplayer.cpp",
    "\t} else if(new_mode == MultiplayerMode::THREE_V_ONE) {\n",
    "\t} else if(new_mode == MultiplayerMode::TWO_V_ONE_BIG5) {\n"
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
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE_BIG5) {\n"
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
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE_BIG5)\n"
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
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE_BIG5) {\n"
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
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE_BIG5) {\n"
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
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE_BIG5) {\n"
    "\t\tif(player < 2) return static_cast<uint8_t>(player + 2);\n"
    "\t\treturn player == 2 ? 1 : NO_PLAYER;\n"
    "\t}\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n",
)

# Team winner logic, but with Big Five in logical slot 2 rather than 3.
replace_once(
    "multiplayer.cpp",
    "\tif(duel_mode == MultiplayerMode::THREE_V_ONE) {\n"
    "\t\tconst uint8_t team_mask = active_teams_mask();\n",
    "\tif(duel_mode == MultiplayerMode::TWO_V_ONE_BIG5 || duel_mode == MultiplayerMode::THREE_V_ONE) {\n"
    "\t\tconst uint8_t team_mask = active_teams_mask();\n",
)
replace_once(
    "multiplayer.cpp",
    "\t\t\t\tif(team == 1 && is_active(3))\n\t\t\t\t\twinning_player = 3;\n",
    "\t\t\t\tif(team == 1) {\n"
    "\t\t\t\t\tconst auto solo = static_cast<uint8_t>(duel_mode == MultiplayerMode::TWO_V_ONE_BIG5 ? 2 : 3);\n"
    "\t\t\t\t\tif(is_active(solo)) winning_player = solo;\n"
    "\t\t\t\t}\n",
)

# Physical side 0 contains two flattened simultaneous fields; side 1 is Big Five.
replace_once(
    "field.cpp",
    "\t} else if(options.flags & DUEL_3_V_1) {\n",
    "\t} else if(options.flags & DUEL_2_V_1_BIG5) {\n"
    "\t\tmultiplayer.configure(MultiplayerMode::TWO_V_ONE_BIG5);\n"
    "\t\tplayer[0].list_mzone.resize(7 * 2, nullptr);\n"
    "\t\tplayer[0].list_szone.resize(8 * 2, nullptr);\n"
    "\t\tplayer[0].extra_used_location.resize(1, 0);\n"
    "\t\tplayer[0].extra_disabled_location.resize(1, 0);\n"
    "\t} else if(options.flags & DUEL_3_V_1) {\n",
)

# Shared team effects: Joey and Yugi may use/affect each other's on-field cards.
replace_once(
    "libduel.cpp",
    "\tif(game_field->multiplayer.mode() != MultiplayerMode::THREE_V_ONE || playerid > 1)\n"
    "\t\treturn { 0, 0 };\n",
    "\tif((game_field->multiplayer.mode() != MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t&& game_field->multiplayer.mode() != MultiplayerMode::TWO_V_ONE_BIG5) || playerid > 1)\n"
    "\t\treturn { 0, 0 };\n",
)

# Battle damage without an explicit target must preserve the logical teammate.
replace_once(
    "operations.cpp",
    "\t\telse if((reason & REASON_BATTLE) && !core.attack_target\n"
    "\t\t\t\t&& multiplayer.mode() == MultiplayerMode::THREE_V_ONE && playerid == 0\n",
    "\t\telse if((reason & REASON_BATTLE) && !core.attack_target\n"
    "\t\t\t\t&& (multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE_BIG5) && playerid == 0\n",
)

# The four-slot wire packet remains fixed-size for compatibility. Never dereference
# an inactive logical slot: write six zero values instead. This is the P4 crash guard.
replace_once(
    "processor.cpp",
    "\t\t\t\tfor(uint8_t logical = 0; logical < MultiplayerState::MAX_PLAYERS; ++logical) {\n"
    "\t\t\t\t\tconst auto side = multiplayer.field_side_of(logical);\n"
    "\t\t\t\t\tconst auto duelist = multiplayer.duelist_index_of(logical);\n"
    "\t\t\t\t\tconst auto logical_lp = get_logical_lp(side, duelist);\n",
    "\t\t\t\tfor(uint8_t logical = 0; logical < MultiplayerState::MAX_PLAYERS; ++logical) {\n"
    "\t\t\t\t\tif(!multiplayer.is_active(logical)) {\n"
    "\t\t\t\t\t\tfor(uint8_t field = 0; field < 6; ++field) logical_message->write<uint32_t>(0);\n"
    "\t\t\t\t\t\tcontinue;\n"
    "\t\t\t\t\t}\n"
    "\t\t\t\t\tconst auto side = multiplayer.field_side_of(logical);\n"
    "\t\t\t\t\tconst auto duelist = multiplayer.duelist_index_of(logical);\n"
    "\t\t\t\t\tconst auto logical_lp = get_logical_lp(side, duelist);\n",
)

# Team-mode elimination reports team winner for both 3v1 and the new 2v1.
replace_once(
    "ocgapi.cpp",
    "\t\t\twinner = game_field.multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t? game_field.multiplayer.winner_team()\n",
    "\t\t\twinner = (game_field.multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t|| game_field.multiplayer.mode() == MultiplayerMode::TWO_V_ONE_BIG5)\n"
    "\t\t\t\t? game_field.multiplayer.winner_team()\n",
)

# The first real Core turn must follow the logical order. 2v1 starts with Big Five
# (logical 2 / physical side 1), while Standard and protected 3v1 keep their
# existing startup behavior unchanged.
replace_once(
    "processor.cpp",
    "\t\t}\n\t\templace_process<Processors::Turn>(0);\n\t\treturn TRUE;\n\t}\n\tcase 2: {\n",
    "\t\t}\n"
    "\t\tif(multiplayer.mode() == MultiplayerMode::TWO_V_ONE_BIG5) {\n"
    "\t\t\tconst auto first_logical = multiplayer.current_player();\n"
    "\t\t\templace_process<Processors::Turn>(multiplayer.field_side_of(first_logical));\n"
    "\t\t} else {\n"
    "\t\t\templace_process<Processors::Turn>(0);\n"
    "\t\t}\n"
    "\t\treturn TRUE;\n\t}\n\tcase 2: {\n",
)

# 2v1 battle targeting mirrors the protected team-target routing, but only for
# this dedicated mode. Big Five may choose Joey/Yugi as the attacked field;
# allied attackers always target the Big Five logical player.
replace_once(
    "processor.cpp",
    "\t\tif(multiplayer.mode() == MultiplayerMode::BATTLE_ROYALE) {\n"
    "\t\t\targ.attack_target_duelists.clear();\n",
    "\t\tif(multiplayer.mode() == MultiplayerMode::TWO_V_ONE_BIG5 && infos.turn_player == 0) {\n"
    "\t\t\tcore.attack_target_logical = 2;\n"
    "\t\t\tcore.attack_target_duelist = 0;\n"
    "\t\t}\n"
    "\t\tif(multiplayer.mode() == MultiplayerMode::BATTLE_ROYALE) {\n"
    "\t\t\targ.attack_target_duelists.clear();\n",
)
replace_once(
    "processor.cpp",
    "\t\t} else if(multiplayer.mode() == MultiplayerMode::THREE_V_ONE && infos.turn_player == 1) {\n"
    "\t\t\targ.attack_target_duelists.clear();\n",
    "\t\t} else if((multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE_BIG5)\n"
    "\t\t\t\t&& infos.turn_player == 1) {\n"
    "\t\t\targ.attack_target_duelists.clear();\n",
)
replace_once(
    "processor.cpp",
    "\t\t} else if(multiplayer.mode() == MultiplayerMode::THREE_V_ONE && infos.turn_player == 1\n"
    "\t\t\t\t&& arg.attack_target_duelists.size() > 1) {\n",
    "\t\t} else if((multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t|| multiplayer.mode() == MultiplayerMode::TWO_V_ONE_BIG5)\n"
    "\t\t\t\t&& infos.turn_player == 1\n"
    "\t\t\t\t&& arg.attack_target_duelists.size() > 1) {\n",
)
replace_once(
    "processor.cpp",
    "\t\t\t} else if(multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t\t&& core.attack_target->current.controler == 0) {\n"
    "\t\t\t\tcore.attack_target_duelist = core.attack_target->current.duelist;\n"
    "\t\t\t\tcore.attack_target_logical = multiplayer.logical_player(\n"
    "\t\t\t\t\t0, core.attack_target_duelist);\n"
    "\t\t\t}\n",
    "\t\t\t} else if(multiplayer.mode() == MultiplayerMode::TWO_V_ONE_BIG5) {\n"
    "\t\t\t\tcore.attack_target_duelist = core.attack_target->current.duelist;\n"
    "\t\t\t\tcore.attack_target_logical = multiplayer.logical_player(\n"
    "\t\t\t\t\tcore.attack_target->current.controler, core.attack_target_duelist);\n"
    "\t\t\t} else if(multiplayer.mode() == MultiplayerMode::THREE_V_ONE\n"
    "\t\t\t\t\t&& core.attack_target->current.controler == 0) {\n"
    "\t\t\t\tcore.attack_target_duelist = core.attack_target->current.duelist;\n"
    "\t\t\t\tcore.attack_target_logical = multiplayer.logical_player(\n"
    "\t\t\t\t\t0, core.attack_target_duelist);\n"
    "\t\t\t}\n",
)

print("Applied isolated 2v1 Big Five Core on top of 137c63b baseline")
