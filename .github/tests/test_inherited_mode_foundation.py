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
# The Windows client vendors its own API header: both copies must agree.
client_flags = (root / "gframe/ocgapi_constants.h").read_text(encoding="utf-8")
for key in ("DUEL_INHERITED_DUEL", "MSG_DUEL_SUCCESSION",
            "DUEL_BATTLE_ROYALE", "DUEL_3_V_1"):
    def definition(content):
        for line in content.splitlines():
            pieces = line.split()
            if len(pieces) >= 3 and pieces[0] == "#define" and pieces[1] == key:
                return pieces[2]
        raise AssertionError(f"Missing {key} definition")
    assert definition(core_flags) == definition(client_flags), (
        f"Windows client/core API mismatch for {key}"
    )
has("gframe/game.cpp", 'cbMultiplayerMode->addItem(L"Inherited Duel Mode");')
has("gframe/game.cpp", "duel_param |= DUEL_INHERITED_DUEL;")
has("gframe/netserver.cpp", "multiplayer_flags & (multiplayer_flags - 1)")
has("gframe/netserver.cpp", "multiplayer_flags == DUEL_INHERITED_DUEL")
has("gframe/netserver.cpp", "pkt.info.team1 = 2;")
has("gframe/netserver.cpp", "pkt.info.team2 = 1;")
has("gframe/game.h", "succession_controller_generation[2]")
# Inherited Duel must use full-width name rows for ALL 3 seats. This fixes
# cropped leading characters on the opponent side, while preserving the
# historical HUD renderer for Standard, Battle Royale and 3v1.
has("gframe/drawing.cpp", "if(inherited_hud) {")
has("gframe/drawing.cpp", "auto DrawCurrentInheritedName =")
has("gframe/drawing.cpp", "inherited_duel_hud::VisibleName(")
has("gframe/drawing.cpp", "dInfo.succession_controller_generation[0]")
has("gframe/drawing.cpp", "const auto rect = Resize(left ? 335 : 695, 31, left ? 629 : 986, 50);")
has("gframe/drawing.cpp", "DrawCurrentInheritedName(self, true, dInfo.isTeam1);")
has("gframe/drawing.cpp", "DrawCurrentInheritedName(oppo, false, !dInfo.isTeam1);")
# The classic two-side drawing branch must keep its own loop index;
# this is compiled on Windows even when the new HUD branch is selected.
has("gframe/drawing.cpp", """} else {
		int i = 0;
		for (const auto& player : self) {""")
has("gframe/drawing.cpp", "const auto visible_self_rows = inherited_hud ? 1u : self.size();")
has("gframe/drawing.cpp", "const auto visible_oppo_rows = inherited_hud ? 1u : oppo.size();")
has("gframe/inherited_duel_hud.h", "inline const std::wstring& VisibleName(")

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
