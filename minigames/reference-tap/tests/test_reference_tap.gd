extends GutTest

const MANIFEST_PATH := "res://minigames/reference-tap/minigame.tres"


func test_reference_tap_runs_through_contract_and_unloads() -> void:
	var runner := MinigameRunner.new()
	add_child_autofree(runner)
	var context := _create_context(2, "reference-run-1")
	var manifest := load(MANIFEST_PATH) as MinigameManifest
	var results: Array[MinigameResult] = []
	runner.minigame_finished.connect(func(result: MinigameResult) -> void: results.append(result))

	assert_true(runner.load_minigame(manifest, context))
	var controller := runner.get_active_controller()
	var legend := controller.get_node("PlayerLegend") as HBoxContainer
	assert_eq(legend.get_child_count(), 2)
	assert_true(legend.get_child(0).get_child(0) is PlayerIdentityBadge)
	assert_true(runner.start_active_minigame())
	context.get_input_source().set_action_strength(
		"player_2",
		MinigameInputSource.ACTION_PRIMARY,
		1.0,
	)
	runner.get_active_controller()._process(0.016)

	assert_eq(results.size(), 1)
	assert_eq(results[0].placements[0], PackedStringArray(["player_2"]))
	assert_eq(results[0].scores_by_player_id["player_2"], 1)
	assert_eq(runner.state, MinigameRunner.State.FINISHED)
	assert_true(runner.unload_minigame())
	assert_eq(runner.state, MinigameRunner.State.EMPTY)
	assert_eq(runner.get_child_count(), 0)
	await get_tree().process_frame


func test_reference_tap_ties_everyone_on_timeout_at_all_supported_counts() -> void:
	var manifest := load(MANIFEST_PATH) as MinigameManifest
	for player_count in range(manifest.minimum_players, manifest.maximum_players + 1):
		var runner := MinigameRunner.new()
		add_child_autofree(runner)
		var context := _create_context(player_count, "timeout-%d" % player_count)
		var results: Array[MinigameResult] = []
		runner.minigame_finished.connect(func(result: MinigameResult) -> void: results.append(result))

		assert_true(runner.load_minigame(manifest, context))
		assert_true(runner.start_active_minigame())
		runner.get_active_controller()._process(10.1)

		assert_eq(results.size(), 1)
		assert_eq(results[0].placements.size(), 1)
		assert_eq(results[0].placements[0].size(), player_count)
		assert_true(runner.unload_minigame())
		await get_tree().process_frame


func _create_context(player_count: int, instance_id: String) -> MinigameContext:
	var session := OfflineMatchSession.new()
	for index in player_count:
		session.add_local_slot("Player %d" % (index + 1))
	var player_ids := PackedStringArray()
	for slot in session.slots:
		player_ids.append(slot.player_id)
	var input_source := MinigameInputSource.new(player_ids)
	return MinigameContext.create(instance_id, session.slots, {}, 12345, input_source)
