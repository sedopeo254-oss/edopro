#include "gframe/multiplayer_ui.h"

#include <cassert>
#include <cmath>

int main() {
	using namespace ygo::multiplayer_ui;
	// One player on each transport side occupies the stock Standard LP frame.
	const auto standard_left = GetHudPanelLayout(0, 1, false);
	const auto standard_right = GetHudPanelLayout(0, 1, true);
	assert(standard_left.left == 330 && standard_left.top == 8);
	assert(standard_right.left == 691 && standard_right.top == 8);
	assert(standard_left.width == 299 && standard_right.width == 299);
	assert(HUD_TURN_LEFT == 635 && HUD_TURN_RIGHT == 685);
	assert(HUD_TURN_TOP == 5 && HUD_TURN_BOTTOM == 40);
	assert(!IsHudRightSide(false, true));
	assert(IsHudRightSide(true, true));
	assert(IsHudRightSide(false, false));
	assert(!IsHudRightSide(true, false));

	// Legacy Battle Royale places two independent LP panels in each Standard
	// side without entering the card/replay sidebar.
	const auto battle_left_1 = GetHudPanelLayout(0, 2, false);
	const auto battle_left_2 = GetHudPanelLayout(1, 2, false);
	const auto battle_right_1 = GetHudPanelLayout(0, 2, true);
	assert(battle_left_1.left == 330 && battle_left_1.width == 149);
	assert(battle_left_2.left == 479 && battle_left_2.width == 149);
	assert(battle_right_1.left == 691 && battle_right_1.width == 149);

	// 3v1 keeps the trio in three readable columns and the solo player in the
	// full opposite Standard frame.
	assert(GetHudPanelLayout(0, 3, false).left == 331);
	assert(GetHudPanelLayout(1, 3, false).left == 430);
	assert(GetHudPanelLayout(2, 3, false).left == 529);
	assert(GetHudPanelLayout(0, 3, false).width == 99);
	assert(GetHudPanelLayout(0, 1, true).width == 299);

	// Full 13-player sides wrap down and centre the final player; they never
	// overflow Standard's x=330..990 HUD region.
	assert(GetHudColumns(13) == 3);
	assert(GetHudRowCount(13) == 5);
	const auto thirteenth_left = GetHudPanelLayout(12, 13, false);
	const auto thirteenth_right = GetHudPanelLayout(12, 13, true);
	assert(thirteenth_left.left == 430 && thirteenth_left.top == 184);
	assert(thirteenth_right.left == 791 && thirteenth_right.top == 184);
	assert(thirteenth_left.width == 99);
	assert(GetHudPanelHeight() == 40);
	for(int count = 1; count <= 13; ++count) {
		for(int index = 0; index < count; ++index) {
			for(bool right : { false, true }) {
				const auto layout = GetHudPanelLayout(index, count, right);
				const int side_left = right ? HUD_RIGHT_SIDE_LEFT : HUD_LEFT_SIDE_LEFT;
				assert(layout.left >= side_left);
				assert(layout.left + layout.width <= side_left + HUD_SIDE_WIDTH);
			}
		}
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
