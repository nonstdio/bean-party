extends GutTest

const MANIFEST_PATH := "res://minigames/snapshot-arena/minigame.tres"


func test_snapshot_arena_submits_completed_result() -> void:
	var runner := MinigameRunner.new()
	add_child_autofree(runner)
	var context := _create_context(2, "snapshot-run-1")
	var manifest := load(MANIFEST_PATH) as MinigameManifest
	var results: Array[MinigameResult] = []
	runner.minigame_finished.connect(func(result: MinigameResult) -> void: results.append(result))

	assert_true(runner.load_minigame(manifest, context))
	assert_true(runner.start_active_minigame())

	var winner_id := context.get_player_ids()[0]
	var simulator := HostSnapshotSimulator.new()
	simulator.reset_for_player_ids(context.get_player_ids())
	simulator.positions_by_player_id[winner_id] = HostSnapshotSimulator.GOAL_CENTER
	simulator.winner_player_id = winner_id
	assert_true(
		(
			runner
			. get_active_controller()
			. submit_minigame_result(
				simulator.build_result(context.get_player_ids()),
			)
		)
	)

	assert_eq(results.size(), 1)
	assert_eq(results[0].status, MinigameResult.Status.COMPLETED)
	assert_eq(results[0].placements[0], PackedStringArray([winner_id]))
	assert_true(runner.unload_minigame())
	await get_tree().process_frame


func _create_context(player_count: int, instance_id: String) -> MinigameContext:
	var session := OfflineMatchSession.new()
	for index in player_count:
		session.add_local_slot("Player %d" % (index + 1))
	var player_ids := PackedStringArray()
	for slot in session.slots:
		player_ids.append(slot.player_id)
	return (
		MinigameContext
		. create(
			instance_id,
			session.slots,
			{},
			12345,
			MinigameInputSource.new(player_ids),
		)
	)
