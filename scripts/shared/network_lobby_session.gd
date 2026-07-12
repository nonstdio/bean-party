class_name NetworkLobbySession
extends Node

signal slots_structure_changed
signal session_state_changed

var slots: Array[PlayerSlot] = []

var _authority: NetworkLobbyAuthority = null
var _local_device_slots: Dictionary = {}
var _local_reconnect_credentials: Dictionary = {}
var _pending_client_rpcs: Array[Callable] = []
var _pending_lobby_sync_peer_ids: Dictionary = {}
var _client_rpc_retry_connected: bool = false


func _ready() -> void:
	var match_session := _match_session()
	if match_session == null:
		return

	match_session.session_state_changed.connect(_on_match_session_state_changed)
	match_session.session_ended.connect(_on_session_ended)
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
	if _is_match_in_progress():
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
		_issue_client_rpc(func() -> void: _rpc_request_add_slot.rpc_id(1, display_name))


func request_remove_local_slot(player_id: String) -> void:
	if not is_networked():
		return

	if is_authority():
		_host_apply_remove_slot(_local_peer_id(), player_id)
	else:
		_issue_client_rpc(func() -> void: _rpc_request_remove_slot.rpc_id(1, player_id))


func request_set_ready(player_id: String, is_ready: bool) -> void:
	if not is_networked():
		return

	if is_authority():
		_host_apply_set_ready(_local_peer_id(), player_id, is_ready)
	else:
		_issue_client_rpc(func() -> void: _rpc_request_set_ready.rpc_id(1, player_id, is_ready))


func request_reclaim_slot(
	player_id: String,
	match_epoch: int,
	recovery_session_id: String,
	reconnect_token: String,
) -> void:
	if not is_networked():
		return

	if is_authority():
		_host_apply_reclaim(
			_local_peer_id(),
			player_id,
			match_epoch,
			recovery_session_id,
			reconnect_token,
		)
	else:
		_issue_client_rpc(
			func() -> void:
				(
					_rpc_request_reclaim_slot
					. rpc_id(
						1,
						player_id,
						match_epoch,
						recovery_session_id,
						reconnect_token,
					)
				)
		)


func owns_slot(player_id: String) -> bool:
	var slot := get_slot(player_id)
	return slot != null and slot.owning_peer_id == _local_peer_id()


func request_set_display_name(player_id: String, display_name: String) -> void:
	if not is_networked():
		return

	if is_authority():
		_host_apply_set_display_name(_local_peer_id(), player_id, display_name)
	else:
		_issue_client_rpc(
			func() -> void: _rpc_request_set_display_name.rpc_id(1, player_id, display_name)
		)


func _board_session() -> NetworkBoardSession:
	var match_session := _match_session()
	if match_session == null:
		return null
	for child in match_session.get_children():
		if child is NetworkBoardSession:
			return child
	return null


func _phase_session() -> NetworkMatchPhaseSession:
	var match_session := _match_session()
	if match_session == null:
		return null
	for child in match_session.get_children():
		if child is NetworkMatchPhaseSession:
			return child
	return null


func _is_match_in_progress() -> bool:
	var board_session := _board_session()
	return board_session != null and board_session.is_board_active()


func _match_session() -> MatchSession:
	var parent := get_parent()
	if parent is MatchSession:
		return parent
	return null


func _can_send_client_rpc() -> bool:
	var match_session := _match_session()
	return match_session != null and match_session.is_client_rpc_ready()


func _issue_client_rpc(action: Callable) -> void:
	if _can_send_client_rpc():
		action.call()
		return
	_pending_client_rpcs.append(action)
	_ensure_transport_retry_listener()


func _ensure_transport_retry_listener() -> void:
	var match_session := _match_session()
	if match_session == null or _client_rpc_retry_connected:
		return
	match_session.session_state_changed.connect(_retry_pending_transport_work)
	_client_rpc_retry_connected = true


func _retry_pending_transport_work() -> void:
	_flush_pending_client_rpcs()
	_flush_pending_lobby_syncs()


func _flush_pending_client_rpcs() -> void:
	if _pending_client_rpcs.is_empty() or not _can_send_client_rpc():
		return
	var pending := _pending_client_rpcs.duplicate()
	_pending_client_rpcs.clear()
	for action in pending:
		action.call()
	_clear_transport_retry_listener_if_idle()


func _flush_pending_lobby_syncs() -> void:
	if _pending_lobby_sync_peer_ids.is_empty() or not is_authority():
		return
	var match_session := _match_session()
	if match_session == null:
		return

	var ready_peer_ids: Array[int] = []
	for peer_id in _pending_lobby_sync_peer_ids:
		if match_session.is_peer_route_ready(peer_id):
			ready_peer_ids.append(peer_id)

	for peer_id in ready_peer_ids:
		_pending_lobby_sync_peer_ids.erase(peer_id)
		_push_lobby_sync_to_peer(peer_id)

	_clear_transport_retry_listener_if_idle()


func _clear_transport_retry_listener_if_idle() -> void:
	if not _pending_client_rpcs.is_empty() or not _pending_lobby_sync_peer_ids.is_empty():
		return
	var match_session := _match_session()
	if match_session == null or not _client_rpc_retry_connected:
		return
	if match_session.session_state_changed.is_connected(_retry_pending_transport_work):
		match_session.session_state_changed.disconnect(_retry_pending_transport_work)
	_client_rpc_retry_connected = false


func _reconnect_host_address(match_session: MatchSession) -> String:
	if match_session.get_transport_id() == TransportAdapterRegistry.TRANSPORT_WEBRTC:
		return ""
	return match_session.get_last_join_address()


func _reconnect_signaling_url(match_session: MatchSession) -> String:
	if match_session.get_transport_id() == TransportAdapterRegistry.TRANSPORT_WEBRTC:
		return match_session.get_last_join_address()
	return ""


func _local_peer_id() -> int:
	var match_session := _match_session()
	if match_session == null or not match_session.is_session_established():
		return MatchConstants.OFFLINE_PEER_ID
	if match_session.multiplayer.multiplayer_peer == null:
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
		_retry_pending_transport_work()
		return

	_reset_lobby()


func _on_session_ended(reason: MatchSession.SessionEndReason, _message: String) -> void:
	if reason == MatchSession.SessionEndReason.HOST_LEFT:
		NetworkReconnectState.clear()
		return
	_capture_reconnect_state()


func _capture_reconnect_state() -> void:
	if is_authority():
		return

	var board_session := _board_session()
	var phase_session := _phase_session()
	var match_session := _match_session()
	if board_session == null or not board_session.is_board_active():
		return
	if phase_session == null or not phase_session.can_reclaim_at_phase_boundary():
		return
	if match_session == null:
		return

	for player_id in _local_device_slots:
		var credential: Variant = _local_reconnect_credentials.get(player_id)
		if credential is not Dictionary:
			return
		var recovery_session_id := String(credential.get("recovery_session_id", ""))
		var reconnect_token := String(credential.get("reconnect_token", ""))
		if recovery_session_id == "" or reconnect_token == "":
			return
		(
			NetworkReconnectState
			. remember(
				player_id,
				phase_session.get_match_epoch(),
				recovery_session_id,
				reconnect_token,
				match_session.get_transport_id(),
				_reconnect_host_address(match_session),
				match_session.get_last_join_port(),
				_reconnect_signaling_url(match_session),
				match_session.get_last_join_room_code(),
			)
		)
		return


func _on_peer_connected(peer_id: int) -> void:
	if not is_authority():
		return

	_queue_lobby_sync_to_peer(peer_id)


func _queue_lobby_sync_to_peer(peer_id: int) -> void:
	if _authority == null:
		return
	var match_session := _match_session()
	if match_session != null and match_session.is_peer_route_ready(peer_id):
		_push_lobby_sync_to_peer(peer_id)
		return
	_pending_lobby_sync_peer_ids[peer_id] = true
	_ensure_transport_retry_listener()


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_authority():
		return
	if _is_match_in_progress():
		if PlayerSlotConnectivity.mark_peer_inactive(_authority.slots, peer_id):
			_publish_authority_state()
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
	if not get_local_slots().is_empty():
		return

	if NetworkReconnectState.has_pending():
		var board_session := _board_session()
		var match_session := _match_session()
		if (
			board_session != null
			and board_session.is_board_active()
			and board_session.get_recovery_session_id() != ""
			and match_session != null
			and (
				NetworkReconnectState
				. matches_target(
					board_session.get_recovery_session_id(),
					match_session.get_transport_id(),
					match_session.get_last_join_address(),
					match_session.get_last_join_port(),
					match_session.get_last_join_room_code(),
				)
			)
		):
			request_reclaim_slot(
				NetworkReconnectState.pending_player_id,
				NetworkReconnectState.pending_match_epoch,
				NetworkReconnectState.pending_recovery_session_id,
				NetworkReconnectState.pending_reconnect_token,
			)
			return
		if (
			board_session != null
			and board_session.is_board_active()
			and board_session.get_recovery_session_id() == ""
		):
			return
		NetworkReconnectState.clear()

	request_add_local_slot("Player")


func _reset_lobby() -> void:
	_pending_client_rpcs.clear()
	_pending_lobby_sync_peer_ids.clear()
	_clear_transport_retry_listener_if_idle()
	_authority = null
	slots.clear()
	_local_device_slots.clear()
	_local_reconnect_credentials.clear()
	slots_structure_changed.emit()
	session_state_changed.emit()


func _publish_authority_state() -> void:
	_sync_slots_from_authority()
	_broadcast_lobby_sync()


func _host_apply_add_slot(peer_id: int, display_name: String) -> void:
	if _is_match_in_progress():
		return
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


func _host_apply_reclaim(
	peer_id: int,
	player_id: String,
	match_epoch: int,
	recovery_session_id: String,
	reconnect_token: String,
) -> void:
	var board_session := _board_session()
	var phase_session := _phase_session()
	if board_session == null or not board_session.is_board_active():
		_reject_reclaim(peer_id)
		return
	if phase_session == null or not phase_session.can_reclaim_at_phase_boundary():
		_reject_reclaim(peer_id)
		return
	if phase_session.get_match_epoch() != match_epoch:
		_reject_reclaim(peer_id)
		return
	if board_session.get_recovery_session_id() != recovery_session_id:
		_reject_reclaim(peer_id)
		return
	if not board_session.verify_reconnect_token(player_id, reconnect_token):
		_reject_reclaim(peer_id)
		return
	if not _authority.can_reclaim_slot_for_peer(player_id):
		_reject_reclaim(peer_id)
		return
	if not board_session.can_reclaim_slot(player_id, peer_id):
		_reject_reclaim(peer_id)
		return
	if not phase_session.can_reclaim_slot(player_id, peer_id):
		_reject_reclaim(peer_id)
		return

	var lobby_backup := PlayerSlotConnectivity.duplicate_slots(_authority.slots)
	var board_backup := PlayerSlotConnectivity.duplicate_slots(board_session._authority.match_slots)
	var phase_backup := PlayerSlotConnectivity.duplicate_slots(phase_session._authority.match_slots)

	if not board_session._apply_reclaim_slot_for_peer(player_id, peer_id):
		_reject_reclaim(peer_id)
		return
	if not _authority.reclaim_slot_for_peer(player_id, peer_id):
		PlayerSlotConnectivity.copy_slots_into(board_session._authority.match_slots, board_backup)
		board_session._sync_board_from_authority()
		_reject_reclaim(peer_id)
		return
	if not phase_session._apply_reclaim_slot_for_peer(player_id, peer_id):
		PlayerSlotConnectivity.copy_slots_into(_authority.slots, lobby_backup)
		PlayerSlotConnectivity.copy_slots_into(board_session._authority.match_slots, board_backup)
		board_session._sync_board_from_authority()
		_reject_reclaim(peer_id)
		return

	_publish_authority_state()
	board_session.publish_reclaim_state()
	phase_session._sync_from_authority()
	phase_session._broadcast_phase_sync()

	var new_token := board_session.rotate_reconnect_token(player_id)
	_push_reconnect_credential_to_peer(
		peer_id,
		player_id,
		board_session.get_recovery_session_id(),
		new_token,
	)


func _reject_reclaim(peer_id: int) -> void:
	if peer_id != _local_peer_id():
		_rpc_reclaim_rejected.rpc_id(peer_id)
	else:
		NetworkReconnectState.clear()
		call_deferred("_ensure_local_slot")


func _push_reconnect_credential_to_peer(
	peer_id: int,
	player_id: String,
	recovery_session_id: String,
	reconnect_token: String,
) -> void:
	if not _peer_is_connected(peer_id):
		return
	(
		_rpc_assign_reconnect_credential
		. rpc_id(
			peer_id,
			player_id,
			recovery_session_id,
			reconnect_token,
		)
	)


func _peer_is_connected(peer_id: int) -> bool:
	if peer_id == MatchConstants.OFFLINE_PEER_ID:
		return false
	var match_session := _match_session()
	if match_session == null or not match_session.is_session_established():
		return false
	return peer_id in match_session.get_session_peer_ids()


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
	_maybe_clear_reconnect_state()


func _maybe_clear_reconnect_state() -> void:
	if not NetworkReconnectState.has_pending():
		return
	for slot in get_local_slots():
		if (
			slot.player_id == NetworkReconnectState.pending_player_id
			and slot.owning_peer_id == _local_peer_id()
			and PlayerSlotConnectivity.is_participating(slot)
		):
			NetworkReconnectState.clear()
			return


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


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_add_slot(display_name: String) -> void:
	if not is_authority():
		return
	_host_apply_add_slot(multiplayer.get_remote_sender_id(), display_name)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_remove_slot(player_id: String) -> void:
	if not is_authority():
		return
	_host_apply_remove_slot(multiplayer.get_remote_sender_id(), player_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_ready(player_id: String, is_ready: bool) -> void:
	if not is_authority():
		return
	_host_apply_set_ready(multiplayer.get_remote_sender_id(), player_id, is_ready)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_set_display_name(player_id: String, display_name: String) -> void:
	if not is_authority():
		return
	_host_apply_set_display_name(multiplayer.get_remote_sender_id(), player_id, display_name)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_reclaim_slot(
	player_id: String,
	match_epoch: int,
	recovery_session_id: String,
	reconnect_token: String,
) -> void:
	if not is_authority():
		return
	_host_apply_reclaim(
		multiplayer.get_remote_sender_id(),
		player_id,
		match_epoch,
		recovery_session_id,
		reconnect_token,
	)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_assign_reconnect_credential(
	player_id: String,
	recovery_session_id: String,
	reconnect_token: String,
) -> void:
	_local_reconnect_credentials[player_id] = {
		"recovery_session_id": recovery_session_id,
		"reconnect_token": reconnect_token,
	}


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_reclaim_rejected() -> void:
	NetworkReconnectState.clear()
	call_deferred("_ensure_local_slot")


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_apply_lobby_sync(payload: Array) -> void:
	_apply_remote_slots(payload)
