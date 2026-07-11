extends GutTest


func _make_slots() -> Array[PlayerSlot]:
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")
	return lobby.slots


func _make_board(slots: Array[PlayerSlot]) -> BoardStub:
	var board := BoardStub.new()
	board.reset_for_slots(slots)
	return board


func test_start_minigame_flow_reaches_briefing() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var slots := _make_slots()
	var board := _make_board(slots)

	assert_true(authority.begin_from_board(slots, board))
	assert_true(authority.try_start_minigame_flow())
	assert_eq(authority.current_phase, MatchPhase.Phase.BRIEFING)
	assert_eq(authority.selected_minigame_id, NetworkMatchPhaseAuthority.ACTION_SPIKE_MINIGAME_ID)
	assert_false(authority.minigame_instance_id.is_empty())


func test_briefing_ready_advances_to_countdown_when_all_ready() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var slots := _make_slots()
	authority.begin_from_board(slots, _make_board(slots))
	authority.try_start_minigame_flow()

	assert_true(authority.try_set_briefing_ready(2, slots[1].player_id, true))
	assert_eq(authority.current_phase, MatchPhase.Phase.BRIEFING)

	assert_true(authority.try_set_briefing_ready(1, slots[0].player_id, true))
	assert_eq(authority.current_phase, MatchPhase.Phase.COUNTDOWN)
	assert_eq(authority.countdown_seconds_remaining, NetworkMatchPhaseAuthority.COUNTDOWN_SECONDS)


func test_two_peers_require_separate_ready() -> void:
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")
	var slots := lobby.slots

	var authority := NetworkMatchPhaseAuthority.new()
	authority.begin_from_board(slots, _make_board(slots))
	authority.try_start_minigame_flow()

	assert_true(authority.try_set_briefing_ready(1, slots[0].player_id, true))
	assert_eq(authority.current_phase, MatchPhase.Phase.BRIEFING)

	assert_true(authority.try_set_briefing_ready(2, slots[1].player_id, true))
	assert_eq(authority.current_phase, MatchPhase.Phase.COUNTDOWN)


func test_countdown_tick_publishes_each_second() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var slots := _make_slots()
	authority.begin_from_board(slots, _make_board(slots))
	authority.try_start_minigame_flow()
	authority.try_set_briefing_ready(1, slots[0].player_id, true)
	authority.try_set_briefing_ready(2, slots[1].player_id, true)

	assert_eq(authority.current_phase, MatchPhase.Phase.COUNTDOWN)
	assert_eq(authority.countdown_seconds_remaining, 3)

	assert_true(authority.tick_countdown(1.0))
	assert_eq(authority.countdown_seconds_remaining, 2)

	assert_true(authority.tick_countdown(1.0))
	assert_eq(authority.countdown_seconds_remaining, 1)

	assert_true(authority.tick_countdown(1.0))
	assert_eq(authority.current_phase, MatchPhase.Phase.ACTIVE_MINIGAME)


func test_result_idempotency_applies_rewards_once() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var slots := _make_slots()
	var board := _make_board(slots)
	authority.begin_from_board(slots, board)
	authority.current_phase = MatchPhase.Phase.RESULTS
	authority.minigame_instance_id = "minigame_1"

	authority.minigame_winner_player_id = slots[0].player_id
	authority._apply_minigame_results()
	assert_eq(authority.pending_board_rewards.size(), 1)
	authority._apply_minigame_results()
	assert_eq(authority.pending_board_rewards.size(), 1)

	var reward: Dictionary = authority.pending_board_rewards[0]
	var winner_id := String(reward.get("player_id", ""))
	var reward_beans := int(reward.get("beans", 0))
	var beans_before := int(board.beans_by_player_id.get(winner_id, 0))
	authority.board_stub = board.duplicate_stub()
	authority._apply_pending_board_rewards()
	authority._apply_pending_board_rewards()

	var beans_after := int(authority.board_stub.beans_by_player_id.get(winner_id, 0))
	assert_eq(beans_after, beans_before + reward_beans)


func test_full_loop_returns_to_board_with_reward() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var slots := _make_slots()
	var board := _make_board(slots)
	authority.begin_from_board(slots, board)
	_walk_to_results(authority, slots)

	assert_true(authority.try_return_to_board())
	assert_eq(authority.current_phase, MatchPhase.Phase.BOARD)
	assert_true(authority.pending_board_rewards.is_empty())

	var max_beans := 0
	for player_id in authority.board_stub.beans_by_player_id:
		max_beans = max(max_beans, int(authority.board_stub.beans_by_player_id[player_id]))
	assert_gt(max_beans, BoardStub.STARTING_BEANS)


func _walk_to_results(authority: NetworkMatchPhaseAuthority, slots: Array[PlayerSlot]) -> void:
	authority.try_start_minigame_flow()
	authority.try_set_briefing_ready(1, slots[0].player_id, true)
	authority.try_set_briefing_ready(2, slots[1].player_id, true)
	while authority.current_phase == MatchPhase.Phase.COUNTDOWN:
		authority.tick_countdown(1.0)
	assert_eq(authority.current_phase, MatchPhase.Phase.ACTIVE_MINIGAME)
	assert_true(authority.try_end_minigame_round())
	assert_eq(authority.current_phase, MatchPhase.Phase.RESULTS)
