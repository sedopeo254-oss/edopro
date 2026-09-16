from pathlib import Path
import sys

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path("windbot").resolve()


def replace_once(path, old, new):
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{p}: expected one replacement site, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# Workflow #2 intentionally carries DUEL_3_V_1 in the Big Five composite flag.
# Keep IsThreeVsOne true so every protected 3v1 multiplayer path remains reused,
# and add only an exact composite discriminator for 2-player allied field sizing.
replace_once(
    "ExecutorBase/Game/Duel.cs",
    "        public bool IsThreeVsOne { get; set; }\n        public bool IsBattleRoyale { get; set; }\n",
    "        public bool IsThreeVsOne { get; set; }\n"
    "        public bool IsBattleRoyale { get; set; }\n"
    "        public bool IsTwoVsOneBig5 { get; set; }\n",
)

replace_once(
    "ExecutorBase/Game/ClientField.cs",
    "        public const int ThreeVsOneMonsterZoneCount = StandardMonsterZoneCount * 3;\n"
    "        public const int ThreeVsOneSpellZoneCount = StandardSpellZoneCount * 3;\n",
    "        public const int ThreeVsOneMonsterZoneCount = StandardMonsterZoneCount * 3;\n"
    "        public const int ThreeVsOneSpellZoneCount = StandardSpellZoneCount * 3;\n"
    "        public const int TwoVsOneMonsterZoneCount = StandardMonsterZoneCount * 2;\n"
    "        public const int TwoVsOneSpellZoneCount = StandardSpellZoneCount * 2;\n",
)
replace_once(
    "ExecutorBase/Game/ClientField.cs",
    "        public void Init(int deck, int extra, bool threeVsOne = false)\n",
    "        public void Init(int deck, int extra, bool threeVsOne = false, bool twoVsOneBig5 = false)\n",
)
replace_once(
    "ExecutorBase/Game/ClientField.cs",
    "            MonsterZone = new ClientCard[threeVsOne ? ThreeVsOneMonsterZoneCount : StandardMonsterZoneCount];\n"
    "            SpellZone = new ClientCard[threeVsOne ? ThreeVsOneSpellZoneCount : StandardSpellZoneCount];\n",
    "            MonsterZone = new ClientCard[twoVsOneBig5 ? TwoVsOneMonsterZoneCount\n"
    "                : threeVsOne ? ThreeVsOneMonsterZoneCount : StandardMonsterZoneCount];\n"
    "            SpellZone = new ClientCard[twoVsOneBig5 ? TwoVsOneSpellZoneCount\n"
    "                : threeVsOne ? ThreeVsOneSpellZoneCount : StandardSpellZoneCount];\n",
)

# Existing public high bits: Battle Royale=0x20, 3v1=0x40.
# Workflow #2 Big Five 2v1 is the exact composite 0xC0 (0x40 | 0x80).
replace_once(
    "Game/GameBehavior.cs",
    "            const uint DUEL_BATTLE_ROYALE_HIGH = 0x20;\n"
    "            const uint DUEL_3_V_1_HIGH = 0x40;\n",
    "            const uint DUEL_BATTLE_ROYALE_HIGH = 0x20;\n"
    "            const uint DUEL_3_V_1_HIGH = 0x40;\n"
    "            const uint DUEL_2_V_1_BIG5_COMPOSITE_HIGH = 0xC0;\n",
)
replace_once(
    "Game/GameBehavior.cs",
    "            _duel.IsBattleRoyale = (duel_flag_high & DUEL_BATTLE_ROYALE_HIGH) != 0;\n"
    "            _duel.IsThreeVsOne = (duel_flag_high & DUEL_3_V_1_HIGH) != 0;\n",
    "            _duel.IsBattleRoyale = (duel_flag_high & DUEL_BATTLE_ROYALE_HIGH) != 0;\n"
    "            _duel.IsThreeVsOne = (duel_flag_high & DUEL_3_V_1_HIGH) != 0;\n"
    "            _duel.IsTwoVsOneBig5 = (duel_flag_high & DUEL_2_V_1_BIG5_COMPOSITE_HIGH)\n"
    "                == DUEL_2_V_1_BIG5_COMPOSITE_HIGH;\n",
)
replace_once(
    "Game/GameBehavior.cs",
    "            _duel.Fields[GetLocalPlayer(0)].Init(deck, extra, _duel.IsThreeVsOne);\n",
    "            _duel.Fields[GetLocalPlayer(0)].Init(deck, extra, _duel.IsThreeVsOne, _duel.IsTwoVsOneBig5);\n",
)

# On field reload, preserve the exact old 21/24 3v1 sizing and 7/8 standard
# sizing; only exact composite 2v1 uses 14/16 on physical side 0.
replace_once(
    "Game/GameBehavior.cs",
    "                int monsterZoneCount = _duel.IsThreeVsOne && player == 0\n"
    "                    ? ClientField.ThreeVsOneMonsterZoneCount\n"
    "                    : ClientField.StandardMonsterZoneCount;\n"
    "                int spellZoneCount = _duel.IsThreeVsOne && player == 0\n"
    "                    ? ClientField.ThreeVsOneSpellZoneCount\n"
    "                    : ClientField.StandardSpellZoneCount;\n",
    "                int monsterZoneCount = player == 0 && _duel.IsTwoVsOneBig5\n"
    "                    ? ClientField.TwoVsOneMonsterZoneCount\n"
    "                    : _duel.IsThreeVsOne && player == 0\n"
    "                        ? ClientField.ThreeVsOneMonsterZoneCount\n"
    "                        : ClientField.StandardMonsterZoneCount;\n"
    "                int spellZoneCount = player == 0 && _duel.IsTwoVsOneBig5\n"
    "                    ? ClientField.TwoVsOneSpellZoneCount\n"
    "                    : _duel.IsThreeVsOne && player == 0\n"
    "                        ? ClientField.ThreeVsOneSpellZoneCount\n"
    "                        : ClientField.StandardSpellZoneCount;\n",
)

print("Applied Workflow #2 compatible Big Five 2v1 WindBot sizing")
