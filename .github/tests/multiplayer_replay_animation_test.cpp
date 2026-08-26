#include <cstdlib>
#include <iostream>
#include "gframe/multiplayer_replay_animation.h"

using namespace ygo::multiplayer_replay_animation;

static void expect(bool condition, const char* message) {
	if(!condition) {
		std::cerr << message << '\n';
		std::exit(EXIT_FAILURE);
	}
}

int main() {
	const auto live = GetSummonTiming(false, true);
	expect(live.reveal_frames == 30 && live.settle_frames == 11
		&& live.move_frames == 10,
		"live duel summon timing must remain stock");
	const auto replay = GetSummonTiming(true, true);
	expect(replay.reveal_frames == 15 && replay.settle_frames == 4
		&& replay.move_frames == 6,
		"3v1 replay summons must use the smooth timing");
	expect(DrawSoundCount(true, true, 6) == 1,
		"Card of Sanctity must play one visible batch draw sound");
	expect(DrawSoundCount(true, false, 6) == 0,
		"hidden teammate draws must not stack sounds");
	expect(DrawSoundCount(false, true, 6) == 6,
		"non-3v1 behavior must stay unchanged");
	std::cout << "Replay draw/summon animation policy tests passed.\n";
}
