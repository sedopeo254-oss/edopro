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


# Mirror the independent Core flag in the client.
replace_once(
    "gframe/ocgapi_constants.h",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n#define DUEL_2_V_1_BIG5        0x8000000000ULL\n",
)

# Host UI: add a fourth mode without changing the three existing selections.
replace_once(
    "gframe/game.cpp",
    "\t\tcbMultiplayerMode->addItem(L\"Standard\");\n"
    "\t\tcbMultiplayerMode->addItem(L\"Battle Royale\");\n"
    "\t\tcbMultiplayerMode->addItem(L\"3 vs 1\");\n"
    "\t\tcbMultiplayerMode->setSelected((duel_param & DUEL_BATTLE_ROYALE) ? 1 : ((duel_param & DUEL_3_V_1) ? 2 : 0));\n",
    "\t\tcbMultiplayerMode->addItem(L\"Standard\");\n"
    "\t\tcbMultiplayerMode->addItem(L\"Battle Royale\");\n"
    "\t\tcbMultiplayerMode->addItem(L\"3 vs 1\");\n"
    "\t\tcbMultiplayerMode->addItem(L\"2 vs 1 - Yugi & Joey vs Big Five\");\n"
    "\t\tcbMultiplayerMode->setSelected((duel_param & DUEL_2_V_1_BIG5) ? 3\n"
    "\t\t\t: (duel_param & DUEL_BATTLE_ROYALE) ? 1 : ((duel_param & DUEL_3_V_1) ? 2 : 0));\n",
)
replace_once(
    "gframe/game.cpp",
    "\tconst auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "\tconst auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5);\n",
)
replace_once(
    "gframe/game.cpp",
    "void Game::UpdateMultiplayerMode() {\n"
    "\tduel_param &= ~(DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n"
    "\tconst auto mode = cbMultiplayerMode->getSelected();\n"
    "\tif(mode == 1) {\n"
    "\t\tduel_param |= DUEL_BATTLE_ROYALE;\n"
    "\t\tebTeam1->setText(L\"2\");\n"
    "\t\tebTeam2->setText(L\"2\");\n"
    "\t} else if(mode == 2) {\n"
    "\t\tduel_param |= DUEL_3_V_1;\n"
    "\t\tebTeam1->setText(L\"1\");\n"
    "\t\tebTeam2->setText(L\"3\");\n"
    "\t}\n",
    "void Game::UpdateMultiplayerMode() {\n"
    "\tduel_param &= ~(DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5);\n"
    "\tconst auto mode = cbMultiplayerMode->getSelected();\n"
    "\tif(mode == 1) {\n"
    "\t\tduel_param |= DUEL_BATTLE_ROYALE;\n"
    "\t\tebTeam1->setText(L\"2\");\n"
    "\t\tebTeam2->setText(L\"2\");\n"
    "\t} else if(mode == 2) {\n"
    "\t\tduel_param |= DUEL_3_V_1;\n"
    "\t\tebTeam1->setText(L\"1\");\n"
    "\t\tebTeam2->setText(L\"3\");\n"
    "\t} else if(mode == 3) {\n"
    "\t\tduel_param |= DUEL_2_V_1_BIG5;\n"
    "\t\tebTeam1->setText(L\"2\");\n"
    "\t\tebTeam2->setText(L\"1\");\n"
    "\t\tebStartLP->setText(L\"4000\");\n"
    "\t}\n",
)

# Logical prompt ids 2 and 3 are Joey/Yugi. Big Five uses physical side 1.
replace_once(
    "gframe/game.h",
    "\t\tif((duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1))\n"
    "\t\t\t\t&& selecting_player >= 2 && selecting_player < 6) {\n",
    "\t\tif((duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5))\n"
    "\t\t\t\t&& selecting_player >= 2 && selecting_player < 6) {\n",
)

# Local/LAN room has exactly three seats for this scenario.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->duel_param & DUEL_BATTLE_ROYALE) {\n"
    "\t\t\t\tcscg.info.team1 = 2;\n"
    "\t\t\t\tcscg.info.team2 = 2;\n"
    "\t\t\t\tcscg.info.duel_flag_low &= ~DUEL_RELAY;\n"
    "\t\t\t} else if(mainGame->duel_param & DUEL_3_V_1) {\n",
    "\t\t\tif(mainGame->duel_param & DUEL_2_V_1_BIG5) {\n"
    "\t\t\t\tcscg.info.team1 = 2;\n"
    "\t\t\t\tcscg.info.team2 = 1;\n"
    "\t\t\t\tcscg.info.duel_flag_low &= ~DUEL_RELAY;\n"
    "\t\t\t} else if(mainGame->duel_param & DUEL_BATTLE_ROYALE) {\n"
    "\t\t\t\tcscg.info.team1 = 2;\n"
    "\t\t\t\tcscg.info.team2 = 2;\n"
    "\t\t\t\tcscg.info.duel_flag_low &= ~DUEL_RELAY;\n"
    "\t\t\t} else if(mainGame->duel_param & DUEL_3_V_1) {\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->btnRelayMode->isPressed()\n"
    "\t\t\t\t\t&& !(mainGame->duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)))\n",
    "\t\t\tif(mainGame->btnRelayMode->isPressed()\n"
    "\t\t\t\t\t&& !(mainGame->duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5)))\n",
)

# Start-state cardinality: three logical players, never P4.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tmainGame->dInfo.active_player_mask = (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
    "\t\tmainGame->dInfo.active_player_mask = mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) ? 0x07\n"
    "\t\t\t: (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
)

# Allocate exactly two allied fields (14 MZ / 16 S/T) and seed logical LP.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tfor(uint8_t logical = 0; logical < 4; ++logical) {\n"
    "\t\t\tmainGame->dInfo.logical_lp[logical] = mainGame->dInfo.startlp;\n"
    "\t\t\tmainGame->dInfo.logical_strLP[logical] = epro::to_wstring(mainGame->dInfo.startlp);\n"
    "\t\t}\n"
    "\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n",
    "\t\tfor(uint8_t logical = 0; logical < 4; ++logical) {\n"
    "\t\t\tmainGame->dInfo.logical_lp[logical] = mainGame->dInfo.startlp;\n"
    "\t\t\tmainGame->dInfo.logical_strLP[logical] = epro::to_wstring(mainGame->dInfo.startlp);\n"
    "\t\t}\n"
    "\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)) {\n"
    "\t\t\tconst auto team_side = mainGame->LocalPlayer(0);\n"
    "\t\t\tconst auto solo_side = mainGame->LocalPlayer(1);\n"
    "\t\t\tmainGame->dInfo.logical_lp[0] = mainGame->dInfo.lp[team_side];\n"
    "\t\t\tmainGame->dInfo.logical_lp[1] = mainGame->dInfo.lp[team_side];\n"
    "\t\t\tmainGame->dInfo.logical_lp[2] = mainGame->dInfo.lp[solo_side];\n"
    "\t\t\tmainGame->dInfo.logical_lp[3] = 0;\n"
    "\t\t\tfor(uint8_t logical = 0; logical < 4; ++logical)\n"
    "\t\t\t\tmainGame->dInfo.logical_strLP[logical] = epro::to_wstring(mainGame->dInfo.logical_lp[logical]);\n"
    "\t\t\tmainGame->dField.mzone[team_side].resize(14, nullptr);\n"
    "\t\t\tmainGame->dField.szone[team_side].resize(16, nullptr);\n"
    "\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n",
)

# Parse logical turn/resource snapshots and encoded on-field selections in 2v1.
replace_all(
    "gframe/duelclient.cpp",
    "mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)",
    "mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)",
    minimum=2,
)
replace_all(
    "gframe/duelclient.cpp",
    "mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)",
    "mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)",
    minimum=1,
)

# Swap button is a field-focus operation for Joey/Yugi only.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tmainGame->btnSpectatorSwap->setVisible(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE));\n",
    "\t\t\tmainGame->btnSpectatorSwap->setVisible(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE));\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap the Team\");\n"
    "\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5))\n"
    "\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap Yugi / Joey\");\n"
    "\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap the Team\");\n"
    "\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n",
)

# Generic flattened-field drawing/projection for the two allied fields.
replace_all(
    "gframe/client_field.cpp",
    "\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
    "\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
    minimum=2,
)
replace_once(
    "gframe/client_field.cpp",
    "void ClientField::CycleTeamField() {\n\tif(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) || mainGame->dInfo.team1 < 2)\n\t\treturn;\n",
    "void ClientField::CycleTeamField() {\n"
    "\tif(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t|| mainGame->dInfo.team1 < 2)\n\t\treturn;\n",
)

# HUD: old BR/3v1 remain four panels; 2v1 renders only three.
replace_once(
    "gframe/drawing.cpp",
    "\tif(dInfo.HasFieldFlag(DUEL_3_V_1) || dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n"
    "\t\tconst auto& team1_names = dInfo.isTeam1 ? dInfo.selfnames : dInfo.opponames;\n",
    "\tif(dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) || dInfo.HasFieldFlag(DUEL_3_V_1) || dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n"
    "\t\tconst auto& team1_names = dInfo.isTeam1 ? dInfo.selfnames : dInfo.opponames;\n",
)
replace_once(
    "gframe/drawing.cpp",
    "\t\tfor(uint8_t logical = 0; logical < 4; ++logical) {\n",
    "\t\tconst uint8_t logical_count = dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) ? 3 : 4;\n"
    "\t\tfor(uint8_t logical = 0; logical < logical_count; ++logical) {\n",
)
replace_all(
    "gframe/drawing.cpp",
    "dInfo.HasFieldFlag(DUEL_3_V_1) || dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)",
    "dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) || dInfo.HasFieldFlag(DUEL_3_V_1) || dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)",
    minimum=2,
)
replace_once(
    "gframe/drawing.cpp",
    "\t\t\t} else if(dInfo.HasFieldFlag(DUEL_3_V_1)) {\n",
    "\t\t\t} else if(dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) || dInfo.HasFieldFlag(DUEL_3_V_1)) {\n",
)

# Live swap action.
replace_once(
    "gframe/event_handler.cpp",
    "\t\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n"
    "\t\t\t\t\tmainGame->dField.CycleBattleRoyaleOpponent();\n"
    "\t\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\t\tmainGame->dField.CycleTeamField();\n",
    "\t\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n"
    "\t\t\t\t\tmainGame->dField.CycleBattleRoyaleOpponent();\n"
    "\t\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5))\n"
    "\t\t\t\t\tmainGame->dField.CycleTeamField();\n"
    "\t\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\t\tmainGame->dField.CycleTeamField();\n",
)

# Server recognizes 2v1 as logical multiplayer, but leaves BR/3v1 branches intact.
replace_once(
    "gframe/generic_duel.cpp",
    "\treturn duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "\treturn duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5);\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    "\t\tif(duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) {\n",
    "\t\tif(duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5)) {\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    "\t\tconst bool three_vs_one = (duel_flags & DUEL_3_V_1) != 0;\n"
    "\t\tif(multiplayer_battle_royale_private_snapshot::\n"
    "\t\t\t\tShouldBroadcastMaskedSnapshot(battle_royale, three_vs_one)) {\n",
    "\t\tconst bool three_vs_one = (duel_flags & DUEL_3_V_1) != 0;\n"
    "\t\tconst bool two_vs_one_big5 = (duel_flags & DUEL_2_V_1_BIG5) != 0;\n"
    "\t\tif(multiplayer_battle_royale_private_snapshot::\n"
    "\t\t\t\tShouldBroadcastMaskedSnapshot(battle_royale, three_vs_one || two_vs_one_big5)) {\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    "\tconst bool logical_selector = playerid >= 2 && logical_player < players.home_size + players.opposing_size\n"
    "\t\t&& (((duel_flags & DUEL_3_V_1) && playerid < 5)\n"
    "\t\t\t|| ((duel_flags & DUEL_BATTLE_ROYALE) && playerid < 6));\n",
    "\tconst bool logical_selector = playerid >= 2 && logical_player < players.home_size + players.opposing_size\n"
    "\t\t&& (((duel_flags & DUEL_3_V_1) && playerid < 5)\n"
    "\t\t\t|| ((duel_flags & DUEL_2_V_1_BIG5) && playerid < 4)\n"
    "\t\t\t|| ((duel_flags & DUEL_BATTLE_ROYALE) && playerid < 6));\n",
)

# Anime starting LP: Joey/Yugi 4000 each; the Big Five body 8000.
replace_once(
    "gframe/generic_duel.cpp",
    "\tOCG_Player team = { host_info.start_lp, host_info.start_hand, host_info.draw_count };\n"
    "\tpduel = mainGame->SetupDuel({ { seed[0], seed[1], seed[2], seed[3] }, opt, team, team });\n",
    "\tconst bool two_vs_one_big5 = (duel_flags & DUEL_2_V_1_BIG5) != 0;\n"
    "\tconst uint32_t home_start_lp = two_vs_one_big5 ? 4000u : host_info.start_lp;\n"
    "\tconst uint32_t opposing_start_lp = two_vs_one_big5 ? 8000u : host_info.start_lp;\n"
    "\tOCG_Player team_home = { home_start_lp, host_info.start_hand, host_info.draw_count };\n"
    "\tOCG_Player team_opposing = { opposing_start_lp, host_info.start_hand, host_info.draw_count };\n"
    "\tpduel = mainGame->SetupDuel({ { seed[0], seed[1], seed[2], seed[3] }, opt, team_home, team_opposing });\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    "\tlast_replay.Write<uint32_t>(host_info.start_lp, false);\n",
    "\tlast_replay.Write<uint32_t>(home_start_lp, false);\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    "\tBufferIO::Write<uint32_t>(pbuf, host_info.start_lp);\n"
    "\tBufferIO::Write<uint32_t>(pbuf, host_info.start_lp);\n",
    "\tBufferIO::Write<uint32_t>(pbuf, home_start_lp);\n"
    "\tBufferIO::Write<uint32_t>(pbuf, opposing_start_lp);\n",
)

print("Applied isolated 2v1 Big Five client/server wiring on 137c63b")
