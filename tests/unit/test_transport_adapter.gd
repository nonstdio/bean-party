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


func test_registry_creates_webrtc_adapter() -> void:
	var adapter := TransportAdapterRegistry.create(TransportAdapterRegistry.TRANSPORT_WEBRTC)
	assert_not_null(adapter)
	assert_eq(adapter.get_transport_id(), TransportAdapterRegistry.TRANSPORT_WEBRTC)
	assert_true(adapter.describe_capabilities().get("supports_room_code_join", false))


func test_webrtc_adapter_normalizes_options() -> void:
	var normalized := WebRtcTransportAdapter.normalize_options({
		"signaling_url": "ws://example.test:9080",
		"room_code": "abc123",
	})
	assert_eq(normalized.get("signaling_url"), "ws://example.test:9080")
	assert_eq(normalized.get("room_code"), "abc123")
	assert_false((normalized.get("ice_servers") as Array).is_empty())


func test_match_session_webrtc_join_requires_room_code() -> void:
	if not WebRtcAvailability.is_extension_loaded():
		pass("Skipping WebRTC join validation without webrtc-native.")
		return

	var session := MatchSession.new()
	add_child_autofree(session)
	assert_eq(
		session.join_with_transport(
			TransportAdapterRegistry.TRANSPORT_WEBRTC,
			{"signaling_url": "ws://127.0.0.1:9080"},
		),
		ERR_INVALID_PARAMETER,
	)


func test_match_session_webrtc_fails_without_extension() -> void:
	if WebRtcAvailability.is_extension_loaded():
		pass("Skipping fail-closed test because webrtc-native is installed.")
		return

	var session := MatchSession.new()
	add_child_autofree(session)
	assert_eq(
		session.host_with_transport(
			TransportAdapterRegistry.TRANSPORT_WEBRTC,
			{"signaling_url": "ws://127.0.0.1:9080"},
		),
		ERR_CANT_CREATE,
	)
	assert_eq(session.get_session_state(), MatchSession.SessionState.IDLE)


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
	assert_eq(
		TransportMessageLanes.webrtc_channel_for_lane(TransportMessageLanes.Lane.SESSION_CONTROL),
		0,
	)
	assert_eq(
		TransportMessageLanes.webrtc_channel_for_lane(TransportMessageLanes.Lane.PLAYER_INPUT),
		1,
	)
	assert_eq(
		TransportMessageLanes.webrtc_channel_for_lane(TransportMessageLanes.Lane.COSMETIC),
		2,
	)
