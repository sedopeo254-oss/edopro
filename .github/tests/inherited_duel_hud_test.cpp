#include "gframe/inherited_duel_hud.h"
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>
static void check(bool value, const char* name) {
	if(!value) { std::cerr << "FAILED: " << name << '\n'; std::exit(1); }
}
int main() {
	const std::vector<std::wstring> home{L"Seto Kaiba",L"Yami Yugi"};
	const std::vector<std::wstring> opposing{L"Noah (first)",L"Noah (second)"};
	const auto saved_home = home, saved_opp = opposing;
	// Initial 1v1 duel; reserve two successors.
	check(inherited_duel_hud::VisibleName(home,0)==L"Seto Kaiba","initial Kaiba");
	check(inherited_duel_hud::VisibleName(opposing,0)==L"Noah (first)","initial Noah");
	// Neither event may rotate the other side prematurely.
	check(inherited_duel_hud::VisibleName(home,1)==L"Yami Yugi","Yugi takes over");
	check(inherited_duel_hud::VisibleName(opposing,0)==L"Noah (first)","Noah unchanged until event");
	check(inherited_duel_hud::VisibleName(home,1)==L"Yami Yugi","Yugi stays");
	check(inherited_duel_hud::VisibleName(opposing,1)==L"Noah (second)","Noah takes over");
	// Reversed perspective and replay rewind.
	check(inherited_duel_hud::VisibleName(opposing,1)==L"Noah (second)","reversed side");
	check(inherited_duel_hud::VisibleName(home,0)==L"Seto Kaiba","replay rewind");
	check(inherited_duel_hud::VisibleName(opposing,0)==L"Noah (first)","replay Noah rewind");
	check(inherited_duel_hud::VisibleName(home,1)==L"Yami Yugi","replay resume");
	check(inherited_duel_hud::VisibleName(opposing,1)==L"Noah (second)","replay Noah resume");
	check(inherited_duel_hud::VisibleName(home,1)==L"Yami Yugi","idempotent generation");
	check(saved_home==home && saved_opp==opposing,"no roster mutations");
	check(inherited_duel_hud::VisibleName({},0).empty(),"no names");
	check(inherited_duel_hud::VisibleName({L"Only Noah"},1)==L"Only Noah","safe fallback");
	std::cout << "Inherited Duel 2+2 HUD / independent generations: PASS\n";
}
