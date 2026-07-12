class_name WebRtcTransportAdapter
extends TransportAdapter

const INVESTIGATION_DOC := "res://docs/research/webrtc-transport-investigation.md"


func get_transport_id() -> String:
	return TransportAdapterRegistry.TRANSPORT_WEBRTC


func create_server_peer(_options: Dictionary) -> MultiplayerPeer:
	if not WebRtcAvailability.is_extension_loaded():
		push_warning(
			"WebRTC transport requires the webrtc-native GDExtension. See %s." % INVESTIGATION_DOC
		)
		return null

	push_warning(
		"WebRTC transport uses async signaling via MatchSession. create_server_peer is not used directly."
	)
	return null


func create_client_peer(_options: Dictionary) -> MultiplayerPeer:
	return create_server_peer(_options)


func describe_capabilities() -> Dictionary:
	return {
		"supports_direct_address_join": false,
		"supports_steam_lobby_join": false,
		"supports_room_code_join": true,
		"supports_transfer_channels": WebRtcAvailability.is_extension_loaded(),
		"max_transfer_channels": 3,
		"notes":
		"Internet transport via WebRTC ICE. Requires webrtc-native and a signaling server.",
	}


static func normalize_options(options: Dictionary) -> Dictionary:
	return {
		"signaling_url":
		String(options.get("signaling_url", MatchConstants.DEFAULT_WEBRTC_SIGNALING_URL)),
		"room_code": String(options.get("room_code", "")),
		"ice_servers": default_ice_servers(options),
	}


static func default_ice_servers(options: Dictionary = {}) -> Array:
	return WebRtcIceConfig.resolve_ice_servers(options)
