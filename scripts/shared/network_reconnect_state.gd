class_name NetworkReconnectState
extends RefCounted

static var pending_player_id: String = ""
static var pending_match_epoch: int = -1


static func remember(player_id: String, match_epoch: int) -> void:
	if player_id == "":
		return
	pending_player_id = player_id
	pending_match_epoch = match_epoch


static func clear() -> void:
	pending_player_id = ""
	pending_match_epoch = -1


static func has_pending() -> bool:
	return pending_player_id != ""
