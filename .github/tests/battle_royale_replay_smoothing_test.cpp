#include <cstdlib>
#include <iostream>
#include "gframe/battle_royale_replay_smoothing.h"

using namespace ygo::battle_royale_replay_smoothing;

static void expect(bool condition, const char* message) {
    if(!condition) {
        std::cerr << message << '\n';
        std::exit(EXIT_FAILURE);
    }
}

int main() {
    expect(ShouldSkipLegacyTagSwap(true, true, true),
        "authoritative Battle Royale replay snapshots must replace legacy TAG_SWAP");
    expect(!ShouldSkipLegacyTagSwap(true, true, false),
        "legacy Battle Royale replays without snapshots must retain TAG_SWAP fallback");
    expect(!ShouldSkipLegacyTagSwap(true, false, true),
        "3v1 must not use the Battle Royale TAG_SWAP policy");
    expect(!ShouldSkipLegacyTagSwap(false, true, true),
        "live Battle Royale must retain its normal swap processing");

    expect(!NeedsSecondTurnRefresh(true, true),
        "Battle Royale replay turn switches must not run a second full refresh");
    expect(NeedsSecondTurnRefresh(false, true),
        "live Battle Royale turn switches must keep normal refresh behavior");
    expect(NeedsSecondTurnRefresh(true, false),
        "3v1 refresh policy must remain independently controlled");

    expect(DrawMoveFrames(true, true) == 10,
        "Battle Royale replay draws must use a smooth non-blocking batch movement");
    expect(DrawMoveFrames(false, true) == 8,
        "live Battle Royale draw movement must stay stock");
    expect(DrawSoundCount(true, true, true, 5) == 1,
        "multi-card Battle Royale replay draws must play one visible sound");
    expect(DrawSoundCount(true, true, false, 5) == 0,
        "hidden Battle Royale replay draws must not stack sounds");
    expect(DrawSoundCount(false, true, true, 5) == 5,
        "live Battle Royale draw sounds must remain unchanged");

    std::cout << "Battle Royale replay smoothing policy tests passed.\n";
}
