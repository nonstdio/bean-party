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


func _on_disconnect_pressed() -> void:
	_match_session.disconnect_session()
	_status_label.text = "Session disconnected."
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
	var active := _match_session.is_active()
	_host_button.disabled = active
	_join_button.disabled = active
	_disconnect_button.disabled = not active
	_echo_button.disabled = not active or _match_session.get_remote_peer_ids().is_empty()

	if active:
		var role := "host" if _match_session.is_server() else "client"
		var peer_ids := _match_session.get_session_peer_ids()
		_peers_label.text = "Peers (%s): %s" % [role, ", ".join(peer_ids)]
		if _status_label.text == "Session disconnected.":
			_status_label.text = "Session active as %s." % role
	else:
		_peers_label.text = "Peers: none"


func _read_port() -> int:
	var text := _port_field.text.strip_edges()
	if not text.is_valid_int():
		_status_label.text = "Port must be a number."
		return -1

	var port := int(text)
	if port < 1 or port > 65535:
		_status_label.text = "Port must be between 1 and 65535."
		return -1
	return port
