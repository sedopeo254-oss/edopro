#ifndef BATTLE_ROYALE_REPLAY_SMOOTHING_H
#define BATTLE_ROYALE_REPLAY_SMOOTHING_H

#include <cstdint>

namespace ygo::battle_royale_replay_smoothing {

constexpr bool ShouldSkipLegacyTagSwap(bool is_replay,
        bool is_battle_royale, bool has_authoritative_snapshot) {
    // Modern Battle Royale replays already carry a complete private-pile
    // snapshot for each logical player. Replaying the legacy tag swap after
    // that snapshot deletes/recreates the same piles and causes the turn hitch.
    return is_replay && is_battle_royale && has_authoritative_snapshot;
}

constexpr bool NeedsSecondTurnRefresh(bool is_replay,
        bool is_battle_royale) {
    // SetBattleRoyaleReplayView already projects both public and private state.
    return !(is_replay && is_battle_royale);
}

constexpr uint8_t DrawMoveFrames(bool is_replay, bool is_battle_royale) {
    // A short non-blocking batch movement is readable without recreating all
    // five private piles or waiting once per card.
    return is_replay && is_battle_royale ? 10 : 8;
}

constexpr uint32_t DrawSoundCount(bool is_replay, bool is_battle_royale,
        bool displayed, uint32_t drawn_count) {
    if(!drawn_count)
        return 0;
    return is_replay && is_battle_royale ? (displayed ? 1u : 0u) : drawn_count;
}

} // namespace ygo::battle_royale_replay_smoothing

#endif
