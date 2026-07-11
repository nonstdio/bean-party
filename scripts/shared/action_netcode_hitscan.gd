class_name ActionNetcodeHitscan
extends RefCounted


static func ray_hits_capsule(
		origin: Vector3,
		direction: Vector3,
		capsule_base: Vector3,
		radius: float,
		height: float,
		max_distance: float,
) -> bool:
	if direction.length_squared() <= 0.0001 or max_distance <= 0.0:
		return false

	var ray_dir := direction.normalized()
	var segment_start := capsule_base
	var segment_end := capsule_base + Vector3(0.0, height, 0.0)
	var segment := segment_end - segment_start
	var ray_offset := origin - segment_start

	var segment_length_sq := segment.dot(segment)
	var ray_projection := ray_dir.dot(ray_dir)
	var mixed := ray_dir.dot(segment)
	var ray_offset_projection := ray_dir.dot(ray_offset)
	var segment_offset_projection := segment.dot(ray_offset)

	var ray_distance := 0.0
	var segment_t := 0.0
	var denominator := ray_projection * segment_length_sq - mixed * mixed
	if denominator <= 0.0001:
		ray_distance = 0.0
		segment_t = clampf(segment_offset_projection / segment_length_sq, 0.0, 1.0)
	else:
		ray_distance = clampf(
			(mixed * segment_offset_projection - ray_offset_projection * segment_length_sq) / denominator,
			0.0,
			max_distance,
		)
		segment_t = clampf(
			(ray_projection * segment_offset_projection - mixed * ray_offset_projection) / denominator,
			0.0,
			1.0,
		)

	if ray_distance < 0.0 or ray_distance > max_distance:
		return false

	var ray_point := origin + ray_dir * ray_distance
	var segment_point := segment_start + segment * segment_t
	return ray_point.distance_squared_to(segment_point) <= radius * radius


static func yaw_to_forward(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, -cos(yaw))


static func move_to_yaw(move: Vector2) -> float:
	return atan2(move.x, -move.y)
