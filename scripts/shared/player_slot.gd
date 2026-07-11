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
