/*
 * Inherited Duel Mode -- stable three-seat role contract.
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Seat 0 (Kaiba / Player 1) begins the duel.
 * Seat 1 (Yugi / Player 2) inherits the same field after succession.
 * Seat 2 (Noah / Opponent) remains the opposing duelist.
 * Labels never become player names or replay metadata.
 */
#ifndef INHERITED_DUEL_LOBBY_H
#define INHERITED_DUEL_LOBBY_H

#include <cstdint>

namespace inherited_duel_lobby {
constexpr uint8_t STARTER_SEAT = 0;
constexpr uint8_t SUCCESSOR_SEAT = 1;
constexpr uint8_t OPPONENT_SEAT = 2;
// In GenericDuel::TPResult, choice 1 keeps the requesting home-side
// player in core-side 0, so Player 1 receives the first turn.
constexpr uint8_t STARTER_FIRST_CHOICE = 1;

inline const wchar_t* SeatCaption(uint8_t seat) {
    switch(seat) {
    case STARTER_SEAT: return L"Player 1 - Starts vs opponent";
    case SUCCESSOR_SEAT: return L"Player 2 - Takes over later";
    case OPPONENT_SEAT: return L"Opponent - Both stages";
    default: return L"";
    }
}
} // namespace inherited_duel_lobby
#endif // INHERITED_DUEL_LOBBY_H
