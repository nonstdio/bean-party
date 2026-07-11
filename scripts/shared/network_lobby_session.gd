class_name NetworkLobbySession
extends Node

signal slots_structure_changed
signal session_state_changed

var slots: Array[PlayerSlot] = []

var _authority: NetworkLobbyAuthority = null
var _local_device_slots: Dictionary = {}


func _ready() -> void:
	var match_session := _match_session()
	if match_session == null:
		return

	match_session.session_state_changed.connect(_on_match_session_state_changed)
	match_session.peer_connected.connect(_on_peer_connected)
	match_session.peer_disconnected.connect(_on_peer_disconnected)
	_on_match_session_state_changed()


func is_networked() -> bool:
	var match_session := _match_session()
	return match_session != null and match_session.is_session_established()


func is_authority() -> bool:
	var match_session := _match_session()
	return match_session != null and match_session.is_server()


func can_add_local_slot() -> bool:
	if not is_networked():
		return false
	if not get_local_slots().is_empty():
		return false
	if is_authority():
		return _authority != null and _authority.can_add_slot_for_peer(_local_peer_id())
	return slots.size() < MatchConstants.MAX_PLAYERS


func get_local_slots() -> Array[PlayerSlot]:
	return _slots_for_peer(_local_peer_id())


func get_slot(player_id: String) -> PlayerSlot:
	for slot in slots:
		if slot.player_id == player_id:
			return slot
	return null


func _slots_for_peer(peer_id: int) -> Array[PlayerSlot]:
	var peer_slots: Array[PlayerSlot] = []
	for slot in slots:
		if slot.owning_peer_id == peer_id:
			peer_slots.append(slot)
	return peer_slots


func get_local_device_slot(player_id: String) -> int:
	return int(_local_device_slots.get(player_id, -1))


func set_local_device_slot(player_id: String, device_slot: int) -> bool:
	var slot := get_slot(player_id)
	if slot == null or slot.owning_peer_id != _local_peer_id():
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


func ready_count() -> int:
	var count := 0
	for slot in slots:
		if slot.ready:
			count += 1
	return count


func request_add_local_slot(display_name: String = "") -> void:
	if not is_networked():
		return

	if is_authority():
		_host_apply_add_slot(_local_peer_id(), display_name)
	else:
		_rpc_request_add_slot.rpc_id(1, display_name)


func request_remove_local_slot(player_id: String) -> void:
	if not is_networked():
		return

	if is_authority():
		_host_apply_remove_slot(_local_peer_id(), player_id)
	else:
		_rpc_request_remove_slot.rpc_id(1, player_id)


func request_set_ready(player_id: String, is_ready: bool) -> void:
	if not is_networked():
		return

	if is_authority():
		_host_apply_set_ready(_local_peer_id(), player_id, is_ready)
	else:
		_rpc_request_set_ready.rpc_id(1, player_id, is_ready)


func request_set_display_name(player_id: String, display_name: String) -> void:
	if not is_networked():
		return

	if is_authority():
		_host_apply_set_display_name(_local_peer_id(), player_id, display_name)
	else:
		_rpc_request_set_display_name.rpc_id(1, player_id, display_name)


func owns_slot(player_id: String) -> bool:
	var slot := get_slot(player_id)
	return slot != null and slot.owning_peer_id == _local_peer_id()


func _match_session() -> MatchSession:
	var parent := get_parent()
	if parent is MatchSession:
		return parent
	return null


func _local_peer_id() -> int:
	var match_session := _match_session()
	if match_session == null:
		return MatchConstants.OFFLINE_PEER_ID
	return match_session.multiplayer.get_unique_id()


func _on_match_session_state_changed() -> void:
	var match_session := _match_session()
	if match_session == null:
		return

	if match_session.is_session_established():
		if is_authority() and _authority == null:
			_start_host_lobby()
		elif not is_authority():
			call_deferred("_ensure_local_slot")
		return

	_reset_lobby()


func _on_peer_connected(peer_id: int) -> void:
	if not is_authority():
		return

	_push_lobby_sync_to_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_authority():
		return

	_authority.remove_slots_for_peer(peer_id)
	_publish_authority_state()


func _start_host_lobby() -> void:
	_authority = NetworkLobbyAuthority.new()
	_authority.try_add_slot(_local_peer_id(), "Host")
	_publish_authority_state()


func _ensure_local_slot() -> void:
	if not is_networked() or is_authority():
		return
	if get_local_slots().is_empty():
		request_add_local_slot("Player")


func _reset_lobby() -> void:
	_authority = null
	slots.clear()
	_local_device_slots.clear()
	slots_structure_changed.emit()
	session_state_changed.emit()


func _publish_authority_state() -> void:
	_sync_slots_from_authority()
	_broadcast_lobby_sync()


func _host_apply_add_slot(peer_id: int, display_name: String) -> void:
	if _authority.try_add_slot(peer_id, display_name) == null:
		return

	_publish_authority_state()


func _host_apply_remove_slot(peer_id: int, player_id: String) -> void:
	if not _authority.try_remove_slot(peer_id, player_id):
		return

	_local_device_slots.erase(player_id)
	_publish_authority_state()


func _host_apply_set_ready(peer_id: int, player_id: String, is_ready: bool) -> void:
	if not _authority.try_set_ready(peer_id, player_id, is_ready):
		return

	_publish_authority_state()


func _host_apply_set_display_name(peer_id: int, player_id: String, display_name: String) -> void:
	if not _authority.try_set_display_name(peer_id, player_id, display_name):
		return

	_publish_authority_state()


func _sync_slots_from_authority() -> void:
	if _authority == null:
		return

	slots.clear()
	for slot in _authority.slots:
		slots.append(slot.duplicate_slot())

	_ensure_local_device_defaults()
	slots_structure_changed.emit()
	session_state_changed.emit()


func _apply_remote_slots(payload: Array) -> void:
	slots.clear()
	for entry in payload:
		if entry is Dictionary:
			slots.append(PlayerSlot.from_dict(entry))

	_ensure_local_device_defaults()
	slots_structure_changed.emit()
	session_state_changed.emit()

	if not is_authority():
		call_deferred("_ensure_local_slot")


func _ensure_local_device_defaults() -> void:
	var local_peer_id := _local_peer_id()
	var next_device := 0
	for slot in slots:
		if slot.owning_peer_id != local_peer_id:
			continue
		if not _local_device_slots.has(slot.player_id):
			while _device_slot_taken(next_device, slot.player_id):
				next_device += 1
			_local_device_slots[slot.player_id] = next_device
			next_device += 1

	for player_id in _local_device_slots.duplicate().keys():
		if get_slot(player_id) == null:
			_local_device_slots.erase(player_id)


func _device_slot_taken(device_slot: int, except_player_id: String) -> bool:
	for player_id in _local_device_slots:
		if player_id == except_player_id:
			continue
		var slot := get_slot(player_id)
		if slot != null and slot.owning_peer_id == _local_peer_id():
			if int(_local_device_slots[player_id]) == device_slot:
				return true
	return false


func _broadcast_lobby_sync() -> void:
	if _authority == null:
		return
	_rpc_apply_lobby_sync.rpc(_authority.export_slots())


func _push_lobby_sync_to_peer(peer_id: int) -> void:
	if _authority == null:
		return
	_rpc_apply_lobby_sync.rpc_id(peer_id, _authority.export_slots())


func _export_slots() -> Array:
	var payload: Array = []
	for slot in slots:
		payload.append(slot.to_dict())
	return payload


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_add_slot(display_name: String) -> void:
	if not is_authority():
		return
	_host_apply_add_slot(multiplayer.get_remote_sender_id(), display_name)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_remove_slot(player_id: String) -> void:
	if not is_authority():
		return
	_host_apply_remove_slot(multiplayer.get_remote_sender_id(), player_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_set_ready(player_id: String, is_ready: bool) -> void:
	if not is_authority():
		return
	_host_apply_set_ready(multiplayer.get_remote_sender_id(), player_id, is_ready)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_set_display_name(player_id: String, display_name: String) -> void:
	if not is_authority():
		return
	_host_apply_set_display_name(multiplayer.get_remote_sender_id(), player_id, display_name)


@rpc("authority", "call_remote", "reliable")
func _rpc_apply_lobby_sync(payload: Array) -> void:
	_apply_remote_slots(payload)
