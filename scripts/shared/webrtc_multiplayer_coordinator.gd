class_name WebRtcMultiplayerCoordinator
extends Node

signal multiplayer_peer_ready(peer: MultiplayerPeer, is_host: bool)
signal lobby_code_ready(lobby_code: String)
signal connection_failed(message: String)

var _signaling := WebRtcSignalingClient.new()
var _rtc_mp: WebRTCMultiplayerPeer = null
var _ice_servers: Array = []
var _lobby_sealed: bool = false


func start_host(signaling_url: String, room_code: String, ice_servers: Array) -> void:
	_begin(signaling_url, room_code, ice_servers, true)


func start_client(signaling_url: String, room_code: String, ice_servers: Array) -> void:
	_begin(signaling_url, room_code, ice_servers, false)


func stop() -> void:
	_signaling.close()
	if _rtc_mp != null:
		_rtc_mp.close()
		_rtc_mp = null
	_lobby_sealed = false


func get_lobby_code() -> String:
	return _signaling.lobby_code


func _begin(
		signaling_url: String,
		room_code: String,
		ice_servers: Array,
		is_host: bool,
) -> void:
	stop()
	_ice_servers = ice_servers
	_signaling.use_mesh = false
	_signaling.lobby_code = room_code if is_host else room_code.strip_edges()
	_bind_signaling_signals()
	_signaling.connect_to_url(signaling_url)


func _bind_signaling_signals() -> void:
	if not _signaling.connected_to_signaling.is_connected(_on_connected_to_signaling):
		_signaling.connected_to_signaling.connect(_on_connected_to_signaling)
	if not _signaling.disconnected_from_signaling.is_connected(_on_disconnected_from_signaling):
		_signaling.disconnected_from_signaling.connect(_on_disconnected_from_signaling)
	if not _signaling.lobby_joined.is_connected(_on_lobby_joined):
		_signaling.lobby_joined.connect(_on_lobby_joined)
	if not _signaling.lobby_sealed.is_connected(_on_lobby_sealed):
		_signaling.lobby_sealed.connect(_on_lobby_sealed)
	if not _signaling.peer_connected.is_connected(_on_peer_connected):
		_signaling.peer_connected.connect(_on_peer_connected)
	if not _signaling.peer_disconnected.is_connected(_on_peer_disconnected):
		_signaling.peer_disconnected.connect(_on_peer_disconnected)
	if not _signaling.offer_received.is_connected(_on_offer_received):
		_signaling.offer_received.connect(_on_offer_received)
	if not _signaling.answer_received.is_connected(_on_answer_received):
		_signaling.answer_received.connect(_on_answer_received)
	if not _signaling.candidate_received.is_connected(_on_candidate_received):
		_signaling.candidate_received.connect(_on_candidate_received)


func _process(_delta: float) -> void:
	_signaling.poll()
	poll_peer_connections()


func poll_peer_connections() -> void:
	if _rtc_mp == null:
		return

	for peer_id in range(1, MatchConstants.MAX_PEERS + 1):
		if not _rtc_mp.has_peer(peer_id):
			continue
		var peer_data: Dictionary = _rtc_mp.get_peer(peer_id)
		var connection: WebRTCPeerConnection = peer_data.get("connection")
		if connection != null:
			connection.poll()


func _exit_tree() -> void:
	stop()


func _on_connected_to_signaling(assigned_id: int, use_mesh: bool) -> void:
	_rtc_mp = WebRTCMultiplayerPeer.new()
	if use_mesh:
		_rtc_mp.create_mesh(assigned_id)
	elif assigned_id == 1:
		_rtc_mp.create_server()
	else:
		_rtc_mp.create_client(assigned_id)

	multiplayer_peer_ready.emit(_rtc_mp, assigned_id == 1)


func _on_lobby_joined(lobby_code: String) -> void:
	_signaling.lobby_code = lobby_code
	lobby_code_ready.emit(lobby_code)


func _on_lobby_sealed() -> void:
	_lobby_sealed = true


func _on_disconnected_from_signaling(code: int, reason: String) -> void:
	if _lobby_sealed:
		return
	connection_failed.emit("Signaling disconnected (%d: %s)." % [code, reason])


func _on_peer_connected(peer_id: int) -> void:
	_create_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if _rtc_mp != null and _rtc_mp.has_peer(peer_id):
		_rtc_mp.remove_peer(peer_id)


func _create_peer(peer_id: int) -> void:
	if _rtc_mp == null:
		return

	var peer := WebRTCPeerConnection.new()
	peer.initialize({"iceServers": _ice_servers})
	peer.session_description_created.connect(_on_session_description_created.bind(peer_id))
	peer.ice_candidate_created.connect(_on_ice_candidate_created.bind(peer_id))
	_rtc_mp.add_peer(peer, peer_id)
	if peer_id < _rtc_mp.get_unique_id():
		peer.create_offer()


func _on_session_description_created(type: String, data: String, peer_id: int) -> void:
	if _rtc_mp == null or not _rtc_mp.has_peer(peer_id):
		return

	_rtc_mp.get_peer(peer_id).connection.set_local_description(type, data)
	if type == "offer":
		_signaling.send_offer(peer_id, data)
	else:
		_signaling.send_answer(peer_id, data)


func _on_ice_candidate_created(
		mid_name: String,
		index_name: int,
		sdp_name: String,
		peer_id: int,
) -> void:
	_signaling.send_candidate(peer_id, mid_name, index_name, sdp_name)


func _on_offer_received(peer_id: int, offer: String) -> void:
	if _rtc_mp != null and _rtc_mp.has_peer(peer_id):
		_rtc_mp.get_peer(peer_id).connection.set_remote_description("offer", offer)


func _on_answer_received(peer_id: int, answer: String) -> void:
	if _rtc_mp != null and _rtc_mp.has_peer(peer_id):
		_rtc_mp.get_peer(peer_id).connection.set_remote_description("answer", answer)


func _on_candidate_received(peer_id: int, mid: String, index: int, sdp: String) -> void:
	if _rtc_mp != null and _rtc_mp.has_peer(peer_id):
		_rtc_mp.get_peer(peer_id).connection.add_ice_candidate(mid, index, sdp)
