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

struct HudPanelLayout {
	int left;
	int top;
	int width;
};

struct LogicalNameSlot {
	bool valid;
	bool second_side;
	uint8_t index;
};

// Battle Royale and Universal Multiplayer always use the two-seat focused
// renderer. Legacy 3-vs-1 keeps its live Swap-the-Team board, but replays use
// the same focused renderer so every camera packet restores an exact player
// pair and its private piles.
constexpr bool UsesFocusedMultiplayerView(bool battle_royale, bool universal,
		bool three_v_one, bool replay) {
	return battle_royale || universal || (three_v_one && replay);
}

// Logical player numbers are canonical (team 1 followed by team 2) and must
// never depend on which side is currently drawn at the bottom of the screen.
constexpr LogicalNameSlot GetLogicalNameSlot(uint8_t logical, uint8_t team1,
		uint8_t team2) {
	if(logical < team1)
		return { true, false, logical };
	if(logical < static_cast<uint8_t>(team1 + team2))
		return { true, true, static_cast<uint8_t>(logical - team1) };
	return { false, false, 0 };
}

constexpr bool HasMultipleLogicalPlayers(uint32_t mask) {
	return mask != 0 && (mask & (mask - 1u)) != 0;
}

// Older multiplayer replays could serialize a negative signed LP value through
// uint32_t. Keep the HUD deterministic and never revive that underflow.
constexpr int32_t NormalizeSerializedLifePoints(uint32_t value) {
	return value > 0x7fffffffu ? 0 : static_cast<int32_t>(value);
}

constexpr int32_t ApplyLifePointDamage(int32_t current_lp, uint32_t damage) {
	const auto available_lp = current_lp > 0
		? static_cast<uint32_t>(current_lp) : 0u;
	return damage >= available_lp
		? 0 : current_lp - static_cast<int32_t>(damage);
}

// Normal focused modes only display active opponents. Anime 3-vs-1 replays
// may temporarily focus any other configured field (including an eliminated
// teammate whose cards remain on the board) when an effect targets it.
constexpr bool CanFocusLogicalPlayer(bool three_v_one, bool replay,
		uint8_t perspective, uint8_t candidate, uint8_t player_count,
		uint32_t active_mask, bool are_opponents) {
	if(perspective >= player_count || candidate >= player_count
			|| perspective == candidate)
		return false;
	if(three_v_one && replay)
		return true;
	return (active_mask & (1u << candidate)) != 0 && are_opponents;
}

constexpr bool IsLogicalFieldAvailable(bool three_v_one, bool replay,
		uint8_t logical, uint8_t player_count, uint32_t active_mask) {
	return logical < player_count
		&& ((three_v_one && replay)
			|| (active_mask & (1u << logical)) != 0);
}

// Mirror the stock Standard Duel HUD exactly: the local side occupies the
// standard left LP frame, the opposing transport side occupies the standard
// right LP frame, and the turn counter remains in the original centre gap.
// Extra logical players wrap down within their own side instead of stretching
// behind the card/replay sidebar or beyond the right edge of the screen.
constexpr int HUD_LEFT_SIDE_LEFT = 330;
constexpr int HUD_RIGHT_SIDE_LEFT = 691;
constexpr int HUD_SIDE_WIDTH = 299;
constexpr int HUD_MAX_SIDE_COLUMNS = 3;
constexpr int HUD_TURN_LEFT = 635;
constexpr int HUD_TURN_RIGHT = 685;
constexpr int HUD_TURN_TOP = 5;
constexpr int HUD_TURN_BOTTOM = 40;
constexpr int HUD_FIRST_ROW_TOP = 8;
constexpr int HUD_ROW_GAP = 44;

constexpr int GetHudColumns(int player_count) {
	return std::clamp(player_count, 1, HUD_MAX_SIDE_COLUMNS);
}

constexpr int GetHudRowCount(int player_count) {
	const int columns = GetHudColumns(player_count);
	return (std::max(1, player_count) + columns - 1) / columns;
}

constexpr int GetHudPanelHeight() {
	return 40;
}

constexpr bool IsHudRightSide(bool second_transport_side, bool local_is_team1) {
	return second_transport_side == local_is_team1;
}

constexpr HudPanelLayout GetHudPanelLayout(int player_index, int player_count,
		bool right_side) {
	const int safe_count = std::max(1, player_count);
	const int columns = GetHudColumns(safe_count);
	const int safe_index = std::clamp(player_index, 0, safe_count - 1);
	const int row = safe_index / columns;
	const int column = safe_index % columns;
	const int row_start = row * columns;
	const int row_count = std::min(columns, safe_count - row_start);
	const int panel_width = HUD_SIDE_WIDTH / columns;
	const int side_left = right_side ? HUD_RIGHT_SIDE_LEFT : HUD_LEFT_SIDE_LEFT;
	const int row_left = side_left + (HUD_SIDE_WIDTH - row_count * panel_width) / 2;
	return {
		row_left + column * panel_width,
		HUD_FIRST_ROW_TOP + row * HUD_ROW_GAP,
		panel_width
	};
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
