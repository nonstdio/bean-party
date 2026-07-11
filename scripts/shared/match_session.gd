class_name MatchSession
extends Node

signal session_state_changed
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal echo_completed(from_peer_id: int, message: String)

var _peer: ENetMultiplayerPeer = null
var _pending_echoes: Dictionary = {}


func is_active() -> bool:
	return _peer != null


func is_server() -> bool:
	return is_active() and multiplayer.is_server()


func host(port: int = MatchConstants.DEFAULT_ENET_PORT) -> Error:
	disconnect_session()

	_peer = EnetTransportAdapter.create_server_peer(port)
	if _peer == null:
		return ERR_CANT_CREATE

	multiplayer.multiplayer_peer = _peer
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
	_bind_multiplayer_signals()
	session_state_changed.emit()
	return OK


func disconnect_session() -> void:
	_unbind_multiplayer_signals()
	_pending_echoes.clear()

	if _peer != null:
		_peer.close()
		_peer = null

	multiplayer.multiplayer_peer = null
	session_state_changed.emit()


func get_session_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	if not is_active():
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
	_pending_echoes[nonce] = message
	_rpc_echo.rpc_id(peer_id, message, nonce)
	return nonce


func _bind_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _unbind_multiplayer_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)


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
	if _pending_echoes.has(nonce):
		if String(_pending_echoes[nonce]) == message:
			_pending_echoes.erase(nonce)
			echo_completed.emit(sender_id, message)
		return

	echo_completed.emit(sender_id, message)
