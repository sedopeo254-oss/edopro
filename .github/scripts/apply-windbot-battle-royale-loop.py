from pathlib import Path
import sys

if len(sys.argv) > 1:
    ROOT = Path(sys.argv[1]).resolve()
else:
    ROOT = Path("windbot").resolve()


def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{p}: expected one replacement site, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# The existing 3v1 patch already introduces IsThreeVsOne. Keep that path
# untouched and add a separate Battle Royale switch.
replace_once(
    "ExecutorBase/Game/Duel.cs",
    "        public bool IsThreeVsOne { get; set; }\n",
    "        public bool IsThreeVsOne { get; set; }\n        public bool IsBattleRoyale { get; set; }\n",
)

replace_once(
    "Game/GameBehavior.cs",
    "            const uint DUEL_3_V_1_HIGH = 0x40;\n",
    "            const uint DUEL_BATTLE_ROYALE_HIGH = 0x20;\n            const uint DUEL_3_V_1_HIGH = 0x40;\n",
)
replace_once(
    "Game/GameBehavior.cs",
    "            _duel.IsThreeVsOne = (duel_flag_high & DUEL_3_V_1_HIGH) != 0;\n",
    "            _duel.IsBattleRoyale = (duel_flag_high & DUEL_BATTLE_ROYALE_HIGH) != 0;\n            _duel.IsThreeVsOne = (duel_flag_high & DUEL_3_V_1_HIGH) != 0;\n",
)

# Live 4-way uses TAG_SWAP internally to project another logical player's field
# onto a physical side. WindBot used to interpret that projection as its own
# private Deck/Hand being swapped, making a just-activated Spell appear Set
# again and immediately re-activate forever. Battle Royale already receives the
# authoritative normal update packets, so consume the legacy projection packet
# without rebuilding WindBot's private piles. Standard and 3v1 keep their
# existing behavior.
replace_once(
    "Game/GameBehavior.cs",
    "        private void OnTagSwap(BinaryReader packet)\n        {\n",
    "        private void OnTagSwap(BinaryReader packet)\n        {\n            if (_duel.IsBattleRoyale)\n            {\n                packet.BaseStream.Position = packet.BaseStream.Length;\n                return;\n            }\n",
)

print("Applied WindBot live Battle Royale TAG_SWAP loop guard")
