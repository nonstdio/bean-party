class_name SteamTransportAdapter
extends TransportAdapter

const INVESTIGATION_DOC := "res://docs/research/steam-transport-investigation.md"


func get_transport_id() -> String:
	return TransportAdapterRegistry.TRANSPORT_STEAM


func create_server_peer(_options: Dictionary) -> MultiplayerPeer:
	push_warning(
		"Steam transport is not implemented. See %s for milestone 11 investigation results."
		% INVESTIGATION_DOC
	)
	return null


func create_client_peer(_options: Dictionary) -> MultiplayerPeer:
	return create_server_peer(_options)


func describe_capabilities() -> Dictionary:
	return {
		"supports_direct_address_join": false,
		"supports_steam_lobby_join": true,
		"supports_room_code_join": false,
		"supports_transfer_channels": false,
		"max_transfer_channels": 1,
		"notes": "Stub adapter only. Candidate integration is GodotSteam MultiplayerPeer after legal review.",
	}
