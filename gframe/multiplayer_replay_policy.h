#ifndef MULTIPLAYER_REPLAY_POLICY_H
#define MULTIPLAYER_REPLAY_POLICY_H

#include <cstdint>

namespace ygo::multiplayer_replay_policy {

inline uint8_t SideOf(uint8_t logical, uint8_t team1) {
	return logical < team1 ? 0 : 1;
}

inline uint8_t FirstActiveOnSide(uint8_t side, uint8_t active_mask,
		uint8_t team1, uint8_t player_count) {
	const uint8_t first = side == 0 ? 0 : team1;
	const uint8_t last = side == 0 ? team1 : player_count;
	for(uint8_t logical = first; logical < last; ++logical)
		if(active_mask & (1u << logical))
			return logical;
	return 0xff;
}

// The 3v1 replay always projects one complete logical player per physical side.
// On the team's side the priority is:
//   1. the attacked/targeted teammate,
//   2. the teammate whose turn it is,
//   3. P1 (or the first active teammate if P1 is eliminated).
// This keeps P1 completely stable throughout the opponent's turn and prevents
// Hand/Deck/Extra/GY/Banish data from different teammates being composed together.
inline uint8_t ChooseFocusForSide(uint8_t turn_player, uint8_t affected_player,
		uint8_t side, uint8_t active_mask, uint8_t team1,
		uint8_t player_count) {
	auto valid_on_side = [&](uint8_t logical) {
		return logical < player_count
			&& SideOf(logical, team1) == side
			&& (active_mask & (1u << logical));
	};
	if(valid_on_side(affected_player))
		return affected_player;
	if(valid_on_side(turn_player))
		return turn_player;
	return FirstActiveOnSide(side, active_mask, team1, player_count);
}

inline uint8_t MakeVisibleHandMask(uint8_t turn_player, uint8_t affected_player,
		uint8_t active_mask, uint8_t player_count, uint8_t team1) {
	uint8_t mask = 0;
	for(uint8_t side = 0; side < 2; ++side) {
		const auto logical = ChooseFocusForSide(turn_player, affected_player,
			side, active_mask, team1, player_count);
		if(logical < player_count)
			mask |= static_cast<uint8_t>(1u << logical);
	}
	return mask;
}

inline uint8_t ChooseHandForSide(uint8_t visible_mask, uint8_t turn_player,
		uint8_t affected_player, uint8_t side, uint8_t team1,
		uint8_t player_count) {
	auto side_of = [team1](uint8_t logical) {
		return SideOf(logical, team1);
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
