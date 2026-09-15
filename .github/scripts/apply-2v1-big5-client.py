from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one replacement site, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# EDOPro carries a client-side copy of the public Core constants. Keep the new
# composite flag mirrored here as well as in ocgcore/ocgapi_constants.h so the
# GUI/server translation units compile against the same duel flag value.
replace_once(
    "gframe/ocgapi_constants.h",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n#define DUEL_2_V_1_BIG5        (DUEL_3_V_1 | 0x8000000000ULL)\n",
)

# Add scenario 1 as its own host option. The composite high bit is checked
# before the inherited 3v1 bit so the existing 3v1 entry remains unchanged.
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
    "\t\tcbMultiplayerMode->setSelected(\n"
    "\t\t\t((duel_param & DUEL_2_V_1_BIG5) == DUEL_2_V_1_BIG5) ? 3 :\n"
    "\t\t\t((duel_param & DUEL_BATTLE_ROYALE) ? 1 : ((duel_param & DUEL_3_V_1) ? 2 : 0)));\n",
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

# The local LAN server must create exactly three network seats: Joey/Yugi on
# core side 0 and the single Big Five body on core side 1.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->duel_param & DUEL_BATTLE_ROYALE) {\n"
    "\t\t\t\tcscg.info.team1 = 2;\n"
    "\t\t\t\tcscg.info.team2 = 2;\n"
    "\t\t\t\tcscg.info.duel_flag_low &= ~DUEL_RELAY;\n"
    "\t\t\t} else if(mainGame->duel_param & DUEL_3_V_1) {\n"
    "\t\t\t\tcscg.info.team1 = 3;\n"
    "\t\t\t\tcscg.info.team2 = 1;\n"
    "\t\t\t\tcscg.info.duel_flag_low &= ~DUEL_RELAY;\n"
    "\t\t\t}\n",
    "\t\t\tif((mainGame->duel_param & DUEL_2_V_1_BIG5) == DUEL_2_V_1_BIG5) {\n"
    "\t\t\t\tcscg.info.team1 = 2;\n"
    "\t\t\t\tcscg.info.team2 = 1;\n"
    "\t\t\t\tcscg.info.duel_flag_low &= ~DUEL_RELAY;\n"
    "\t\t\t} else if(mainGame->duel_param & DUEL_BATTLE_ROYALE) {\n"
    "\t\t\t\tcscg.info.team1 = 2;\n"
    "\t\t\t\tcscg.info.team2 = 2;\n"
    "\t\t\t\tcscg.info.duel_flag_low &= ~DUEL_RELAY;\n"
    "\t\t\t} else if(mainGame->duel_param & DUEL_3_V_1) {\n"
    "\t\t\t\tcscg.info.team1 = 3;\n"
    "\t\t\t\tcscg.info.team2 = 1;\n"
    "\t\t\t\tcscg.info.duel_flag_low &= ~DUEL_RELAY;\n"
    "\t\t\t}\n",
)

# MSG_START has physical-side LP values. Seed the three logical LP displays
# correctly and allocate only two teammate fields (14 MZ / 16 S/T slots), not
# the protected 3v1 mode's three fields.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tfor(uint8_t logical = 0; logical < 4; ++logical) {\n"
    "\t\t\tmainGame->dInfo.logical_lp[logical] = mainGame->dInfo.startlp;\n"
    "\t\t\tmainGame->dInfo.logical_strLP[logical] = epro::to_wstring(mainGame->dInfo.startlp);\n"
    "\t\t}\n"
    "\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\tconst auto team_side = mainGame->LocalPlayer(0);\n"
    "\t\t\tmainGame->dField.mzone[team_side].resize(21, nullptr);\n"
    "\t\t\tmainGame->dField.szone[team_side].resize(24, nullptr);\n"
    "\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
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
    "\t\t} else {\n"
    "\t\t\tfor(uint8_t logical = 0; logical < 4; ++logical) {\n"
    "\t\t\t\tmainGame->dInfo.logical_lp[logical] = mainGame->dInfo.startlp;\n"
    "\t\t\t\tmainGame->dInfo.logical_strLP[logical] = epro::to_wstring(mainGame->dInfo.startlp);\n"
    "\t\t\t}\n"
    "\t\t}\n"
    "\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t&& !mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)) {\n"
    "\t\t\tconst auto team_side = mainGame->LocalPlayer(0);\n"
    "\t\t\tmainGame->dField.mzone[team_side].resize(21, nullptr);\n"
    "\t\t\tmainGame->dField.szone[team_side].resize(24, nullptr);\n"
    "\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
)

# Give the duel-side field switch a scenario-specific label while retaining the
# exact old labels for protected 3v1 and Battle Royale.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap the Team\");\n"
    "\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n"
    "\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap the player\");\n",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5))\n"
    "\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap Yugi / Joey\");\n"
    "\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap the Team\");\n"
    "\t\t\telse if(mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n"
    "\t\t\t\tmainGame->btnSpectatorSwap->setText(L\"Swap the player\");\n",
)

# The server gives side 0 (Joey/Yugi) 4000 each and side 1 (Big Five) 8000.
# The streamed replay carries these two physical starting values in MSG_START.
replace_once(
    "gframe/generic_duel.cpp",
    "\tOCG_Player team = { host_info.start_lp, host_info.start_hand, host_info.draw_count };\n"
    "\tpduel = mainGame->SetupDuel({ { seed[0], seed[1], seed[2], seed[3] }, opt, team, team });\n",
    "\tconst bool two_vs_one_big5 = (duel_flags & DUEL_2_V_1_BIG5) == DUEL_2_V_1_BIG5;\n"
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

print("Applied Yugi & Joey vs Big Five 2v1 client/server mode")
