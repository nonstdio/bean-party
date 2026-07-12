extends GutTest

var _test_port: int


func before_each() -> void:
	_test_port = 19000 + int(Time.get_ticks_msec() % 1000)


func _make_slots() -> Array[PlayerSlot]:
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")
	return lobby.slots


func test_apply_host_minigame_result_stores_winner() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var slots := _make_slots()
	var participant_ids := PackedStringArray([slots[0].player_id, slots[1].player_id])
	var result := HostSnapshotSimulator.new().build_result(participant_ids)
	result.placements[0] = PackedStringArray([slots[1].player_id])

	assert_true(authority.apply_host_minigame_result(result))
	assert_eq(authority.minigame_winner_player_id, slots[1].player_id)


func test_host_minigame_session_submits_matching_result() -> void:
	var match_session := MatchSession.new()
	add_child_autofree(match_session)

	var minigame_session := NetworkMinigameSession.new()
	match_session.add_child(minigame_session)
	assert_eq(match_session.host(_test_port), OK)
	await get_tree().process_frame

	var slots := _make_slots()
	var received: Array = []
	minigame_session.minigame_result_ready.connect(
		func(result: MinigameResult) -> void: received.append(result)
	)

	assert_true(minigame_session.start_minigame(slots, "minigame_test"))
	minigame_session._simulator.winner_player_id = slots[0].player_id
	minigame_session._simulator.positions_by_player_id[slots[0].player_id] = (
		HostSnapshotSimulator.GOAL_CENTER
	)
	minigame_session.force_complete_round()
	await get_tree().process_frame

	assert_eq(received.size(), 1)
	var result: MinigameResult = received[0]
	assert_eq(result.status, MinigameResult.Status.COMPLETED)
	assert_eq(result.placements[0], PackedStringArray([slots[0].player_id]))


func test_local_device_slot_uses_lobby_assignment() -> void:
	var match_session := MatchSession.new()
	add_child_autofree(match_session)

	var lobby_session := NetworkLobbySession.new()
	match_session.add_child(lobby_session)

	var minigame_session := NetworkMinigameSession.new()
	match_session.add_child(minigame_session)
	assert_eq(match_session.host(_test_port), OK)
	await get_tree().process_frame

	var local_slots := lobby_session.get_local_slots()
	assert_false(local_slots.is_empty())
	var player_id := local_slots[0].player_id
	assert_true(lobby_session.set_local_device_slot(player_id, 2))
	assert_eq(minigame_session._local_device_slot_for_player(player_id), 2)


func test_authoritative_snapshot_hash_matches_after_apply() -> void:
	var host_session := autofree(NetworkMinigameSession.new()) as NetworkMinigameSession
	var client_session := autofree(NetworkMinigameSession.new()) as NetworkMinigameSession
	var payload := {
		"player_a": {"x": 120.0, "y": 88.0},
		"player_b": {"x": 500.0, "y": 360.0},
	}

	host_session._publish_authoritative_snapshot(3, payload)
	client_session._apply_snapshot_payload(3, payload)

	assert_eq(host_session.get_snapshot_serial(), client_session.get_snapshot_serial())
	assert_eq(host_session.get_snapshot_hash(), client_session.get_snapshot_hash())


func test_remote_input_rejects_spoofed_player_id() -> void:
	var minigame_session := NetworkMinigameSession.new()
	add_child_autofree(minigame_session)

	var slots := _make_slots()
	assert_true(minigame_session.start_minigame(slots, "minigame_test"))

	var victim_id := slots[0].player_id
	var attacker_peer_id := slots[1].owning_peer_id
	minigame_session._host_apply_remote_input(attacker_peer_id, victim_id, Vector2.RIGHT, 1)

	assert_false(minigame_session._remote_inputs.has(victim_id))


func test_remote_input_accepts_owned_player_id() -> void:
	var minigame_session := NetworkMinigameSession.new()
	add_child_autofree(minigame_session)

	var slots := _make_slots()
	assert_true(minigame_session.start_minigame(slots, "minigame_test"))

	var player_id := slots[1].player_id
	var peer_id := slots[1].owning_peer_id
	minigame_session._host_apply_remote_input(peer_id, player_id, Vector2.UP, 1)

	assert_eq(minigame_session._remote_inputs[player_id], Vector2.UP)


func test_early_win_broadcasts_final_snapshot() -> void:
	var host_session := NetworkMinigameSession.new()
	var client_session := NetworkMinigameSession.new()
	add_child_autofree(host_session)
	add_child_autofree(client_session)

	var slots := _make_slots()
	assert_true(host_session.start_minigame(slots, "minigame_test"))

	host_session._simulator.winner_player_id = slots[0].player_id
	host_session._simulator.positions_by_player_id[slots[0].player_id] = (
		HostSnapshotSimulator.GOAL_CENTER
	)
	var starting_serial := host_session.get_snapshot_serial()

	host_session._host_tick(0.01)

	assert_gt(host_session.get_snapshot_serial(), starting_serial)
	(
		client_session
		. _apply_snapshot_payload(
			host_session.get_snapshot_serial(),
			host_session._simulator.export_positions(),
		)
	)
	assert_eq(client_session.get_snapshot_hash(), host_session.get_snapshot_hash())


func test_prediction_reconciles_local_player_on_snapshot() -> void:
	var client_session := NetworkMinigameSession.new()
	add_child_autofree(client_session)

	var slots := _make_slots()
	assert_true(client_session.start_minigame(slots, "minigame_test"))
	client_session.prediction_enabled = true
	client_session._local_player_ids = PackedStringArray([slots[1].player_id])
	client_session._predicted_positions[slots[1].player_id] = Vector2(200.0, 200.0)

	var payload := {
		slots[1].player_id: {"x": 120.0, "y": 88.0, "acked_input_tick": 0},
	}
	client_session._apply_snapshot_payload(1, payload)

	var stats := client_session.get_prediction_stats()
	assert_eq(int(stats.get("correction_count", 0)), 1)
	assert_eq(
		client_session._predicted_positions[slots[1].player_id],
		Vector2(120.0, 88.0),
	)
	assert_eq(
		client_session.get_display_position(slots[1].player_id),
		Vector2(200.0, 200.0),
	)


func test_prediction_correction_offset_decays_toward_authoritative() -> void:
	var client_session := NetworkMinigameSession.new()
	add_child_autofree(client_session)

	var slots := _make_slots()
	assert_true(client_session.start_minigame(slots, "minigame_test"))
	client_session.prediction_enabled = true
	client_session._local_player_ids = PackedStringArray([slots[1].player_id])
	client_session._predicted_positions[slots[1].player_id] = Vector2(200.0, 200.0)
	client_session._display_positions[slots[1].player_id] = Vector2(200.0, 200.0)

	var payload := {
		slots[1].player_id: {"x": 120.0, "y": 88.0, "acked_input_tick": 0},
	}
	client_session._apply_snapshot_payload(1, payload)

	var player_id := String(slots[1].player_id)
	assert_not_null(client_session._input_source)
	var offset_before: Vector2 = client_session._correction_offsets.get(player_id, Vector2.ZERO)
	assert_gt(offset_before.length(), 1.0)

	client_session._client_predict_local(0.05)
	var offset_after: Vector2 = client_session._correction_offsets.get(player_id, Vector2.ZERO)
	assert_lt(offset_after.length(), offset_before.length())


func test_prediction_replays_unacked_inputs_after_delayed_snapshot() -> void:
	var client_session := NetworkMinigameSession.new()
	add_child_autofree(client_session)

	var slots := _make_slots()
	assert_true(client_session.start_minigame(slots, "minigame_test"))
	client_session.prediction_enabled = true
	var player_id := String(slots[1].player_id)
	client_session._local_player_ids = PackedStringArray([slots[1].player_id])
	client_session._predicted_positions[player_id] = Vector2(100.0, 100.0)
	client_session._display_positions[player_id] = Vector2(100.0, 100.0)
	(
		client_session
		. _input_source
		. set_action_strength(
			slots[1].player_id,
			MinigameInputSource.ACTION_MOVE_RIGHT,
			1.0,
		)
	)

	for _i in 5:
		client_session._sample_local_inputs(0.05)
		client_session._client_predict_local(0.05)

	var predicted_before: Vector2 = client_session._predicted_positions[player_id]
	var auth_x := 100.0 + HostSnapshotSimulator.MOVE_SPEED * 0.05 * 2.0
	var payload := {
		player_id: {"x": auth_x, "y": 100.0, "acked_input_tick": 2},
	}
	client_session._apply_snapshot_payload(1, payload)

	var predicted_after: Vector2 = client_session._predicted_positions[player_id]
	assert_gt(predicted_after.x, auth_x)
	assert_true(absf(predicted_after.x - predicted_before.x) < 0.01)
	var stats := client_session.get_prediction_stats()
	assert_eq(int(stats.get("correction_count", 0)), 0)


func test_remote_input_ignores_stale_input_tick() -> void:
	var minigame_session := NetworkMinigameSession.new()
	add_child_autofree(minigame_session)

	var slots := _make_slots()
	assert_true(minigame_session.start_minigame(slots, "minigame_test"))

	var player_id := slots[1].player_id
	var peer_id := slots[1].owning_peer_id
	minigame_session._host_apply_remote_input(peer_id, player_id, Vector2.RIGHT, 5)
	minigame_session._host_apply_remote_input(peer_id, player_id, Vector2.UP, 3)

	assert_eq(minigame_session._remote_inputs[player_id], Vector2.RIGHT)
	assert_eq(int(minigame_session._latest_input_tick_by_player[String(player_id)]), 5)


func test_client_predict_local_moves_display_position() -> void:
	var client_session := NetworkMinigameSession.new()
	add_child_autofree(client_session)

	var slots := _make_slots()
	assert_true(client_session.start_minigame(slots, "minigame_test"))
	client_session.prediction_enabled = true
	client_session._local_player_ids = PackedStringArray([slots[1].player_id])
	client_session._predicted_positions[slots[1].player_id] = Vector2(100.0, 100.0)
	client_session._display_positions[slots[1].player_id] = Vector2(100.0, 100.0)
	(
		client_session
		. _input_source
		. set_action_strength(
			slots[1].player_id,
			MinigameInputSource.ACTION_MOVE_RIGHT,
			1.0,
		)
	)

	client_session._client_predict_local(0.1)

	var moved := client_session.get_display_position(slots[1].player_id)
	assert_gt(moved.x, 100.0)
