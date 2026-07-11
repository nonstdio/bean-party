extends GutTest

var _test_port: int


func before_each() -> void:
	_test_port = 18000 + int(Time.get_ticks_msec() % 1000)


func _export_match_slots(authority: NetworkBoardAuthority) -> Array:
	var payload: Array = []
	for slot in authority.match_slots:
		payload.append(slot.to_dict())
	return payload


func _make_host_stack() -> Dictionary:
	var host_session := MatchSession.new()
	add_child_autofree(host_session)

	var lobby := NetworkLobbySession.new()
	host_session.add_child(lobby)

	var board := NetworkBoardSession.new()
	host_session.add_child(board)

	assert_eq(host_session.host(_test_port), OK)
	await get_tree().process_frame
	# Host lobby auto-adds the first local slot when the session starts.

	return {
		"session": host_session,
		"lobby": lobby,
		"board": board,
	}


func test_local_board_mutation_is_overwritten_by_authority_sync() -> void:
	var authority := NetworkBoardAuthority.new()
	var lobby_authority := NetworkLobbyAuthority.new()
	lobby_authority.try_add_slot(1, "Host")
	lobby_authority.try_add_slot(2, "Client")

	authority.reset_for_slots(lobby_authority.slots)

	var client_board := NetworkBoardSession.new()
	add_child_autofree(client_board)
	client_board._apply_remote_board_state(
		authority.export_board_state(),
		_export_match_slots(authority),
		true,
	)

	client_board.board_stub.turn_index = 99
	assert_eq(client_board.board_stub.turn_index, 99)

	authority.try_advance_turn(
		lobby_authority.slots[0].owning_peer_id,
		lobby_authority.slots[0].player_id,
	)
	client_board._apply_remote_board_state(
		authority.export_board_state(),
		_export_match_slots(authority),
		true,
	)

	assert_eq(client_board.board_stub.turn_index, 1)
	assert_eq(client_board.board_stub.turn_index, authority.board_stub.turn_index)


func test_host_rejects_out_of_turn_request() -> void:
	var stack := await _make_host_stack()
	var board: NetworkBoardSession = stack.board
	var lobby: NetworkLobbySession = stack.lobby

	lobby.request_add_local_slot("Host Two")
	await get_tree().process_frame

	board.request_start_board()
	await get_tree().process_frame

	var active_id := board.get_active_player_id()
	var inactive_id := ""
	for slot in lobby.slots:
		if slot.player_id != active_id:
			inactive_id = slot.player_id
			break

	var turn_before := board.board_stub.turn_index
	board.request_advance_turn(inactive_id)
	await get_tree().process_frame

	assert_eq(board.board_stub.turn_index, turn_before)


func test_board_hash_matches_after_sync_payload() -> void:
	var authority := NetworkBoardAuthority.new()
	var lobby_authority := NetworkLobbyAuthority.new()
	lobby_authority.try_add_slot(1, "Host")
	lobby_authority.try_add_slot(2, "Client")

	authority.reset_for_slots(lobby_authority.slots)
	authority.try_advance_turn(
		lobby_authority.slots[0].owning_peer_id,
		lobby_authority.slots[0].player_id,
	)

	var host_board := NetworkBoardSession.new()
	add_child_autofree(host_board)
	host_board._authority = authority
	host_board._is_active = true
	host_board._sync_board_from_authority()

	var client_board := NetworkBoardSession.new()
	add_child_autofree(client_board)
	client_board._apply_remote_board_state(
		authority.export_board_state(),
		_export_match_slots(authority),
		true,
	)

	assert_eq(host_board.get_board_state_hash(), client_board.get_board_state_hash())

	authority.try_advance_turn(
		lobby_authority.slots[1].owning_peer_id,
		lobby_authority.slots[1].player_id,
	)
	host_board._sync_board_from_authority()
	client_board._apply_remote_board_state(
		authority.export_board_state(),
		_export_match_slots(authority),
		true,
	)

	assert_eq(host_board.get_board_state_hash(), client_board.get_board_state_hash())
	assert_eq(host_board.board_stub.turn_index, 2)


func test_multiple_turns_keep_host_and_client_hashes_aligned() -> void:
	var authority := NetworkBoardAuthority.new()
	var lobby_authority := NetworkLobbyAuthority.new()
	lobby_authority.try_add_slot(1, "Host")
	lobby_authority.try_add_slot(2, "Client")

	authority.reset_for_slots(lobby_authority.slots)

	var host_board := NetworkBoardSession.new()
	add_child_autofree(host_board)
	host_board._authority = authority
	host_board._is_active = true

	var client_board := NetworkBoardSession.new()
	add_child_autofree(client_board)

	for _turn in 2:
		var active_id := authority.board_stub.active_player_id
		var active_slot := lobby_authority.slots[0]
		for slot in lobby_authority.slots:
			if slot.player_id == active_id:
				active_slot = slot
				break

		assert_true(
			authority.try_advance_turn(
				active_slot.owning_peer_id,
				active_id,
			)
		)
		host_board._sync_board_from_authority()
		client_board._apply_remote_board_state(
		authority.export_board_state(),
		_export_match_slots(authority),
		true,
	)
		assert_eq(host_board.get_board_state_hash(), client_board.get_board_state_hash())


func test_host_ignores_second_board_start() -> void:
	var stack := await _make_host_stack()
	var board: NetworkBoardSession = stack.board
	var lobby: NetworkLobbySession = stack.lobby

	lobby.request_add_local_slot("Guest")
	await get_tree().process_frame

	board.request_start_board()
	await get_tree().process_frame
	var hash_after_first_start := board.get_board_state_hash()
	var turn_after_first_start := board.board_stub.turn_index

	board.request_start_board()
	await get_tree().process_frame

	assert_true(board.is_board_active())
	assert_eq(board.get_board_state_hash(), hash_after_first_start)
	assert_eq(board.board_stub.turn_index, turn_after_first_start)
	assert_eq(board.get_board_slots().size(), 2)


func test_board_rejects_turn_during_minigame_flow() -> void:
	var stack := await _make_host_stack()
	var phase := NetworkMatchPhaseSession.new()
	stack.session.add_child(phase)
	await get_tree().process_frame

	var board: NetworkBoardSession = stack.board
	var lobby: NetworkLobbySession = stack.lobby

	lobby.request_add_local_slot("Guest")
	await get_tree().process_frame

	board.request_start_board()
	await get_tree().process_frame

	phase.request_start_minigame_flow()
	await get_tree().process_frame

	assert_false(board.accepts_turn_requests())

	var hash_before := board.get_board_state_hash()
	var turn_before := board.board_stub.turn_index
	var active_id := board.get_active_player_id()
	board.request_advance_turn(active_id)
	await get_tree().process_frame

	assert_eq(board.get_board_state_hash(), hash_before)
	assert_eq(board.board_stub.turn_index, turn_before)


func test_board_uses_frozen_roster_after_lobby_changes() -> void:
	var stack := await _make_host_stack()
	var board: NetworkBoardSession = stack.board
	var lobby: NetworkLobbySession = stack.lobby

	lobby.request_add_local_slot("Guest")
	await get_tree().process_frame

	board.request_start_board()
	await get_tree().process_frame

	var active_id := board.get_active_player_id()
	var frozen_count := board.get_board_slots().size()
	lobby.request_remove_local_slot(active_id)
	await get_tree().process_frame

	assert_eq(lobby.slots.size(), 1)
	assert_eq(board.get_board_slots().size(), frozen_count)

	board.request_advance_turn(active_id)
	await get_tree().process_frame

	assert_eq(board.board_stub.turn_index, 1)


func test_board_roster_ignores_lobby_additions_after_start() -> void:
	var stack := await _make_host_stack()
	var board: NetworkBoardSession = stack.board
	var lobby: NetworkLobbySession = stack.lobby

	board.request_start_board()
	await get_tree().process_frame
	var frozen_count := board.get_board_slots().size()

	lobby.request_add_local_slot("Latecomer")
	await get_tree().process_frame

	assert_eq(lobby.slots.size(), frozen_count + 1)
	assert_eq(board.get_board_slots().size(), frozen_count)


func test_synced_client_restores_frozen_roster_from_board_sync() -> void:
	var authority := NetworkBoardAuthority.new()
	var lobby_authority := NetworkLobbyAuthority.new()
	lobby_authority.try_add_slot(1, "Host")
	lobby_authority.try_add_slot(2, "Client")
	authority.reset_for_slots(lobby_authority.slots)

	var client_board := NetworkBoardSession.new()
	add_child_autofree(client_board)
	client_board._apply_remote_board_state(
		authority.export_board_state(),
		_export_match_slots(authority),
		true,
	)

	assert_eq(client_board.get_board_slots().size(), 2)
	assert_eq(client_board.get_board_slots()[1].owning_peer_id, 2)


func test_replicated_roster_enables_turn_detection_without_authority() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)
	session.host(_test_port)
	await get_tree().process_frame

	var board := NetworkBoardSession.new()
	session.add_child(board)

	var slots: Array[PlayerSlot] = []
	slots.append(PlayerSlot.create("player_1", 1, 0, "Host", Color.WHITE))
	slots.append(PlayerSlot.create("player_2", 2, 0, "Client", Color.WHITE))
	var stub := BoardStub.new()
	stub.reset_for_slots(slots)

	var slots_payload: Array = []
	for slot in slots:
		slots_payload.append(slot.to_dict())

	board._apply_remote_board_state(stub.to_dict(), slots_payload, true)
	assert_true(board.can_local_player_advance_turn())

	stub.advance_turn(slots)
	board._apply_remote_board_state(stub.to_dict(), slots_payload, true)
	assert_false(board.can_local_player_advance_turn())
	assert_eq(board.get_active_player_id(), "player_2")
