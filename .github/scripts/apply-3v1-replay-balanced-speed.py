from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one replacement site, found {count}")
    return text.replace(old, new, 1)


# The previous smooth build removed the stalls, but 15+4 frames made the
# replay feel rushed. Use a true midpoint between stock (30+11) and fast
# (15+4), while keeping live duels and every other mode unchanged.
header = ROOT / "gframe" / "multiplayer_replay_animation.h"
text = header.read_text(encoding="utf-8")
if "SummonTiming{ 15, 4, 6 }" in text:
    text = text.replace("SummonTiming{ 15, 4, 6 }", "SummonTiming{ 22, 8, 8 }", 1)
elif "SummonTiming{ 22, 8, 8 }" not in text:
    raise SystemExit("multiplayer_replay_animation.h: unexpected summon timing baseline")
text = text.replace(
    "shorter because a projected field/private-pile update already surrounds\n"
    "\t// each summon and the stock 30+11 frame pause feels like a freeze.",
    "balanced because a projected field/private-pile update already surrounds\n"
    "\t// each summon: slower than the fast profile, but still below the stock pause.",
)
if "constexpr uint8_t GetDrawMoveFrames" not in text:
    marker = "constexpr uint32_t DrawSoundCount(bool smooth_three_vs_one_replay,\n"
    insertion = (
        "constexpr uint8_t GetDrawMoveFrames(bool is_replay, bool is_three_vs_one) {\n"
        "\t// A 12-frame batch movement is visible and deliberate without restoring\n"
        "\t// the old full-pile rebuild or any blocking wait.\n"
        "\treturn is_replay && is_three_vs_one ? 12 : 8;\n"
        "}\n\n"
    )
    if marker not in text:
        raise SystemExit("multiplayer_replay_animation.h: DrawSoundCount marker missing")
    text = text.replace(marker, insertion + marker, 1)
header.write_text(text, encoding="utf-8")


# Use the balanced draw movement only for the already-isolated 3v1 replay
# batch path. This keeps the no-rebuild optimization and merely restores a
# readable visual pace.
field = ROOT / "gframe" / "client_field.cpp"
text = field.read_text(encoding="utf-8")
if '#include "multiplayer_replay_animation.h"' not in text:
    text = replace_once(
        text,
        '#include "duelclient.h"\n',
        '#include "duelclient.h"\n#include "multiplayer_replay_animation.h"\n',
        "client_field.cpp include",
    )
start = text.find("bool ClientField::ApplyThreeVsOneReplayPrivateDraw(")
end = text.find("void ClientField::UpdateMultiplayerPrivateMove(", start)
if start < 0 or end < 0:
    raise SystemExit("client_field.cpp: replay private draw method range missing")
method = text[start:end]
old_move = "\t\t\tMoveCard(pcard, 8);"
new_move = (
    "\t\t\tMoveCard(pcard,\n"
    "\t\t\t\tmultiplayer_replay_animation::GetDrawMoveFrames(\n"
    "\t\t\t\t\tmainGame->dInfo.isReplay,\n"
    "\t\t\t\t\tmainGame->dInfo.HasFieldFlag(DUEL_3_V_1)));"
)
if old_move in method:
    method = method.replace(old_move, new_move, 1)
elif "GetDrawMoveFrames(" not in method:
    raise SystemExit("client_field.cpp: unexpected draw movement baseline")
text = text[:start] + method + text[end:]
field.write_text(text, encoding="utf-8")


# Update the focused policy test so future speed changes cannot accidentally
# make the replay too fast again.
test = ROOT / ".github" / "tests" / "multiplayer_replay_animation_test.cpp"
text = test.read_text(encoding="utf-8")
if "replay.reveal_frames == 15 && replay.settle_frames == 4" in text:
    text = text.replace(
        "replay.reveal_frames == 15 && replay.settle_frames == 4\n"
        "\t\t&& replay.move_frames == 6,\n"
        "\t\t\"3v1 replay summons must use the smooth timing\"",
        "replay.reveal_frames == 22 && replay.settle_frames == 8\n"
        "\t\t&& replay.move_frames == 8,\n"
        "\t\t\"3v1 replay summons must use the balanced timing\"",
        1,
    )
elif "replay.reveal_frames == 22 && replay.settle_frames == 8" not in text:
    raise SystemExit("multiplayer_replay_animation_test.cpp: unexpected replay timing assertion")
if "GetDrawMoveFrames(true, true)" not in text:
    marker = "\texpect(DrawSoundCount(true, true, 6) == 1,\n"
    insertion = (
        "\texpect(GetDrawMoveFrames(true, true) == 12,\n"
        "\t\t\"3v1 replay draws must use a readable balanced movement\");\n"
        "\texpect(GetDrawMoveFrames(false, true) == 8,\n"
        "\t\t\"live duel draw movement must remain unchanged\");\n"
    )
    if marker not in text:
        raise SystemExit("multiplayer_replay_animation_test.cpp: DrawSoundCount marker missing")
    text = text.replace(marker, insertion + marker, 1)
test.write_text(text, encoding="utf-8")

print("Applied balanced 3v1 replay pacing: summon 22/8/8, draw movement 12 frames")
