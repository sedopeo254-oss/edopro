#!/usr/bin/env python3
"""Cross-repository live handoff contract checks. All behavior opt-in."""
from pathlib import Path
r=Path(__file__).resolve().parents[2]
def read(name):
    return (r/name).read_text(encoding="utf-8")
def require(file,needle):
    assert needle in read(file), f"{file} missing {needle!r}"

# New mode exists separately; prior modes must keep their own identifiers.
for word in ("DUEL_BATTLE_ROYALE","DUEL_3_V_1","DUEL_INHERITED_DUEL"):
    require("ocgcore/ocgapi_constants.h",word)
require("gframe/netserver.cpp","pkt.info.team1 = 2;")
require("gframe/netserver.cpp","multiplayer_flags == DUEL_INHERITED_DUEL")
require("gframe/game.cpp",'cbMultiplayerMode->addItem(L"Inherited Duel Mode");')
require("gframe/generic_duel.cpp","void GenericDuel::IsInheritedMode() const")
require("gframe/generic_duel.cpp","cur_player[0] = players.home_iterator->player;")
require("gframe/generic_duel.cpp","if(IsInheritedMode() && dp != response_player)")
require("gframe/generic_duel.cpp","if(IsInheritedMode() && dp != cur_player[0] && dp != cur_player[1])")
require("gframe/generic_duel.cpp","else if(IsInheritedMode())")
require("gframe/duelclient.cpp","case MSG_DUEL_SUCCESSION:")
require("gframe/duelclient.cpp","current_player[mainGame->LocalPlayer(inherited_side)] = 1;")
require("gframe/replay_mode.cpp","case MSG_DUEL_SUCCESSION:")
require("ocgcore/libduel.cpp","reason == 0x16")
require("ocgcore/libduel.cpp","DuelSuccessionPhase::AWAITING_SUCCESSOR")
require("ocgcore/libduel.cpp","if(pduel->game_field->succession.enabled())")
require("ocgcore/field.cpp","bool field::commit_inherited_duel_succession(uint32_t next_turn)")
require("ocgcore/field.cpp","side.list_main.insert(")
require("ocgcore/field.cpp","side.list_extra.insert(")
require("ocgcore/field.cpp","MSG_DUEL_SUCCESSION")
require("ocgcore/processor.cpp","if(!commit_inherited_duel_succession(infos.turn_id))")
require("ocgcore/processor.cpp","!succession.enabled()")
print("Inherited Duel Live Handoff integration guards: PASS")
