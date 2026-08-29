#include <cstdlib>
#include <iostream>
#include <vector>
#include "gframe/multiplayer_battle_royale_private_snapshot.h"

using namespace ygo::multiplayer_battle_royale_private_snapshot;

static void expect(bool condition, const char* message) {
    if(!condition) {
        std::cerr << "FAILED: " << message << '\n';
        std::exit(EXIT_FAILURE);
    }
}

static void append_u32(std::vector<uint8_t>& out, uint32_t value) {
    out.push_back(static_cast<uint8_t>(value));
    out.push_back(static_cast<uint8_t>(value >> 8));
    out.push_back(static_cast<uint8_t>(value >> 16));
    out.push_back(static_cast<uint8_t>(value >> 24));
}

static uint32_t read_u32(const std::vector<uint8_t>& in, std::size_t offset) {
    uint32_t value = 0;
    expect(ReadU32(in, offset, value), "test payload read failed");
    return value;
}

int main() {
    expect(ShouldBroadcastMaskedSnapshot(true, false),
        "live Battle Royale must broadcast masked snapshots");
    expect(!ShouldBroadcastMaskedSnapshot(false, true),
        "3v1 must remain owner-only");
    expect(!ShouldBroadcastMaskedSnapshot(false, false),
        "Standard must remain unchanged");

    std::vector<uint8_t> payload;
    payload.push_back(1); // logical P3 in core-side order (P1/P3 share side 0)
    append_u32(payload, 55); // deck count
    append_u32(payload, 2);  // extra count
    append_u32(payload, 1);  // face-up Pendulum count
    append_u32(payload, 3);  // hand count
    append_u32(payload, 0x11223344); // secret deck top

    // Hand: every identity and position must become a card back.
    append_u32(payload, 1001); append_u32(payload, POS_FACEUP_ATTACK);
    append_u32(payload, 1002); append_u32(payload, POS_FACEDOWN_DEFENSE);
    append_u32(payload, 1003); append_u32(payload, POS_FACEUP_DEFENSE);

    // Extra: face-down identity hidden; face-up identity remains public.
    append_u32(payload, 2001); append_u32(payload, POS_FACEDOWN_DEFENSE);
    append_u32(payload, 2002); append_u32(payload, POS_FACEUP_ATTACK);

    append_u32(payload, 2); // grave count
    append_u32(payload, 2); // removed count
    append_u32(payload, 3001); append_u32(payload, POS_FACEUP_ATTACK);
    append_u32(payload, 3002); append_u32(payload, POS_FACEUP_DEFENSE);
    append_u32(payload, 4001); append_u32(payload, POS_FACEUP_ATTACK);
    append_u32(payload, 4002); append_u32(payload, POS_FACEDOWN_DEFENSE);

    const auto original_size = payload.size();
    expect(MaskForOpponent(payload), "valid private snapshot must be maskable");
    expect(payload.size() == original_size, "masking must preserve packet size");
    expect(payload[0] == 1, "logical player identity must be preserved");
    expect(read_u32(payload, 1) == 55, "deck count must be preserved");
    expect(read_u32(payload, 5) == 2, "extra count must be preserved");
    expect(read_u32(payload, 9) == 1, "face-up extra count must be preserved");
    expect(read_u32(payload, 13) == 3, "hand count must be preserved");
    expect(read_u32(payload, 17) == 0, "deck top identity must be hidden");

    std::size_t cursor = 21;
    for(int i = 0; i < 3; ++i) {
        expect(read_u32(payload, cursor) == 0,
            "opponent hand identity must be hidden");
        expect(read_u32(payload, cursor + 4) == POS_FACEDOWN_DEFENSE,
            "opponent hand must render as card backs");
        cursor += 8;
    }
    expect(read_u32(payload, cursor) == 0,
        "face-down Extra Deck identity must be hidden");
    cursor += 8;
    expect(read_u32(payload, cursor) == 2002,
        "face-up Extra Deck identity must remain visible");
    cursor += 8;
    expect(read_u32(payload, cursor) == 2, "grave count must remain visible");
    cursor += 4;
    expect(read_u32(payload, cursor) == 2, "banish count must remain visible");
    cursor += 4;
    expect(read_u32(payload, cursor) == 3001, "grave card 1 must remain public");
    cursor += 8;
    expect(read_u32(payload, cursor) == 3002, "grave card 2 must remain public");
    cursor += 8;
    expect(read_u32(payload, cursor) == 4001,
        "face-up banished identity must remain public");
    cursor += 8;
    expect(read_u32(payload, cursor) == 0,
        "face-down banished identity must be hidden");

    std::vector<uint8_t> malformed{1, 2, 3};
    const auto malformed_before = malformed;
    expect(!MaskForOpponent(malformed), "malformed snapshot must be rejected");
    expect(malformed == malformed_before,
        "malformed input must remain unchanged");

    std::cout << "Battle Royale masked private snapshot tests passed.\n";
}
