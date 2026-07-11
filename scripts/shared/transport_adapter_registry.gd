class_name TransportAdapterRegistry
extends RefCounted

const TRANSPORT_ENET := "enet"
const TRANSPORT_STEAM := "steam"
const TRANSPORT_WEBRTC := "webrtc"

static func create(transport_id: String) -> TransportAdapter:
	match transport_id:
		TRANSPORT_ENET:
			return EnetTransportAdapter.new()
		TRANSPORT_STEAM:
			return SteamTransportAdapter.new()
		TRANSPORT_WEBRTC:
			return WebRtcTransportAdapter.new()
		_:
			return null


static func default_transport_id() -> String:
	return TRANSPORT_ENET
