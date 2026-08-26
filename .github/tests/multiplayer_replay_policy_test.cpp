#include "gframe/multiplayer_replay_policy.h"

#include <cstdlib>
#include <iostream>

using namespace ygo::multiplayer_replay_policy;

static void expect(bool value, const char* message) {
	if(!value) {
		std::cerr << "FAILED: " << message << '\n';
		std::exit(1);
	}
}

int main() {
	constexpr uint8_t team1 = 3;
	constexpr uint8_t players = 4;
	constexpr uint8_t all = 0x0f;

	// Exact requested default: throughout P4's turn the shared team projection
	// stays on P1 unless a teammate is actually attacked or targeted.
	auto mask = MakeVisibleHandMask(3, 0xff, all, players, team1);
	expect(mask == 0x09, "P4 turn must show exactly P1 and P4");
	expect(ChooseHandForSide(mask, 3, 0xff, 0, team1, players) == 0,
		"P1 must remain fixed on the allied side during P4 turn");
	expect(ChooseHandForSide(mask, 3, 0xff, 1, team1, players) == 3,
		"P4 must remain on the opposing side during P4 turn");

	mask = MakeVisibleHandMask(3, 1, all, players, team1);
	expect(mask == 0x0a, "P4 attacking/targeting P2 must show P2 and P4");
	expect(ChooseHandForSide(mask, 3, 1, 0, team1, players) == 1,
		"P2 must temporarily replace P1 when P2 is affected");

	mask = MakeVisibleHandMask(3, 2, all, players, team1);
	expect(mask == 0x0c, "P4 attacking/targeting P3 must show P3 and P4");
	expect(ChooseHandForSide(mask, 3, 2, 0, team1, players) == 2,
		"P3 must temporarily replace P1 when P3 is affected");

	mask = MakeVisibleHandMask(3, 0xff, all, players, team1);
	expect(ChooseHandForSide(mask, 3, 0xff, 0, team1, players) == 0,
		"after an event finishes the allied side must return to P1");

	mask = MakeVisibleHandMask(1, 0xff, all, players, team1);
	expect(mask == 0x0a, "P2 turn must show P2 and P4");
	expect(ChooseHandForSide(mask, 1, 0xff, 0, team1, players) == 1,
		"the current teammate must be shown on their own turn");

	mask = MakeVisibleHandMask(1, 0, all, players, team1);
	expect(mask == 0x09, "P2 targeting P1 must temporarily show P1 and P4");
	expect(ChooseHandForSide(mask, 1, 0, 0, team1, players) == 0,
		"the explicitly affected teammate must win over turn ownership");

	const auto without_p1 = static_cast<uint8_t>(all & ~(1u << 0));
	mask = MakeVisibleHandMask(3, 0xff, without_p1, players, team1);
	expect(ChooseHandForSide(mask, 3, 0xff, 0, team1, players) == 1,
		"if P1 is eliminated, P2 must become the stable fallback");

	std::cout << "3v1 deterministic P1 replay policy tests passed.\n";
}
