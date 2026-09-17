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


# Mirror the Core's composite scenario flag. The DUEL_3_V_1 bit is inherited
# deliberately so all already-proven team/private-pile transport remains intact.
replace_once(
    "gframe/ocgapi_constants.h",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n",
    "#define DUEL_BATTLE_ROYALE     0x2000000000\n#define DUEL_3_V_1             0x4000000000\n#define DUEL_2_V_1_BIG5        (DUEL_3_V_1 | 0x8000000000ULL)\n",
)

# Add the mode without changing the three existing choices. Check the full
# composite before the generic 3v1 bit so it never appears as 3v1 in the UI.
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

# Custom-rule refresh must preserve the scenario's extra high bit. Losing it was
# one of the previous reasons the lobby silently fell back to generic 3v1.
replace_once(
    "gframe/game.cpp",
    "\tconst auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "\tconst auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5);\n",
)

# LAN/Local-AI room topology: exactly Joey + Yugi against one Big Five seat.
# The exact composite check MUST be before generic DUEL_3_V_1.
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

# The physical core has two sides, but side 0 contains two flattened logical
# fields in this scenario. P3 is explicitly zeroed and never displayed.
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

# Do not create a fourth active logical player just because the inherited 3v1
# bit is present.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tmainGame->dInfo.active_player_mask = (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
    "\t\tmainGame->dInfo.active_player_mask = mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) ? 0x07\n"
    "\t\t\t: (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
)

# Show exactly team1+team2 HUD panels. Existing BR and 3v1 remain four, while
# Big Five 2v1 becomes three. This is the only HUD cardinality change.
replace_once(
    "gframe/drawing.cpp",
    "\t\tfor(uint8_t logical = 0; logical < 4; ++logical) {\n",
    "\t\tconst uint8_t logical_player_count = static_cast<uint8_t>(\n"
    "\t\t\t(dInfo.team1 + dInfo.team2) < 4 ? (dInfo.team1 + dInfo.team2) : 4);\n"
    "\t\tfor(uint8_t logical = 0; logical < logical_player_count; ++logical) {\n",
)

# The inherited 3v1 swap machinery already uses team1 dynamically (2 here), so
# only the label needs a scenario-first check.
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

# Starting LP: Joey/Yugi 4000 each (logical piles), Big Five physical side 8000.
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

print("Applied safe Yugi & Joey vs Big Five 2v1 client/server patch")
