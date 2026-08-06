#ifndef MULTIPLAYER_UI_H
#define MULTIPLAYER_UI_H

#include <algorithm>
#include <cmath>
#include <cstdint>

namespace ygo::multiplayer_ui {

struct AttackPoint {
	float x;
	float y;
};

constexpr int HUD_BASE_WIDTH = 1024;
// The card image/replay controls occupy the left edge of every duel screen.
// Keep custom-mode HUD elements inside the unobstructed play area so P1 is
// never hidden behind that panel at any window size or DPI scale.
constexpr int HUD_CARD_PANEL_RIGHT = 198;
constexpr int HUD_EDGE_PADDING = 8;
constexpr int HUD_CONTENT_LEFT = HUD_CARD_PANEL_RIGHT + HUD_EDGE_PADDING;
constexpr int HUD_CONTENT_RIGHT = HUD_BASE_WIDTH - HUD_EDGE_PADDING;
constexpr int HUD_CONTENT_WIDTH = HUD_CONTENT_RIGHT - HUD_CONTENT_LEFT;
constexpr int HUD_TURN_TOP = 3;
constexpr int HUD_TURN_HEIGHT = 32;
constexpr int HUD_TURN_WIDTH = 112;
constexpr int HUD_FIRST_ROW_TOP = 39;
constexpr int HUD_ROW_GAP = 44;

constexpr int GetHudPanelWidth(int columns) {
	return std::clamp(HUD_CONTENT_WIDTH / std::max(1, columns), 60, 235);
}

constexpr int GetHudLayoutLeft(int columns, int panel_width) {
	const int used_width = std::max(1, columns) * panel_width;
	return HUD_CONTENT_LEFT + std::max(0, (HUD_CONTENT_WIDTH - used_width) / 2);
}

constexpr int GetHudPanelHeight() {
	return 40;
}

constexpr int GetHudTop(bool second_side) {
	return second_side ? HUD_FIRST_ROW_TOP + HUD_ROW_GAP : HUD_FIRST_ROW_TOP;
}

constexpr int GetTurnBadgeLeft() {
	return HUD_CONTENT_LEFT + (HUD_CONTENT_WIDTH - HUD_TURN_WIDTH) / 2;
}

constexpr int GetTurnBadgeRight() {
	return GetTurnBadgeLeft() + HUD_TURN_WIDTH;
}

constexpr int GetTurnBadgeBottom() {
	return HUD_TURN_TOP + HUD_TURN_HEIGHT;
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

// Focused multiplayer replays always render the perspective player on the
// lower field (display side 0) and the selected opponent on the upper field
// (display side 1). During a replay seek or camera change Irrlicht can retain
// a card's previous transform for one frame. Correcting only that stale side
// prevents a semantically reversed arrow while preserving exact zone-to-zone
// arrows whenever the card transform is already current.
constexpr AttackPoint GetStableAttackPoint(float x, float y, uint8_t display_side) {
	if(display_side == 0 && y < 0.0f)
		return { 3.95f, 3.2f };
	if(display_side == 1 && y > 0.0f)
		return { 3.95f, -3.2f };
	return { x, y };
}

constexpr bool IsValidLogicalAttack(uint8_t attacker, uint8_t target,
		uint8_t player_count, uint32_t active_mask) {
	return attacker < player_count && target < player_count
		&& attacker != target && (active_mask & (1u << attacker))
		&& (active_mask & (1u << target));
}

}

#endif // MULTIPLAYER_UI_H
