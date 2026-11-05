#!/usr/bin/env python3
"""Static integration guard for Inherited Duel Mode live handoff.

A real takeover scenario still needs end-to-end engine, lobby and replay tests.
This script intentionally does not claim those unimplemented features work.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[2]

def has(path: str, fragment: str) -> None:
    data = (root / path).read_text(encoding="utf-8")
    assert fragment in data, f"{path} lost expected integration: {fragment}"

core_flags = (root / "ocgcore/ocgapi_constants.h").read_text(encoding="utf-8")
assert "#define DUEL_INHERITED_DUEL    0x8000000000ULL" in core_flags
assert "#define MSG_DUEL_SUCCESSION 197" in core_flags
has("gframe/game.cpp", 'cbMultiplayerMode->addItem(L"Inherited Duel Mode");')
has("gframe/game.cpp", "duel_param |= DUEL_INHERITED_DUEL;")
has("gframe/netserver.cpp", "multiplayer_flags & (multiplayer_flags - 1)")
has("gframe/netserver.cpp", "multiplayer_flags == DUEL_INHERITED_DUEL")
has("gframe/netserver.cpp", "pkt.info.team1 = 2;")
has("gframe/netserver.cpp", "pkt.info.team2 = 1;")
has("gframe/game.h", "succession_controller_generation[2]")
has("gframe/duelclient.cpp", "case MSG_DUEL_SUCCESSION:")
has("gframe/duelclient.cpp", "if(len != 10")
has("gframe/replay_mode.cpp", "case MSG_DUEL_SUCCESSION:")
has("ocgcore/field.cpp", "succession.configure(")
has("ocgcore/field.h", "DuelSuccessionState succession;")
has("ocgcore/duel_succession.h", "bool request(")
has("ocgcore/duel_succession.h", "bool commit(")
has("gframe/game.cpp", 'cbMultiplayerMode->addItem(L"Inherited Duel Mode");')
has("ocgcore/libduel.cpp", "playerid == 1 && reason == 0x16")
has("ocgcore/libduel.cpp", "complete_inherited_succession()")
has("ocgcore/field.cpp", "bool field::complete_inherited_succession()")
has("ocgcore/field.cpp", "DuelSuccessionTransfer::preflight(")
has("ocgcore/field.cpp", "pduel->new_message(MSG_TAG_SWAP)")
has("ocgcore/field.cpp", "pduel->new_message(MSG_DUEL_SUCCESSION)")
has("ocgcore/processor.cpp", "&& !is_flag(DUEL_INHERITED_DUEL)")
has("gframe/generic_duel.cpp", "bool GenericDuel::IsInheritedDuelMode() const")
has("gframe/generic_duel.cpp", "DuelPlayer* successor = IsInheritedDuelMode()")
netserver = (root / "gframe/netserver.cpp").read_text(encoding="utf-8")
mode_start = netserver.index("} else if(multiplayer_flags == DUEL_INHERITED_DUEL) {")
mode_end = netserver.index("\n\t\t}", mode_start)
mode = netserver[mode_start:mode_end]
assert "pkt.info.team1 = 2;" in mode and "pkt.info.team2 = 1;" in mode, (
    "Inherited Duel must reserve Kaiba+Yugi against Noah"
)

print("Inherited Duel Mode stage 1 integration: PASS")
