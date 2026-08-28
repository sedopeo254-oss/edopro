#include <cstdlib>
#include <iostream>
#include "gframe/multiplayer_battle_royale_live.h"

using namespace ygo::multiplayer_battle_royale_live;

static void expect(bool condition, const char* message) {
	if(!condition) {
		std::cerr << message << '\n';
		std::exit(EXIT_FAILURE);
	}
}

int main() {
	expect(Enabled(false, true),
		"live Battle Royale compatibility must be enabled");
	expect(!Enabled(true, true),
		"Battle Royale replay must remain on the tested replay path");
	expect(!Enabled(false, false),
		"3v1 and stock modes must not enter the live Battle Royale path");
	expect(!NeedsFullTurnRefresh(false, true),
		"live Battle Royale turn changes must not rebuild every private pile");
	expect(NeedsFullTurnRefresh(true, true),
		"replay behavior is managed separately and must remain untouched");
	expect(ShouldCacheSnapshot(false, true),
		"live Battle Royale must cache authoritative logical snapshots");
	expect(ShouldUseSnapshotTagSwap(false, true, true, true),
		"modern live tag swaps must use their authoritative snapshot");
	expect(!ShouldUseSnapshotTagSwap(false, true, false, true),
		"legacy tag swaps without a logical id must retain the ec2 fallback");
	expect(!ShouldUseSnapshotTagSwap(true, true, true, true),
		"replay tag-swap behavior must not be changed by the live fix");
	expect(DrawMoveFrames(false, true) == 10,
		"live Battle Royale draws must retain readable ec2-era movement");
	expect(DrawSoundCount(false, true, true, 6) == 1,
		"a visible multi-card draw must use one batch sound");
	expect(DrawSoundCount(false, true, false, 6) == 0,
		"a hidden player's draw must not stack sounds");
	std::cout << "Live Battle Royale ec2 compatibility policy tests passed.\n";
}
