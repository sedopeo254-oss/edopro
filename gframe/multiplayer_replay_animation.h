#ifndef MULTIPLAYER_REPLAY_ANIMATION_H
#define MULTIPLAYER_REPLAY_ANIMATION_H

#include <cstdint>

namespace ygo::multiplayer_replay_animation {

struct SummonTiming {
	uint8_t reveal_frames;
	uint8_t settle_frames;
	uint8_t move_frames;
};

constexpr SummonTiming GetSummonTiming(bool is_replay, bool is_three_vs_one) {
	// Keep live duels and all stock modes unchanged. 3v1 replay animations are
	// shorter because a projected field/private-pile update already surrounds
	// each summon and the stock 30+11 frame pause feels like a freeze.
	return is_replay && is_three_vs_one
		? SummonTiming{ 15, 4, 6 }
		: SummonTiming{ 30, 11, 10 };
}

constexpr uint32_t DrawSoundCount(bool smooth_three_vs_one_replay,
		bool displayed, uint32_t drawn_count) {
	if(!drawn_count)
		return 0;
	// Multi-card effects such as Card of Sanctity must not stack six identical
	// sounds while private snapshots are being reconciled. Play one sound only
	// for the hand that is actually visible.
	return smooth_three_vs_one_replay ? (displayed ? 1u : 0u) : drawn_count;
}

} // namespace ygo::multiplayer_replay_animation

#endif
