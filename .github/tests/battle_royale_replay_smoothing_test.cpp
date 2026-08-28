#include <cstdlib>
#include <iostream>
#include "gframe/multiplayer_battle_royale_replay.h"

using ygo::multiplayer_battle_royale_replay::SnapshotBatch;

static void expect(bool condition, const char* message) {
	if(!condition) {
		std::cerr << message << '\n';
		std::exit(EXIT_FAILURE);
	}
}

int main() {
	SnapshotBatch batch;
	batch.Begin(0x0f);
	expect(batch.IsCollecting() && !batch.HasCurrentSnapshots(),
		"new turn must begin an empty four-player snapshot batch");
	expect(!batch.Observe(0) && !batch.Observe(1) && !batch.Observe(2),
		"partial snapshots must not rebuild the projected private piles");
	expect(batch.HasCurrentSnapshots() && batch.NeedsApply(),
		"a partial authoritative batch must suppress legacy TAG_SWAP");
	expect(batch.Observe(3),
		"the fourth active snapshot must complete the batch exactly once");
	batch.MarkApplied();
	expect(!batch.NeedsApply(),
		"an applied batch must not rebuild again on TAG_SWAP");
	batch.Finish();
	expect(!batch.IsCollecting() && !batch.HasCurrentSnapshots(),
		"finishing a turn must clear only current-batch state");

	batch.Begin(0x0b); // P0, P1 and P3 remain active.
	expect(!batch.Observe(0) && !batch.Observe(1) && batch.Observe(3),
		"eliminated players must not block a reduced active-player batch");
	batch.MarkApplied();
	batch.Finish();

	batch.Begin(0x0f);
	expect(!batch.HasCurrentSnapshots(),
		"a legacy replay without snapshots must keep its TAG_SWAP fallback");
	batch.Finish();
	std::cout << "Battle Royale replay snapshot batching tests passed.\n";
}
