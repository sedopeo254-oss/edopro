#ifndef MULTIPLAYER_REPLAY_POLICY_H
#define MULTIPLAYER_REPLAY_POLICY_H

#include <cstdint>

namespace ygo::multiplayer_replay_policy {

inline uint8_t MakeVisibleHandMask(uint8_t turn_player, uint8_t affected_player,
		uint8_t active_mask, uint8_t player_count) {
	uint8_t mask = 0;
	if(turn_player < player_count && (active_mask & (1u << turn_player)))
		mask |= static_cast<uint8_t>(1u << turn_player);
	if(affected_player < player_count && (active_mask & (1u << affected_player)))
		mask |= static_cast<uint8_t>(1u << affected_player);
	return mask;
}

inline uint8_t ChooseHandForSide(uint8_t visible_mask, uint8_t turn_player,
		uint8_t affected_player, uint8_t side, uint8_t team1, uint8_t player_count) {
	auto side_of = [team1](uint8_t logical) {
		return static_cast<uint8_t>(logical < team1 ? 0 : 1);
	};
	if(affected_player < player_count && side_of(affected_player) == side
			&& (visible_mask & (1u << affected_player)))
		return affected_player;
	if(turn_player < player_count && side_of(turn_player) == side
			&& (visible_mask & (1u << turn_player)))
		return turn_player;
	for(uint8_t logical = 0; logical < player_count; ++logical)
		if(side_of(logical) == side && (visible_mask & (1u << logical)))
			return logical;
	return 0xff;
}

} // namespace ygo::multiplayer_replay_policy

#endif
