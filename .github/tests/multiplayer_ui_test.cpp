#include "gframe/multiplayer_ui.h"

#include <cassert>
#include <cmath>

int main() {
	using namespace ygo::multiplayer_ui;
	const auto four_player_width = GetHudPanelWidth(4);
	assert(four_player_width == 235);
	assert(GetHudLayoutLeft(4, four_player_width) == 42);

	const auto thirteen_player_width = GetHudPanelWidth(13);
	assert(thirteen_player_width == 73);
	assert(GetHudLayoutLeft(13, thirteen_player_width) == 37);
	assert(GetHudPanelHeight() == 40);
	assert(GetHudTop(false) == 39);
	assert(GetHudTop(true) == 83);
	assert(GetTurnBadgeBottom() < GetHudTop(false));
	assert(GetTurnBadgeLeft() >= 0);
	assert(GetTurnBadgeRight() <= HUD_BASE_WIDTH);
	for(int columns = 1; columns <= 13; ++columns) {
		const auto width = GetHudPanelWidth(columns);
		const auto left = GetHudLayoutLeft(columns, width);
		assert(left >= 0);
		assert(left + columns * width <= HUD_BASE_WIDTH);
	}
	assert(GetStableOpponent(0, 0x0f, 4) == 1);
	assert(GetStableOpponent(1, 0x0d, 4) == 2);
	assert(GetStableOpponent(3, 0x09, 4) == 0);
	assert(GetStableOpponent(3, 0x02, 4) == 1);
	assert(GetStableOpponent(0, 0x01, 4) == -1);
	assert(GetStableOpponent(-1, 0x0f, 4) == -1);
	assert(GetStableOpponent(0, 0x01, 1) == -1);

	constexpr float epsilon = 0.0001f;
	const auto bottom_to_top = GetAttackArrowRotation(3.95f, 3.2f, 3.95f, -3.2f);
	assert(std::abs(bottom_to_top) < epsilon);
	const auto top_to_bottom = GetAttackArrowRotation(3.95f, -3.2f, 3.95f, 3.2f);
	assert(std::abs(std::abs(top_to_bottom) - 3.14159265f) < epsilon);
	const auto bottom_to_top_right = GetAttackArrowRotation(3.0f, 3.0f, 4.0f, -3.0f);
	assert(bottom_to_top_right > 0.0f && bottom_to_top_right < 1.0f);
	const auto bottom_to_top_left = GetAttackArrowRotation(4.0f, 3.0f, 3.0f, -3.0f);
	assert(bottom_to_top_left < 0.0f && bottom_to_top_left > -1.0f);
	const auto left_to_right = GetAttackArrowRotation(-3.0f, 0.0f, 3.0f, 0.0f);
	assert(std::abs(left_to_right - 1.57079632f) < epsilon);
	const auto right_to_left = GetAttackArrowRotation(3.0f, 0.0f, -3.0f, 0.0f);
	assert(std::abs(right_to_left + 1.57079632f) < epsilon);
	// Replaying the same packet must always produce exactly the same direction.
	assert(GetAttackArrowRotation(3.0f, 3.0f, 4.0f, -3.0f) == bottom_to_top_right);
	const auto stale_attacker = GetStableAttackPoint(3.0f, -1.4f, 0);
	const auto stale_target = GetStableAttackPoint(4.0f, 1.4f, 1);
	assert(stale_attacker.y > 0.0f);
	assert(stale_target.y < 0.0f);
	const auto corrected = GetAttackArrowRotation(stale_attacker.x,
		stale_attacker.y, stale_target.x, stale_target.y);
	assert(corrected > -1.0f && corrected < 1.0f);
	assert(IsValidLogicalAttack(0, 2, 4, 0x0f));
	assert(!IsValidLogicalAttack(2, 2, 4, 0x0f));
	assert(!IsValidLogicalAttack(0, 3, 4, 0x07));
	return 0;
}
