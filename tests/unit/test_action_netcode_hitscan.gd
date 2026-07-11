extends GutTest


func test_ray_hits_capsule_when_aligned() -> void:
	var origin := Vector3(0.0, 1.35, 0.0)
	var direction := Vector3(0.0, 0.0, -1.0)
	var capsule_base := Vector3(0.0, 1.0, -6.0)
	assert_true(
		ActionNetcodeHitscan.ray_hits_capsule(
			origin,
			direction,
			capsule_base,
			0.45,
			1.8,
			20.0,
		)
	)


func test_move_to_yaw_matches_forward_axis() -> void:
	var forward := ActionNetcodeHitscan.yaw_to_forward(ActionNetcodeHitscan.move_to_yaw(Vector2(0.0, -1.0)))
	assert_true(forward.dot(Vector3(0.0, 0.0, -1.0)) > 0.99)


func test_ray_misses_when_offset() -> void:
	var origin := Vector3(0.0, 1.35, 0.0)
	var direction := Vector3(0.0, 0.0, -1.0)
	var capsule_base := Vector3(6.0, 1.0, -6.0)
	assert_false(
		ActionNetcodeHitscan.ray_hits_capsule(
			origin,
			direction,
			capsule_base,
			0.45,
			1.8,
			20.0,
		)
	)
