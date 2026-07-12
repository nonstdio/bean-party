class_name BoardStub
extends RefCounted

const STARTING_BEANS := 5

var turn_index: int = 0
var beans_by_player_id: Dictionary = {}
var board_position_by_player_id: Dictionary = {}
var active_player_id: String = ""


func reset_for_slots(slots: Array[PlayerSlot]) -> void:
	turn_index = 0
	beans_by_player_id.clear()
	board_position_by_player_id.clear()
	active_player_id = ""

	for slot in slots:
		beans_by_player_id[slot.player_id] = STARTING_BEANS
		board_position_by_player_id[slot.player_id] = 0

	if not slots.is_empty():
		active_player_id = slots[0].player_id


func advance_turn(slots: Array[PlayerSlot]) -> void:
	if slots.is_empty():
		return

	turn_index += 1
	var active_index := _index_for_player_id(slots, active_player_id)
	for _attempt in slots.size():
		active_index = (active_index + 1) % slots.size()
		if PlayerSlotConnectivity.is_participating(slots[active_index]):
			active_player_id = slots[active_index].player_id
			return


func award_beans(player_id: String, amount: int) -> void:
	if not beans_by_player_id.has(player_id):
		return
	beans_by_player_id[player_id] = int(beans_by_player_id[player_id]) + amount


func to_dict() -> Dictionary:
	var beans: Dictionary = {}
	for player_id in beans_by_player_id:
		beans[player_id] = int(beans_by_player_id[player_id])

	var positions: Dictionary = {}
	for player_id in board_position_by_player_id:
		positions[player_id] = int(board_position_by_player_id[player_id])

	return {
		"active_player_id": active_player_id,
		"beans_by_player_id": beans,
		"board_position_by_player_id": positions,
		"turn_index": turn_index,
	}


static func from_dict(data: Dictionary) -> BoardStub:
	var stub := BoardStub.new()
	stub.turn_index = int(data.get("turn_index", 0))
	stub.active_player_id = String(data.get("active_player_id", ""))
	stub.beans_by_player_id = _intify_player_dictionary(data.get("beans_by_player_id", {}))
	stub.board_position_by_player_id = _intify_player_dictionary(
		data.get("board_position_by_player_id", {})
	)
	return stub


static func _intify_player_dictionary(data: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for player_id in data:
		normalized[player_id] = int(data[player_id])
	return normalized


func duplicate_stub() -> BoardStub:
	return BoardStub.from_dict(to_dict())


func state_hash() -> int:
	return MatchSnapshotSerializer.hash_dictionary(to_dict())


func _index_for_player_id(slots: Array[PlayerSlot], player_id: String) -> int:
	for i in slots.size():
		if slots[i].player_id == player_id:
			return i
	return 0
