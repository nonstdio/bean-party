class_name EnetTransportAdapter
extends RefCounted

static func create_server_peer(port: int = MatchConstants.DEFAULT_ENET_PORT) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MatchConstants.MAX_REMOTE_NETWORK_CLIENTS)
	if error != OK:
		peer.close()
		return null
	return peer


static func create_client_peer(
		address: String,
		port: int = MatchConstants.DEFAULT_ENET_PORT,
) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		peer.close()
		return null
	return peer
