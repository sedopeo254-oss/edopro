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


# GenericDuel must classify the independent 2v1 flag as multiplayer. Otherwise
# the server falls back to Standard response routing even though the Core is
# sending logical-player prompts.
replace_once(
    "gframe/generic_duel.cpp",
    "\treturn duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "\treturn duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5);\n",
)

# Any per-logical-player deck/response state used by the protected multiplayer
# server path must also be enabled for 2v1. Existing BR/3v1 behavior is unchanged.
replace_once(
    "gframe/generic_duel.cpp",
    "\t\tif(duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) {\n",
    "\t\tif(duel_flags & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5)) {\n",
)

# Private logical pile snapshots are required for Joey/Yugi's independent
# Hand/Deck/Extra/GY/Banish state just as for the protected team-vs-one path.
replace_once(
    "gframe/generic_duel.cpp",
    "\t\tconst bool battle_royale = (duel_flags & DUEL_BATTLE_ROYALE) != 0;\n"
    "\t\tconst bool three_vs_one = (duel_flags & DUEL_3_V_1) != 0;\n"
    "\t\tif(multiplayer_battle_royale_private_snapshot::\n"
    "\t\t\t\tShouldBroadcastMaskedSnapshot(battle_royale, three_vs_one)) {\n",
    "\t\tconst bool battle_royale = (duel_flags & DUEL_BATTLE_ROYALE) != 0;\n"
    "\t\tconst bool team_vs_one = (duel_flags & (DUEL_3_V_1 | DUEL_2_V_1_BIG5)) != 0;\n"
    "\t\tif(multiplayer_battle_royale_private_snapshot::\n"
    "\t\t\t\tShouldBroadcastMaskedSnapshot(battle_royale, team_vs_one)) {\n",
)

# Logical prompt IDs are 2+logical_player. In Big Five 2v1 only Joey/Yugi use
# synthetic selectors (2 and 3); Big Five is the physical solo side (1).
replace_once(
    "gframe/generic_duel.cpp",
    "\tconst bool logical_selector = playerid >= 2 && logical_player < players.home_size + players.opposing_size\n"
    "\t\t&& (((duel_flags & DUEL_3_V_1) && playerid < 5)\n"
    "\t\t\t|| ((duel_flags & DUEL_BATTLE_ROYALE) && playerid < 6));\n",
    "\tconst bool logical_selector = playerid >= 2 && logical_player < players.home_size + players.opposing_size\n"
    "\t\t&& (((duel_flags & DUEL_2_V_1_BIG5) && playerid < 4)\n"
    "\t\t\t|| ((duel_flags & DUEL_3_V_1) && playerid < 5)\n"
    "\t\t\t|| ((duel_flags & DUEL_BATTLE_ROYALE) && playerid < 6));\n",
)

print("Applied isolated Big Five 2v1 server response routing")
