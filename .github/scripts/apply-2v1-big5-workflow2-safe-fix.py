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


# IMPORTANT: this patch is deliberately based on the known-good Workflow #2
# composite-flag design. 2v1 keeps inheriting the already-tested 3v1 plumbing;
# we only distinguish it at the few places where 3 players and 4 players differ.

# 1) Reloading custom duel rules must preserve BOTH bits of the composite
# DUEL_2_V_1_BIG5 flag. The old mask kept only DUEL_3_V_1, silently turning
# 2v1 into ordinary 3v1 before the room was created.
replace_once(
    "gframe/game.cpp",
    "\tconst auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "\tconst auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_2_V_1_BIG5);\n",
)

# 2) Before the first logical-turn packet arrives, 2v1 has exactly three
# active logical players. Pure 3v1 and Battle Royale stay at four.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tmainGame->dInfo.active_player_mask = (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
    "\t\tmainGame->dInfo.active_player_mask = mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) ? 0x07\n"
    "\t\t\t: (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
)

# 3) The multiplayer HUD in the protected modes normally renders four logical
# panels. Big Five 2v1 has only Joey, Yugi and Big Five, so do not create P4.
replace_once(
    "gframe/drawing.cpp",
    "\t\t};\n"
    "\t\tfor(uint8_t logical = 0; logical < 4; ++logical) {\n"
    "\t\t\tconst irr::s32 left = 330 + logical * 165;\n",
    "\t\t};\n"
    "\t\tconst uint8_t logical_player_count = dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) ? 3 : 4;\n"
    "\t\tfor(uint8_t logical = 0; logical < logical_player_count; ++logical) {\n"
    "\t\t\tconst irr::s32 left = 330 + logical * 165;\n",
)

# 4) Core logical-turn snapshots use a fixed four-slot wire format so existing
# clients/replays stay compatible. Big Five 2v1 alone has an intentionally
# inactive fourth slot. Zero ONLY that mode's inactive slot before translating
# side/duelist IDs. This deliberately leaves eliminated-player snapshots in
# Battle Royale and protected 3v1 on their exact pre-existing behavior.
# In this Core revision Turn/phase processing lives in processor.cpp.
replace_once(
    "ocgcore/processor.cpp",
    "\t\t\t\tfor(uint8_t logical = 0; logical < MultiplayerState::MAX_PLAYERS; ++logical) {\n"
    "\t\t\t\t\tconst auto side = multiplayer.field_side_of(logical);\n"
    "\t\t\t\t\tconst auto duelist = multiplayer.duelist_index_of(logical);\n",
    "\t\t\t\tfor(uint8_t logical = 0; logical < MultiplayerState::MAX_PLAYERS; ++logical) {\n"
    "\t\t\t\t\tif(multiplayer.is_two_vs_one_big5()) {\n"
    "\t\t\t\t\t\tif(!multiplayer.is_active(logical)) {\n"
    "\t\t\t\t\t\t\tfor(uint8_t value = 0; value < 6; ++value)\n"
    "\t\t\t\t\t\t\t\tlogical_message->write<uint32_t>(0);\n"
    "\t\t\t\t\t\t\tcontinue;\n"
    "\t\t\t\t\t\t}\n"
    "\t\t\t\t\t}\n"
    "\t\t\t\t\tconst auto side = multiplayer.field_side_of(logical);\n"
    "\t\t\t\t\tconst auto duelist = multiplayer.duelist_index_of(logical);\n",
)

print("Applied minimal Workflow #2 Big Five 2v1 safety fix")
