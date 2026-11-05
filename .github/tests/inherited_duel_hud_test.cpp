#include "gframe/inherited_duel_hud.h"
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

static void check(bool condition, const char* message) {
    if(!condition) {
        std::cerr << "FAILED: " << message << '\n';
        std::exit(1);
    }
}

int main() {
    const std::vector<std::wstring> kaiba_yugi{L"Seto Kaiba", L"Yami Yugi"};
    const std::vector<std::wstring> noah{L"Noah"};
    const auto original_roster = kaiba_yugi;
    // Stage 1: two on-field names, without showing standby Yugi.
    check(inherited_duel_hud::VisibleName(kaiba_yugi, true, 0) == L"Seto Kaiba",
          "before Last Turn, only Kaiba should be displayed");
    check(inherited_duel_hud::VisibleName(noah, false, 0) == L"Noah",
          "Noah must remain the opponent");
    // Stage 2: the same duel/LP bars, one player name is replaced.
    check(inherited_duel_hud::VisibleName(kaiba_yugi, true, 1) == L"Yami Yugi",
          "successor name must replace Kaiba after succession event");
    check(inherited_duel_hud::VisibleName(noah, false, 1) == L"Noah",
          "Noah must not change when Yugi inherits the duel");
    // Reverse seat view: spectator or Noah is the local side.
    check(inherited_duel_hud::VisibleName(noah, false, 1) == L"Noah",
          "reversed view must keep local opponent");
    check(inherited_duel_hud::VisibleName(kaiba_yugi, true, 1) == L"Yami Yugi",
          "reversed view must use successor's name");
    // Replay rewind and reapplication of the event must remain deterministic.
    check(inherited_duel_hud::VisibleName(kaiba_yugi, true, 0) == L"Seto Kaiba",
          "replaying from the beginning restores Kaiba");
    check(inherited_duel_hud::VisibleName(kaiba_yugi, true, 1) == L"Yami Yugi",
          "replaying succession restores Yugi");
    check(inherited_duel_hud::VisibleName(kaiba_yugi, true, 1) == L"Yami Yugi",
          "repeated event must not flip back to Kaiba");
    // Never mutate participant names or abbreviate long names.
    check(kaiba_yugi == original_roster, "read-only label selection cannot mutate replay roster");
    const std::vector<std::wstring> long_names{
        L"Seto Kaiba - Original Duelist", L"Yami Yugi - Successor Duelist"};
    check(inherited_duel_hud::VisibleName(long_names, true, 1) ==
          L"Yami Yugi - Successor Duelist", "name must not be abbreviated internally");
    check(inherited_duel_hud::VisibleName({L"Kaiba"}, true, 1) == L"Kaiba",
          "missing successor slot must not crash or expose an empty name");
    check(inherited_duel_hud::VisibleName({}, true, 0).empty(),
          "early incomplete lobby must display safely");
    std::cout << "Inherited Duel HUD: two names, succession event and replay tests PASS\n";
}
