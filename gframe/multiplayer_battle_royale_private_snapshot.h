#ifndef MULTIPLAYER_BATTLE_ROYALE_PRIVATE_SNAPSHOT_H
#define MULTIPLAYER_BATTLE_ROYALE_PRIVATE_SNAPSHOT_H

#include <cstddef>
#include <cstdint>
#include <vector>
#include "ocgapi_constants.h"

namespace ygo::multiplayer_battle_royale_private_snapshot {

constexpr bool ShouldBroadcastMaskedSnapshot(bool is_battle_royale,
        bool is_three_vs_one) {
    // This transport fix is exclusively for live 1v1v1v1. 3v1 keeps its
    // existing owner-only private snapshot routing and tested replay logic.
    return is_battle_royale && !is_three_vs_one;
}

inline bool ReadU32(const std::vector<uint8_t>& buffer, std::size_t offset,
        uint32_t& value) {
    if(offset > buffer.size() || buffer.size() - offset < sizeof(uint32_t))
        return false;
    value = static_cast<uint32_t>(buffer[offset])
        | (static_cast<uint32_t>(buffer[offset + 1]) << 8)
        | (static_cast<uint32_t>(buffer[offset + 2]) << 16)
        | (static_cast<uint32_t>(buffer[offset + 3]) << 24);
    return true;
}

inline bool WriteU32(std::vector<uint8_t>& buffer, std::size_t offset,
        uint32_t value) {
    if(offset > buffer.size() || buffer.size() - offset < sizeof(uint32_t))
        return false;
    buffer[offset] = static_cast<uint8_t>(value);
    buffer[offset + 1] = static_cast<uint8_t>(value >> 8);
    buffer[offset + 2] = static_cast<uint8_t>(value >> 16);
    buffer[offset + 3] = static_cast<uint8_t>(value >> 24);
    return true;
}

inline bool HasCardEntries(const std::vector<uint8_t>& buffer,
        std::size_t offset, uint32_t count) {
    constexpr std::size_t card_size = 2 * sizeof(uint32_t);
    return offset <= buffer.size()
        && count <= (buffer.size() - offset) / card_size;
}

// Converts a full MSG_MULTIPLAYER_PRIVATE_PILES payload into the public view
// that every non-owner Battle Royale client may receive. Counts and public
// zones are preserved, while Hand, Deck top, face-down Extra and face-down
// Banished identities are hidden. The input remains unchanged if malformed.
inline bool MaskForOpponent(std::vector<uint8_t>& payload) {
    // logical player + deck/extra/p-count/hand/top-code
    constexpr std::size_t fixed_prefix = 1 + 5 * sizeof(uint32_t);
    if(payload.size() < fixed_prefix)
        return false;

    auto masked = payload;
    std::size_t cursor = 1;
    uint32_t deck_count = 0;
    uint32_t extra_count = 0;
    uint32_t extra_p_count = 0;
    uint32_t hand_count = 0;
    uint32_t top_code = 0;
    if(!ReadU32(masked, cursor, deck_count)) return false;
    cursor += sizeof(uint32_t);
    if(!ReadU32(masked, cursor, extra_count)) return false;
    cursor += sizeof(uint32_t);
    if(!ReadU32(masked, cursor, extra_p_count)) return false;
    cursor += sizeof(uint32_t);
    if(!ReadU32(masked, cursor, hand_count)) return false;
    cursor += sizeof(uint32_t);
    if(!ReadU32(masked, cursor, top_code)) return false;
    if(!WriteU32(masked, cursor, 0)) return false;
    cursor += sizeof(uint32_t);

    if(!HasCardEntries(masked, cursor, hand_count))
        return false;
    for(uint32_t i = 0; i < hand_count; ++i) {
        if(!WriteU32(masked, cursor, 0)
                || !WriteU32(masked, cursor + sizeof(uint32_t),
                    POS_FACEDOWN_DEFENSE))
            return false;
        cursor += 2 * sizeof(uint32_t);
    }

    if(!HasCardEntries(masked, cursor, extra_count))
        return false;
    for(uint32_t i = 0; i < extra_count; ++i) {
        uint32_t position = 0;
        if(!ReadU32(masked, cursor + sizeof(uint32_t), position))
            return false;
        if(!(position & POS_FACEUP)
                && !WriteU32(masked, cursor, 0))
            return false;
        cursor += 2 * sizeof(uint32_t);
    }

    uint32_t grave_count = 0;
    uint32_t removed_count = 0;
    if(!ReadU32(masked, cursor, grave_count)) return false;
    cursor += sizeof(uint32_t);
    if(!ReadU32(masked, cursor, removed_count)) return false;
    cursor += sizeof(uint32_t);

    if(!HasCardEntries(masked, cursor, grave_count))
        return false;
    // Graveyard identities are public and are intentionally preserved.
    cursor += static_cast<std::size_t>(grave_count)
        * 2 * sizeof(uint32_t);

    if(!HasCardEntries(masked, cursor, removed_count))
        return false;
    for(uint32_t i = 0; i < removed_count; ++i) {
        uint32_t position = 0;
        if(!ReadU32(masked, cursor + sizeof(uint32_t), position))
            return false;
        if(!(position & POS_FACEUP)
                && !WriteU32(masked, cursor, 0))
            return false;
        cursor += 2 * sizeof(uint32_t);
    }

    if(cursor != masked.size())
        return false;
    payload.swap(masked);
    return true;
}

} // namespace ygo::multiplayer_battle_royale_private_snapshot

#endif
