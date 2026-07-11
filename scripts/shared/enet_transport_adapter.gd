class_name EnetTransportAdapter
extends TransportAdapter


func get_transport_id() -> String:
	return TransportAdapterRegistry.TRANSPORT_ENET


func create_server_peer(options: Dictionary) -> MultiplayerPeer:
	var port: int = int(options.get("port", MatchConstants.DEFAULT_ENET_PORT))
	return create_enet_server_peer(port)


func create_client_peer(options: Dictionary) -> MultiplayerPeer:
	var address := String(options.get("address", "127.0.0.1"))
	var port: int = int(options.get("port", MatchConstants.DEFAULT_ENET_PORT))
	return create_enet_client_peer(address, port)


func describe_capabilities() -> Dictionary:
	return {
		"supports_direct_address_join": true,
		"supports_steam_lobby_join": false,
		"supports_room_code_join": false,
		"supports_transfer_channels": true,
		"max_transfer_channels": 4,
		"notes": "Debug/LAN transport for milestones 3–10.",
	}


static func create_enet_server_peer(port: int) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MatchConstants.MAX_REMOTE_NETWORK_CLIENTS)
	if error != OK:
		peer.close()
		return null
	return peer


static func create_enet_client_peer(address: String, port: int) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		peer.close()
		return null
	return peer
