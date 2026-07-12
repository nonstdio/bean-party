class_name NetworkLobbyAuthority
extends RefCounted

signal slots_structure_changed
signal session_state_changed

var slots: Array[PlayerSlot] = []

var _next_player_serial: int = 1


func can_add_slot_for_peer(peer_id: int) -> bool:
	if slots.size() >= MatchConstants.MAX_PLAYERS:
		return false
	return get_slots_for_peer(peer_id).is_empty()


func try_add_slot(peer_id: int, display_name: String = "") -> PlayerSlot:
	if not can_add_slot_for_peer(peer_id):
		return null

	var peer_slots := get_slots_for_peer(peer_id)
	var local_index := peer_slots.size()
	var resolved_name := display_name if display_name != "" else "Player %d" % (local_index + 1)
	var color_index := _first_unused_color_index()
	color_index = color_index % MatchConstants.SLOT_COLORS.size()

	var slot := (
		PlayerSlot
		. create(
			_allocate_player_id(),
			peer_id,
			local_index,
			resolved_name,
			MatchConstants.SLOT_COLORS[color_index],
		)
	)
	slots.append(slot)
	slots_structure_changed.emit()
	return slot


func try_remove_slot(requesting_peer_id: int, player_id: String) -> bool:
	var slot := get_slot(player_id)
	if slot == null or slot.owning_peer_id != requesting_peer_id:
		return false

	var index := _index_for_player_id(player_id)
	if index < 0:
		return false

	slots.remove_at(index)
	_reindex_local_player_indices_for_peer(requesting_peer_id)
	slots_structure_changed.emit()
	return true


func try_set_ready(requesting_peer_id: int, player_id: String, is_ready: bool) -> bool:
	var slot := get_slot(player_id)
	if slot == null or slot.owning_peer_id != requesting_peer_id:
		return false

	if slot.ready == is_ready:
		return true

	slot.ready = is_ready
	session_state_changed.emit()
	return true


func try_set_display_name(
	requesting_peer_id: int,
	player_id: String,
	display_name: String,
) -> bool:
	var slot := get_slot(player_id)
	if slot == null or slot.owning_peer_id != requesting_peer_id:
		return false

	var trimmed := display_name.strip_edges()
	if slot.display_name == trimmed:
		return true

	slot.display_name = trimmed
	session_state_changed.emit()
	return true


func remove_slots_for_peer(peer_id: int) -> void:
	var removed := false
	for i in range(slots.size() - 1, -1, -1):
		if slots[i].owning_peer_id == peer_id:
			slots.remove_at(i)
			removed = true

	if not removed:
		return

	_reindex_local_player_indices_for_peer(peer_id)
	slots_structure_changed.emit()


func get_slot(player_id: String) -> PlayerSlot:
	var index := _index_for_player_id(player_id)
	if index < 0:
		return null
	return slots[index]


func get_slots_for_peer(peer_id: int) -> Array[PlayerSlot]:
	var peer_slots: Array[PlayerSlot] = []
	for slot in slots:
		if slot.owning_peer_id == peer_id:
			peer_slots.append(slot)
	peer_slots.sort_custom(
		func(a: PlayerSlot, b: PlayerSlot) -> bool:
			return a.local_player_index < b.local_player_index
	)
	return peer_slots


func ready_count() -> int:
	var count := 0
	for slot in slots:
		if slot.ready:
			count += 1
	return count


func export_slots() -> Array:
	var payload: Array = []
	for slot in slots:
		payload.append(slot.to_dict())
	return payload


func mark_peer_inactive(peer_id: int) -> bool:
	return PlayerSlotConnectivity.mark_peer_inactive(slots, peer_id)


func reclaim_slot_for_peer(player_id: String, peer_id: int) -> bool:
	return PlayerSlotConnectivity.reclaim_slot(slots, player_id, peer_id)


func can_reclaim_slot_for_peer(player_id: String) -> bool:
	return PlayerSlotConnectivity.can_reclaim_slot(slots, player_id)


func load_slots(payload: Array) -> void:
	slots.clear()
	for entry in payload:
		if entry is Dictionary:
			slots.append(PlayerSlot.from_dict(entry))
	_next_player_serial = _derive_next_player_serial()
	slots_structure_changed.emit()


func _allocate_player_id() -> String:
	var id := "player_%d" % _next_player_serial
	_next_player_serial += 1
	return id


func _index_for_player_id(player_id: String) -> int:
	for i in slots.size():
		if slots[i].player_id == player_id:
			return i
	return -1


func _reindex_local_player_indices_for_peer(peer_id: int) -> void:
	var next_index := 0
	for slot in slots:
		if slot.owning_peer_id == peer_id:
			slot.local_player_index = next_index
			next_index += 1


func _derive_next_player_serial() -> int:
	var highest := 0
	for slot in slots:
		if slot.player_id.begins_with("player_"):
			var suffix := slot.player_id.trim_prefix("player_")
			if suffix.is_valid_int():
				highest = max(highest, int(suffix))
	return highest + 1


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
