#include "ocgcore/duel_succession_transfer.h"
#include <cstdlib>
#include <iostream>
#include <vector>
static void check(bool v, const char* label) {
	if(!v) { std::cerr << "FAILED: " << label << '\n'; std::exit(1); }
}
using Z=SuccessionCardZone;
using C=SuccessionCardIdentity;
int main() {
	std::vector<C> existing{
		{1,10992251,0,Z::GRAVE}, // Kaiba's Gradius/other used cards persist
		{2,14291024,1,Z::GRAVE}, // Noah's Ark/other used cards persist
		{3,89631139,0,Z::MONSTER}, // Kaiba's remaining active monster
		{4,53839837,1,Z::MONSTER}
	};
	std::vector<C> yugi{{5,46986414,0,Z::DECK},{6,49021917,0,Z::EXTRA}};
	std::vector<C> second_noah{{7,49389190,1,Z::DECK},{8,96947648,1,Z::EXTRA}};
	auto with_opposing=existing;
	with_opposing.insert(with_opposing.end(),second_noah.begin(),second_noah.end());
	auto home=DuelSuccessionTransfer::preflight(0,with_opposing,yugi);
	check(home.valid() && home.imported_count()==2,"Yugi inherits only undeployed Deck/Extra");
	auto with_yugi=existing;
	with_yugi.insert(with_yugi.end(),yugi.begin(),yugi.end());
	auto opposite=DuelSuccessionTransfer::preflight(1,with_yugi,second_noah);
	check(opposite.valid() && opposite.imported_count()==2,"second Noah imports own Deck/Extra");
	// Duplicate physical instance anywhere across imports must abort both.
	second_noah[0].instance_id=yugi[0].instance_id;
	with_opposing=existing;
	with_opposing.insert(with_opposing.end(),second_noah.begin(),second_noah.end());
	check(!DuelSuccessionTransfer::preflight(0,with_opposing,yugi).valid(),
		"same card object cannot be imported to both sides");
	check(!DuelSuccessionTransfer::preflight(1,with_yugi,second_noah).valid(),
		"cross-side duplicate must be rejected");
	second_noah[0].instance_id=7;
	second_noah[1].owner_side=0;
	check(!DuelSuccessionTransfer::preflight(1,with_yugi,second_noah).valid(),
		"second Noah cannot import cards owned by Kaiba/Yugi");
	std::cout << "Inherited Duel two-side transfer preflight: PASS\n";
}
