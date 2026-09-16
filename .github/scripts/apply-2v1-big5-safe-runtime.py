from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / "ocgcore"


def replace_once(root, path, old, new):
    p = root / path
    text = p.read_text(encoding="utf-8")
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{p}: expected one replacement site, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# Keep the original composite 2v1 flag from the last build that is known to
# launch. The bug was not the inherited 3v1 plumbing itself: UpdateDuelParam
# discarded the scenario's high marker and left only DUEL_3_V_1 at runtime.
replace_once(
    ROOT,
    "gframe/game.cpp",
    "\tconst auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "\tconst bool two_vs_one_big5 = (duel_param & DUEL_2_V_1_BIG5) == DUEL_2_V_1_BIG5;\n"
    "\tconst auto multiplayer_mode = two_vs_one_big5 ? DUEL_2_V_1_BIG5\n"
    "\t\t: duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
)

# Before the first logical-turn packet arrives, the client used to seed every
# mode carrying the 3v1 bit as four active logical players. Big Five 2v1 has
# exactly three: Joey, Yugi, Big Five.
replace_once(
    ROOT,
    "gframe/duelclient.cpp",
    "\t\tmainGame->dInfo.active_player_mask = (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
    "\t\tmainGame->dInfo.active_player_mask = mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) ? 0x07\n"
    "\t\t\t: (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
)

# The multiplayer HUD inherited the four-player loop. Draw only the actual
# number of network/logical duelists in 2v1 while preserving four for BR/3v1.
replace_once(
    ROOT,
    "gframe/drawing.cpp",
    "\tif(dInfo.HasFieldFlag(DUEL_3_V_1) || dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n"
    "\t\tconst auto& team1_names = dInfo.isTeam1 ? dInfo.selfnames : dInfo.opponames;\n",
    "\tif(dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t|| dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t|| dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n"
    "\t\tconst auto& team1_names = dInfo.isTeam1 ? dInfo.selfnames : dInfo.opponames;\n",
)
replace_once(
    ROOT,
    "gframe/drawing.cpp",
    "\t\tfor(uint8_t logical = 0; logical < 4; ++logical) {\n",
    "\t\tconst uint8_t logical_player_count = static_cast<uint8_t>(\n"
    "\t\t\tstd::min(4, dInfo.team1 + dInfo.team2));\n"
    "\t\tfor(uint8_t logical = 0; logical < logical_player_count; ++logical) {\n",
)

# Critical crash fix: the wire snapshot is intentionally fixed at four slots,
# but the fourth slot is inactive in 2v1. The old code mapped logical 3 through
# field_side_of()/duelist_index_of() and then indexed player[0xff], producing
# the huge bogus P4 LP seen in the screenshot and corrupting memory. Preserve
# the fixed packet size by serializing six zero uint32 values for inactive slots.
replace_once(
    CORE,
    "processor.cpp",
    "\t\t\t\tfor(uint8_t logical = 0; logical < MultiplayerState::MAX_PLAYERS; ++logical) {\n"
    "\t\t\t\t\tconst auto side = multiplayer.field_side_of(logical);\n"
    "\t\t\t\t\tconst auto duelist = multiplayer.duelist_index_of(logical);\n"
    "\t\t\t\t\tconst auto logical_lp = get_logical_lp(side, duelist);\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(logical_lp > 0\n"
    "\t\t\t\t\t\t? static_cast<uint32_t>(logical_lp) : 0u);\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_DECK, duelist).size());\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_HAND, duelist).size());\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_EXTRA, duelist).size());\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_GRAVE, duelist).size());\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_REMOVED, duelist).size());\n"
    "\t\t\t\t}\n",
    "\t\t\t\tfor(uint8_t logical = 0; logical < MultiplayerState::MAX_PLAYERS; ++logical) {\n"
    "\t\t\t\t\tif(!multiplayer.is_active(logical)) {\n"
    "\t\t\t\t\t\tfor(uint8_t field = 0; field < 6; ++field)\n"
    "\t\t\t\t\t\t\tlogical_message->write<uint32_t>(0u);\n"
    "\t\t\t\t\t\tcontinue;\n"
    "\t\t\t\t\t}\n"
    "\t\t\t\t\tconst auto side = multiplayer.field_side_of(logical);\n"
    "\t\t\t\t\tconst auto duelist = multiplayer.duelist_index_of(logical);\n"
    "\t\t\t\t\tconst auto logical_lp = get_logical_lp(side, duelist);\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(logical_lp > 0\n"
    "\t\t\t\t\t\t? static_cast<uint32_t>(logical_lp) : 0u);\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_DECK, duelist).size());\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_HAND, duelist).size());\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_EXTRA, duelist).size());\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_GRAVE, duelist).size());\n"
    "\t\t\t\t\tlogical_message->write<uint32_t>(get_logical_list(side, LOCATION_REMOVED, duelist).size());\n"
    "\t\t\t\t}\n",
)

print("Applied startup-safe Big Five 2v1 runtime/P4 snapshot fix")
