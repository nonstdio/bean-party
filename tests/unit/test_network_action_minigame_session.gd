extends GutTest


func _make_single_player_slots() -> Array[PlayerSlot]:
	var slots: Array[PlayerSlot] = []
	slots.append(PlayerSlot.create("player_1", 1, 0, "Player 1"))
	slots.append(PlayerSlot.create("player_2", 2, 0, "Player 2"))
	return slots


func test_host_consumes_buffered_inputs_in_tick_order() -> void:
	var session := NetworkActionMinigameSession.new()
	add_child_autofree(session)

	var slots := _make_single_player_slots()
	assert_true(session.start_minigame(slots, "action_test"))

	var player_id := "player_1"
	session._host_apply_remote_input(
		1,
		player_id,
		Vector2(0.0, -1.0),
		false,
		false,
		0.0,
		1,
	)
	session._host_apply_remote_input(
		1,
		player_id,
		Vector2(0.0, 1.0),
		false,
		false,
		0.0,
		2,
	)

	var first := session._consume_simulation_inputs()
	var second := session._consume_simulation_inputs()

	assert_eq(int(first[player_id]["move"].y), -1)
	assert_eq(int(second[player_id]["move"].y), 1)
	assert_eq(int(session._processed_input_tick_by_player[player_id]), 2)


func test_snapshot_ack_reports_processed_not_received_tick() -> void:
	var session := NetworkActionMinigameSession.new()
	add_child_autofree(session)

	var slots := _make_single_player_slots()
	assert_true(session.start_minigame(slots, "action_test"))

	var player_id := "player_1"
	session._host_apply_remote_input(1, player_id, Vector2.RIGHT, false, false, 0.0, 5)
	session._consume_simulation_inputs()
	session._update_snapshot_input_acks()

	assert_eq(int(session._acked_input_tick_by_player[player_id]), 1)


func test_snapshot_reconciliation_resets_yaw_before_replay() -> void:
	var session := NetworkActionMinigameSession.new()
	add_child_autofree(session)

	var slots := _make_single_player_slots()
	assert_true(session.start_minigame(slots, "action_test"))

	var player_id := "player_1"
	session._local_player_ids = PackedStringArray([player_id])
	session._predicted_positions[player_id] = Vector3(0.0, 1.0, 0.0)
	session._predicted_yaw[player_id] = 1.5
	session._predicted_vertical_velocity[player_id] = 0.0
	session._local_input_history[player_id] = [
		{
			"tick": 3,
			"payload": {"move": Vector2(-1.0, 0.0), "jump": false, "fire": false, "aim_yaw": 1.5},
			"delta": 1.0 / 30.0,
		},
	]

	var payload := {
		player_id: {
			"x": 0.0,
			"y": 1.0,
			"z": 0.0,
			"yaw": 0.25,
			"health": HostActionSimulator.MAX_HEALTH,
			"eliminations": 0,
			"acked_input_tick": 2,
			"vertical_velocity": 0.0,
		},
	}
	session._apply_snapshot_payload(1, payload)

	assert_gt(absf(float(session._predicted_yaw[player_id]) - 1.5), 0.5)

