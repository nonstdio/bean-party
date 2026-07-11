class_name NetworkBoardAuthority
extends RefCounted

var board_stub: BoardStub = BoardStub.new()


func reset_for_slots(slots: Array[PlayerSlot]) -> void:
	board_stub.reset_for_slots(slots)


func try_advance_turn(
		slots: Array[PlayerSlot],
		requesting_peer_id: int,
		player_id: String,
) -> bool:
	if slots.is_empty():
		return false

	if board_stub.active_player_id != player_id:
		return false

	var slot := _slot_for_player_id(slots, player_id)
	if slot == null or slot.owning_peer_id != requesting_peer_id:
		return false

	board_stub.advance_turn(slots)
	return true


func export_board_state() -> Dictionary:
	return board_stub.to_dict()


func load_board_state(payload: Dictionary) -> void:
	board_stub = BoardStub.from_dict(payload)


func state_hash() -> int:
	return board_stub.state_hash()


func _slot_for_player_id(slots: Array[PlayerSlot], player_id: String) -> PlayerSlot:
	for slot in slots:
		if slot.player_id == player_id:
			return slot
	return null
