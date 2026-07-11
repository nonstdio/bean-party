extends GutTest


func test_hitscan_damages_target_in_line() -> void:
	var simulator := HostActionSimulator.new()
	var player_ids := PackedStringArray(["shooter", "target"])
	simulator.reset_for_player_ids(player_ids)
	simulator.positions_by_player_id["shooter"] = Vector3(0.0, 1.0, 0.0)
	simulator.positions_by_player_id["target"] = Vector3(0.0, 1.0, -8.0)
	simulator.yaw_by_player_id["shooter"] = 0.0
	simulator.tick(
		{
			"shooter": {
				"move": Vector2.ZERO,
				"jump": false,
				"fire": true,
				"aim_yaw": 0.0,
			},
		},
		1.0 / 30.0,
		{"shooter": true, "target": true},
	)
	assert_eq(simulator.get_health("target"), 50)


func test_last_player_standing_wins() -> void:
	var simulator := HostActionSimulator.new()
	var player_ids := PackedStringArray(["shooter", "target"])
	simulator.reset_for_player_ids(player_ids)
	simulator.positions_by_player_id["shooter"] = Vector3(0.0, 1.0, 0.0)
	simulator.positions_by_player_id["target"] = Vector3(0.0, 1.0, -8.0)
	simulator.yaw_by_player_id["shooter"] = 0.0
	var fire_input := {
		"shooter": {
			"move": Vector2.ZERO,
			"jump": false,
			"fire": true,
			"aim_yaw": 0.0,
		},
	}
	var eligible := {"shooter": true, "target": true}
	simulator.tick(fire_input, 1.0 / 30.0, eligible)
	simulator.tick(fire_input, HostActionSimulator.FIRE_COOLDOWN_SEC + 0.05, eligible)
	assert_eq(simulator.winner_player_id, "shooter")


func test_inactive_player_cannot_be_damaged() -> void:
	var simulator := HostActionSimulator.new()
	var player_ids := PackedStringArray(["shooter", "target"])
	simulator.reset_for_player_ids(player_ids)
	simulator.positions_by_player_id["shooter"] = Vector3(0.0, 1.0, 0.0)
	simulator.positions_by_player_id["target"] = Vector3(0.0, 1.0, -8.0)
	simulator.yaw_by_player_id["shooter"] = 0.0
	simulator.tick(
		{
			"shooter": {
				"move": Vector2.ZERO,
				"jump": false,
				"fire": true,
				"aim_yaw": 0.0,
			},
		},
		1.0 / 30.0,
		{"shooter": true},
	)
	assert_eq(simulator.get_health("target"), HostActionSimulator.MAX_HEALTH)


func test_snapshot_hash_matches_after_export_load_round_trip() -> void:
	var simulator := HostActionSimulator.new()
	simulator.reset_for_player_ids(PackedStringArray(["player_1", "player_2"]))
	var hash_before := simulator.state_hash()
	var payload := simulator.export_positions()
	var clone := HostActionSimulator.new()
	clone.load_positions(payload)
	assert_eq(clone.state_hash(), hash_before)


func test_turn_left_rotates_without_translation() -> void:
	var simulator := HostActionSimulator.new()
	simulator.reset_for_player_ids(PackedStringArray(["player_1"]))
	var start := simulator.get_position("player_1")
	simulator.tick(
		{
			"player_1": {
				"move": Vector2(-1.0, 0.0),
				"jump": false,
				"fire": false,
			},
		},
		0.5,
		{"player_1": true},
	)
	assert_true(simulator.get_yaw("player_1") < 0.0)
	assert_almost_eq(simulator.get_position("player_1"), start, Vector3(0.01, 0.01, 0.01))


func test_forward_moves_along_facing() -> void:
	var simulator := HostActionSimulator.new()
	simulator.reset_for_player_ids(PackedStringArray(["player_1"]))
	simulator.yaw_by_player_id["player_1"] = 0.0
	var start := simulator.get_position("player_1")
	simulator.tick(
		{
			"player_1": {
				"move": Vector2(0.0, -1.0),
				"jump": false,
				"fire": false,
			},
		},
		0.5,
		{"player_1": true},
	)
	var delta := simulator.get_position("player_1") - start
	assert_true(delta.z < 0.0)
	assert_almost_eq(delta.x, 0.0, 0.01)
