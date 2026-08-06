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
	assert(GetHudTop(false) == 6);
	assert(GetHudTop(true) == 50);
	assert(GetStableOpponent(0, 0x0f, 4) == 1);
	assert(GetStableOpponent(1, 0x0d, 4) == 2);
	assert(GetStableOpponent(3, 0x09, 4) == 0);
	assert(GetStableOpponent(3, 0x02, 4) == 1);
	assert(GetStableOpponent(0, 0x01, 4) == -1);
	assert(GetStableOpponent(-1, 0x0f, 4) == -1);

	// Common 3v1/CaD layouts have enough margin to lift the turn counter all
	// the way to the top. Dense/single-row layouts use the first non-overlap row.
	assert(GetTurnCounterLeft(159) == 51);
	assert(GetTurnCounterTop(159, true) == 8);
	assert(GetTurnCounterLeft(42) == 484);
	assert(GetTurnCounterTop(42, false) == 48);
	assert(GetTurnCounterTop(37, true) == 92);

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
	return 0;
}
