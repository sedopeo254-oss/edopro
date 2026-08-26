#include "gframe/multiplayer_attack_arrow.h"

#include <cstdlib>
#include <iostream>

using namespace ygo::multiplayer_attack_arrow;

static void expect(bool value, const char* message) {
	if(!value) {
		std::cerr << "FAILED: " << message << '\n';
		std::exit(1);
	}
}

int main() {
	// Source 13-era 3v1 replays encode teammate -> P4 targets as 0xff.
	// The target card location still says P4, so recover P4 before drawing.
	expect(ResolveLogicalTarget(0xff, 3, 4) == 3,
		"legacy team-to-P4 attacks must derive P4 from target loc_info");
	expect(ResolveLogicalTarget(2, 0, 4) == 2,
		"an explicit P3 target must remain authoritative");

	// Team -> opponent, opponent -> team, and diagonal attacks must all put the
	// arrow head on the target rather than on the attacker.
	expect(PointsToTarget(0.0f, 3.0f, 0.0f, -3.0f),
		"team-to-opponent vertical arrow must point at the opponent");
	expect(PointsToTarget(0.0f, -3.0f, 0.0f, 3.0f),
		"opponent-to-team vertical arrow must point at the teammate");
	expect(PointsToTarget(-2.4f, 2.7f, 1.8f, -2.1f),
		"team-to-opponent diagonal arrow must point at the opponent");
	expect(PointsToTarget(2.2f, -2.6f, -1.7f, 2.4f),
		"opponent-to-team diagonal arrow must point at the teammate");
	std::cout << "3v1 attack arrow direction tests passed.\n";
}
