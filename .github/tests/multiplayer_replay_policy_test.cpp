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

	auto mask = MakeVisibleHandMask(3, 0xff, all, players);
	expect(mask == 0x08, "P4 turn must reveal P4 only");
	expect(ChooseHandForSide(mask, 3, 0xff, 0, team1, players) == 0xff,
		"no P1/P2/P3 hand may appear during P4 turn without an event");
	expect(ChooseHandForSide(mask, 3, 0xff, 1, team1, players) == 3,
		"P4 hand must remain visible on P4 turn");

	mask = MakeVisibleHandMask(3, 2, all, players);
	expect(mask == 0x0c, "P4 attacking P3 must reveal P3 and P4");
	expect(ChooseHandForSide(mask, 3, 2, 0, team1, players) == 2,
		"P3 must be chosen on the allied side when attacked");

	mask = MakeVisibleHandMask(1, 0, all, players);
	expect(mask == 0x03, "P2 targeting P1 must retain exactly P1/P2 eligibility");
	expect(ChooseHandForSide(mask, 1, 0, 0, team1, players) == 0,
		"targeted P1 must temporarily replace P2's hand on the shared side");

	mask = MakeVisibleHandMask(3, 0xff, all, players);
	expect(ChooseHandForSide(mask, 3, 0xff, 0, team1, players) == 0xff,
		"P3 acting in a chain must not reveal P3 during P4 turn");
	expect(ChooseHandForSide(mask, 3, 0xff, 0, team1, players) == 0xff,
		"replay camera movement alone must never reveal P3's hand");

	mask = MakeVisibleHandMask(3, 2, all, players);
	expect(ChooseHandForSide(mask, 3, 2, 0, team1, players) == 2,
		"P3 must be visible while actually attacked");
	mask = MakeVisibleHandMask(3, 0xff, all, players);
	expect(ChooseHandForSide(mask, 3, 0xff, 0, team1, players) == 0xff,
		"P3 must hide again after the attack finishes");

	mask = MakeVisibleHandMask(3, 2, static_cast<uint8_t>(all & ~(1u << 2)), players);
	expect(mask == 0x08, "eliminated P3 must not be revealed");

	std::cout << "3v1 replay hand policy tests passed.\n";
}
