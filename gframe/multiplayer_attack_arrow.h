#ifndef MULTIPLAYER_ATTACK_ARROW_H
#define MULTIPLAYER_ATTACK_ARROW_H

#include <cmath>

namespace ygo::multiplayer_attack_arrow {

inline float AngleFromAttackerToTarget(float attacker_x, float attacker_y,
		float target_x, float target_y) {
	// The mesh head is at local (0, -half_length). Under Irrlicht's Z rotation,
	// atan2(dx, -dy) maps that head exactly onto target - midpoint.
	return std::atan2(target_x - attacker_x, attacker_y - target_y);
}

inline bool PointsToTarget(float attacker_x, float attacker_y,
		float target_x, float target_y, float epsilon = 0.0001f) {
	const float dx = target_x - attacker_x;
	const float dy = target_y - attacker_y;
	const float distance = std::sqrt(dx * dx + dy * dy);
	if(distance < epsilon)
		return false;
	const float half = distance * 0.5f;
	const float angle = AngleFromAttackerToTarget(
		attacker_x, attacker_y, target_x, target_y);
	const float projected_x = std::sin(angle) * half;
	const float projected_y = -std::cos(angle) * half;
	return std::fabs(projected_x - dx * 0.5f) <= epsilon
		&& std::fabs(projected_y - dy * 0.5f) <= epsilon;
}

} // namespace ygo::multiplayer_attack_arrow

#endif
