extends VBoxContainer

@onready var _match_session: MatchSession = %MatchSession
@onready var _address_field: LineEdit = %AddressField
@onready var _port_field: LineEdit = %PortField
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _disconnect_button: Button = %DisconnectButton
@onready var _echo_button: Button = %EchoButton
@onready var _status_label: Label = %NetworkStatusLabel
@onready var _peers_label: Label = %PeersLabel

var _last_echo_message := ""


func _ready() -> void:
	_port_field.text = str(MatchConstants.DEFAULT_ENET_PORT)
	_address_field.text = "127.0.0.1"
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_disconnect_button.pressed.connect(_on_disconnect_pressed)
	_echo_button.pressed.connect(_on_echo_pressed)
	_match_session.session_state_changed.connect(_refresh)
	_match_session.connection_failed.connect(_on_connection_failed)
	_match_session.server_disconnected.connect(_on_server_disconnected)
	_match_session.session_ended.connect(_on_session_ended)
	_match_session.echo_completed.connect(_on_echo_completed)
	_refresh()


func _on_host_pressed() -> void:
	var port := _read_port()
	if port < 0:
		return
	var error := _match_session.host(port)
	_status_label.text = (
		"Hosting on port %d." % port if error == OK else "Host failed (%d)." % error
	)
	_refresh()


func _on_join_pressed() -> void:
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


func _on_session_ended(reason: MatchSession.SessionEndReason, message: String) -> void:
	_status_label.text = message
	_refresh()


func _on_disconnect_pressed() -> void:
	_match_session.disconnect_session()
	_refresh()


func _on_connection_failed() -> void:
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
	_echo_button.disabled = (
		not _match_session.is_session_established()
		or _match_session.get_remote_peer_ids().is_empty()
	)

	match state:
		MatchSession.SessionState.CONNECTING:
			_peers_label.text = "Peers: connecting..."
		MatchSession.SessionState.CONNECTED:
			var peer_ids := _match_session.get_session_peer_ids()
			_peers_label.text = "Peers (client): %s" % ", ".join(peer_ids)
			if not _is_terminal_status():
				_status_label.text = "Connected as client."
		MatchSession.SessionState.HOSTING:
			var peer_ids := _match_session.get_session_peer_ids()
			_peers_label.text = "Peers (host): %s" % ", ".join(peer_ids)
			if not _is_terminal_status():
				var port := _read_port(true)
				if port > 0:
					_status_label.text = "Hosting on port %d." % port
		_:
			_peers_label.text = "Peers: none"


func _is_terminal_status() -> bool:
	return (
		_status_label.text == "Connection failed."
		or _status_label.text == "Host left the match."
		or _status_label.text == "Session disconnected."
	)


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
