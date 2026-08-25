#ifndef REPLAY_COMPAT_H
#define REPLAY_COMPAT_H

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <vector>
#include "core_utils.h"
#include "ocgapi_constants.h"

namespace ygo::ReplayCompat {

// The YRPX container already stores every streamed message as
// [message:1][payload length:4][payload:N]. Keep that container untouched and
// publish capabilities as an ordinary, safely-skippable extension packet.
static constexpr uint32_t METADATA_MAGIC = 0x32504d52; // "RMP2" little-endian
static constexpr uint16_t LEGACY_SCHEMA = 0;
static constexpr uint16_t SOURCE13_SCHEMA = 1;
static constexpr uint16_t CURRENT_SCHEMA = 2;
static constexpr uint16_t CURRENT_READER_SCHEMA = 2;

using CapabilityMask = uint64_t;
enum Capability : CapabilityMask {
	CAP_LOGICAL_TURNS          = 1ULL << 0,
	CAP_LOGICAL_DRAWS          = 1ULL << 1,
	CAP_DECK_MASTER_STATE      = 1ULL << 2,
	CAP_PRIVATE_PILE_SNAPSHOTS = 1ULL << 3,
	CAP_REPLAY_VIEW_HINTS      = 1ULL << 4,
	CAP_LOGICAL_LOCATIONS      = 1ULL << 5,
	CAP_LOGICAL_DAMAGE         = 1ULL << 6,
	CAP_PUBLIC_SUMMON_CODES    = 1ULL << 7,
	CAP_LENGTH_PREFIXED_EXT    = 1ULL << 8,
};

static constexpr CapabilityMask CURRENT_CAPABILITIES =
	CAP_LOGICAL_TURNS | CAP_LOGICAL_DRAWS | CAP_DECK_MASTER_STATE
	| CAP_PRIVATE_PILE_SNAPSHOTS | CAP_REPLAY_VIEW_HINTS
	| CAP_LOGICAL_LOCATIONS | CAP_LOGICAL_DAMAGE
	| CAP_PUBLIC_SUMMON_CODES | CAP_LENGTH_PREFIXED_EXT;

struct Info {
	uint16_t schema = LEGACY_SCHEMA;
	uint16_t minimum_reader_schema = LEGACY_SCHEMA;
	CapabilityMask capabilities = 0;
	bool explicit_metadata = false;
	bool metadata_valid = false;

	bool Has(Capability capability) const {
		return (capabilities & static_cast<CapabilityMask>(capability)) != 0;
	}
	bool RequiresNewerReader() const {
		return minimum_reader_schema > CURRENT_READER_SCHEMA;
	}
};

inline void AppendU16(std::vector<uint8_t>& out, uint16_t value) {
	out.push_back(static_cast<uint8_t>(value));
	out.push_back(static_cast<uint8_t>(value >> 8));
}
inline void AppendU32(std::vector<uint8_t>& out, uint32_t value) {
	for(unsigned shift = 0; shift < 32; shift += 8)
		out.push_back(static_cast<uint8_t>(value >> shift));
}
inline void AppendU64(std::vector<uint8_t>& out, uint64_t value) {
	for(unsigned shift = 0; shift < 64; shift += 8)
		out.push_back(static_cast<uint8_t>(value >> shift));
}
inline bool ReadU16(const uint8_t*& data, const uint8_t* end, uint16_t& value) {
	if(static_cast<size_t>(end - data) < 2)
		return false;
	value = static_cast<uint16_t>(data[0])
		| static_cast<uint16_t>(data[1] << 8);
	data += 2;
	return true;
}
inline bool ReadU32(const uint8_t*& data, const uint8_t* end, uint32_t& value) {
	if(static_cast<size_t>(end - data) < 4)
		return false;
	value = 0;
	for(unsigned shift = 0; shift < 32; shift += 8)
		value |= static_cast<uint32_t>(*data++) << shift;
	return true;
}
inline bool ReadU64(const uint8_t*& data, const uint8_t* end, uint64_t& value) {
	if(static_cast<size_t>(end - data) < 8)
		return false;
	value = 0;
	for(unsigned shift = 0; shift < 64; shift += 8)
		value |= static_cast<uint64_t>(*data++) << shift;
	return true;
}

inline CoreUtils::Packet MakeMetadataPacket(
		uint16_t schema = CURRENT_SCHEMA,
		uint16_t minimum_reader_schema = SOURCE13_SCHEMA,
		CapabilityMask capabilities = CURRENT_CAPABILITIES) {
	std::vector<uint8_t> payload;
	payload.reserve(16);
	AppendU32(payload, METADATA_MAGIC);
	AppendU16(payload, schema);
	AppendU16(payload, minimum_reader_schema);
	AppendU64(payload, capabilities);
	return CoreUtils::Packet(MSG_MULTIPLAYER_REPLAY_CAPS,
		payload.data(), payload.size());
}

inline bool ParseMetadata(const CoreUtils::Packet& packet, Info& info) {
	if(packet.message != MSG_MULTIPLAYER_REPLAY_CAPS || packet.buff_size() < 16)
		return false;
	const auto* data = packet.data();
	const auto* end = data + packet.buff_size();
	uint32_t magic{};
	uint16_t schema{};
	uint16_t minimum_reader{};
	uint64_t capabilities{};
	if(!ReadU32(data, end, magic) || magic != METADATA_MAGIC
			|| !ReadU16(data, end, schema)
			|| !ReadU16(data, end, minimum_reader)
			|| !ReadU64(data, end, capabilities))
		return false;
	info.schema = schema;
	info.minimum_reader_schema = minimum_reader;
	info.capabilities = capabilities;
	info.explicit_metadata = true;
	info.metadata_valid = true;
	return true;
}

// Source Export #13 predates explicit metadata. Infer only capabilities that
// are proven by packet presence. This lets one reader support pre-#13, #13,
// and metadata-enabled recordings without guessing from the client version.
inline void ObservePacket(Info& info, uint8_t message) {
	switch(message) {
	case MSG_MULTIPLAYER_NEW_TURN:
		info.capabilities |= CAP_LOGICAL_TURNS;
		break;
	case MSG_MULTIPLAYER_DRAW:
		info.capabilities |= CAP_LOGICAL_DRAWS;
		break;
	case MSG_MULTIPLAYER_DECK_MASTER:
		info.capabilities |= CAP_DECK_MASTER_STATE;
		break;
	case MSG_MULTIPLAYER_PRIVATE_PILES:
		info.capabilities |= CAP_PRIVATE_PILE_SNAPSHOTS
			| CAP_LOGICAL_LOCATIONS | CAP_PUBLIC_SUMMON_CODES;
		break;
	case MSG_MULTIPLAYER_REPLAY_VIEW:
		info.capabilities |= CAP_REPLAY_VIEW_HINTS;
		break;
	default:
		break;
	}
	if(!info.explicit_metadata && info.capabilities != 0) {
		info.schema = SOURCE13_SCHEMA;
		info.minimum_reader_schema = LEGACY_SCHEMA;
		info.metadata_valid = true;
	}
}

// IDs 197..230 are reserved for additive, length-prefixed replay extensions.
// Readers that do not understand a future extension can skip it without
// desynchronizing the stream. OLD_REPLAY_MODE (231) remains separately handled.
inline bool IsSkippableExtension(uint8_t message) {
	return message >= MSG_MULTIPLAYER_REPLAY_CAPS && message < 231;
}

} // namespace ygo::ReplayCompat

#endif // REPLAY_COMPAT_H
