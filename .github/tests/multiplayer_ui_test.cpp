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

	constexpr float epsilon = 0.0001f;
	const auto bottom_to_top = GetAttackArrowRotation(3.95f, 3.2f, 3.95f, -3.2f);
	assert(std::abs(bottom_to_top) < epsilon);
	const auto top_to_bottom = GetAttackArrowRotation(3.95f, -3.2f, 3.95f, 3.2f);
	assert(std::abs(std::abs(top_to_bottom) - 3.14159265f) < epsilon);
	const auto bottom_to_top_right = GetAttackArrowRotation(3.0f, 3.0f, 4.0f, -3.0f);
	assert(bottom_to_top_right > 0.0f && bottom_to_top_right < 1.0f);
	return 0;
}
