/*
 * Inherited Duel Mode: 2+2 network seats, one active seat per side.
 * Side 0: Kaiba -> Yugi. Side 1: Noah first -> Noah second.
 */
#ifndef INHERITED_DUEL_LOBBY_H
#define INHERITED_DUEL_LOBBY_H
#include <cstdint>
namespace inherited_duel_lobby {
constexpr uint8_t STARTER_SEAT = 0;
constexpr uint8_t SUCCESSOR_SEAT = 1;
constexpr uint8_t OPPONENT_SEAT = 2;
constexpr uint8_t OPPONENT_SUCCESSOR_SEAT = 3;
constexpr uint8_t STARTER_FIRST_CHOICE = 1;
inline const wchar_t* SeatCaption(uint8_t seat) {
	switch(seat) {
	case STARTER_SEAT: return L"Kaiba - Before Last Turn";
	case SUCCESSOR_SEAT: return L"Yugi - Inherits Kaiba";
	case OPPONENT_SEAT: return L"Noah - Vs Kaiba";
	case OPPONENT_SUCCESSOR_SEAT: return L"Noah - Vs Yugi";
	default: return L"";
	}
}
}
#endif
