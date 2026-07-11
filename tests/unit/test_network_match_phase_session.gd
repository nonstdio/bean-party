extends GutTest


func test_phase_agreement_after_sync_payload() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")
	var board := BoardStub.new()
	board.reset_for_slots(lobby.slots)

	authority.begin_from_board(lobby.slots, board)
	authority.try_start_minigame_flow()
	authority.try_set_briefing_ready(1, lobby.slots[0].player_id, true)
	authority.try_set_briefing_ready(2, lobby.slots[1].player_id, true)

	var host_phase := NetworkMatchPhaseSession.new()
	add_child_autofree(host_phase)
	host_phase._authority = authority
	host_phase._sync_from_authority()

	var client_phase := NetworkMatchPhaseSession.new()
	add_child_autofree(client_phase)
	client_phase._apply_remote_phase_state(authority.export_state())

	assert_eq(host_phase.current_phase, client_phase.current_phase)
	assert_eq(host_phase.selected_minigame_id, client_phase.selected_minigame_id)
	assert_eq(host_phase.minigame_instance_id, client_phase.minigame_instance_id)


func test_phase_agreement_through_active_and_results() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")
	var board := BoardStub.new()
	board.reset_for_slots(lobby.slots)

	authority.begin_from_board(lobby.slots, board)
	authority.try_start_minigame_flow()
	authority.try_set_briefing_ready(1, lobby.slots[0].player_id, true)
	authority.try_set_briefing_ready(2, lobby.slots[1].player_id, true)
	while authority.current_phase == MatchPhase.Phase.COUNTDOWN:
		authority.tick_countdown(1.0)
	authority.try_end_minigame_round()

	var host_phase := NetworkMatchPhaseSession.new()
	add_child_autofree(host_phase)
	host_phase._authority = authority
	host_phase._sync_from_authority()

	var client_phase := NetworkMatchPhaseSession.new()
	add_child_autofree(client_phase)
	client_phase._apply_remote_phase_state(authority.export_state())

	assert_eq(host_phase.current_phase, MatchPhase.Phase.RESULTS)
	assert_eq(client_phase.current_phase, MatchPhase.Phase.RESULTS)
	assert_eq(host_phase.current_phase, client_phase.current_phase)


func test_countdown_sync_keeps_host_and_client_aligned() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")
	var board := BoardStub.new()
	board.reset_for_slots(lobby.slots)

	authority.begin_from_board(lobby.slots, board)
	authority.try_start_minigame_flow()
	authority.try_set_briefing_ready(1, lobby.slots[0].player_id, true)
	authority.try_set_briefing_ready(2, lobby.slots[1].player_id, true)

	var host_phase := NetworkMatchPhaseSession.new()
	add_child_autofree(host_phase)
	host_phase._authority = authority
	host_phase._sync_from_authority()

	for expected in [3, 2, 1]:
		var client_phase := NetworkMatchPhaseSession.new()
		add_child_autofree(client_phase)
		client_phase._apply_remote_phase_state(authority.export_state())
		assert_eq(host_phase.countdown_seconds_remaining, expected)
		assert_eq(client_phase.countdown_seconds_remaining, expected)

		assert_true(authority.tick_countdown(1.0))
		host_phase._sync_from_authority()

	assert_eq(host_phase.current_phase, MatchPhase.Phase.ACTIVE_MINIGAME)
