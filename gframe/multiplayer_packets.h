#ifndef EDOPRO_MULTIPLAYER_PACKETS_H
#define EDOPRO_MULTIPLAYER_PACKETS_H

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>

namespace ygo::multiplayer_packets {

inline bool ReadU32(const uint8_t* data, size_t size, size_t& offset,
		uint32_t& value) {
	if(offset > size || size - offset < sizeof(value))
		return false;
	std::memcpy(&value, data + offset, sizeof(value));
	offset += sizeof(value);
	return true;
}

inline void WriteU32(uint8_t* data, size_t offset, uint32_t value) {
	std::memcpy(data + offset, &value, sizeof(value));
}

inline bool AdvanceCards(size_t size, size_t& offset, uint32_t count) {
	constexpr size_t card_bytes = 2u * sizeof(uint32_t);
	if(offset > size || count > (size - offset) / card_bytes)
		return false;
	offset += static_cast<size_t>(count) * card_bytes;
	return true;
}

// MSG_MULTIPLAYER_PRIVATE_PILES is complete for its logical owner. This helper
// converts it into the public projection used by teammates, opponents and
// spectators: Deck top and Hand identities are always hidden; only face-up
// Extra Deck and banished cards remain visible; Graveyard cards stay public.
inline bool SanitizePrivatePiles(uint8_t* data, size_t size,
		uint32_t faceup_position_mask) {
	if(!data || size < 1u + 5u * sizeof(uint32_t))
		return false;

	size_t offset = 1; // logical player
	uint32_t deck_count = 0;
	uint32_t extra_count = 0;
	uint32_t extra_p_count = 0;
	uint32_t hand_count = 0;
	if(!ReadU32(data, size, offset, deck_count)
			|| !ReadU32(data, size, offset, extra_count)
			|| !ReadU32(data, size, offset, extra_p_count)
			|| !ReadU32(data, size, offset, hand_count))
		return false;
	(void)deck_count;
	(void)extra_p_count;

	const size_t top_code_offset = offset;
	uint32_t top_code = 0;
	if(!ReadU32(data, size, offset, top_code))
		return false;
	(void)top_code;
	const size_t hand_offset = offset;
	if(!AdvanceCards(size, offset, hand_count))
		return false;
	const size_t extra_offset = offset;
	if(!AdvanceCards(size, offset, extra_count))
		return false;

	uint32_t grave_count = 0;
	uint32_t removed_count = 0;
	if(!ReadU32(data, size, offset, grave_count)
			|| !ReadU32(data, size, offset, removed_count))
		return false;
	const size_t grave_offset = offset;
	if(!AdvanceCards(size, offset, grave_count))
		return false;
	const size_t removed_offset = offset;
	if(!AdvanceCards(size, offset, removed_count) || offset != size)
		return false;
	(void)grave_offset;

	WriteU32(data, top_code_offset, 0);
	constexpr size_t card_bytes = 2u * sizeof(uint32_t);
	for(uint32_t index = 0; index < hand_count; ++index)
		WriteU32(data, hand_offset + static_cast<size_t>(index) * card_bytes, 0);
	auto hide_facedown = [&](size_t cards_offset, uint32_t count) {
		for(uint32_t index = 0; index < count; ++index) {
			const auto card_offset = cards_offset
				+ static_cast<size_t>(index) * card_bytes;
			uint32_t position = 0;
			std::memcpy(&position, data + card_offset + sizeof(uint32_t),
				sizeof(position));
			if(!(position & faceup_position_mask))
				WriteU32(data, card_offset, 0);
		}
	};
	hide_facedown(extra_offset, extra_count);
	hide_facedown(removed_offset, removed_count);
	return true;
}

} // namespace ygo::multiplayer_packets

#endif // EDOPRO_MULTIPLAYER_PACKETS_H
