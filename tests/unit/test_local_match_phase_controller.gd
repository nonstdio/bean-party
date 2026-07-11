extends GutTest


func test_illegal_transition_from_active_minigame_to_lobby_is_rejected() -> void:
	var session := OfflineMatchSession.new()
	session.add_local_slot("Player 1")
	var controller := LocalMatchPhaseController.new(session)

	_walk_to_phase(controller, MatchPhase.Phase.ACTIVE_MINIGAME)

	assert_false(controller.can_transition_to(MatchPhase.Phase.LOBBY))
	assert_false(controller.transition_to(MatchPhase.Phase.LOBBY))
	assert_eq(controller.current_phase, MatchPhase.Phase.ACTIVE_MINIGAME)


func test_happy_path_reaches_board_again_after_return_to_board() -> void:
	var session := OfflineMatchSession.new()
	session.add_local_slot("Player 1")
	session.add_local_slot("Player 2")
	var controller := LocalMatchPhaseController.new(session)

	while controller.current_phase != MatchPhase.Phase.RETURN_TO_BOARD:
		assert_true(controller.advance_happy_path())

	assert_true(controller.transition_to(MatchPhase.Phase.BOARD))
	assert_eq(controller.current_phase, MatchPhase.Phase.BOARD)
	assert_false(controller.board_stub.beans_by_player_id.is_empty())


func test_snapshot_round_trip_preserves_hash() -> void:
	var session := OfflineMatchSession.new()
	session.add_local_slot("Bean A")
	session.add_local_slot("Bean B")
	var controller := LocalMatchPhaseController.new(session)

	controller.transition_to(MatchPhase.Phase.BOARD)
	controller.advance_board_turn()
	var snapshot := controller.capture_snapshot()
	var encoded := MatchSnapshotSerializer.serialize(snapshot)

	var decoded := MatchSnapshotSerializer.deserialize(encoded)

	assert_eq(MatchSnapshotSerializer.serialize(decoded), encoded)
	assert_eq(decoded.phase, MatchPhase.Phase.BOARD)
	assert_eq(decoded.board_stub.turn_index, snapshot.board_stub.turn_index)


func test_restore_from_snapshot_restores_phase_and_board_state() -> void:
	var session := OfflineMatchSession.new()
	session.add_local_slot("Bean A")
	var controller := LocalMatchPhaseController.new(session)

	controller.transition_to(MatchPhase.Phase.BOARD)
	controller.advance_board_turn()
	var board_snapshot := controller.capture_snapshot()

	controller.advance_happy_path()
	assert_ne(controller.current_phase, MatchPhase.Phase.BOARD)

	assert_true(controller.restore_from_snapshot(board_snapshot))
	assert_eq(controller.current_phase, MatchPhase.Phase.BOARD)
	assert_eq(controller.board_stub.turn_index, board_snapshot.board_stub.turn_index)
	assert_eq(controller.session.slots.size(), 1)
	assert_eq(controller.session.slots[0].display_name, "Bean A")


func test_match_epoch_increments_on_snapshot_capture() -> void:
	var session := OfflineMatchSession.new()
	session.add_local_slot("Player")
	var controller := LocalMatchPhaseController.new(session)
	var initial_epoch := controller.match_epoch

	controller.transition_to(MatchPhase.Phase.BOARD)

	assert_gt(controller.match_epoch, initial_epoch)


func test_initial_lobby_snapshot_contains_match_settings() -> void:
	var session := OfflineMatchSession.new()
	session.add_local_slot("Player")
	var controller := LocalMatchPhaseController.new(session)

	assert_eq(controller.last_snapshot.match_settings.get("max_players"), 4)


func test_restore_keeps_match_epoch_monotonic() -> void:
	var session := OfflineMatchSession.new()
	session.add_local_slot("Player")
	var controller := LocalMatchPhaseController.new(session)

	var oldest := MatchSnapshotSerializer.deserialize(
		MatchSnapshotSerializer.serialize(controller.last_snapshot)
	)
	var epochs: Array[int] = [controller.match_epoch]

	controller.transition_to(MatchPhase.Phase.BOARD)
	epochs.append(controller.match_epoch)
	controller.transition_to(MatchPhase.Phase.MINIGAME_SELECTION)
	controller.transition_to(MatchPhase.Phase.BRIEFING)
	epochs.append(controller.match_epoch)

	var highest_before_restore := 0
	for epoch in epochs:
		highest_before_restore = max(highest_before_restore, epoch)

	assert_true(controller.restore_from_snapshot(oldest))
	assert_gt(controller.match_epoch, highest_before_restore)


func test_restore_preserves_local_device_slots() -> void:
	var session := OfflineMatchSession.new()
	var slot := session.add_local_slot("Player")
	session.set_local_device_slot(slot.player_id, 2)
	var controller := LocalMatchPhaseController.new(session)

	controller.transition_to(MatchPhase.Phase.BOARD)
	var board_snapshot := controller.capture_snapshot()

	controller.advance_happy_path()
	assert_true(controller.restore_from_snapshot(board_snapshot))
	assert_eq(session.get_local_device_slot(slot.player_id), 2)


func test_snapshot_contains_required_fields() -> void:
	var session := OfflineMatchSession.new()
	session.add_local_slot("Player")
	var controller := LocalMatchPhaseController.new(session)
	controller.transition_to(MatchPhase.Phase.BOARD)
	controller.transition_to(MatchPhase.Phase.MINIGAME_SELECTION)
	controller.transition_to(MatchPhase.Phase.BRIEFING)

	var snapshot := controller.last_snapshot
	assert_not_null(snapshot)
	assert_gt(snapshot.match_epoch, 0)
	assert_eq(snapshot.phase, MatchPhase.Phase.BRIEFING)
	assert_true(snapshot.rng_seed != 0 or snapshot.rng_state != 0)
	assert_false(snapshot.slots.is_empty())
	assert_eq(snapshot.selected_minigame_id, controller.selected_minigame_id)
	assert_not_null(snapshot.board_stub)


func _walk_to_phase(controller: LocalMatchPhaseController, target: MatchPhase.Phase) -> void:
	var guard := 0
	while controller.current_phase != target and guard < 20:
		assert_true(controller.advance_happy_path())
		guard += 1
	assert_eq(controller.current_phase, target)
