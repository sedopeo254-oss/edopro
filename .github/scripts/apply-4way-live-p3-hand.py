from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GENERIC = ROOT / "gframe" / "generic_duel.cpp"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one replacement site, found {count}")
    return text.replace(old, new, 1)


text = GENERIC.read_text(encoding="utf-8")

include = '#include "multiplayer_battle_royale_private_snapshot.h"\n'
if include not in text:
    text = replace_once(
        text,
        '#include "core_utils.h"\n',
        '#include "core_utils.h"\n' + include,
        "private snapshot include",
    )

old_case = '''\tcase MSG_MULTIPLAYER_PRIVATE_PILES: {
\t\tconst auto logical_player = BufferIO::Read<uint8_t>(pbuf);
\t\tif(logical_player < players.home_size + players.opposing_size)
\t\t\tSEND(GetAtPos(logical_player).player);
\t\tbreak;
\t}
'''

new_case = '''\tcase MSG_MULTIPLAYER_PRIVATE_PILES: {
\t\tconst auto logical_player = BufferIO::Read<uint8_t>(pbuf);
\t\tif(logical_player >= players.home_size + players.opposing_size)
\t\t\tbreak;
\t\tauto* owner = GetAtPos(logical_player).player;
\t\t// The owner receives the complete private snapshot, exactly as before.
\t\tif(owner)
\t\t\tSEND(owner);

\t\tconst uint64_t duel_flags =
\t\t\tstatic_cast<uint64_t>(host_info.duel_flag_low)
\t\t\t| (static_cast<uint64_t>(host_info.duel_flag_high) << 32);
\t\tconst bool battle_royale = (duel_flags & DUEL_BATTLE_ROYALE) != 0;
\t\tconst bool three_vs_one = (duel_flags & DUEL_3_V_1) != 0;
\t\tif(multiplayer_battle_royale_private_snapshot::
\t\t\t\tShouldBroadcastMaskedSnapshot(battle_royale, three_vs_one)) {
\t\t\tauto public_packet = packet;
\t\t\tif(multiplayer_battle_royale_private_snapshot::
\t\t\t\t\tMaskForOpponent(public_packet.buffer)) {
\t\t\t\t// Prepare one privacy-safe network packet, then send it to all
\t\t\t\t// non-owners. This gives P1 a card-back Hand/Deck/Extra/GY/Banish
\t\t\t\t// snapshot for P3 without exposing any private card identity.
\t\t\t\tNetServer::SendCoreUtilsPacketToPlayer(
\t\t\t\t\tnullptr, STOC_GAME_MSG, public_packet);
\t\t\t\tResendToAll(owner);
\t\t\t\t// Catch-up clients and observers must receive only the masked form.
\t\t\t\tpackets_cache.push_back(public_packet);
\t\t\t}
\t\t}
\t\tbreak;
\t}
'''

if new_case not in text:
    text = replace_once(text, old_case, new_case, "private snapshot routing")

GENERIC.write_text(text, encoding="utf-8")
print("Applied privacy-safe live Battle Royale P3 hand snapshot routing.")
