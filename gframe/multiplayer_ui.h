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

// The generated arrow points along its local negative Y axis. This angle maps
// that axis from attacker to target without an extra quadrant correction.
inline float GetAttackArrowRotation(float attacker_x, float attacker_y,
		float target_x, float target_y) {
	return std::atan2(target_x - attacker_x, attacker_y - target_y);
}

}

#endif // MULTIPLAYER_UI_H
