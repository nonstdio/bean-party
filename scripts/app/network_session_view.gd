extends VBoxContainer

enum TransportMode {
	ENET,
	WEBRTC,
}

@onready var _match_session: MatchSession = %MatchSession
@onready var _transport_field: OptionButton = %TransportField
@onready var _enet_fields: HBoxContainer = %EnetFields
@onready var _webrtc_fields: HBoxContainer = %WebRtcFields
@onready var _address_field: LineEdit = %AddressField
@onready var _port_field: LineEdit = %PortField
@onready var _signaling_url_field: LineEdit = %SignalingUrlField
@onready var _room_code_field: LineEdit = %RoomCodeField
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _disconnect_button: Button = %DisconnectButton
@onready var _echo_button: Button = %EchoButton
@onready var _status_label: Label = %NetworkStatusLabel
@onready var _peers_label: Label = %PeersLabel

var _last_echo_message := ""
var _online_config_probe: Dictionary = {}


func _ready() -> void:
	_transport_field.add_item("ENet (LAN)", TransportMode.ENET)
	_transport_field.add_item("WebRTC (internet)", TransportMode.WEBRTC)
	_port_field.text = str(MatchConstants.DEFAULT_ENET_PORT)
	_address_field.text = "127.0.0.1"
	var online_defaults := OnlineServiceConfig.resolve({})
	if String(online_defaults.get("signaling_url", "")) != "":
		_signaling_url_field.text = String(online_defaults.get("signaling_url"))
	elif OnlineServiceConfig.is_development_mode():
		_signaling_url_field.text = MatchConstants.DEFAULT_WEBRTC_SIGNALING_URL
	_transport_field.item_selected.connect(_on_transport_selected)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_disconnect_button.pressed.connect(_on_disconnect_pressed)
	_echo_button.pressed.connect(_on_echo_pressed)
	_match_session.session_state_changed.connect(_refresh)
	_match_session.connection_failed.connect(_on_connection_failed)
	_match_session.server_disconnected.connect(_on_server_disconnected)
	_match_session.session_ended.connect(_on_session_ended)
	_match_session.echo_completed.connect(_on_echo_completed)
	_on_transport_selected(0)
	_apply_pending_reconnect_target()
	_refresh()


func _apply_pending_reconnect_target() -> void:
	if not NetworkReconnectState.has_pending():
		return

	if NetworkReconnectState.pending_transport_id == TransportAdapterRegistry.TRANSPORT_WEBRTC:
		_select_transport_mode(TransportMode.WEBRTC)
		if NetworkReconnectState.pending_signaling_url != "":
			_signaling_url_field.text = NetworkReconnectState.pending_signaling_url
		if NetworkReconnectState.pending_room_code != "":
			_room_code_field.text = NetworkReconnectState.pending_room_code
		return

	_select_transport_mode(TransportMode.ENET)
	if NetworkReconnectState.pending_host_address != "":
		_address_field.text = NetworkReconnectState.pending_host_address
	if NetworkReconnectState.pending_host_port > 0:
		_port_field.text = str(NetworkReconnectState.pending_host_port)


func _select_transport_mode(mode: TransportMode) -> void:
	for index in range(_transport_field.item_count):
		if _transport_field.get_item_id(index) == mode:
			_transport_field.select(index)
			_on_transport_selected(index)
			return


func _on_transport_selected(_index: int) -> void:
	var mode := _selected_transport_mode()
	_enet_fields.visible = mode == TransportMode.ENET
	_webrtc_fields.visible = mode == TransportMode.WEBRTC


func _on_host_pressed() -> void:
	if _selected_transport_mode() == TransportMode.WEBRTC:
		_host_webrtc()
		return

	var port := _read_port()
	if port < 0:
		return
	var error := _match_session.host(port)
	_status_label.text = (
		"Hosting on port %d." % port if error == OK else "Host failed (%d)." % error
	)
	_refresh()


func _host_webrtc() -> void:
	if OnlineServiceConfig.is_release_online_blocked(_online_config_probe):
		_status_label.text = OnlineServiceConfig.unconfigured_message()
		return
	var signaling_url := _read_signaling_url()
	if signaling_url == "":
		return
	var error := _match_session.host_with_transport(
		TransportAdapterRegistry.TRANSPORT_WEBRTC,
		{"signaling_url": signaling_url},
	)
	if error == OK:
		_status_label.text = "Connecting to signaling and creating room..."
	elif error == ERR_UNCONFIGURED:
		_status_label.text = OnlineServiceConfig.unconfigured_message()
	elif error == ERR_CANT_CREATE:
		_status_label.text = "WebRTC host failed. Install webrtc-native (see docs/guides/webrtc-setup.md)."
	else:
		_status_label.text = "WebRTC host failed (%d)." % error
	_refresh()


func _on_join_pressed() -> void:
	if _selected_transport_mode() == TransportMode.WEBRTC:
		_join_webrtc()
		return

	var port := _read_port()
	if port < 0:
		return
	var address := _address_field.text.strip_edges()
	if address == "":
		_status_label.text = "Enter an address to join."
		return
	var error := _match_session.join(address, port)
	_status_label.text = (
		"Joining %s:%d..." % [address, port]
		if error == OK
		else "Join failed (%d)." % error
	)
	_refresh()


func _join_webrtc() -> void:
	if OnlineServiceConfig.is_release_online_blocked(_online_config_probe):
		_status_label.text = OnlineServiceConfig.unconfigured_message()
		return
	var signaling_url := _read_signaling_url()
	if signaling_url == "":
		return
	var room_code := _room_code_field.text.strip_edges()
	if room_code == "":
		_status_label.text = "Enter a room code to join."
		return
	var error := _match_session.join_with_transport(
		TransportAdapterRegistry.TRANSPORT_WEBRTC,
		{
			"signaling_url": signaling_url,
			"room_code": room_code,
		},
	)
	if error == OK:
		_status_label.text = "Joining room %s..." % room_code
	elif error == ERR_UNCONFIGURED:
		_status_label.text = OnlineServiceConfig.unconfigured_message()
	elif error == ERR_CANT_CREATE:
		_status_label.text = "WebRTC join failed. Install webrtc-native (see docs/guides/webrtc-setup.md)."
	else:
		_status_label.text = "WebRTC join failed (%d)." % error
	_refresh()


func _on_session_ended(reason: MatchSession.SessionEndReason, message: String) -> void:
	_status_label.text = message
	_apply_pending_reconnect_target()
	_refresh()


func _on_disconnect_pressed() -> void:
	_match_session.disconnect_session()
	_apply_pending_reconnect_target()
	_refresh()


func _on_connection_failed() -> void:
	_apply_pending_reconnect_target()
	_refresh()


func _on_server_disconnected() -> void:
	_refresh()


func _on_echo_pressed() -> void:
	var remote_peers := _match_session.get_remote_peer_ids()
	if remote_peers.is_empty():
		_status_label.text = "No remote peers available for echo."
		return

	_last_echo_message = "echo-%d" % Time.get_ticks_msec()
	_match_session.send_echo(remote_peers[0], _last_echo_message)
	_status_label.text = "Echo sent to peer %d..." % remote_peers[0]


func _on_echo_completed(from_peer_id: int, message: String) -> void:
	if message == _last_echo_message:
		_status_label.text = "Echo OK from peer %d." % from_peer_id
	else:
		_status_label.text = "Echo mismatch from peer %d." % from_peer_id
	_refresh()


func _refresh() -> void:
	var state := _match_session.get_session_state()
	var in_session := state != MatchSession.SessionState.IDLE
	_host_button.disabled = in_session
	_join_button.disabled = in_session
	_disconnect_button.disabled = not in_session
	_transport_field.disabled = in_session
	_echo_button.disabled = (
		not _match_session.is_session_established()
		or _match_session.get_remote_peer_ids().is_empty()
	)

	match state:
		MatchSession.SessionState.CONNECTING:
			_peers_label.text = "Peers: connecting..."
			if _match_session.get_transport_id() == TransportAdapterRegistry.TRANSPORT_WEBRTC:
				var room_code := _match_session.get_last_join_room_code()
				if room_code != "":
					_room_code_field.text = room_code
					_status_label.text = "Room code: %s (share with friends)" % room_code
		MatchSession.SessionState.CONNECTED:
			var peer_ids := _match_session.get_session_peer_ids()
			_peers_label.text = "Peers (client): %s" % ", ".join(peer_ids)
			if not _is_terminal_status():
				_status_label.text = _connected_status_text()
		MatchSession.SessionState.HOSTING:
			var peer_ids := _match_session.get_session_peer_ids()
			_peers_label.text = "Peers (host): %s" % ", ".join(peer_ids)
			if not _is_terminal_status():
				_status_label.text = _hosting_status_text()
		_:
			_peers_label.text = "Peers: none"


func _connected_status_text() -> String:
	if _match_session.get_transport_id() == TransportAdapterRegistry.TRANSPORT_WEBRTC:
		var diagnostic := _match_session.get_webrtc_connectivity_diagnostic()
		if diagnostic.begins_with("relay_unavailable"):
			return (
				"Connected (WebRTC room %s). Relay service unavailable; STUN-only attempt."
				% _match_session.get_last_join_room_code()
			)
		return "Connected (WebRTC room %s)." % _match_session.get_last_join_room_code()
	return "Connected as client."


func _hosting_status_text() -> String:
	if _match_session.get_transport_id() == TransportAdapterRegistry.TRANSPORT_WEBRTC:
		var room_code := _match_session.get_last_join_room_code()
		if room_code != "":
			_room_code_field.text = room_code
		return "Hosting WebRTC room %s." % room_code

	var port := _read_port(true)
	if port > 0:
		return "Hosting on port %d." % port
	return "Hosting."


func _is_terminal_status() -> bool:
	return (
		_status_label.text.begins_with("Connection failed")
		or _status_label.text == "Host left the match."
		or _status_label.text == "Session disconnected."
		or _status_label.text.begins_with("WebRTC host failed")
		or _status_label.text.begins_with("WebRTC join failed")
		or _status_label.text.begins_with("Signaling disconnected")
	)


func _selected_transport_mode() -> TransportMode:
	return _transport_field.get_selected_id() as TransportMode


func _read_signaling_url() -> String:
	var url := _signaling_url_field.text.strip_edges()
	if url == "":
		_status_label.text = "Enter a signaling server URL."
		return ""
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		_status_label.text = "Signaling URL must start with ws:// or wss://."
		return ""
	return url


func _read_port(quiet := false) -> int:
	var text := _port_field.text.strip_edges()
	if not text.is_valid_int():
		if not quiet:
			_status_label.text = "Port must be a number."
		return -1

	var port := int(text)
	if port < 1 or port > 65535:
		if not quiet:
			_status_label.text = "Port must be between 1 and 65535."
		return -1
	return port
