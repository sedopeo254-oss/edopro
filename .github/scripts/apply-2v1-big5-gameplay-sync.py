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
        if new in text:
            return
        raise SystemExit(f"{path}: expected at least {minimum} replacement site(s), found 0")
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f"{path}: expected at least {minimum} replacement site(s), found {count}")
    write(path, text.replace(old, new))

# ---------------------------------------------------------------------------
# 1) Visual field <-> encoded field mapping.
# The client draws only the focused 7/8-zone slice, but every command sent
# back to Core must still point at the real encoded Joey/Yugi sequence.
# ---------------------------------------------------------------------------
replace_once(
    "gframe/event_handler.cpp",
    "\t\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
    "\t\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)) {\n",
)
replace_once(
    "gframe/event_handler.cpp",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tconst auto core_side = mainGame->LocalPlayer(controler);\n"
    "\t\t\t\tconst auto field_count = core_side == 0\n",
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n"
    "\t\t\t\tconst auto core_side = mainGame->LocalPlayer(controler);\n"
    "\t\t\t\tconst auto field_count = core_side == 0\n",
)
replace_once(
    "gframe/event_handler.cpp",
    "\t\t} else if(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t&& (hovered_location == LOCATION_MZONE || hovered_location == LOCATION_SZONE)) {\n",
    "\t\t} else if((mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\t&& (hovered_location == LOCATION_MZONE || hovered_location == LOCATION_SZONE)) {\n",
)
replace_once(
    "gframe/event_handler.cpp",
    "\t\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n"
    "\t\t\t\t\t&& logical < mainGame->dInfo.team1 + mainGame->dInfo.team2) {\n",
    "\t\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))\n"
    "\t\t\t\t\t&& logical < mainGame->dInfo.team1 + mainGame->dInfo.team2) {\n",
)

# ---------------------------------------------------------------------------
# 2) Deck Master + atomic Joey/Yugi swap.
# The focused field and that logical player's private projection move together.
# ---------------------------------------------------------------------------
replace_once(
    "gframe/client_field.cpp",
    "void ClientField::RefreshLogicalDeckMasters() {\n"
    "\tif(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t|| !mainGame->dInfo.logical_deck_master_enabled)\n",
    "void ClientField::RefreshLogicalDeckMasters() {\n"
    "\tif(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t|| !mainGame->dInfo.logical_deck_master_enabled)\n",
)
replace_once(
    "gframe/client_field.cpp",
    "void ClientField::CycleTeamField() {\n"
    "\tif(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t|| mainGame->dInfo.team1 < 2)\n"
    "\t\treturn;\n"
    "\tmainGame->dInfo.field_focus[0] = static_cast<uint8_t>(\n"
    "\t\t(mainGame->dInfo.field_focus[0] + 1) % mainGame->dInfo.team1);\n"
    "\thovered_card = nullptr;\n"
    "\thovered_location = 0;\n"
    "\thovered_sequence = 0;\n"
    "\tRefreshAllCards();\n"
    "}\n",
    "void ClientField::CycleTeamField() {\n"
    "\tif(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) || mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t|| mainGame->dInfo.team1 < 2)\n"
    "\t\treturn;\n"
    "\tmainGame->dInfo.field_focus[0] = static_cast<uint8_t>(\n"
    "\t\t(mainGame->dInfo.field_focus[0] + 1) % mainGame->dInfo.team1);\n"
    "\thovered_card = nullptr;\n"
    "\thovered_location = 0;\n"
    "\thovered_sequence = 0;\n"
    "\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)) {\n"
    "\t\tconst auto logical = mainGame->dInfo.GetFocusedLogicalPlayer(0);\n"
    "\t\tconst auto display_side = mainGame->LocalPlayer(0);\n"
    "\t\tif(logical < multiplayer_private_piles.size()\n"
    "\t\t\t\t&& multiplayer_private_piles_valid[logical])\n"
    "\t\t\tReplaceMultiplayerPrivatePiles(display_side,\n"
    "\t\t\t\tmultiplayer_private_piles[logical], false);\n"
    "\t}\n"
    "\tRefreshAllCards();\n"
    "}\n",
)

# ---------------------------------------------------------------------------
# 3) Live private-pile sync for 2v1.
# Every logical snapshot is cached; only the focused logical player is projected.
# Non-owners receive the already-masked snapshot from the server.
# ---------------------------------------------------------------------------
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif(mainGame->dInfo.isReplay\n"
    "\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {\n",
    "\t\tif(!mainGame->dInfo.isReplay\n"
    "\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)) {\n"
    "\t\t\tmainGame->dField.CacheMultiplayerPrivatePiles(logical_player, snapshot);\n"
    "\t\t\tconst auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);\n"
    "\t\t\tif(core_side < 2\n"
    "\t\t\t\t\t&& mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player) {\n"
    "\t\t\t\tauto lock = LockIf();\n"
    "\t\t\t\tmainGame->dField.ReplaceMultiplayerPrivatePiles(\n"
    "\t\t\t\t\tmainGame->LocalPlayer(core_side), snapshot, false);\n"
    "\t\t\t\tmainGame->dField.RefreshAllCards();\n"
    "\t\t\t}\n"
    "\t\t\treturn true;\n"
    "\t\t}\n"
    "\t\tif(mainGame->dInfo.isReplay\n"
    "\t\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))) {\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\t} else if(multiplayer_battle_royale_live::Enabled(\n"
    "\t\t\t\tmainGame->dInfo.isReplay,\n"
    "\t\t\t\tmainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))) {\n",
    "\t\t} else if(!mainGame->dInfo.isReplay\n"
    "\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)) {\n"
    "\t\t\tconst auto core_side = mainGame->dInfo.GetLogicalCoreSide(logical_player);\n"
    "\t\t\tconst bool displayed = core_side < 2\n"
    "\t\t\t\t&& mainGame->dInfo.GetFocusedLogicalPlayer(core_side) == logical_player;\n"
    "\t\t\tif(logical_player < mainGame->dField.multiplayer_private_piles_valid.size()\n"
    "\t\t\t\t\t&& mainGame->dField.multiplayer_private_piles_valid[logical_player]) {\n"
    "\t\t\t\tmainGame->dField.UpdateMultiplayerPrivateDraw(logical_player, drawn_cards);\n"
    "\t\t\t\tif(displayed) {\n"
    "\t\t\t\t\tauto lock = LockIf();\n"
    "\t\t\t\t\tmainGame->dField.ReplaceMultiplayerPrivatePiles(\n"
    "\t\t\t\t\t\tmainGame->LocalPlayer(core_side),\n"
    "\t\t\t\t\t\tmainGame->dField.multiplayer_private_piles[logical_player], false);\n"
    "\t\t\t\t\tmainGame->dField.RefreshAllCards();\n"
    "\t\t\t\t}\n"
    "\t\t\t}\n"
    "\t\t\tsounds = displayed ? count : 0;\n"
    "\t\t} else if(multiplayer_battle_royale_live::Enabled(\n"
    "\t\t\t\tmainGame->dInfo.isReplay,\n"
    "\t\t\t\tmainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE))) {\n",
)

# Normal MSG_DRAW is used by the currently-active saved duelist. Reconcile the
# 2v1 cache after the standard animation so later Swap cannot restore stale piles.
replace_once(
    "gframe/duelclient.cpp",
    "\t\tmainGame->dField.CaptureBattleRoyaleReplayPrivatePiles();\n"
    "\t\treturn true;\n"
    "\t}\n"
    "\tcase MSG_MULTIPLAYER_DRAW: {\n",
    "\t\tmainGame->dField.CaptureBattleRoyaleReplayPrivatePiles();\n"
    "\t\tif(!mainGame->dInfo.isReplay\n"
    "\t\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t&& logical_player < mainGame->dField.multiplayer_private_piles.size()) {\n"
    "\t\t\tMultiplayerPrivatePileSnapshot snapshot;\n"
    "\t\t\tsnapshot.deck_count = static_cast<uint32_t>(mainGame->dField.deck[player].size());\n"
    "\t\t\tsnapshot.top_code = mainGame->dField.deck[player].empty()\n"
    "\t\t\t\t? 0u : mainGame->dField.deck[player].back()->code;\n"
    "\t\t\tsnapshot.extra_p_count = static_cast<uint32_t>(std::max(0,\n"
    "\t\t\t\tmainGame->dField.extra_p_count[player]));\n"
    "\t\t\tauto copy_pile = [](const auto& source, auto& destination) {\n"
    "\t\t\t\tfor(const auto* card : source)\n"
    "\t\t\t\t\tif(card) destination.push_back({ card->code,\n"
    "\t\t\t\t\t\tstatic_cast<uint8_t>(card->position) });\n"
    "\t\t\t};\n"
    "\t\t\tcopy_pile(mainGame->dField.hand[player], snapshot.hand);\n"
    "\t\t\tcopy_pile(mainGame->dField.extra[player], snapshot.extra);\n"
    "\t\t\tcopy_pile(mainGame->dField.grave[player], snapshot.grave);\n"
    "\t\t\tcopy_pile(mainGame->dField.remove[player], snapshot.removed);\n"
    "\t\t\tmainGame->dField.CacheMultiplayerPrivatePiles(logical_player, snapshot);\n"
    "\t\t}\n"
    "\t\treturn true;\n"
    "\t}\n"
    "\tcase MSG_MULTIPLAYER_DRAW: {\n",
)

# All Core LP messages in logical multiplayer carry an extra logical-player byte.
replace_all(
    "gframe/duelclient.cpp",
    "(DUEL_BATTLE_ROYALE | DUEL_3_V_1)",
    "(DUEL_BATTLE_ROYALE | DUEL_3_V_1 | DUEL_2_V_1_BIG5)",
    minimum=4,
)

# ---------------------------------------------------------------------------
# 4) Team-view attack arrows. 2v1 uses the same one-byte logical target wire
# extension as the protected 3v1 path, but never changes 3v1 behavior.
# ---------------------------------------------------------------------------
replace_once(
    "gframe/duelclient.cpp",
    "\tauto SetThreeVsOneView = [&](uint8_t perspective,\n"
    "\t\t\tuint8_t opponent = 0xff) {\n"
    "\t\tif(!mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n",
    "\tauto SetThreeVsOneView = [&](uint8_t perspective,\n"
    "\t\t\tuint8_t opponent = 0xff) {\n"
    "\t\tif(!(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\tconst bool has_three_vs_one_target =\n"
    "\t\t\t!mainGame->dInfo.compat_mode\n"
    "\t\t\t&& mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t&& len >= 21;\n",
    "\t\tconst bool has_three_vs_one_target =\n"
    "\t\t\t!mainGame->dInfo.compat_mode\n"
    "\t\t\t&& (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t&& len >= 21;\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)\n"
    "\t\t\t\t&& valid_logical_attack) {\n",
    "\t\tif((mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1))\n"
    "\t\t\t\t&& valid_logical_attack) {\n",
)
replace_once(
    "gframe/duelclient.cpp",
    "\t\tauto GetAttackDisplaySide = [&](uint8_t logical) {\n"
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n",
    "\t\tauto GetAttackDisplaySide = [&](uint8_t logical) {\n"
    "\t\t\tif(mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5)\n"
    "\t\t\t\t\t|| mainGame->dInfo.HasFieldFlag(DUEL_3_V_1)) {\n",
)

# 2v1 reload/replay keeps exactly two allied physical field slices.
replace_once(
    "gframe/duelclient.cpp",
    "\t\t\tconst int mzone_count = mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t? 14 : (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) && i == 0 ? 21 : 7);\n"
    "\t\t\tconst int szone_count = mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t? 16 : (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) && i == 0 ? 24 : 8);\n",
    "\t\t\tconst int mzone_count = mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t? 14 : (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) && i == 0 ? 14\n"
    "\t\t\t\t\t: (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) && i == 0 ? 21 : 7));\n"
    "\t\t\tconst int szone_count = mainGame->dInfo.HasFieldFlag(DUEL_BATTLE_ROYALE)\n"
    "\t\t\t\t? 16 : (mainGame->dInfo.HasFieldFlag(DUEL_2_V_1_BIG5) && i == 0 ? 16\n"
    "\t\t\t\t\t: (mainGame->dInfo.HasFieldFlag(DUEL_3_V_1) && i == 0 ? 24 : 8));\n",
)

# ---------------------------------------------------------------------------
# 5) Server: allied on-field cards are fully known to both Joey and Yugi, while
# private piles remain independently masked. Selection packets must not erase a
# teammate's on-field card code when it is a valid Fusion/tribute/effect target.
# ---------------------------------------------------------------------------
replace_once(
    "gframe/generic_duel.cpp",
    "void GenericDuel::Sending(CoreUtils::Packet& packet, int& return_value, bool& record, [[maybe_unused]] bool& record_last) {\n"
    "\tuint8_t& message = packet.message;\n",
    "void GenericDuel::Sending(CoreUtils::Packet& packet, int& return_value, bool& record, [[maybe_unused]] bool& record_last) {\n"
    "\tconst uint64_t active_duel_flags = static_cast<uint64_t>(host_info.duel_flag_low)\n"
    "\t\t| (static_cast<uint64_t>(host_info.duel_flag_high) << 32);\n"
    "\tconst bool two_vs_one_big5_mode = (active_duel_flags & DUEL_2_V_1_BIG5) != 0;\n"
    "\tuint8_t& message = packet.message;\n",
)
replace_all(
    "gframe/generic_duel.cpp",
    "\t\t\tif(info.controler != visible_side\n"
    "\t\t\t\t\t|| (logical_selector && info_logical != logical_player))\n"
    "\t\t\t\tBufferIO::Write<uint32_t>(pbufw, 0);\n",
    "\t\t\tconst bool shared_allied_field = two_vs_one_big5_mode\n"
    "\t\t\t\t&& visible_side == 0 && info.controler == 0\n"
    "\t\t\t\t&& (info.location & LOCATION_ONFIELD)\n"
    "\t\t\t\t&& info_logical < players.home_size;\n"
    "\t\t\tif(info.controler != visible_side\n"
    "\t\t\t\t\t|| (logical_selector && info_logical != logical_player\n"
    "\t\t\t\t\t\t&& !shared_allied_field))\n"
    "\t\t\t\tBufferIO::Write<uint32_t>(pbufw, 0);\n",
    minimum=3,
)

replace_once(
    "gframe/generic_duel.cpp",
    "void GenericDuel::RefreshLocation(uint8_t player, uint32_t flag, uint8_t location) {\n"
    "\tstd::vector<uint8_t> buffer;\n",
    "void GenericDuel::RefreshLocation(uint8_t player, uint32_t flag, uint8_t location) {\n"
    "\tconst uint64_t duel_flags = static_cast<uint64_t>(host_info.duel_flag_low)\n"
    "\t\t| (static_cast<uint64_t>(host_info.duel_flag_high) << 32);\n"
    "\tconst bool two_vs_one_big5 = (duel_flags & DUEL_2_V_1_BIG5) != 0;\n"
    "\tstd::vector<uint8_t> buffer;\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    "\tif(IsMultiplayerMode() && (location == LOCATION_MZONE || location == LOCATION_SZONE)) {\n"
    "\t\tconst auto stride = static_cast<uint8_t>(location == LOCATION_MZONE ? 7 : 8);\n",
    "\tif(IsMultiplayerMode() && (location == LOCATION_MZONE || location == LOCATION_SZONE)) {\n"
    "\t\tif(two_vs_one_big5 && player == 0) {\n"
    "\t\t\tbuffer.resize(3);\n"
    "\t\t\tquery.GenerateBuffer(buffer, false);\n"
    "\t\t\tNetServer::SendBufferToPlayer(nullptr, STOC_GAME_MSG, buffer);\n"
    "\t\t\tfor(auto& dueler : players.home)\n"
    "\t\t\t\tNetServer::ReSendToPlayer(dueler);\n"
    "\t\t\tbuffer.resize(3);\n"
    "\t\t\tquery.GeneratePublicBuffer(buffer);\n"
    "\t\t\tNetServer::SendBufferToPlayer(nullptr, STOC_GAME_MSG, buffer);\n"
    "\t\t\tfor(auto& dueler : players.opposing)\n"
    "\t\t\t\tNetServer::ReSendToPlayer(dueler);\n"
    "\t\t\tfor(auto& obs : observers)\n"
    "\t\t\t\tNetServer::ReSendToPlayer(obs);\n"
    "\t\t\tpackets_cache.emplace_back(buffer.data(), buffer.size());\n"
    "\t\t\treturn;\n"
    "\t\t}\n"
    "\t\tconst auto stride = static_cast<uint8_t>(location == LOCATION_MZONE ? 7 : 8);\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    "void GenericDuel::RefreshSingle(uint8_t player, uint8_t location, uint8_t sequence, uint32_t flag) {\n"
    "\tstd::vector<uint8_t> buffer;\n",
    "void GenericDuel::RefreshSingle(uint8_t player, uint8_t location, uint8_t sequence, uint32_t flag) {\n"
    "\tconst uint64_t duel_flags = static_cast<uint64_t>(host_info.duel_flag_low)\n"
    "\t\t| (static_cast<uint64_t>(host_info.duel_flag_high) << 32);\n"
    "\tconst bool two_vs_one_big5 = (duel_flags & DUEL_2_V_1_BIG5) != 0;\n"
    "\tstd::vector<uint8_t> buffer;\n",
)
replace_once(
    "gframe/generic_duel.cpp",
    "\tif(IsMultiplayerMode()) {\n"
    "\t\tDuelPlayer* owner = cur_player[player];\n"
    "\t\tif(location == LOCATION_MZONE || location == LOCATION_SZONE) {\n",
    "\tif(IsMultiplayerMode()) {\n"
    "\t\tif(two_vs_one_big5 && player == 0\n"
    "\t\t\t\t&& (location == LOCATION_MZONE || location == LOCATION_SZONE)) {\n"
    "\t\t\tbuffer.resize(4);\n"
    "\t\t\tquery.GenerateBuffer(buffer, false, true);\n"
    "\t\t\tNetServer::SendBufferToPlayer(nullptr, STOC_GAME_MSG, buffer);\n"
    "\t\t\tfor(auto& dueler : players.home)\n"
    "\t\t\t\tNetServer::ReSendToPlayer(dueler);\n"
    "\t\t\tbuffer.resize(4);\n"
    "\t\t\tquery.GenerateBuffer(buffer, true, true);\n"
    "\t\t\tNetServer::SendBufferToPlayer(nullptr, STOC_GAME_MSG, buffer);\n"
    "\t\t\tfor(auto& dueler : players.opposing)\n"
    "\t\t\t\tNetServer::ReSendToPlayer(dueler);\n"
    "\t\t\tfor(auto& obs : observers)\n"
    "\t\t\t\tNetServer::ReSendToPlayer(obs);\n"
    "\t\t\tpackets_cache.emplace_back(buffer.data(), buffer.size());\n"
    "\t\t\treturn;\n"
    "\t\t}\n"
    "\t\tDuelPlayer* owner = cur_player[player];\n"
    "\t\tif(location == LOCATION_MZONE || location == LOCATION_SZONE) {\n",
)

print("Applied 2v1 gameplay sync: field projection, private piles, team selections, Deck Master and attack arrows")
