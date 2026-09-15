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
        # Idempotency: if the transformed form is already present, accept it.
        if new in text:
            return
        raise SystemExit(f"{path}: expected at least {minimum} replacement site(s), found 0")
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f"{path}: expected at least {minimum} replacement site(s), found {count}")
    write(path, text.replace(old, new))


# ---------------------------------------------------------------------------
# 1) Public flag isolation
# ---------------------------------------------------------------------------
# apply-2v1-big5-client.py historically mirrored a composite flag. Convert the
# materialized client constant to the same independent flag used by the Core.
replace_once(
    "gframe/ocgapi_constants.h",
    "#define DUEL_2_V_1_BIG5        (DUEL_3_V_1 | 0x8000000000ULL)\n",
    "#define DUEL_2_V_1_BIG5        0x8000000000ULL\n",
)

# Custom-rule refresh used to preserve only BR/3v1 and silently dropped the
# 2v1 bit. That collapse recreated protected 3v1 at runtime and spawned P4.
replace_once(
    "gframe/game.cpp",
    "\tconst auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1);\n",
    "\tconst auto multiplayer_mode = duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5);\n",
)

# Relay is incompatible with every custom logical-player mode, including 2v1.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tif(mainGame->btnRelayMode->isPressed()\n"
    "\t\t\t\t\t&& !(mainGame->duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)))\n",
    "\t\t\tif(mainGame->btnRelayMode->isPressed()\n"
    "\t\t\t\t\t&& !(mainGame->duel_param & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5)))\n",
)

# ---------------------------------------------------------------------------
# 2) Correct three-player runtime cardinality
# ---------------------------------------------------------------------------
replace_once(
    "gframe/duelclient.cpp",
    "\t\tmainGame->dInfo.active_player_mask = (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
    "\t\tmainGame->dInfo.active_player_mask = mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) ? 0x07\n"
    "\t\t\t: (mainGame->dInfo.duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1)) ? 0x0f : 0x03;\n",
)

# Draw one HUD panel per actual logical duelist. Existing modes remain 4-player
# HUDs because their team1+team2 is still four; 2v1 is exactly three.
replace_once(
    "gframe/drawing.cpp",
    "\tif(dInfo.HasFieldFlag(DUEL_3_V_1) || dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n"
    "\t\tconst auto& team1_names = dInfo.isTeam1 ? dInfo.selfnames : dInfo.opponames;\n",
    "\tif(dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t|| dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t|| dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n"
    "\t\tconst auto& team1_names = dInfo.isTeam1 ? dInfo.selfnames : dInfo.opponames;\n",
)
replace_once(
    "gframe/drawing.cpp",
    "\t\tfor(uint8_t logical = 0; logical < 4; ++logical) {\n",
    "\t\tconst uint8_t logical_player_count = static_cast<uint8_t>(\n"
    "\t\t\t(dInfo.team1 + dInfo.team2) < 4 ? (dInfo.team1 + dInfo.team2) : 4);\n"
    "\t\tfor(uint8_t logical = 0; logical < logical_player_count; ++logical) {\n",
)

# ---------------------------------------------------------------------------
# 3) Logical prompt routing and team field projection
# ---------------------------------------------------------------------------
replace_once(
    "gframe/game.h",
    "\t\tif((duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1))\n"
    "\t\t\t\t&& selecting_player >= 2 && selecting_player < 6) {\n",
    "\t\tif((duel_params & (DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5))\n"
    "\t\t\t\t&& selecting_player >= 2 && selecting_player < 6) {\n",
)

# The second allied field is encoded using the same flattened-zone scheme as
# protected 3v1/BR. Add 2v1 to those generic rendering paths only.
replace_all(
    "gframe/client_field.cpp",
    "\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
    "\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
    minimum=2,
)
replace_once(
    "gframe/client_field.cpp",
    "void ClientField::CycleTeamField() {\n"
    "\tif(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) || mainGame->dInfo.team1 < 2)\n"
    "\t\treturn;\n",
    "void ClientField::CycleTeamField() {\n"
    "\tif(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t|| mainGame->dInfo.team1 < 2)\n"
    "\t\treturn;\n",
)

# Hover/linked-zone projection must decode the second Yugi/Joey field too.
replace_all(
    "gframe/drawing.cpp",
    "dInfo.HasFieldFlag(DUEL_3_V_1) || dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)",
    "dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) || dInfo.HasFieldFlag(DUEL_3_V_1) || dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)",
    minimum=2,
)
replace_once(
    "gframe/drawing.cpp",
    "\t\t\t} else if(dInfo.HasFieldFlag(DUEL_3_V_1)) {\n",
    "\t\t\t} else if(dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t\t|| dInfo.HasFieldFlag(DUEL_3_V_1)) {\n",
)

# Swap Yugi/Joey is a live field-focus operation, distinct from BR's opponent
# cycle. The existing 3v1 button remains exactly as before.
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

# ---------------------------------------------------------------------------
# 4) Shared live multiplayer packets/selections
# ---------------------------------------------------------------------------
# Logical turn packets contain the four-slot wire snapshot, but active_mask=07
# marks slot 3 inactive. 2v1 must parse that packet just like the existing modes.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n"
    "\t\t\t\t&& len >= 2 + 4 * 6 * sizeof(uint32_t)) {\n",
    "\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n"
    "\t\t\t\t&& len >= 2 + 4 * 6 * sizeof(uint32_t)) {\n",
)

# Both lobby/start locations that expose the swap button must include 2v1.
replace_all(
    "gframe/duelclient.cpp",
    "mainGame->btnSpectatorSwap->setVisible(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE));",
    "mainGame->btnSpectatorSwap->setVisible(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE));",
    minimum=2,
)

# Card/chain selection on Joey/Yugi's encoded second field must focus the
# correct logical field before GetCard() is asked for the encoded sequence.
replace_all(
    "gframe/duelclient.cpp",
    "(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))",
    "(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))",
    minimum=1,
)

print("Applied runtime-isolated Big Five 2v1 client fix")
