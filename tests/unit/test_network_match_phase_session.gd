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


func _make_active_minigame_phase_setup() -> Dictionary:
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
	return {"authority": authority}


func _make_phase_session_with_minigame() -> Dictionary:
	var match_session := MatchSession.new()
	var phase_session := NetworkMatchPhaseSession.new()
	var minigame_session := NetworkMinigameSession.new()
	match_session.add_child(phase_session)
	match_session.add_child(minigame_session)
	add_child_autofree(match_session)
	return {
		"match_session": match_session,
		"phase_session": phase_session,
		"minigame_session": minigame_session,
	}


func test_active_minigame_starts_when_peer_in_frozen_roster() -> void:
	var setup := _make_phase_session_with_minigame()
	var phase_session: NetworkMatchPhaseSession = setup.phase_session
	var minigame_session: NetworkMinigameSession = setup.minigame_session
	await get_tree().process_frame

	assert_eq(phase_session._minigame_session, minigame_session)

	var active_setup := _make_active_minigame_phase_setup()
	var authority: NetworkMatchPhaseAuthority = active_setup.authority
	phase_session._authority = authority
	phase_session.current_phase = MatchPhase.Phase.ACTIVE_MINIGAME
	phase_session._update_minigame_for_phase(MatchPhase.Phase.BOARD)

	assert_true(phase_session.can_participate_in_active_minigame())
	assert_true(minigame_session.is_active)


func test_active_minigame_does_not_start_without_roster_membership() -> void:
	var setup := _make_phase_session_with_minigame()
	var phase_session: NetworkMatchPhaseSession = setup.phase_session
	var minigame_session: NetworkMinigameSession = setup.minigame_session
	await get_tree().process_frame

	assert_eq(phase_session._minigame_session, minigame_session)

	var authority := NetworkMatchPhaseAuthority.new()
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(2, "Remote A")
	lobby.try_add_slot(3, "Remote B")
	var board := BoardStub.new()
	board.reset_for_slots(lobby.slots)

	authority.begin_from_board(lobby.slots, board)
	authority.try_start_minigame_flow()
	authority.try_set_briefing_ready(2, lobby.slots[0].player_id, true)
	authority.try_set_briefing_ready(3, lobby.slots[1].player_id, true)
	while authority.current_phase == MatchPhase.Phase.COUNTDOWN:
		authority.tick_countdown(1.0)

	phase_session._authority = authority
	phase_session.current_phase = MatchPhase.Phase.ACTIVE_MINIGAME
	phase_session._update_minigame_for_phase(MatchPhase.Phase.BOARD)

	assert_false(minigame_session.is_active)
	assert_false(phase_session.can_participate_in_active_minigame())
