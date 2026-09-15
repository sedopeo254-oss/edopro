#include <cassert>
#include <cstdint>

static constexpr uint64_t DUEL_BATTLE_ROYALE_TEST = 0x2000000000ULL;
static constexpr uint64_t DUEL_3_V_1_TEST = 0x4000000000ULL;
static constexpr uint64_t DUEL_2_V_1_BIG5_TEST = 0x8000000000ULL;

int main() {
    static_assert((DUEL_2_V_1_BIG5_TEST & DUEL_3_V_1_TEST) == 0,
        "2v1 must not inherit the protected 3v1 flag");
    static_assert((DUEL_2_V_1_BIG5_TEST & DUEL_BATTLE_ROYALE_TEST) == 0,
        "2v1 must not inherit the Battle Royale flag");
    assert(DUEL_2_V_1_BIG5_TEST != DUEL_3_V_1_TEST);
    assert(DUEL_2_V_1_BIG5_TEST != DUEL_BATTLE_ROYALE_TEST);
    return 0;
}
