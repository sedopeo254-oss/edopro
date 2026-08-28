#ifndef MULTIPLAYER_BATTLE_ROYALE_LIVE_H
#define MULTIPLAYER_BATTLE_ROYALE_LIVE_H

#include <cstdint>

namespace ygo::multiplayer_battle_royale_live {

constexpr bool Enabled(bool is_replay, bool is_battle_royale) {
	return !is_replay && is_battle_royale;
}

constexpr bool NeedsFullTurnRefresh(bool is_replay, bool is_battle_royale) {
	// Live Battle Royale already receives an authoritative logical snapshot and
	// a public field-focus change at each turn. Rebuilding every private pile a
	// second time is the hitch that appeared after the 3v1 projection work.
	return !Enabled(is_replay, is_battle_royale);
}

constexpr bool ShouldCacheSnapshot(bool is_replay, bool is_battle_royale) {
	// Replay already caches snapshots. Live Battle Royale now uses the same
	// authoritative cache only for the two displayed seats; hidden players stay
	// off-screen until their logical field is selected.
	return is_battle_royale;
}

constexpr bool ShouldUseSnapshotTagSwap(bool is_replay,
		bool is_battle_royale, bool has_authoritative_logical,
		bool has_snapshot) {
	return Enabled(is_replay, is_battle_royale)
		&& has_authoritative_logical && has_snapshot;
}

constexpr uint8_t DrawMoveFrames(bool is_replay, bool is_battle_royale) {
	// Match the readable ec2d962-era movement without a blocking wait per card.
	return Enabled(is_replay, is_battle_royale) ? 10 : 8;
}

constexpr uint32_t DrawSoundCount(bool is_replay, bool is_battle_royale,
		bool displayed, uint32_t drawn_count) {
	if(!drawn_count)
		return 0;
	return Enabled(is_replay, is_battle_royale)
		? (displayed ? 1u : 0u) : drawn_count;
}

} // namespace ygo::multiplayer_battle_royale_live

#endif
