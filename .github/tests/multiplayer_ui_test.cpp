#include "gframe/multiplayer_ui.h"
#include "gframe/multiplayer_packets.h"
#include <cstring>
#include <vector>

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

	// Focused rendering is deterministic for all independent-field replays,
	// while live 3-vs-1 retains its manual Swap-the-Team presentation.
	assert(UsesFocusedMultiplayerView(true, false, false, false));
	assert(UsesFocusedMultiplayerView(false, true, false, false));
	assert(!UsesFocusedMultiplayerView(false, false, true, false));
	assert(UsesFocusedMultiplayerView(false, false, true, true));
	assert(!UsesFocusedMultiplayerView(false, false, false, true));

	// Logical names never change when the visual side is swapped.
	const auto p1_name = GetLogicalNameSlot(0, 3, 1);
	const auto p3_name = GetLogicalNameSlot(2, 3, 1);
	const auto p4_name = GetLogicalNameSlot(3, 3, 1);
	assert(p1_name.valid && !p1_name.second_side && p1_name.index == 0);
	assert(p3_name.valid && !p3_name.second_side && p3_name.index == 2);
	assert(p4_name.valid && p4_name.second_side && p4_name.index == 0);
	assert(!GetLogicalNameSlot(4, 3, 1).valid);
	assert(!HasMultipleLogicalPlayers(0));
	assert(!HasMultipleLogicalPlayers(1u << 2));
	assert(HasMultipleLogicalPlayers((1u << 0) | (1u << 2)));

	// Public private-pile packets expose Graveyards and face-up public cards,
	// but never leak Deck top, Hand, face-down Extra or face-down banished codes.
	std::vector<uint8_t> piles;
	auto write_u8 = [&](uint8_t value) { piles.push_back(value); };
	auto write_u32 = [&](uint32_t value) {
		const auto old_size = piles.size();
		piles.resize(old_size + sizeof(value));
		std::memcpy(piles.data() + old_size, &value, sizeof(value));
	};
	auto read_u32 = [&](size_t offset) {
		uint32_t value = 0;
		std::memcpy(&value, piles.data() + offset, sizeof(value));
		return value;
	};
	write_u8(1);       // logical player
	write_u32(30);     // Deck count
	write_u32(2);      // Extra count
	write_u32(0);      // face-up Pendulum count
	write_u32(2);      // Hand count
	write_u32(999);    // Deck top
	write_u32(101); write_u32(0x1); // Hand, even if position is face-up
	write_u32(102); write_u32(0x8);
	write_u32(201); write_u32(0x1); // face-up Extra
	write_u32(202); write_u32(0x8); // face-down Extra
	write_u32(1);      // Grave count
	write_u32(2);      // banished count
	write_u32(301); write_u32(0x1); // Graveyard stays public
	write_u32(401); write_u32(0x1); // face-up banished
	write_u32(402); write_u32(0x8); // face-down banished
	assert(ygo::multiplayer_packets::SanitizePrivatePiles(
		piles.data(), piles.size(), 0x5));
	assert(read_u32(17) == 0); // top code
	assert(read_u32(21) == 0 && read_u32(29) == 0); // Hand codes
	assert(read_u32(37) == 201 && read_u32(45) == 0); // Extra codes
	assert(read_u32(61) == 301); // Graveyard code
	assert(read_u32(69) == 401 && read_u32(77) == 0); // banished codes
	auto malformed = piles;
	malformed.pop_back();
	assert(!ygo::multiplayer_packets::SanitizePrivatePiles(
		malformed.data(), malformed.size(), 0x5));
	assert(NormalizeSerializedLifePoints(4000u) == 4000);
	assert(NormalizeSerializedLifePoints(0xfffffc4au) == 0);
	assert(ApplyLifePointDamage(4000, 950u) == 3050);
	assert(ApplyLifePointDamage(4000, 4950u) == 0);
	assert(ApplyLifePointDamage(0, 950u) == 0);
	assert(CanFocusLogicalPlayer(false, false, 0, 3, 4, 0x0fu, true));
	assert(!CanFocusLogicalPlayer(false, false, 0, 1, 4, 0x0fu, false));
	assert(CanFocusLogicalPlayer(true, true, 2, 0, 4, 0x0eu, false));
	assert(!CanFocusLogicalPlayer(true, false, 2, 0, 4, 0x0eu, false));
	assert(IsLogicalFieldAvailable(true, true, 0, 4, 0x0eu));
	assert(!IsLogicalFieldAvailable(false, true, 0, 4, 0x0eu));

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
