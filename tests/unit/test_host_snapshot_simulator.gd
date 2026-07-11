extends GutTest


func _make_player_ids(count: int = 2) -> PackedStringArray:
	var ids := PackedStringArray()
	for index in count:
		ids.append("player_%d" % (index + 1))
	return ids


func test_spawn_points_cover_two_to_four_players() -> void:
	for count in [2, 3, 4]:
		var simulator := HostSnapshotSimulator.new()
		var ids := _make_player_ids(count)
		simulator.reset_for_player_ids(ids)
		assert_eq(simulator.positions_by_player_id.size(), count)
		for player_id in ids:
			var position: Vector2 = simulator.positions_by_player_id[player_id]
			assert_gt(position.x, 0.0)
			assert_gt(position.y, 0.0)


func test_first_player_to_goal_wins() -> void:
	var simulator := HostSnapshotSimulator.new()
	var ids := _make_player_ids(2)
	simulator.reset_for_player_ids(ids)

	var winner_id := ids[0]
	var goal := HostSnapshotSimulator.GOAL_CENTER
	var inputs := {
		winner_id: (goal - simulator.get_position(winner_id)).normalized(),
		ids[1]: Vector2.ZERO,
	}

	for _step in 120:
		simulator.tick(inputs, 1.0 / 60.0)
		if not simulator.winner_player_id.is_empty():
			break

	assert_eq(simulator.winner_player_id, winner_id)


func test_snapshot_hash_matches_after_export_load_round_trip() -> void:
	var host := HostSnapshotSimulator.new()
	var client := HostSnapshotSimulator.new()
	var ids := _make_player_ids(3)
	host.reset_for_player_ids(ids)
	client.reset_for_player_ids(ids)

	var inputs := {
		ids[0]: Vector2(1.0, 0.0),
		ids[1]: Vector2(0.0, 1.0),
		ids[2]: Vector2(-1.0, 0.0),
	}
	for _step in 30:
		host.tick(inputs, 1.0 / 60.0)

	var payload := host.export_positions()
	client.load_positions(payload)
	assert_eq(host.state_hash(), client.state_hash())


func test_result_agreement_after_forced_end() -> void:
	var host := HostSnapshotSimulator.new()
	var client := HostSnapshotSimulator.new()
	var ids := _make_player_ids(4)
	host.reset_for_player_ids(ids)
	client.reset_for_player_ids(ids)

	host.positions_by_player_id[ids[0]] = HostSnapshotSimulator.GOAL_CENTER
	host.winner_player_id = ids[0]
	client.load_positions(host.export_positions())
	client.winner_player_id = host.winner_player_id

	var host_result := host.build_result(ids)
	var client_result := client.build_result(ids)
	assert_eq(host_result.status, MinigameResult.Status.COMPLETED)
	assert_eq(client_result.status, MinigameResult.Status.COMPLETED)
	assert_eq(host_result.placements.size(), client_result.placements.size())
	for index in host_result.placements.size():
		assert_eq(host_result.placements[index], client_result.placements[index])
