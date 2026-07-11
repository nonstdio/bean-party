class_name TransportAdapter
extends RefCounted

## Shared transport boundary for MatchSession. Board and minigames must not create peers.


func get_transport_id() -> String:
	push_error("TransportAdapter.get_transport_id() must be overridden.")
	return ""


func create_server_peer(options: Dictionary) -> MultiplayerPeer:
	push_error("TransportAdapter.create_server_peer() must be overridden.")
	return null


func create_client_peer(options: Dictionary) -> MultiplayerPeer:
	push_error("TransportAdapter.create_client_peer() must be overridden.")
	return null


func describe_capabilities() -> Dictionary:
	return {
		"supports_direct_address_join": false,
		"supports_steam_lobby_join": false,
		"supports_room_code_join": false,
		"supports_transfer_channels": false,
		"max_transfer_channels": 1,
		"notes": "",
	}
