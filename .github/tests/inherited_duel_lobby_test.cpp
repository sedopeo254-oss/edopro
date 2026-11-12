#include "gframe/inherited_duel_lobby.h"
#include "gframe/inherited_duel_hud.h"
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>
using namespace inherited_duel_lobby;
static_assert(STARTER_SEAT==0, "Kaiba starts in seat 0");
static_assert(SUCCESSOR_SEAT==1, "Yugi is reserved on side 0");
static_assert(OPPONENT_SEAT==2, "Noah starts in seat 2");
static_assert(OPPONENT_SUCCESSOR_SEAT==3, "Noah's successor is seat 3");
static_assert(STARTER_FIRST_CHOICE==1, "First player is Kaiba");
static void check(bool ok,const char* why) {
	if(!ok) { std::cerr << "FAILED: "<<why<<'\n';std::exit(1); }
}
int main() {
	check(std::wstring(SeatCaption(0)).find(L"Kaiba")!=std::wstring::npos,"Kaiba label");
	check(std::wstring(SeatCaption(1)).find(L"Yugi")!=std::wstring::npos,"Yugi label");
	check(std::wstring(SeatCaption(2)).find(L"Noah")!=std::wstring::npos,"Noah label");
	check(std::wstring(SeatCaption(3)).find(L"Noah")!=std::wstring::npos,"Second Noah label");
	check(std::wstring(SeatCaption(4)).empty(),"out of range seat");
	const std::vector<std::wstring> home={L"Kaiba",L"Yugi"};
	const std::vector<std::wstring> oppo={L"Noah A",L"Noah B"};
	check(inherited_duel_hud::VisibleName(home,0)==L"Kaiba","stage one home");
	check(inherited_duel_hud::VisibleName(oppo,0)==L"Noah A","stage one opposing");
	check(inherited_duel_hud::VisibleName(home,1)==L"Yugi","stage two home");
	check(inherited_duel_hud::VisibleName(oppo,1)==L"Noah B","stage two opposing");
	std::cout << "Inherited Duel four-seat lobby roles: PASS\n";
}
