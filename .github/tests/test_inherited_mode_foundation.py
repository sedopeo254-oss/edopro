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
has("gframe/netserver.cpp", "pkt.info.team2 = 2;")
has("gframe/game.h", "succession_controller_generation[2]")
# Inherited Duel uses full-width name rows for all four seats. This fixes
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

# The role captions live in their own label widgets. Never overwrite
# stHostPrepDuelist names, which EDOPro serializes into YRPX.
has("gframe/game.h", "stInheritedSeatRole[3]")
has("gframe/game.cpp", "stInheritedSeatRole[i] = env->addStaticText(")
has("gframe/game.h", "stInheritedSeatRole[4]")
has("gframe/duelclient.cpp", "const bool inherited_lobby =")
has("gframe/duelclient.cpp", "stInheritedSeatRole[i]->setText(inherited_lobby")
has("gframe/duelclient.cpp", "inherited_duel_lobby::SeatCaption(")
has("gframe/duelclient.cpp", "const int row = inherited_lobby ? 65 + i * 35")
has("gframe/inherited_duel_lobby.h", "STARTER_FIRST_CHOICE = 1")
has("gframe/inherited_duel_lobby.h", "OPPONENT_SUCCESSOR_SEAT = 3")
has("gframe/generic_duel.cpp", "void GenericDuel::StartInheritedDuel() {")
has("gframe/generic_duel.cpp", "TPResult(starter, inherited_duel_lobby::STARTER_FIRST_CHOICE);")
has("gframe/generic_duel.cpp", "if(IsInheritedDuelMode() && (players.home.empty() || dp != players.home.front().player))")
has("gframe/generic_duel.h", "void StartInheritedDuel();")
# Default RPS is still available to Standard, while the special mode bypasses
# it and starts via a server-side TPResult for the original Kaiba seat.
server = (root / "gframe/generic_duel.cpp").read_text(encoding="utf-8")
start_duel = server[server.index("void GenericDuel::StartDuel("):server.index("void GenericDuel::HandResult(")]
assert start_duel.index("if(IsInheritedDuelMode())") < start_duel.index("STOC_SELECT_HAND"), (
    "Inherited Duel must start before the normal RPS handshake"
)

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
# The anime Last Turn override must never silently replace other modes.
has("multiplayer-inherited-duel/c28566710.lua", "Duel.IsDuelType(DUEL_INHERITED_DUEL)")
has("multiplayer-inherited-duel/c28566710.lua", "Duel.SummonDeckMasterPlayer(opponent,POS_FACEUP_ATTACK)")
has("multiplayer-inherited-duel/c28566710.lua", "function s.checkop_legacy(")
has("multiplayer-inherited-duel/c28566710.lua", "function s.checkop_inherited(")
has("multiplayer-deck-master/c153000000.lua", "function Duel.SummonDeckMasterPlayer(p,position)")
has("multiplayer-deck-master/c153000000.lua", "position or POS_FACEUP")
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
assert "pkt.info.team1 = 2;" in mode and "pkt.info.team2 = 2;" in mode, (
    "Inherited Duel reserves Kaiba+Yugi against Noah+second Noah"
)

# Succession is an uninterrupted takeover, not a user-confirmed dialog.
client = (root / "gframe/duelclient.cpp").read_text(encoding="utf-8")
succession_case = client.split("case MSG_DUEL_SUCCESSION: {", 1)[1].split(
    "case MSG_PLAYER_ELIMINATED: {", 1)[0]
assert "PopupMessage(" not in succession_case, (
    "Inherited Duel succession must not interrupt the duel with a modal"
)
# Inherited Duel uses physical two-side positions. Neither the attack origin
# nor a direct-attack target may depend on Battle Royale logical IDs.
has("gframe/duelclient.cpp", "const bool inherited_attack =")
has("gframe/duelclient.cpp", "if(inherited_attack)")
has("gframe/duelclient.cpp", "multiplayer_attack_arrow::OppositeDisplaySide(attacker_display)")
has("gframe/duelclient.cpp", "if(valid_logical_attack || inherited_attack)")
has("gframe/multiplayer_attack_arrow.h", "inline uint8_t OppositeDisplaySide(")

# Shinato's Ark must allow controller selection and preserve ownership after chains.
has("multiplayer-deck-master/c153000017.lua", "local picks={Duel.SelectCardsFromCodes(tp,1,ct,false,true,codes)}")
has("multiplayer-deck-master/c153000017.lua", "codes[#codes+1]=tc:GetOriginalCode()")
has("multiplayer-deck-master/c153000017.lua", "local tc=cards[pick[2]]")
has("multiplayer-deck-master/c153000017.lua", "e1:SetReset(RESET_EVENT+RESETS_STANDARD)")
ark_source = (root / "multiplayer-deck-master/c153000017.lua").read_text(encoding="utf-8")
assert "Duel.GetRandomNumber(1,#g)-1" not in ark_source
assert "g:Select(tp,1,ct,nil)" not in ark_source
assert "e1:SetReset(RESET_EVENT+RESETS_STANDARD+RESET_CHAIN)" not in ark_source

# Gradius ATK final overwrite must supersede Cyclon Laser's normal +300.
has("multiplayer-anime-cards/c5494820.lua", "e2:SetCode(EFFECT_UPDATE_ATTACK)")
has("multiplayer-anime-cards/c5494820.lua", "e2:SetValue(300)")
has("multiplayer-anime-cards/c5494820.lua", "e3:SetCode(EFFECT_PIERCE)")
has("multiplayer-anime-cards/c511000219.lua", "e3:SetCode(EFFECT_SET_ATTACK_FINAL)")
has("multiplayer-anime-cards/c511000219.lua", "return Duel.GetAttackTarget():GetDefense()+100")
# Gradius' Option anime: printed stats, linked Gradius, continuous Equip effects.
has("multiplayer-anime-cards/c14291024.lua", "c:EnableUnsummonable()")
has("multiplayer-anime-cards/c14291024.lua", "tc:GetTextAttack()")
has("multiplayer-anime-cards/c14291024.lua", "tc:GetTextDefense()")
has("multiplayer-anime-cards/c14291024.lua", "s.mirror(c,eq,eff)")
has("multiplayer-anime-cards/c14291024.lua", "EFFECT_SET_ATTACK_FINAL")
has("multiplayer-anime-cards/c14291024.lua", "return c:GetFlagEffect(id)>0 and not s.linked(c)")
# Shinato's Ark: a native graveyard redirect must finish BEFORE the Ark
# stores Gradius and its self-destroyed Option, never nested SEND_REPLACE.
ark = (root / "multiplayer-deck-master/c153000017.lua").read_text(encoding="utf-8")
assert "e1:SetCode(EFFECT_SEND_REPLACE)" not in ark, (
    "Shinato's Ark must not reenter SendTo from an active replacement")
has("multiplayer-deck-master/c153000017.lua", "local ark_active=Duel.IsDeckMaster(tp,id)")
has("multiplayer-deck-master/c153000017.lua", "c:IsLocation(LOCATION_DECK|LOCATION_EXTRA)")
has("multiplayer-deck-master/c153000017.lua", "local moved=Duel.GetOperatedGroup():Filter(")
has("multiplayer-deck-master/c153000017.lua", "e:GetLabelObject():Merge(moved)")
# Dual-sided succession: both standby decks are imported without an opening hand,
# while both clients receive a private, authenticated MSG_TAG_SWAP.
core_field = (root / "ocgcore/field.cpp").read_text(encoding="utf-8")
assert "for(uint8_t side = 0; side < 2; ++side)" in core_field
assert "imports[1 - side]" in core_field
assert "auto event = pduel->new_message(MSG_DUEL_SUCCESSION)" in core_field
core_processor = (root / "ocgcore/processor.cpp").read_text(encoding="utf-8")
assert 'if(is_flag(DUEL_INHERITED_DUEL))' in core_processor
has("gframe/generic_duel.cpp", "players.opposing.size() != 2")
has("gframe/generic_duel.cpp", "players.opposing[1].player")
has("gframe/generic_duel.cpp", "players.opposing_iterator == players.opposing.begin() + 1")
has("gframe/drawing.cpp", "dInfo.succession_controller_generation[core_side]")
has("gframe/inherited_duel_hud.h", "generation > 0")
print("Inherited Duel 2+2 dual-sided succession integration: PASS")
