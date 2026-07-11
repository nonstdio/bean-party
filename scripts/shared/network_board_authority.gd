class_name NetworkBoardAuthority
extends RefCounted

var board_stub: BoardStub = BoardStub.new()
var match_slots: Array[PlayerSlot] = []


func reset_for_slots(slots: Array[PlayerSlot]) -> void:
	match_slots.clear()
	for slot in slots:
		match_slots.append(slot.duplicate_slot())
	board_stub.reset_for_slots(match_slots)


func try_advance_turn(requesting_peer_id: int, player_id: String) -> bool:
	if match_slots.is_empty():
		return false

	if board_stub.active_player_id != player_id:
		return false

	var slot := _slot_for_player_id(player_id)
	if slot == null or slot.owning_peer_id != requesting_peer_id:
		return false
	if not PlayerSlotConnectivity.is_participating(slot):
		return false

	board_stub.advance_turn(match_slots)
	return true


func mark_peer_inactive(peer_id: int) -> bool:
	return PlayerSlotConnectivity.mark_peer_inactive(match_slots, peer_id)


func reclaim_slot_for_peer(player_id: String, peer_id: int) -> bool:
	return PlayerSlotConnectivity.reclaim_slot(match_slots, player_id, peer_id)


func export_board_state() -> Dictionary:
	return board_stub.to_dict()


func load_board_state(payload: Dictionary) -> void:
	board_stub = BoardStub.from_dict(payload)


func state_hash() -> int:
	return board_stub.state_hash()


func _slot_for_player_id(player_id: String) -> PlayerSlot:
	for slot in match_slots:
		if slot.player_id == player_id:
			return slot
	return null
