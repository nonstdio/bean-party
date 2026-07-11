class_name NetworkBoardSession
extends Node

signal board_state_changed
signal board_active_changed(is_active: bool)

var board_stub: BoardStub = BoardStub.new()

var _authority: NetworkBoardAuthority = null
var _board_slots: Array[PlayerSlot] = []
var _is_active: bool = false


func _ready() -> void:
	var match_session := _match_session()
	if match_session == null:
		return

	match_session.session_state_changed.connect(_on_match_session_state_changed)
	match_session.peer_connected.connect(_on_peer_connected)
	_on_match_session_state_changed()


func is_networked() -> bool:
	var match_session := _match_session()
	return match_session != null and match_session.is_session_established()


func is_authority() -> bool:
	var match_session := _match_session()
	return match_session != null and match_session.is_server()


func is_board_active() -> bool:
	return _is_active


func get_board_state_hash() -> int:
	return board_stub.state_hash()


func get_active_player_id() -> String:
	return board_stub.active_player_id


func can_local_player_advance_turn() -> bool:
	if not _is_active:
		return false

	var active_id := board_stub.active_player_id
	if active_id == "":
		return false

	for slot in get_board_slots():
		if slot.player_id == active_id:
			return slot.owning_peer_id == _local_peer_id()
	return false


func get_board_slots() -> Array[PlayerSlot]:
	return _board_slots


func request_start_board() -> void:
	if not is_networked() or not is_authority():
		return
	_host_start_board()


func request_advance_turn(player_id: String) -> void:
	if not is_networked() or not _is_active:
		return

	if is_authority():
		_host_apply_advance_turn(_local_peer_id(), player_id)
	else:
		_rpc_request_advance_turn.rpc_id(1, player_id)


func _match_session() -> MatchSession:
	var parent := get_parent()
	if parent is MatchSession:
		return parent
	return null


func _lobby_session() -> NetworkLobbySession:
	var match_session := _match_session()
	if match_session == null:
		return null

	for child in match_session.get_children():
		if child is NetworkLobbySession:
			return child
	return null


func _local_peer_id() -> int:
	var match_session := _match_session()
	if match_session == null:
		return MatchConstants.OFFLINE_PEER_ID
	return match_session.multiplayer.get_unique_id()


func _lobby_slots() -> Array[PlayerSlot]:
	var lobby := _lobby_session()
	if lobby == null:
		return []
	return lobby.slots


func _on_match_session_state_changed() -> void:
	if is_networked():
		return
	_reset_board()


func _on_peer_connected(peer_id: int) -> void:
	if not is_authority() or not _is_active:
		return
	_push_board_sync_to_peer(peer_id)


func _reset_board() -> void:
	var was_active := _is_active
	_authority = null
	_board_slots.clear()
	_is_active = false
	board_stub = BoardStub.new()
	board_state_changed.emit()
	if was_active:
		board_active_changed.emit(false)


func _host_start_board() -> void:
	if not is_authority() or _is_active:
		return

	var slots := _lobby_slots()
	if slots.is_empty():
		return

	_authority = NetworkBoardAuthority.new()
	_authority.reset_for_slots(slots)
	_is_active = true
	_sync_board_from_authority()
	_broadcast_board_sync()
	board_active_changed.emit(true)


func _host_apply_advance_turn(peer_id: int, player_id: String) -> void:
	if not is_authority() or _authority == null or not _is_active:
		return

	if not _authority.try_advance_turn(peer_id, player_id):
		return

	_sync_board_from_authority()
	_broadcast_board_sync()


func _sync_board_from_authority() -> void:
	if _authority == null:
		return

	board_stub = _authority.board_stub.duplicate_stub()
	_board_slots.clear()
	for slot in _authority.match_slots:
		_board_slots.append(slot.duplicate_slot())
	board_state_changed.emit()


func _apply_remote_board_state(
		payload: Dictionary,
		slots_payload: Array,
		is_active: bool,
) -> void:
	_authority = null
	_is_active = is_active
	board_stub = BoardStub.from_dict(payload)
	_load_board_slots(slots_payload)
	board_state_changed.emit()
	if is_active:
		board_active_changed.emit(true)


func _load_board_slots(slots_payload: Array) -> void:
	_board_slots.clear()
	for entry in slots_payload:
		if entry is Dictionary:
			_board_slots.append(PlayerSlot.from_dict(entry))


func _export_board_slots() -> Array:
	var payload: Array = []
	for slot in _authority.match_slots:
		payload.append(slot.to_dict())
	return payload


func _broadcast_board_sync() -> void:
	if _authority == null:
		return
	_rpc_apply_board_sync.rpc(_authority.export_board_state(), _export_board_slots(), true)


func _push_board_sync_to_peer(peer_id: int) -> void:
	if _authority == null:
		return
	_rpc_apply_board_sync.rpc_id(
		peer_id,
		_authority.export_board_state(),
		_export_board_slots(),
		true,
	)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_advance_turn(player_id: String) -> void:
	if not is_authority():
		return
	_host_apply_advance_turn(multiplayer.get_remote_sender_id(), player_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_apply_board_sync(
		payload: Dictionary,
		slots_payload: Array,
		is_active: bool,
) -> void:
	_apply_remote_board_state(payload, slots_payload, is_active)
