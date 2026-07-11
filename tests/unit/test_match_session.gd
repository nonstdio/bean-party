extends GutTest

var _test_port: int


func before_each() -> void:
	_test_port = 17000 + int(Time.get_ticks_msec() % 1000)


func test_enet_transport_adapter_creates_server_peer() -> void:
	var peer := EnetTransportAdapter.create_server_peer(_test_port)
	assert_not_null(peer)
	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)
	peer.close()


func test_enet_transport_adapter_creates_client_peer() -> void:
	var server := EnetTransportAdapter.create_server_peer(_test_port)
	var client := EnetTransportAdapter.create_client_peer("127.0.0.1", _test_port)
	assert_not_null(server)
	assert_not_null(client)
	client.close()
	server.close()


func test_disconnect_clears_multiplayer_peer() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.host(_test_port), OK)
	assert_not_null(session.multiplayer.multiplayer_peer)

	session.disconnect_session()
	assert_null(session.multiplayer.multiplayer_peer)
	assert_false(session.is_active())


func test_host_assigns_server_role_and_local_peer_id() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.host(_test_port), OK)
	assert_true(session.is_server())
	assert_eq(session.multiplayer.get_unique_id(), 1)
	assert_eq(session.get_session_peer_ids(), [1])


func test_join_configures_client_peer() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.join("127.0.0.1", _test_port), OK)
	assert_false(session.is_server())
	assert_true(session.is_active())
	assert_not_null(session.multiplayer.multiplayer_peer)

	session.disconnect_session()
	assert_null(session.multiplayer.multiplayer_peer)
