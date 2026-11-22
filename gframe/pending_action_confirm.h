#ifndef EDOPRO_PENDING_ACTION_CONFIRM_H
#define EDOPRO_PENDING_ACTION_CONFIRM_H
#include <cstdint>
#include "ocgapi_constants.h"

namespace ygo {

// Client-only pre-commit choice. Mandatory zone/position selections already
// inside the Core do not support a generic cancellation response.
enum class PendingActionKind : std::uint8_t {
	None, NormalSummon, SpecialSummon, MonsterSet, SpellSet, Activate
};

constexpr PendingActionKind ClassifyPendingAction(std::uint8_t msg,
		std::int32_t response, bool forced_chain = false) {
	if(msg == MSG_SELECT_IDLECMD) {
		switch(static_cast<std::uint32_t>(response) & 0xffffu) {
		case 0: return PendingActionKind::NormalSummon;
		case 1: return PendingActionKind::SpecialSummon;
		case 3: return PendingActionKind::MonsterSet;
		case 4: return PendingActionKind::SpellSet;
		case 5: return PendingActionKind::Activate;
		default: return PendingActionKind::None;
		}
	}
	if(msg == MSG_SELECT_BATTLECMD)
		return (static_cast<std::uint32_t>(response) & 0xffffu) == 0
			? PendingActionKind::Activate : PendingActionKind::None;
	if(msg == MSG_SELECT_CHAIN && !forced_chain && response >= 0)
		return PendingActionKind::Activate;
	return PendingActionKind::None;
}

struct PendingActionConfirmation {
	bool active = false;
	std::uint8_t message = 0;
	std::int32_t response = 0;
	PendingActionKind kind = PendingActionKind::None;
	bool Stage(std::uint8_t msg, std::int32_t value) {
		if(active)
			return false;
		const auto next=ClassifyPendingAction(msg,value);
		if(next==PendingActionKind::None)
			return false;
		active=true;
		message=msg;
		response=value;
		kind=next;
		return true;
	}
	void Reset() {
		active=false;
		message=0;
		response=0;
		kind=PendingActionKind::None;
	}
};

} // namespace ygo
#endif
