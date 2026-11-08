#include "gframe/multiplayer_attack_arrow.h"

#include <cstdlib>
#include <iostream>

using namespace ygo::multiplayer_attack_arrow;

static void expect(bool condition, const char* message) {
	if(!condition) {
		std::cerr << "FAILED: " << message << '\n';
		std::exit(1);
	}
}

int main() {
	// Physical side 0 targets physical side 1, and vice versa. The reserved
	// successor does not introduce a third on-field target.
	expect(OppositeDisplaySide(0) == 1,
		"side 0 must attack directly into side 1");
	expect(OppositeDisplaySide(1) == 0,
		"side 1 must attack directly into side 0");
	expect(OppositeDisplaySide(0xff) == 0xff,
		"invalid attacker display sides must stay invalid");

	// EDOPro's two physical monster fields are at positive / negative Y.
	// The arrow mesh head is at local -Y, so test both attack directions
	// (including the inherited Kaiba -> Yugi segment of the same duel).
	expect(PointsToTarget(3.95f, 1.4f, 3.95f, -1.4f),
		"monster attack from physical side 0 to 1");
	expect(PointsToTarget(3.95f, -1.4f, 3.95f, 1.4f),
		"monster attack from physical side 1 to 0");
	expect(PointsToTarget(2.2f, 1.4f, 6.1f, -1.4f),
		"diagonal inherited attack towards opposite side");
	expect(PointsToTarget(6.1f, -1.4f, 2.2f, 1.4f),
		"reverse diagonal inherited attack");
	expect(PointsToTarget(3.95f, 1.4f, 3.95f, -3.2f),
		"direct attack from physical side 0 to side 1 anchor");
	expect(PointsToTarget(3.95f, -1.4f, 3.95f, 3.2f),
		"direct attack from physical side 1 to side 0 anchor");
	std::cout << "Inherited Duel arrow geometry: PASS\n";
}
