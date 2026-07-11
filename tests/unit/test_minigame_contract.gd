extends GutTest

const REFERENCE_MANIFEST_PATH := "res://minigames/reference-tap/minigame.tres"


func test_registry_discovers_valid_minigames_and_ignores_authoring_folders() -> void:
	var registry := MinigameRegistry.new()

	assert_true(registry.discover(), "; ".join(registry.errors))
	var ids := registry.get_minigame_ids()
	assert_eq(ids.size(), 3)
	assert_true(ids.has(&"reference-tap"))
	assert_true(ids.has(&"snapshot-arena"))
	assert_true(ids.has(&"action-spike"))
	assert_not_null(registry.get_manifest(&"reference-tap"))
	assert_not_null(registry.get_manifest(&"snapshot-arena"))
	assert_not_null(registry.get_manifest(&"action-spike"))


func test_manifest_rejects_invalid_metadata() -> void:
	var manifest := MinigameManifest.new()
	manifest.minigame_id = &"Bad Slug"
	manifest.display_name = ""
	manifest.minimum_players = 4
	manifest.maximum_players = 2
	manifest.capability = MinigameManifest.CAPABILITY_NETWORK_CAPABLE

	var errors := manifest.validate()

	assert_gt(errors.size(), 3)


func test_context_copies_shell_owned_players() -> void:
	var session := _create_session(2)
	var context := _create_context(session, "copy-test")
	session.slots[0].display_name = "Changed outside context"
	var supplied_players := context.get_players()
	supplied_players[0].display_name = "Changed returned copy"

	assert_eq(context.get_player("player_1").display_name, "Player 1")


func test_completed_result_supports_ties_and_scores() -> void:
	var result := MinigameResult.completed(
		[
			PackedStringArray(["player_1", "player_2"]),
			PackedStringArray(["player_3"]),
		],
		{"player_1": 5, "player_2": 5, "player_3": 2},
	)

	assert_true(
		result.validate(PackedStringArray(["player_1", "player_2", "player_3"])).is_empty()
	)


func test_result_rejects_missing_duplicate_and_unknown_players() -> void:
	var result := MinigameResult.completed(
		[
			PackedStringArray(["player_1"]),
			PackedStringArray(["player_1", "intruder"]),
		]
	)

	var errors := result.validate(PackedStringArray(["player_1", "player_2"]))

	assert_gt(errors.size(), 2)


func test_aborted_result_cannot_carry_outcome_data() -> void:
	var result := MinigameResult.aborted("early exit")
	result.scores_by_player_id["player_1"] = 10

	assert_false(result.validate(PackedStringArray(["player_1", "player_2"])).is_empty())


func test_runner_rejects_unsupported_player_count() -> void:
	var manifest := load(REFERENCE_MANIFEST_PATH) as MinigameManifest
	manifest = manifest.duplicate(true) as MinigameManifest
	manifest.minimum_players = 3
	var runner := MinigameRunner.new()
	add_child_autofree(runner)
	var session := _create_session(2)

	assert_false(runner.load_minigame(manifest, _create_context(session, "count-test")))
	assert_eq(runner.state, MinigameRunner.State.EMPTY)


func test_runner_aborts_once_and_unloads_cleanly() -> void:
	var runner := MinigameRunner.new()
	add_child_autofree(runner)
	var results: Array[MinigameResult] = []
	runner.minigame_finished.connect(func(result: MinigameResult) -> void: results.append(result))
	var session := _create_session(2)
	var context := _create_context(session, "abort-test")

	assert_true(runner.load_minigame(load(REFERENCE_MANIFEST_PATH), context))
	assert_true(runner.start_active_minigame())
	assert_true(runner.abort_active_minigame("test requested abort"))
	assert_false(runner.abort_active_minigame("duplicate abort"))
	assert_eq(results.size(), 1)
	assert_eq(results[0].status, MinigameResult.Status.ABORTED)
	assert_true(runner.unload_minigame())
	assert_eq(runner.get_child_count(), 0)


func test_runner_retries_with_a_fresh_context() -> void:
	var runner := MinigameRunner.new()
	add_child_autofree(runner)
	var session := _create_session(2)
	var first_context := _create_context(session, "retry-1")
	assert_true(runner.load_minigame(load(REFERENCE_MANIFEST_PATH), first_context))
	assert_true(runner.start_active_minigame())
	assert_true(runner.abort_active_minigame("finish first run"))

	var second_context := _create_context(session, "retry-2")
	assert_true(runner.retry_minigame(second_context))
	assert_eq(
		runner.get_active_controller().get_minigame_context().get_minigame_instance_id(),
		"retry-2",
	)
	assert_true(runner.abort_active_minigame("finish second run"))
	assert_true(runner.unload_minigame())


func test_controller_rejects_duplicate_result_submission() -> void:
	var runner := MinigameRunner.new()
	add_child_autofree(runner)
	var session := _create_session(2)
	var context := _create_context(session, "duplicate-result")
	assert_true(runner.load_minigame(load(REFERENCE_MANIFEST_PATH), context))
	assert_true(runner.start_active_minigame())
	var result := MinigameResult.completed(
		[PackedStringArray(["player_1"]), PackedStringArray(["player_2"])]
	)

	assert_true(runner.get_active_controller().submit_minigame_result(result))
	assert_false(runner.get_active_controller().submit_minigame_result(result))
	assert_true(runner.unload_minigame())


func _create_session(player_count: int) -> OfflineMatchSession:
	var session := OfflineMatchSession.new()
	for index in player_count:
		session.add_local_slot("Player %d" % (index + 1))
	return session


func _create_context(session: OfflineMatchSession, instance_id: String) -> MinigameContext:
	var player_ids := PackedStringArray()
	for slot in session.slots:
		player_ids.append(slot.player_id)
	return MinigameContext.create(
		instance_id,
		session.slots,
		{},
		424242,
		MinigameInputSource.new(player_ids),
	)
