/*
 * Inherited Duel Mode - active duelist label selection.
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * A 2+1 lobby has TWO physical fields and exactly TWO visible HUD names.
 * Never rename a participant in the replay or mutate the underlying rosters.
 */
#ifndef INHERITED_DUEL_HUD_H
#define INHERITED_DUEL_HUD_H

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace inherited_duel_hud {

// The inherited side has Kaiba in slot 0 and Yugi in slot 1; the opposing
// side only shows its current duelist (Noah), regardless of succession.
inline const std::wstring& VisibleName(const std::vector<std::wstring>& team,
		bool is_inherited_side, uint8_t controller_generation) {
	static const std::wstring empty{};
	if(team.empty())
		return empty;
	const size_t active = is_inherited_side && controller_generation > 0
		&& team.size() > 1 ? 1u : 0u;
	return team[active];
}

} // namespace inherited_duel_hud

#endif // INHERITED_DUEL_HUD_H
