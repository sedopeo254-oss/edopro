/*
 * Inherited Duel Mode: exactly one visible name per physical field.
 * Original Kaiba/Yugi and Noah/Noah rosters remain unchanged in YRPX.
 */
#ifndef INHERITED_DUEL_HUD_H
#define INHERITED_DUEL_HUD_H
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>
namespace inherited_duel_hud {
inline const std::wstring& VisibleName(const std::vector<std::wstring>& side,
		uint8_t generation) {
	static const std::wstring empty{};
	if(side.empty()) return empty;
	const size_t index = generation > 0 && side.size() > 1 ? 1u : 0u;
	return side[index];
}
}
#endif
