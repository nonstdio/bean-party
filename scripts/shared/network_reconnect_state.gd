class_name NetworkReconnectState
extends RefCounted

static var pending_player_id: String = ""
static var pending_match_epoch: int = -1
static var pending_recovery_session_id: String = ""
static var pending_reconnect_token: String = ""
static var pending_host_address: String = ""
static var pending_host_port: int = -1


static func remember(
		player_id: String,
		match_epoch: int,
		recovery_session_id: String,
		reconnect_token: String,
		host_address: String,
		host_port: int,
) -> void:
	if player_id == "" or recovery_session_id == "" or reconnect_token == "":
		return
	pending_player_id = player_id
	pending_match_epoch = match_epoch
	pending_recovery_session_id = recovery_session_id
	pending_reconnect_token = reconnect_token
	pending_host_address = host_address
	pending_host_port = host_port


static func clear() -> void:
	pending_player_id = ""
	pending_match_epoch = -1
	pending_recovery_session_id = ""
	pending_reconnect_token = ""
	pending_host_address = ""
	pending_host_port = -1


static func has_pending() -> bool:
	return pending_player_id != ""


static func matches_target(
		recovery_session_id: String,
		host_address: String,
		host_port: int,
) -> bool:
	if not has_pending():
		return false
	if pending_recovery_session_id != recovery_session_id:
		return false
	if pending_host_address != host_address:
		return false
	return pending_host_port == host_port
