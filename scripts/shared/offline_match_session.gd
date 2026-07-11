class_name OfflineMatchSession
extends RefCounted

signal slots_changed

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
	var color_index := preferred_color_index if preferred_color_index >= 0 else local_index
	color_index = color_index % MatchConstants.SLOT_COLORS.size()
	var player_id := _allocate_player_id()

	var slot := PlayerSlot.create(
		player_id,
		MatchConstants.OFFLINE_PEER_ID,
		local_index,
		resolved_name,
		MatchConstants.SLOT_COLORS[color_index],
	)
	slots.append(slot)
	_local_device_slots[player_id] = local_index
	slots_changed.emit()
	return slot


func remove_slot(player_id: String) -> bool:
	var index := _index_for_player_id(player_id)
	if index < 0:
		return false

	var removed_id := slots[index].player_id
	slots.remove_at(index)
	_local_device_slots.erase(removed_id)
	_reindex_local_player_indices()
	slots_changed.emit()
	return true


func set_ready(player_id: String, is_ready: bool) -> bool:
	var slot := get_slot(player_id)
	if slot == null:
		return false

	slot.ready = is_ready
	slots_changed.emit()
	return true


func set_display_name(player_id: String, display_name: String) -> bool:
	var slot := get_slot(player_id)
	if slot == null:
		return false

	slot.display_name = display_name.strip_edges()
	slots_changed.emit()
	return true


func set_local_device_slot(player_id: String, device_slot: int) -> bool:
	if get_slot(player_id) == null:
		return false

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
