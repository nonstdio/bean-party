class_name PlayerSlot
extends RefCounted

enum ConnectionStatus {
	CONNECTED,
	DISCONNECTED,
	MIGRATING,
	INACTIVE,
}

var player_id: String = ""
var owning_peer_id: int = MatchConstants.OFFLINE_PEER_ID
var local_player_index: int = -1
var display_name: String = ""
var team_id: Variant = null
var character_id: Variant = null
var ready: bool = false
var connection_status: ConnectionStatus = ConnectionStatus.CONNECTED
var slot_color: Color = Color.WHITE


static func create(
	player_id: String,
	owning_peer_id: int,
	local_player_index: int,
	display_name: String,
	slot_color: Color = Color.WHITE,
) -> PlayerSlot:
	var slot := PlayerSlot.new()
	slot.player_id = player_id
	slot.owning_peer_id = owning_peer_id
	slot.local_player_index = local_player_index
	slot.display_name = display_name
	slot.slot_color = slot_color
	return slot


func duplicate_slot() -> PlayerSlot:
	var copy := PlayerSlot.new()
	copy.player_id = player_id
	copy.owning_peer_id = owning_peer_id
	copy.local_player_index = local_player_index
	copy.display_name = display_name
	copy.team_id = team_id
	copy.character_id = character_id
	copy.ready = ready
	copy.connection_status = connection_status
	copy.slot_color = slot_color
	return copy


func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"connection_status": connection_status,
		"display_name": display_name,
		"local_player_index": local_player_index,
		"owning_peer_id": owning_peer_id,
		"player_id": player_id,
		"ready": ready,
		"slot_color": _color_to_array(slot_color),
		"team_id": team_id,
	}


static func from_dict(data: Dictionary) -> PlayerSlot:
	var slot := PlayerSlot.new()
	slot.player_id = String(data.get("player_id", ""))
	slot.owning_peer_id = int(data.get("owning_peer_id", MatchConstants.OFFLINE_PEER_ID))
	slot.local_player_index = int(data.get("local_player_index", -1))
	slot.display_name = String(data.get("display_name", ""))
	slot.team_id = data.get("team_id")
	slot.character_id = data.get("character_id")
	slot.ready = bool(data.get("ready", false))
	slot.connection_status = (
		int(data.get("connection_status", ConnectionStatus.CONNECTED)) as ConnectionStatus
	)
	slot.slot_color = _color_from_array(data.get("slot_color", []))
	return slot


static func _color_to_array(color: Color) -> Array:
	return [
		snappedf(color.r, 0.000001),
		snappedf(color.g, 0.000001),
		snappedf(color.b, 0.000001),
		snappedf(color.a, 0.000001),
	]


static func _color_from_array(values: Variant) -> Color:
	if values is Array and values.size() >= 4:
		return Color(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	return Color.WHITE
