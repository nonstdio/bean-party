class_name MatchSession
extends Node

enum SessionState {
	IDLE,
	CONNECTING,
	CONNECTED,
	HOSTING,
}

signal session_state_changed
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_failed
signal server_disconnected
signal echo_completed(from_peer_id: int, message: String)

var _peer: ENetMultiplayerPeer = null
var _state: SessionState = SessionState.IDLE
var _pending_echoes: Dictionary = {}
var _connect_started_msec: int = 0

const CONNECT_TIMEOUT_MSEC := 5000


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
	_teardown_peer()
	_state = SessionState.IDLE
	session_state_changed.emit()


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


func send_echo(peer_id: int, message: String) -> int:
	var nonce := randi()
	_pending_echoes[nonce] = {
		"peer_id": peer_id,
		"message": message,
	}
	_rpc_echo.rpc_id(peer_id, message, nonce)
	return nonce


func _exit_tree() -> void:
	if is_active():
		_teardown_peer()
		_state = SessionState.IDLE


func _process(_delta: float) -> void:
	if _state != SessionState.CONNECTING or _peer == null:
		return

	if _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_on_connection_failed()
		return

	if Time.get_ticks_msec() - _connect_started_msec > CONNECT_TIMEOUT_MSEC:
		_on_connection_failed()


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

	if _peer != null:
		_peer.close()
		_peer = null

	multiplayer.multiplayer_peer = null


func _on_connected_to_server() -> void:
	if _state != SessionState.CONNECTING:
		return

	_state = SessionState.CONNECTED
	session_state_changed.emit()


func _on_connection_failed() -> void:
	if _state != SessionState.CONNECTING:
		return

	_teardown_peer()
	_state = SessionState.IDLE
	connection_failed.emit()
	session_state_changed.emit()


func _on_server_disconnected() -> void:
	if _state != SessionState.CONNECTED:
		return

	_teardown_peer()
	_state = SessionState.IDLE
	server_disconnected.emit()
	session_state_changed.emit()


func _on_peer_connected(peer_id: int) -> void:
	peer_connected.emit(peer_id)
	session_state_changed.emit()


func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected.emit(peer_id)
	session_state_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_echo(message: String, nonce: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_rpc_echo_reply.rpc_id(sender_id, message, nonce)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_echo_reply(message: String, nonce: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if not _pending_echoes.has(nonce):
		return

	var pending: Dictionary = _pending_echoes[nonce]
	if int(pending.get("peer_id", -1)) != sender_id:
		return
	if String(pending.get("message", "")) != message:
		return

	_pending_echoes.erase(nonce)
	echo_completed.emit(sender_id, message)
