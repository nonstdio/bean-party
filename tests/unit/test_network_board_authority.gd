extends GutTest


func _make_slots() -> Array[PlayerSlot]:
	var authority := NetworkLobbyAuthority.new()
	var host := authority.try_add_slot(1, "Host")
	var client := authority.try_add_slot(2, "Client")
	return authority.slots


func test_reset_initializes_active_player_from_first_slot() -> void:
	var board := NetworkBoardAuthority.new()
	var slots := _make_slots()

	board.reset_for_slots(slots)

	assert_eq(board.board_stub.turn_index, 0)
	assert_eq(board.board_stub.active_player_id, slots[0].player_id)
	assert_eq(board.board_stub.beans_by_player_id[slots[0].player_id], BoardStub.STARTING_BEANS)


func test_advance_turn_only_from_active_player_peer() -> void:
	var board := NetworkBoardAuthority.new()
	var slots := _make_slots()
	board.reset_for_slots(slots)

	var active_id := board.board_stub.active_player_id
	var active_slot := slots[0] if slots[0].player_id == active_id else slots[1]

	assert_true(board.try_advance_turn(active_slot.owning_peer_id, active_id))
	assert_eq(board.board_stub.turn_index, 1)

	var next_active := board.board_stub.active_player_id
	var next_slot := slots[0] if slots[0].player_id == next_active else slots[1]
	var wrong_slot := slots[1] if next_slot == slots[0] else slots[0]

	assert_false(board.try_advance_turn(wrong_slot.owning_peer_id, next_active))
	assert_true(board.try_advance_turn(next_slot.owning_peer_id, next_active))
	assert_eq(board.board_stub.turn_index, 2)


func test_rejects_advance_for_wrong_player_id() -> void:
	var board := NetworkBoardAuthority.new()
	var slots := _make_slots()
	board.reset_for_slots(slots)

	var inactive_id := slots[1].player_id if slots[0].player_id == board.board_stub.active_player_id else slots[0].player_id
	assert_false(board.try_advance_turn(slots[1].owning_peer_id, inactive_id))
	assert_eq(board.board_stub.turn_index, 0)


func test_reset_snapshots_match_slots() -> void:
	var board := NetworkBoardAuthority.new()
	var slots := _make_slots()

	board.reset_for_slots(slots)

	assert_eq(board.match_slots.size(), 2)
	assert_eq(board.match_slots[0].player_id, slots[0].player_id)
	slots[0].display_name = "Mutated"
	assert_eq(board.match_slots[0].display_name, "Host")


func test_export_and_load_round_trip_preserves_hash() -> void:
	var board := NetworkBoardAuthority.new()
	var slots := _make_slots()
	board.reset_for_slots(slots)
	board.try_advance_turn(slots[0].owning_peer_id, slots[0].player_id)

	var original_hash := board.state_hash()
	var replica := NetworkBoardAuthority.new()
	replica.load_board_state(board.export_board_state())

	assert_eq(replica.state_hash(), original_hash)
	assert_eq(replica.board_stub.turn_index, board.board_stub.turn_index)
