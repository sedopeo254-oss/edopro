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


# Independent public flag. The mode must never satisfy DUEL_3_V_1 in the UI.
replace_once(
    "ocgapi_constants.h",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n#define DUEL_2_V_1_BIG5        0x8000000000ULL\n",
)

replace_once(
    "multiplayer.h",
    "\tvoid configure(MultiplayerMode new_mode);\n\tvoid reset();\n",
    "\tvoid configure(MultiplayerMode new_mode);\n\tvoid configure_two_vs_one_big5();\n\tvoid reset();\n",
)
replace_once(
    "multiplayer.h",
    "\tMultiplayerMode mode() const;\n\tbool enabled() const;\n",
    "\tMultiplayerMode mode() const;\n\tbool enabled() const;\n\tbool is_two_vs_one_big5() const;\n",
)
replace_once(
    "multiplayer.h",
    "\tMultiplayerMode duel_mode{ MultiplayerMode::NONE };\n\tuint8_t players_mask{ 0 };\n",
    "\tMultiplayerMode duel_mode{ MultiplayerMode::NONE };\n\tbool two_vs_one_big5{ false };\n\tuint8_t players_mask{ 0 };\n",
)

replace_once(
    "multiplayer.cpp",
    "}\n\nvoid MultiplayerState::reset() {\n",
    "}\n\nvoid MultiplayerState::configure_two_vs_one_big5() {\n"
    "\treset();\n"
    "\t// Reuse the tested team-vs-one Core mechanics internally, but expose\n"
    "\t// exactly three logical duelists: Joey (0), Yugi (1), Big Five (2).\n"
    "\tduel_mode = MultiplayerMode::THREE_V_ONE;\n"
    "\ttwo_vs_one_big5 = true;\n"
    "\tplayers_mask = 0x07;\n"
    "\tteams = { 0, 0, 1, NO_TEAM };\n"
    "\t// Anime order: Big Five -> Joey -> Yugi. Slot 3 is permanently inactive.\n"
    "\tturn_order = { 2, 0, 1, 3 };\n"
    "\tturn_player = 2;\n"
    "}\n\nvoid MultiplayerState::reset() {\n",
)
replace_once(
    "multiplayer.cpp",
    "\tduel_mode = MultiplayerMode::NONE;\n\tplayers_mask = 0;\n",
    "\tduel_mode = MultiplayerMode::NONE;\n\ttwo_vs_one_big5 = false;\n\tplayers_mask = 0;\n",
)
replace_once(
    "multiplayer.cpp",
    "bool MultiplayerState::enabled() const {\n\treturn duel_mode != MultiplayerMode::NONE;\n}\n",
    "bool MultiplayerState::enabled() const {\n\treturn duel_mode != MultiplayerMode::NONE;\n}\n\n"
    "bool MultiplayerState::is_two_vs_one_big5() const {\n"
    "\treturn two_vs_one_big5;\n"
    "}\n",
)
replace_once(
    "multiplayer.cpp",
    "\tif(player >= MAX_PLAYERS || !enabled())\n\t\treturn NO_PLAYER;\n\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n\t\treturn player < 2 ? 0 : 1;\n\treturn player < 3 ? 0 : 1;\n",
    "\tif(player >= MAX_PLAYERS || !enabled())\n\t\treturn NO_PLAYER;\n"
    "\tif(two_vs_one_big5) {\n"
    "\t\tif(player < 2)\n\t\t\treturn 0;\n"
    "\t\treturn player == 2 ? 1 : NO_PLAYER;\n"
    "\t}\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n\t\treturn player < 2 ? 0 : 1;\n\treturn player < 3 ? 0 : 1;\n",
)
replace_once(
    "multiplayer.cpp",
    "\tif(!enabled() || field_side > 1)\n\t\treturn 0;\n\tif(duel_mode == MultiplayerMode::THREE_V_ONE)\n\t\treturn field_side == 0 ? 3 : 1;\n",
    "\tif(!enabled() || field_side > 1)\n\t\treturn 0;\n"
    "\tif(two_vs_one_big5)\n\t\treturn field_side == 0 ? 2 : 1;\n"
    "\tif(duel_mode == MultiplayerMode::THREE_V_ONE)\n\t\treturn field_side == 0 ? 3 : 1;\n",
)
replace_once(
    "multiplayer.cpp",
    "\tif(player >= MAX_PLAYERS || !enabled())\n\t\treturn NO_PLAYER;\n\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n\t\treturn player & 1u;\n\treturn player < 3 ? player : 0;\n",
    "\tif(player >= MAX_PLAYERS || !enabled())\n\t\treturn NO_PLAYER;\n"
    "\tif(two_vs_one_big5) {\n"
    "\t\tif(player < 2)\n\t\t\treturn player;\n"
    "\t\treturn player == 2 ? 0 : NO_PLAYER;\n"
    "\t}\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n\t\treturn player & 1u;\n\treturn player < 3 ? player : 0;\n",
)
replace_once(
    "multiplayer.cpp",
    "\tif(!enabled() || field_side > 1)\n\t\treturn NO_PLAYER;\n\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE) {\n",
    "\tif(!enabled() || field_side > 1)\n\t\treturn NO_PLAYER;\n"
    "\tif(two_vs_one_big5) {\n"
    "\t\tif(field_side == 0)\n\t\t\treturn duelist_index < 2 ? duelist_index : NO_PLAYER;\n"
    "\t\treturn duelist_index == 0 ? 2 : NO_PLAYER;\n"
    "\t}\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE) {\n",
)
replace_once(
    "multiplayer.cpp",
    "\tif(player >= MAX_PLAYERS || !enabled())\n\t\treturn NO_PLAYER;\n\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n\t\treturn static_cast<uint8_t>(player + 2);\n",
    "\tif(player >= MAX_PLAYERS || !enabled())\n\t\treturn NO_PLAYER;\n"
    "\tif(two_vs_one_big5) {\n"
    "\t\tif(player < 2)\n\t\t\treturn static_cast<uint8_t>(player + 2);\n"
    "\t\treturn player == 2 ? 1 : NO_PLAYER;\n"
    "\t}\n"
    "\tif(duel_mode == MultiplayerMode::BATTLE_ROYALE)\n\t\treturn static_cast<uint8_t>(player + 2);\n",
)
replace_once(
    "multiplayer.cpp",
    "\t\t\t\twinning_team = team;\n\t\t\t\tif(team == 1 && is_active(3))\n\t\t\t\t\twinning_player = 3;\n\t\t\t\treturn;\n",
    "\t\t\t\twinning_team = team;\n"
    "\t\t\t\tif(team == 1) {\n"
    "\t\t\t\t\tconst auto solo = static_cast<uint8_t>(two_vs_one_big5 ? 2 : 3);\n"
    "\t\t\t\t\tif(is_active(solo))\n\t\t\t\t\t\twinning_player = solo;\n"
    "\t\t\t\t}\n"
    "\t\t\t\treturn;\n",
)

replace_once(
    "field.cpp",
    "\t} else if(options.flags & DUEL_3_V_1) {\n"
    "\t\tmultiplayer.configure(MultiplayerMode::THREE_V_ONE);\n"
    "\t\t// Side 0 owns three simultaneous fields. Internal on-field sequences are\n"
    "\t\t// unique while Lua-facing zone operations continue to use local indices.\n"
    "\t\tplayer[0].list_mzone.resize(7 * 3, nullptr);\n"
    "\t\tplayer[0].list_szone.resize(8 * 3, nullptr);\n"
    "\t\tplayer[0].extra_used_location.resize(2, 0);\n"
    "\t\tplayer[0].extra_disabled_location.resize(2, 0);\n"
    "\t}\n",
    "\t} else if(options.flags & DUEL_2_V_1_BIG5) {\n"
    "\t\tmultiplayer.configure_two_vs_one_big5();\n"
    "\t\t// Joey and Yugi: two independent fields/piles on side 0.\n"
    "\t\t// Big Five: one logical player, one field and one shared deck on side 1.\n"
    "\t\tplayer[0].list_mzone.resize(7 * 2, nullptr);\n"
    "\t\tplayer[0].list_szone.resize(8 * 2, nullptr);\n"
    "\t\tplayer[0].extra_used_location.resize(1, 0);\n"
    "\t\tplayer[0].extra_disabled_location.resize(1, 0);\n"
    "\t\tplayer[0].lp = player[0].start_lp = 4000;\n"
    "\t\tplayer[1].lp = player[1].start_lp = 8000;\n"
    "\t} else if(options.flags & DUEL_3_V_1) {\n"
    "\t\tmultiplayer.configure(MultiplayerMode::THREE_V_ONE);\n"
    "\t\t// Side 0 owns three simultaneous fields. Internal on-field sequences are\n"
    "\t\t// unique while Lua-facing zone operations continue to use local indices.\n"
    "\t\tplayer[0].list_mzone.resize(7 * 3, nullptr);\n"
    "\t\tplayer[0].list_szone.resize(8 * 3, nullptr);\n"
    "\t\tplayer[0].extra_used_location.resize(2, 0);\n"
    "\t\tplayer[0].extra_disabled_location.resize(2, 0);\n"
    "\t}\n",
)

print("Applied isolated Yugi & Joey vs Big Five 2v1 core mode")
