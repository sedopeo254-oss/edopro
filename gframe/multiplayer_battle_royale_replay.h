#ifndef MULTIPLAYER_BATTLE_ROYALE_REPLAY_H
#define MULTIPLAYER_BATTLE_ROYALE_REPLAY_H

#include <cstdint>

namespace ygo::multiplayer_battle_royale_replay {

struct SnapshotBatch {
	uint8_t pending_mask{};
	uint8_t received_mask{};
	bool collecting{};
	bool authoritative_seen{};
	bool applied{};

	constexpr void Reset() {
		pending_mask = 0;
		received_mask = 0;
		collecting = false;
		authoritative_seen = false;
		applied = false;
	}
	constexpr void Begin(uint8_t active_mask) {
		pending_mask = active_mask & 0x0f;
		received_mask = 0;
		collecting = true;
		applied = false;
	}
	constexpr bool Observe(uint8_t logical_player) {
		if(logical_player >= 4)
			return false;
		authoritative_seen = true;
		if(!collecting)
			return false;
		const auto bit = static_cast<uint8_t>(1u << logical_player);
		received_mask |= bit;
		pending_mask &= static_cast<uint8_t>(~bit);
		return pending_mask == 0 && !applied;
	}
	constexpr bool IsCollecting() const {
		return collecting;
	}
	constexpr bool HasCurrentSnapshots() const {
		return collecting && received_mask != 0;
	}
	constexpr bool NeedsApply() const {
		return HasCurrentSnapshots() && !applied;
	}
	constexpr void MarkApplied() {
		applied = true;
	}
	constexpr void Finish() {
		pending_mask = 0;
		received_mask = 0;
		collecting = false;
		applied = false;
	}
};

} // namespace ygo::multiplayer_battle_royale_replay

#endif
