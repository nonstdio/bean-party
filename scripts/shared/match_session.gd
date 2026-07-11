class_name MatchSession
extends Node

enum SessionState {
	IDLE,
	CONNECTING,
	CONNECTED,
	HOSTING,
}

enum SessionEndReason {
	NONE,
	HOST_LEFT,
	LOCAL_LEFT,
	CONNECTION_FAILED,
}

signal session_state_changed
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed
signal server_disconnected
signal session_ended(reason: SessionEndReason, message: String)
signal echo_completed(from_peer_id: int, message: String)
signal ping_updated(peer_id: int, ping_ms: int)

var _peer: ENetMultiplayerPeer = null
var _state: SessionState = SessionState.IDLE
var _pending_echoes: Dictionary = {}
var _ping_ms_by_peer_id: Dictionary = {}
var _connect_started_msec: int = 0
var _ping_accumulator: float = 0.0

const CONNECT_TIMEOUT_MSEC := 5000
const PING_INTERVAL_SEC := 1.0


func get_session_state() -> SessionState:
	return _state


func is_active() -> bool:
	return _state != SessionState.IDLE


func is_session_established() -> bool:
	return _state == SessionState.CONNECTED or _state == SessionState.HOSTING


func is_server() -> bool:
	return _state == SessionState.HOSTING


func host(port: int = MatchConstants.DEFAULT_ENET_PORT) -> Error:
	disconnect_session()

	_peer = EnetTransportAdapter.create_server_peer(port)
	if _peer == null:
		return ERR_CANT_CREATE

	multiplayer.multiplayer_peer = _peer
	_state = SessionState.HOSTING
	_bind_multiplayer_signals()
	session_state_changed.emit()
	return OK


func join(
		address: String,
		port: int = MatchConstants.DEFAULT_ENET_PORT,
) -> Error:
	disconnect_session()

	_peer = EnetTransportAdapter.create_client_peer(address, port)
	if _peer == null:
		return ERR_CANT_CREATE

	multiplayer.multiplayer_peer = _peer
	_state = SessionState.CONNECTING
	_connect_started_msec = Time.get_ticks_msec()
	_bind_multiplayer_signals()
	session_state_changed.emit()
	return OK


func disconnect_session() -> void:
	if is_server() and is_session_established():
		_rpc_session_ended.rpc(SessionEndReason.HOST_LEFT, _default_end_message(SessionEndReason.HOST_LEFT))
	_end_session(SessionEndReason.LOCAL_LEFT, _default_end_message(SessionEndReason.LOCAL_LEFT))


func get_session_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	if not is_session_established():
		return peer_ids

	var own_id := multiplayer.get_unique_id()
	if own_id > 0 and own_id not in peer_ids:
		peer_ids.append(own_id)

	for peer_id in multiplayer.get_peers():
		if peer_id not in peer_ids:
			peer_ids.append(peer_id)

	peer_ids.sort()
	return peer_ids


func get_remote_peer_ids() -> Array[int]:
	var peer_ids := get_session_peer_ids()
	var own_id := multiplayer.get_unique_id()
	return peer_ids.filter(func(peer_id: int) -> bool:
		return peer_id != own_id
	)


func get_ping_ms(peer_id: int) -> int:
	return int(_ping_ms_by_peer_id.get(peer_id, -1))


func send_echo(peer_id: int, message: String) -> int:
	var nonce := randi()
	_pending_echoes[nonce] = {
		"peer_id": peer_id,
		"message": message,
		"sent_msec": Time.get_ticks_msec(),
	}
	_rpc_echo.rpc_id(peer_id, message, nonce)
	return nonce


func _exit_tree() -> void:
	if is_active():
		_teardown_peer()
		_state = SessionState.IDLE


func _process(delta: float) -> void:
	if _state == SessionState.CONNECTING and _peer != null:
		if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_on_connection_failed()
			return

		if Time.get_ticks_msec() - _connect_started_msec > CONNECT_TIMEOUT_MSEC:
			_on_connection_failed()
			return

	if not is_session_established():
		return

	_ping_accumulator += delta
	if _ping_accumulator < PING_INTERVAL_SEC:
		return

	_ping_accumulator = 0.0
	for peer_id in get_remote_peer_ids():
		send_echo(peer_id, "ping-%d" % Time.get_ticks_msec())


func _bind_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _unbind_multiplayer_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)


func _teardown_peer() -> void:
	_unbind_multiplayer_signals()
	_pending_echoes.clear()
	_ping_ms_by_peer_id.clear()

	if _peer != null:
		_peer.close()
		_peer = null

	multiplayer.multiplayer_peer = null


func _on_connected_to_server() -> void:
	if _state != SessionState.CONNECTING:
		return

	_state = SessionState.CONNECTED
	session_state_changed.emit()
	_ping_accumulator = PING_INTERVAL_SEC


func _on_connection_failed() -> void:
	if _state != SessionState.CONNECTING:
		return

	_end_session(
		SessionEndReason.CONNECTION_FAILED,
		_default_end_message(SessionEndReason.CONNECTION_FAILED),
	)
	connection_failed.emit()


func _on_server_disconnected() -> void:
	if _state != SessionState.CONNECTED:
		return

	_end_session(SessionEndReason.HOST_LEFT, _default_end_message(SessionEndReason.HOST_LEFT))
	server_disconnected.emit()


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)
	session_state_changed.emit()
	_ping_accumulator = PING_INTERVAL_SEC


func _on_peer_disconnected(peer_id: int) -> void:
	_ping_ms_by_peer_id.erase(peer_id)
	peer_disconnected.emit(peer_id)
	session_state_changed.emit()


func _end_session(reason: SessionEndReason, message: String) -> void:
	if _state == SessionState.IDLE:
		return

	if reason != SessionEndReason.NONE:
		session_ended.emit(reason, message)
	_teardown_peer()
	_state = SessionState.IDLE
	session_state_changed.emit()


func _default_end_message(reason: SessionEndReason) -> String:
	match reason:
		SessionEndReason.HOST_LEFT:
			return "Host left the match."
		SessionEndReason.LOCAL_LEFT:
			return "Session disconnected."
		SessionEndReason.CONNECTION_FAILED:
			return "Connection failed."
		_:
			return ""


@rpc("authority", "call_remote", "reliable")
func _rpc_session_ended(reason: int, message: String) -> void:
	if _state != SessionState.CONNECTED:
		return
	_end_session(reason as SessionEndReason, message)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_echo(message: String, nonce: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_rpc_echo_reply.rpc_id(sender_id, message, nonce)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_echo_reply(message: String, nonce: int) -> void:
	_apply_echo_reply(multiplayer.get_remote_sender_id(), message, nonce)


func _apply_echo_reply(from_peer_id: int, message: String, nonce: int) -> void:
	if not _pending_echoes.has(nonce):
		return

	var pending: Dictionary = _pending_echoes[nonce]
	if int(pending.get("peer_id", -1)) != from_peer_id:
		return
	if String(pending.get("message", "")) != message:
		return

	_pending_echoes.erase(nonce)

	var sent_msec := int(pending.get("sent_msec", 0))
	if sent_msec > 0:
		var ping_ms := maxi(0, Time.get_ticks_msec() - sent_msec)
		_ping_ms_by_peer_id[from_peer_id] = ping_ms
		ping_updated.emit(from_peer_id, ping_ms)

	echo_completed.emit(from_peer_id, message)
