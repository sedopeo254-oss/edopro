#ifndef SUMMON_ANIMATION_PLAYER_H
#define SUMMON_ANIMATION_PLAYER_H

#include <cstdint>
#include <memory>

namespace irr::video {
class IVideoDriver;
}

namespace ygo {

// Cross-platform summon-video overlay. FFmpeg decodes the selected media file
// in a background process, while texture upload and drawing stay on Irrlicht's
// render thread.
class SummonAnimationPlayer final {
public:
	explicit SummonAnimationPlayer(irr::video::IVideoDriver* driver);
	~SummonAnimationPlayer();

	SummonAnimationPlayer(const SummonAnimationPlayer&) = delete;
	SummonAnimationPlayer& operator=(const SummonAnimationPlayer&) = delete;

	void Play(uint32_t summon_type);
	void Tick(bool enabled);
	void Draw(uint32_t width, uint32_t height);
	void Stop();

private:
	struct Impl;
	std::unique_ptr<Impl> impl;
};

}

#endif // SUMMON_ANIMATION_PLAYER_H
