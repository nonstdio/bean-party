class_name OfflineMatchSession
extends RefCounted

signal slots_structure_changed
signal session_state_changed

var slots: Array[PlayerSlot] = []

var _next_player_serial: int = 1
var _local_device_slots: Dictionary = {}


func can_add_slot() -> bool:
	return slots.size() < MatchConstants.MAX_PLAYERS


func add_local_slot(display_name: String = "", preferred_color_index: int = -1) -> PlayerSlot:
	if not can_add_slot():
		return null

	var local_index := slots.size()
	var resolved_name := display_name if display_name != "" else "Player %d" % (local_index + 1)
	var color_index := (
		preferred_color_index
		if preferred_color_index >= 0
		else _first_unused_color_index()
	)
	color_index = color_index % MatchConstants.SLOT_COLORS.size()
	var device_slot := _first_unused_device_slot()
	var player_id := _allocate_player_id()

	var slot := PlayerSlot.create(
		player_id,
		MatchConstants.OFFLINE_PEER_ID,
		local_index,
		resolved_name,
		MatchConstants.SLOT_COLORS[color_index],
	)
	slots.append(slot)
	_local_device_slots[player_id] = device_slot
	slots_structure_changed.emit()
	return slot


func remove_slot(player_id: String) -> bool:
	var index := _index_for_player_id(player_id)
	if index < 0:
		return false

	var removed_id := slots[index].player_id
	slots.remove_at(index)
	_local_device_slots.erase(removed_id)
	_reindex_local_player_indices()
	slots_structure_changed.emit()
	return true


func set_ready(player_id: String, is_ready: bool) -> bool:
	var slot := get_slot(player_id)
	if slot == null:
		return false

	if slot.ready == is_ready:
		return true

	slot.ready = is_ready
	session_state_changed.emit()
	return true


func set_display_name(player_id: String, display_name: String) -> bool:
	var slot := get_slot(player_id)
	if slot == null:
		return false

	var trimmed := display_name.strip_edges()
	if slot.display_name == trimmed:
		return true

	slot.display_name = trimmed
	return true


func set_local_device_slot(player_id: String, device_slot: int) -> bool:
	if get_slot(player_id) == null:
		return false
	if device_slot < 0 or device_slot >= MatchConstants.MAX_PLAYERS:
		return false

	for other_id in _local_device_slots:
		if other_id != player_id and int(_local_device_slots[other_id]) == device_slot:
			var current_slot := get_local_device_slot(player_id)
			_local_device_slots[other_id] = current_slot
			break

	_local_device_slots[player_id] = device_slot
	return true


func get_local_device_slot(player_id: String) -> int:
	return int(_local_device_slots.get(player_id, -1))


func get_slot(player_id: String) -> PlayerSlot:
	var index := _index_for_player_id(player_id)
	if index < 0:
		return null
	return slots[index]


func get_slot_by_local_index(local_player_index: int) -> PlayerSlot:
	for slot in slots:
		if slot.local_player_index == local_player_index:
			return slot
	return null


func ready_count() -> int:
	var count := 0
	for slot in slots:
		if slot.ready:
			count += 1
	return count


func _allocate_player_id() -> String:
	var id := "player_%d" % _next_player_serial
	_next_player_serial += 1
	return id


func _index_for_player_id(player_id: String) -> int:
	for i in slots.size():
		if slots[i].player_id == player_id:
			return i
	return -1


func _reindex_local_player_indices() -> void:
	for i in slots.size():
		slots[i].local_player_index = i


func _first_unused_device_slot() -> int:
	var used: Dictionary = {}
	for player_id in _local_device_slots:
		used[int(_local_device_slots[player_id])] = true

	for device_slot in MatchConstants.MAX_PLAYERS:
		if not used.has(device_slot):
			return device_slot

	return 0


func _first_unused_color_index() -> int:
	var used: Dictionary = {}
	for slot in slots:
		var color_index := MatchConstants.SLOT_COLORS.find(slot.slot_color)
		if color_index >= 0:
			used[color_index] = true

	for color_index in MatchConstants.SLOT_COLORS.size():
		if not used.has(color_index):
			return color_index

	return 0
