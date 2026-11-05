#include "gframe/inherited_duel_lobby.h"
#include "gframe/inherited_duel_hud.h"
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

using namespace inherited_duel_lobby;
static_assert(STARTER_SEAT == 0, "Player 1 must occupy the starting seat");
static_assert(SUCCESSOR_SEAT == 1, "Player 2 must be the reserved successor");
static_assert(OPPONENT_SEAT == 2, "Opponent must occupy the third lobby seat");
static_assert(STARTER_FIRST_CHOICE == 1,
              "TPResult choice 1 keeps Player 1's home side in first position");

void expect(bool ok, const char* description) {
    if(!ok) {
        std::cerr << "FAILED: " << description << '\n';
        std::exit(1);
    }
}

int main() {
    const std::vector<std::wstring> team = {L"Seto", L"yugi"};
    const std::vector<std::wstring> opponent = {L"noah"};
    const auto original = team;
    expect(std::wstring(SeatCaption(STARTER_SEAT)).find(L"Starts") != std::wstring::npos,
           "starter must be visibly labeled");
    expect(std::wstring(SeatCaption(SUCCESSOR_SEAT)).find(L"Takes over") != std::wstring::npos,
           "successor must be visibly labeled");
    expect(std::wstring(SeatCaption(OPPONENT_SEAT)).find(L"Both stages") != std::wstring::npos,
           "opponent must be visibly labeled for both stages");
    expect(std::wstring(SeatCaption(4)).empty(), "invalid seat has no inherited label");
    expect(inherited_duel_hud::VisibleName(team, true, 0) == L"Seto",
           "stage 1: Seto against Noah");
    expect(inherited_duel_hud::VisibleName(opponent, false, 0) == L"noah",
           "stage 1: opponent appears unchanged");
    expect(inherited_duel_hud::VisibleName(team, true, 1) == L"yugi",
           "stage 2: Yugi replaces Seto");
    expect(inherited_duel_hud::VisibleName(opponent, false, 1) == L"noah",
           "stage 2: Noah remains the same opponent");
    expect(team == original, "role labels never modify names saved in replay");
    std::cout << "Inherited Duel lobby seat roles and starter selection: PASS\n";
}
