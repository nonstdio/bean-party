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

var _peer: MultiplayerPeer = null
var _transport_adapter: TransportAdapter = TransportAdapterRegistry.create(
	TransportAdapterRegistry.default_transport_id(),
)
var _injected_transport_adapter: TransportAdapter = null
var _state: SessionState = SessionState.IDLE
var _pending_echoes: Dictionary = {}
var _ping_ms_by_peer_id: Dictionary = {}
var _connect_started_msec: int = 0
var _ping_accumulator: float = 0.0
var _last_join_address: String = ""
var _last_join_port: int = MatchConstants.DEFAULT_ENET_PORT
var _last_join_room_code: String = ""
var _webrtc_coordinator: WebRtcMultiplayerCoordinator = null

const CONNECT_TIMEOUT_MSEC := 5000
const WEBRTC_CONNECT_TIMEOUT_MSEC := 20000
const PING_INTERVAL_SEC := 1.0


func get_session_state() -> SessionState:
	return _state


func is_active() -> bool:
	return _state != SessionState.IDLE


func is_session_established() -> bool:
	return _state == SessionState.CONNECTED or _state == SessionState.HOSTING


func is_server() -> bool:
	return _state == SessionState.HOSTING


func get_transport_id() -> String:
	if _transport_adapter == null:
		return ""
	return _transport_adapter.get_transport_id()


func set_transport_adapter(adapter: TransportAdapter) -> void:
	if is_active():
		return
	_injected_transport_adapter = adapter
	if adapter != null:
		_transport_adapter = adapter


func is_client_rpc_ready() -> bool:
	if not is_session_established() or is_server():
		return false
	return is_peer_route_ready(1)


func is_peer_route_ready(peer_id: int) -> bool:
	if not is_session_established() or _peer == null:
		return false
	if multiplayer.multiplayer_peer == null:
		return false
	if (
		multiplayer.multiplayer_peer.get_connection_status()
		!= MultiplayerPeer.CONNECTION_CONNECTED
	):
		return false
	return peer_id in multiplayer.get_peers()


func host_with_transport(transport_id: String, options: Dictionary = {}) -> Error:
	disconnect_session()

	var adapter := _resolve_transport_adapter(transport_id)
	if adapter == null:
		return ERR_UNAVAILABLE

	if transport_id == TransportAdapterRegistry.TRANSPORT_WEBRTC:
		_transport_adapter = adapter
		var error := _begin_webrtc_session(options, true)
		if error != OK:
			_reset_transport_adapter()
			return error
		return OK

	var peer := adapter.create_server_peer(options)
	if peer == null:
		_reset_transport_adapter()
		return ERR_CANT_CREATE

	_transport_adapter = adapter
	_peer = peer
	multiplayer.multiplayer_peer = _peer
	_state = SessionState.HOSTING
	_bind_multiplayer_signals()
	session_state_changed.emit()
	return OK


func host(port: int = MatchConstants.DEFAULT_ENET_PORT) -> Error:
	return host_with_transport(TransportAdapterRegistry.default_transport_id(), {"port": port})


func join(
		address: String,
		port: int = MatchConstants.DEFAULT_ENET_PORT,
) -> Error:
	return join_with_transport(
		TransportAdapterRegistry.default_transport_id(),
		{"address": address, "port": port},
	)


func join_with_transport(transport_id: String, options: Dictionary = {}) -> Error:
	disconnect_session()

	var adapter := _resolve_transport_adapter(transport_id)
	if adapter == null:
		return ERR_UNAVAILABLE

	_last_join_address = String(options.get("address", options.get("signaling_url", "")))
	_last_join_port = int(options.get("port", MatchConstants.DEFAULT_ENET_PORT))
	_last_join_room_code = String(options.get("room_code", ""))

	if transport_id == TransportAdapterRegistry.TRANSPORT_WEBRTC:
		_transport_adapter = adapter
		var error := _begin_webrtc_session(options, false)
		if error != OK:
			_reset_transport_adapter()
			return error
		return OK

	var peer := adapter.create_client_peer(options)
	if peer == null:
		_reset_transport_adapter()
		return ERR_CANT_CREATE

	_transport_adapter = adapter
	_peer = peer
	multiplayer.multiplayer_peer = _peer
	_state = SessionState.CONNECTING
	_connect_started_msec = Time.get_ticks_msec()
	_bind_multiplayer_signals()
	session_state_changed.emit()
	return OK


func disconnect_session() -> void:
	if (
		is_server()
		and is_session_established()
		and not get_remote_peer_ids().is_empty()
	):
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


func get_last_join_address() -> String:
	return _last_join_address


func get_last_join_port() -> int:
	return _last_join_port


func get_last_join_room_code() -> String:
	return _last_join_room_code


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
	if not is_active():
		return
	_teardown_peer()
	_state = SessionState.IDLE
	_reset_transport_adapter()
	session_state_changed.emit()


func _process(delta: float) -> void:
	if _state == SessionState.CONNECTING:
		var timeout_msec := _connect_timeout_msec()
		if Time.get_ticks_msec() - _connect_started_msec > timeout_msec:
			_on_connection_failed()
			return

		if _peer != null and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			_on_connection_failed()
			return

		if (
			get_transport_id() == TransportAdapterRegistry.TRANSPORT_WEBRTC
			and not is_server()
			and _is_webrtc_client_transport_ready()
		):
			_on_connected_to_server()
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
	_teardown_webrtc_coordinator()

	if _peer != null:
		_peer.close()
		_peer = null

	multiplayer.multiplayer_peer = null


func _teardown_webrtc_coordinator() -> void:
	if _webrtc_coordinator == null:
		return

	if _webrtc_coordinator.multiplayer_peer_ready.is_connected(_on_webrtc_peer_ready):
		_webrtc_coordinator.multiplayer_peer_ready.disconnect(_on_webrtc_peer_ready)
	if _webrtc_coordinator.connection_failed.is_connected(_on_webrtc_connection_failed):
		_webrtc_coordinator.connection_failed.disconnect(_on_webrtc_connection_failed)
	if _webrtc_coordinator.lobby_code_ready.is_connected(_on_webrtc_lobby_code_ready):
		_webrtc_coordinator.lobby_code_ready.disconnect(_on_webrtc_lobby_code_ready)

	_webrtc_coordinator.stop()
	_webrtc_coordinator.queue_free()
	_webrtc_coordinator = null


func _connect_timeout_msec() -> int:
	if get_transport_id() == TransportAdapterRegistry.TRANSPORT_WEBRTC:
		return WEBRTC_CONNECT_TIMEOUT_MSEC
	return CONNECT_TIMEOUT_MSEC


func _begin_webrtc_session(options: Dictionary, is_host: bool) -> Error:
	if not WebRtcAvailability.is_extension_loaded():
		return ERR_CANT_CREATE

	var normalized := WebRtcTransportAdapter.normalize_options(options)
	var signaling_url := String(normalized.get("signaling_url", ""))
	var room_code := String(normalized.get("room_code", ""))
	var ice_servers: Array = normalized.get("ice_servers", [])

	if signaling_url == "":
		return ERR_INVALID_PARAMETER
	if not is_host and room_code.strip_edges() == "":
		return ERR_INVALID_PARAMETER

	_last_join_address = signaling_url
	_last_join_room_code = room_code

	_webrtc_coordinator = WebRtcMultiplayerCoordinator.new()
	add_child(_webrtc_coordinator)
	_webrtc_coordinator.multiplayer_peer_ready.connect(_on_webrtc_peer_ready)
	_webrtc_coordinator.connection_failed.connect(_on_webrtc_connection_failed)
	_webrtc_coordinator.lobby_code_ready.connect(_on_webrtc_lobby_code_ready)

	_state = SessionState.CONNECTING
	_connect_started_msec = Time.get_ticks_msec()
	session_state_changed.emit()

	if is_host:
		_webrtc_coordinator.start_host(signaling_url, room_code, ice_servers)
	else:
		_webrtc_coordinator.start_client(signaling_url, room_code, ice_servers)

	return OK


func _on_webrtc_peer_ready(peer: MultiplayerPeer, is_host: bool) -> void:
	_peer = peer
	multiplayer.multiplayer_peer = _peer
	_bind_multiplayer_signals()

	if is_host:
		_state = SessionState.HOSTING
		session_state_changed.emit()
		_ping_accumulator = PING_INTERVAL_SEC
		return

	# Wait for ICE/channel setup; _process will promote to CONNECTED when ready.


func _is_webrtc_client_transport_ready() -> bool:
	return is_client_rpc_ready()


func _on_webrtc_lobby_code_ready(lobby_code: String) -> void:
	_last_join_room_code = lobby_code
	session_state_changed.emit()


func _on_webrtc_connection_failed(message: String) -> void:
	if _state != SessionState.CONNECTING:
		return

	_end_session(SessionEndReason.CONNECTION_FAILED, message)
	connection_failed.emit()


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
	_reset_transport_adapter()
	session_state_changed.emit()


func _resolve_transport_adapter(transport_id: String) -> TransportAdapter:
	if _injected_transport_adapter != null:
		if _injected_transport_adapter.get_transport_id() != transport_id:
			push_warning(
				"Injected transport adapter id '%s' does not match requested '%s'."
				% [_injected_transport_adapter.get_transport_id(), transport_id]
			)
		return _injected_transport_adapter
	return TransportAdapterRegistry.create(transport_id)


func _reset_transport_adapter() -> void:
	_transport_adapter = TransportAdapterRegistry.create(
		TransportAdapterRegistry.default_transport_id(),
	)


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


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_session_ended(reason: int, message: String) -> void:
	if _state != SessionState.CONNECTED:
		return
	_end_session(reason as SessionEndReason, message)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_echo(message: String, nonce: int) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_rpc_echo_reply.rpc_id(sender_id, message, nonce)


@rpc("any_peer", "call_remote", "reliable", 0)
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
