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
	// balanced because a projected field/private-pile update already surrounds
	// each summon: slower than the fast profile, but still below the stock pause.
	return is_replay && is_three_vs_one
		? SummonTiming{ 22, 8, 8 }
		: SummonTiming{ 30, 11, 10 };
}

constexpr uint8_t GetDrawMoveFrames(bool is_replay, bool is_three_vs_one) {
	// A 12-frame batch movement is visible and deliberate without restoring
	// the old full-pile rebuild or any blocking wait.
	return is_replay && is_three_vs_one ? 12 : 8;
}

constexpr uint8_t GetBattleRoyaleDrawMoveFrames(bool is_replay,
		bool is_battle_royale) {
	// Keep a visible ten-frame movement, but never rebuild all five private
	// piles or block replay playback for every drawn card.
	return is_replay && is_battle_royale ? 10 : 8;
}

constexpr uint8_t GetBattleRoyaleTurnFrames(bool is_replay,
		bool is_battle_royale) {
	// The stock forty-frame banner plus duplicate field/pile rebuilds felt like
	// a stall. Thirty-two frames remains readable after those rebuilds are gone.
	return is_replay && is_battle_royale ? 32 : 40;
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
