extends GutTest

var _test_port: int


func before_each() -> void:
	_test_port = 19000 + int(Time.get_ticks_msec() % 1000)


func test_registry_creates_enet_adapter() -> void:
	var adapter := TransportAdapterRegistry.create(TransportAdapterRegistry.TRANSPORT_ENET)
	assert_not_null(adapter)
	assert_eq(adapter.get_transport_id(), TransportAdapterRegistry.TRANSPORT_ENET)


func test_registry_creates_steam_stub_adapter() -> void:
	var adapter := TransportAdapterRegistry.create(TransportAdapterRegistry.TRANSPORT_STEAM)
	assert_not_null(adapter)
	assert_eq(adapter.get_transport_id(), TransportAdapterRegistry.TRANSPORT_STEAM)
	assert_null(adapter.create_server_peer({}))


func test_enet_adapter_creates_server_and_client_peers() -> void:
	var adapter := EnetTransportAdapter.new()
	var server := adapter.create_server_peer({"port": _test_port})
	var client := adapter.create_client_peer({"address": "127.0.0.1", "port": _test_port})
	assert_not_null(server)
	assert_not_null(client)
	server.close()
	client.close()


func test_enet_static_helpers_remain_available() -> void:
	var server := EnetTransportAdapter.create_enet_server_peer(_test_port)
	assert_not_null(server)
	server.close()


func test_match_session_host_with_enet_transport() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)
	assert_eq(
		session.host_with_transport(
			TransportAdapterRegistry.TRANSPORT_ENET,
			{"port": _test_port},
		),
		OK,
	)
	assert_eq(session.get_transport_id(), TransportAdapterRegistry.TRANSPORT_ENET)
	assert_eq(session.get_session_state(), MatchSession.SessionState.HOSTING)


func test_match_session_steam_transport_fails_closed() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)
	assert_eq(
		session.host_with_transport(TransportAdapterRegistry.TRANSPORT_STEAM, {}),
		ERR_CANT_CREATE,
	)
	assert_eq(session.get_session_state(), MatchSession.SessionState.IDLE)


func test_lane_channel_map_matches_architecture_lanes() -> void:
	assert_eq(
		TransportMessageLanes.enet_channel_for_lane(TransportMessageLanes.Lane.SESSION_CONTROL),
		0,
	)
	assert_eq(
		TransportMessageLanes.enet_channel_for_lane(TransportMessageLanes.Lane.PLAYER_INPUT),
		1,
	)
	assert_eq(
		TransportMessageLanes.enet_channel_for_lane(TransportMessageLanes.Lane.WORLD_SNAPSHOT),
		2,
	)
