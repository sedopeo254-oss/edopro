#include <cstdlib>
#include <iostream>
#include "gframe/replay_compat.h"

namespace {
void expect(bool value, const char* message) {
	if(!value) {
		std::cerr << "FAILED: " << message << '\n';
		std::exit(1);
	}
}
}

int main() {
	using namespace ygo::ReplayCompat;

	// New recordings publish an additive length-prefixed envelope.
	auto packet = MakeMetadataPacket();
	Info current{};
	expect(ParseMetadata(packet, current), "current metadata must parse");
	expect(current.explicit_metadata, "current metadata must be explicit");
	expect(current.schema == CURRENT_SCHEMA, "current schema must match");
	expect(current.Has(CAP_PRIVATE_PILE_SNAPSHOTS), "current replay must advertise private piles");
	expect(current.Has(CAP_PUBLIC_SUMMON_CODES), "current replay must advertise public summon codes");
	expect(!current.RequiresNewerReader(), "current replay must be readable here");

	// Temporary replay source export #13 has no envelope; infer its feature set
	// from the exact custom messages it contains.
	Info source13{};
	ObservePacket(source13, MSG_MULTIPLAYER_NEW_TURN);
	ObservePacket(source13, MSG_MULTIPLAYER_DRAW);
	ObservePacket(source13, MSG_MULTIPLAYER_DECK_MASTER);
	ObservePacket(source13, MSG_MULTIPLAYER_PRIVATE_PILES);
	ObservePacket(source13, MSG_MULTIPLAYER_REPLAY_VIEW);
	expect(!source13.explicit_metadata, "source #13 inference must remain implicit");
	expect(source13.schema == SOURCE13_SCHEMA, "source #13 must infer schema 1");
	expect(source13.Has(CAP_LOGICAL_TURNS), "source #13 logical turns");
	expect(source13.Has(CAP_LOGICAL_DRAWS), "source #13 logical draws");
	expect(source13.Has(CAP_DECK_MASTER_STATE), "source #13 deck master state");
	expect(source13.Has(CAP_PRIVATE_PILE_SNAPSHOTS), "source #13 private piles");
	expect(source13.Has(CAP_REPLAY_VIEW_HINTS), "source #13 replay views");

	// Pre-#13 streamed replays remain legacy and use TAG_SWAP/normal draw paths.
	Info legacy{};
	ObservePacket(legacy, MSG_DRAW);
	ObservePacket(legacy, MSG_TAG_SWAP);
	expect(legacy.schema == LEGACY_SCHEMA, "legacy replay must remain schema 0");
	expect(!legacy.Has(CAP_PRIVATE_PILE_SNAPSHOTS), "legacy replay must not fake snapshots");

	// A future additive schema can carry unknown bits. This reader keeps known
	// bits, safely ignores unknown extension packets and reports when a newer
	// semantic reader is genuinely required.
	auto future_packet = MakeMetadataPacket(7, 99,
		CURRENT_CAPABILITIES | (1ULL << 60));
	Info future{};
	expect(ParseMetadata(future_packet, future), "future metadata must parse");
	expect(future.schema == 7, "future schema must be preserved");
	expect(future.Has(CAP_PRIVATE_PILE_SNAPSHOTS), "known future capability must survive");
	expect(future.RequiresNewerReader(), "future minimum reader must be reported");
	expect(IsSkippableExtension(MSG_MULTIPLAYER_REPLAY_CAPS), "metadata must be skippable");
	expect(IsSkippableExtension(230), "future extension 230 must be skippable");
	expect(!IsSkippableExtension(231), "OLD_REPLAY_MODE must not be swallowed");

	CoreUtils::Packet malformed(MSG_MULTIPLAYER_REPLAY_CAPS, nullptr, 0);
	Info bad{};
	expect(!ParseMetadata(malformed, bad), "malformed metadata must be ignored");

	std::cout << "Replay compatibility tests passed.\n";
	return 0;
}
