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
	session.session_ended.connect(
		func(_reason: MatchSession.SessionEndReason, message: String) -> void:
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
	lobby_session._local_reconnect_credentials["player_2"] = {
		"recovery_session_id": "recovery_test",
		"reconnect_token": "token_test",
	}
	match_session._state = MatchSession.SessionState.CONNECTED
	match_session._last_join_address = "127.0.0.1"
	match_session._last_join_port = 7777
	board_session._client_recovery_session_id = "recovery_test"

	lobby_session._capture_reconnect_state()
	assert_true(NetworkReconnectState.has_pending())
	assert_eq(NetworkReconnectState.pending_player_id, "player_2")
	assert_eq(NetworkReconnectState.pending_recovery_session_id, "recovery_test")
	assert_eq(NetworkReconnectState.pending_reconnect_token, "token_test")
	assert_eq(NetworkReconnectState.pending_host_address, "127.0.0.1")
	assert_eq(NetworkReconnectState.pending_host_port, 7777)
	assert_eq(NetworkReconnectState.pending_transport_id, TransportAdapterRegistry.TRANSPORT_ENET)
	NetworkReconnectState.clear()


func test_reconnect_state_requires_matching_host_target() -> void:
	(
		NetworkReconnectState
		. remember(
			"player_2",
			1,
			"recovery_a",
			"token",
			TransportAdapterRegistry.TRANSPORT_ENET,
			"127.0.0.1",
			7777,
		)
	)
	assert_true(
		(
			NetworkReconnectState
			. matches_target(
				"recovery_a",
				TransportAdapterRegistry.TRANSPORT_ENET,
				"127.0.0.1",
				7777,
			)
		)
	)
	assert_false(
		(
			NetworkReconnectState
			. matches_target(
				"recovery_b",
				TransportAdapterRegistry.TRANSPORT_ENET,
				"127.0.0.1",
				7777,
			)
		)
	)
	assert_false(
		(
			NetworkReconnectState
			. matches_target(
				"recovery_a",
				TransportAdapterRegistry.TRANSPORT_ENET,
				"10.0.0.1",
				7777,
			)
		)
	)
	NetworkReconnectState.clear()


func test_reconnect_state_requires_matching_webrtc_target() -> void:
	(
		NetworkReconnectState
		. remember(
			"player_2",
			1,
			"recovery_a",
			"token",
			TransportAdapterRegistry.TRANSPORT_WEBRTC,
			"",
			-1,
			"ws://127.0.0.1:9080",
			"room123",
		)
	)
	assert_true(
		(
			NetworkReconnectState
			. matches_target(
				"recovery_a",
				TransportAdapterRegistry.TRANSPORT_WEBRTC,
				"ws://127.0.0.1:9080",
				-1,
				"room123",
			)
		)
	)
	assert_false(
		(
			NetworkReconnectState
			. matches_target(
				"recovery_a",
				TransportAdapterRegistry.TRANSPORT_WEBRTC,
				"ws://127.0.0.1:9080",
				-1,
				"other",
			)
		)
	)
	NetworkReconnectState.clear()


func test_board_verify_reconnect_token() -> void:
	var match_session := MatchSession.new()
	var board_session := NetworkBoardSession.new()
	match_session.add_child(board_session)
	add_child_autofree(match_session)
	match_session._state = MatchSession.SessionState.HOSTING
	var token := NetworkMatchRecovery.generate_reconnect_token()
	board_session._reconnect_token_hashes_by_player_id["player_2"] = (
		NetworkMatchRecovery.hash_token(token)
	)
	assert_true(board_session.verify_reconnect_token("player_2", token))
	assert_false(board_session.verify_reconnect_token("player_2", "wrong-token"))


func test_disconnect_active_player_advances_authority_turn() -> void:
	var authority := NetworkBoardAuthority.new()
	var slots: Array[PlayerSlot] = []
	slots.append(PlayerSlot.create("player_1", 1, 0, "Host"))
	slots.append(PlayerSlot.create("player_2", 2, 0, "Client"))
	authority.reset_for_slots(slots)
	authority.board_stub.advance_turn(authority.match_slots)
	assert_eq(authority.board_stub.active_player_id, "player_2")

	assert_true(authority.mark_peer_inactive(2))
	authority.board_stub.advance_turn(authority.match_slots)
	assert_eq(authority.board_stub.active_player_id, "player_1")


func test_atomic_reclaim_rolls_back_board_when_phase_fails() -> void:
	var lobby := NetworkLobbyAuthority.new()
	lobby.try_add_slot(1, "Host")
	lobby.try_add_slot(2, "Client")
	lobby.slots[1].connection_status = PlayerSlot.ConnectionStatus.INACTIVE

	var board_authority := NetworkBoardAuthority.new()
	board_authority.reset_for_slots(lobby.slots)
	board_authority.match_slots[1].connection_status = PlayerSlot.ConnectionStatus.INACTIVE

	var phase_authority := NetworkMatchPhaseAuthority.new()
	phase_authority.begin_from_board(board_authority.match_slots, board_authority.board_stub)
	phase_authority.match_slots[1].connection_status = PlayerSlot.ConnectionStatus.CONNECTED

	var lobby_backup := PlayerSlotConnectivity.duplicate_slots(lobby.slots)
	var board_backup := PlayerSlotConnectivity.duplicate_slots(board_authority.match_slots)

	assert_true(board_authority.reclaim_slot_for_peer("player_2", 9))
	assert_true(lobby.reclaim_slot_for_peer("player_2", 9))
	assert_false(PlayerSlotConnectivity.reclaim_slot(phase_authority.match_slots, "player_2", 9))

	PlayerSlotConnectivity.copy_slots_into(lobby.slots, lobby_backup)
	PlayerSlotConnectivity.copy_slots_into(board_authority.match_slots, board_backup)
	assert_eq(lobby.slots[1].owning_peer_id, 2)
	assert_eq(board_authority.match_slots[1].owning_peer_id, 2)
	assert_eq(lobby.slots[1].connection_status, PlayerSlot.ConnectionStatus.INACTIVE)


func test_minigame_mark_peer_inactive_clears_remote_input_and_winner() -> void:
	var minigame_session := NetworkMinigameSession.new()
	add_child_autofree(minigame_session)
	var slots: Array[PlayerSlot] = []
	slots.append(PlayerSlot.create("player_1", 1, 0, "Host"))
	slots.append(PlayerSlot.create("player_2", 2, 0, "Client"))
	assert_true(minigame_session.start_minigame(slots, "snapshot_test"))
	minigame_session._remote_inputs["player_2"] = Vector2.RIGHT
	minigame_session._simulator.winner_player_id = "player_2"

	minigame_session.mark_peer_inactive(2)
	assert_false(minigame_session._remote_inputs.has("player_2"))
	assert_eq(minigame_session._simulator.winner_player_id, "")
	assert_eq(minigame_session._slots[1].connection_status, PlayerSlot.ConnectionStatus.INACTIVE)


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
