#ifndef EDOPRO_CARD_MOTION_H
#define EDOPRO_CARD_MOTION_H
// Render-only interpolation, independent of game logic and replay payloads.
namespace ygo::card_motion {
constexpr float Clamp01(float x) {return x<=0.f ? 0.f : x>=1.f ? 1.f : x;}
constexpr float SmoothStep(float x) {
	const float t=Clamp01(x);
	return t*t*(3.f-2.f*t);
}
constexpr float MotionProgress(float elapsed, float duration) {
	return duration<=0.f ? 1.f : SmoothStep(elapsed/duration);
}
constexpr float OverlayOpacity(float elapsed_frames,float total_frames) {
	if(total_frames<=0.f) return 1.f;
	const float in=SmoothStep(elapsed_frames/(total_frames*.24f));
	const float out=SmoothStep((total_frames-elapsed_frames)/(total_frames*.22f));
	return in<out?in:out;
}
}
#endif
