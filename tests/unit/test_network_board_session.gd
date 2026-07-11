extends GutTest

var _test_port: int


func before_each() -> void:
	_test_port = 18000 + int(Time.get_ticks_msec() % 1000)


func _make_host_stack() -> Dictionary:
	var host_session := MatchSession.new()
	add_child_autofree(host_session)

	var lobby := NetworkLobbySession.new()
	host_session.add_child(lobby)

	var board := NetworkBoardSession.new()
	host_session.add_child(board)

	assert_eq(host_session.host(_test_port), OK)
	await get_tree().process_frame

	lobby.request_add_local_slot("Host")
	await get_tree().process_frame

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
	client_board._apply_remote_board_state(authority.export_board_state(), true)

	client_board.board_stub.turn_index = 99
	assert_eq(client_board.board_stub.turn_index, 99)

	authority.try_advance_turn(
		lobby_authority.slots,
		lobby_authority.slots[0].owning_peer_id,
		lobby_authority.slots[0].player_id,
	)
	client_board._apply_remote_board_state(authority.export_board_state(), true)

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
		lobby_authority.slots,
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
	client_board._apply_remote_board_state(authority.export_board_state(), true)

	assert_eq(host_board.get_board_state_hash(), client_board.get_board_state_hash())

	authority.try_advance_turn(
		lobby_authority.slots,
		lobby_authority.slots[1].owning_peer_id,
		lobby_authority.slots[1].player_id,
	)
	host_board._sync_board_from_authority()
	client_board._apply_remote_board_state(authority.export_board_state(), true)

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
				lobby_authority.slots,
				active_slot.owning_peer_id,
				active_id,
			)
		)
		host_board._sync_board_from_authority()
		client_board._apply_remote_board_state(authority.export_board_state(), true)
		assert_eq(host_board.get_board_state_hash(), client_board.get_board_state_hash())
