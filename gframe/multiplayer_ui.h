#ifndef MULTIPLAYER_UI_H
#define MULTIPLAYER_UI_H

#include <algorithm>
#include <cmath>

namespace ygo::multiplayer_ui {

constexpr int GetHudPanelWidth(int columns) {
	return std::clamp(960 / std::max(1, columns), 70, 235);
}

constexpr int GetHudLayoutLeft(int columns, int panel_width) {
	return std::max(8, (1024 - std::max(1, columns) * panel_width) / 2);
}

constexpr int GetHudPanelHeight() {
	return 40;
}

constexpr int GetHudTop(bool second_side) {
	return second_side ? 50 : 6;
}

// Keep fallback opponent selection stable. Starting immediately after the
// local seat avoids the apparent "random" jumps caused by always falling back
// to the lowest numbered active player after an elimination or replay seek.
constexpr int GetStableOpponent(int local, unsigned int active_mask, int player_count) {
	if(local < 0 || local >= player_count || player_count < 2)
		return -1;
	for(int offset = 1; offset < player_count; ++offset) {
		const int candidate = (local + offset) % player_count;
		if(active_mask & (1u << candidate))
			return candidate;
	}
	return -1;
}

// The generated arrow points along its local negative Y axis. This angle maps
// that axis from attacker to target without an extra quadrant correction.
inline float GetAttackArrowRotation(float attacker_x, float attacker_y,
		float target_x, float target_y) {
	return std::atan2(target_x - attacker_x, attacker_y - target_y);
}

}

#endif // MULTIPLAYER_UI_H
