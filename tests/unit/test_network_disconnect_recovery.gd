extends GutTest


func test_mark_peer_inactive_preserves_board_hash() -> void:
	var authority := NetworkBoardAuthority.new()
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")
	authority.reset_for_slots(lobby.slots)

	var hash_before := authority.state_hash()
	assert_true(PlayerSlotConnectivity.mark_peer_inactive(authority.match_slots, 2))
	assert_eq(authority.state_hash(), hash_before)
	assert_eq(authority.match_slots[1].connection_status, PlayerSlot.ConnectionStatus.INACTIVE)


func test_advance_turn_skips_inactive_slot() -> void:
	var board := BoardStub.new()
	var slots: Array[PlayerSlot] = []
	slots.append(PlayerSlot.create("player_1", 1, 0, "Host"))
	slots.append(PlayerSlot.create("player_2", 2, 0, "Client"))
	board.reset_for_slots(slots)
	assert_eq(board.active_player_id, "player_1")

	slots[1].connection_status = PlayerSlot.ConnectionStatus.INACTIVE
	board.advance_turn(slots)
	assert_eq(board.active_player_id, "player_1")


func test_reclaim_slot_restores_peer_ownership() -> void:
	var slots: Array[PlayerSlot] = []
	slots.append(PlayerSlot.create("player_1", 1, 0, "Host"))
	slots.append(PlayerSlot.create("player_2", 2, 0, "Client"))
	slots[1].connection_status = PlayerSlot.ConnectionStatus.INACTIVE

	assert_true(PlayerSlotConnectivity.reclaim_slot(slots, "player_2", 9))
	assert_eq(slots[1].owning_peer_id, 9)
	assert_eq(slots[1].connection_status, PlayerSlot.ConnectionStatus.CONNECTED)


func test_briefing_ready_ignores_inactive_slots() -> void:
	var authority := NetworkMatchPhaseAuthority.new()
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")
	var board := BoardStub.new()
	board.reset_for_slots(lobby.slots)

	authority.begin_from_board(lobby.slots, board)
	authority.try_start_minigame_flow()
	authority.match_slots[1].connection_status = PlayerSlot.ConnectionStatus.INACTIVE

	assert_true(authority.try_set_briefing_ready(1, lobby.slots[0].player_id, true))
	assert_eq(authority.current_phase, MatchPhase.Phase.COUNTDOWN)


func test_session_ended_on_server_disconnect() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	session._state = MatchSession.SessionState.CONNECTED
	var result := {"ended": false, "message": ""}
	session.session_ended.connect(func(_reason: MatchSession.SessionEndReason, message: String) -> void:
		result.ended = true
		result.message = message
	)

	session._on_server_disconnected()
	assert_true(result.ended)
	assert_eq(result.message, "Host left the match.")
	assert_eq(session.get_session_state(), MatchSession.SessionState.IDLE)


func test_lobby_marks_peer_inactive_during_active_board() -> void:
	var authority := NetworkLobbyAuthority.new()
	authority.try_add_slot(1, "Host")
	authority.try_add_slot(2, "Client")

	assert_true(authority.mark_peer_inactive(2))
	assert_eq(authority.slots.size(), 2)
	assert_eq(authority.slots[1].connection_status, PlayerSlot.ConnectionStatus.INACTIVE)


func test_capture_reconnect_state_uses_local_device_slots_without_peer() -> void:
	var match_session := MatchSession.new()
	var lobby_session := NetworkLobbySession.new()
	var board_session := NetworkBoardSession.new()
	var phase_session := NetworkMatchPhaseSession.new()
	match_session.add_child(lobby_session)
	match_session.add_child(board_session)
	match_session.add_child(phase_session)
	add_child_autofree(match_session)

	var authority := NetworkBoardAuthority.new()
	var slots: Array[PlayerSlot] = []
	slots.append(PlayerSlot.create("player_1", 1, 0, "Host"))
	slots.append(PlayerSlot.create("player_2", 2, 0, "Client"))
	authority.reset_for_slots(slots)
	board_session._authority = authority
	board_session._is_active = true
	board_session._board_slots = authority.match_slots.duplicate()

	phase_session._authority = NetworkMatchPhaseAuthority.new()
	phase_session._authority.begin_from_board(authority.match_slots, authority.board_stub)
	phase_session.current_phase = MatchPhase.Phase.BOARD

	lobby_session.slots = slots
	lobby_session._local_device_slots["player_2"] = 0

	lobby_session._capture_reconnect_state()
	assert_true(NetworkReconnectState.has_pending())
	assert_eq(NetworkReconnectState.pending_player_id, "player_2")
	NetworkReconnectState.clear()


func test_host_reclaim_restores_same_player_count() -> void:
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")

	var board_authority := NetworkBoardAuthority.new()
	board_authority.reset_for_slots(lobby.slots)
	lobby.slots[1].connection_status = PlayerSlot.ConnectionStatus.INACTIVE
	board_authority.match_slots[1].connection_status = PlayerSlot.ConnectionStatus.INACTIVE

	assert_true(lobby.reclaim_slot_for_peer(lobby.slots[1].player_id, 9))
	assert_true(board_authority.reclaim_slot_for_peer(lobby.slots[1].player_id, 9))
	assert_eq(lobby.slots.size(), 2)
	assert_eq(board_authority.match_slots.size(), 2)
	assert_eq(lobby.slots[1].owning_peer_id, 9)
