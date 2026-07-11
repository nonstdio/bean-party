extends GutTest

var _test_port: int


func before_each() -> void:
	_test_port = 17000 + int(Time.get_ticks_msec() % 1000)


func test_enet_transport_adapter_creates_server_peer() -> void:
	var peer := EnetTransportAdapter.create_enet_server_peer(_test_port)
	assert_not_null(peer)
	assert_eq(peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)
	peer.close()


func test_enet_transport_adapter_creates_client_peer() -> void:
	var server := EnetTransportAdapter.create_enet_server_peer(_test_port)
	var client := EnetTransportAdapter.create_enet_client_peer("127.0.0.1", _test_port)
	assert_not_null(server)
	assert_not_null(client)
	client.close()
	server.close()


func test_network_peer_capacity_is_separate_from_logical_players() -> void:
	assert_eq(MatchConstants.MAX_REMOTE_NETWORK_CLIENTS, MatchConstants.MAX_PEERS - 1)
	assert_true(MatchConstants.MAX_PLAYERS >= MatchConstants.MAX_PEERS)


func test_disconnect_clears_multiplayer_peer() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.host(_test_port), OK)
	assert_not_null(session.multiplayer.multiplayer_peer)

	session.disconnect_session()
	assert_null(session.multiplayer.multiplayer_peer)
	assert_false(session.is_active())
	assert_eq(session.get_session_state(), MatchSession.SessionState.IDLE)


func test_host_assigns_server_role_and_local_peer_id() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.host(_test_port), OK)
	assert_true(session.is_server())
	assert_true(session.is_session_established())
	assert_eq(session.get_session_state(), MatchSession.SessionState.HOSTING)
	assert_eq(session.multiplayer.get_unique_id(), 1)
	assert_eq(session.get_session_peer_ids(), [1])


func test_join_starts_in_connecting_state() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.join("127.0.0.1", _test_port), OK)
	assert_false(session.is_server())
	assert_true(session.is_active())
	assert_false(session.is_session_established())
	assert_eq(session.get_session_state(), MatchSession.SessionState.CONNECTING)
	assert_not_null(session.multiplayer.multiplayer_peer)

	session.disconnect_session()
	assert_null(session.multiplayer.multiplayer_peer)


func test_connection_failed_returns_to_idle() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.join("127.0.0.1", _test_port), OK)
	assert_eq(session.get_session_state(), MatchSession.SessionState.CONNECTING)

	session._on_connection_failed()
	assert_eq(session.get_session_state(), MatchSession.SessionState.IDLE)
	assert_null(session.multiplayer.multiplayer_peer)
	assert_false(session.is_active())


func test_connect_timeout_returns_to_idle() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	session._peer = EnetTransportAdapter.create_enet_client_peer("127.0.0.1", _test_port)
	session._state = MatchSession.SessionState.CONNECTING
	session._connect_started_msec = Time.get_ticks_msec() - MatchSession.CONNECT_TIMEOUT_MSEC - 1

	session._process(0.0)
	assert_eq(session.get_session_state(), MatchSession.SessionState.IDLE)
	assert_null(session.multiplayer.multiplayer_peer)


func test_server_disconnected_returns_to_idle() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	session._state = MatchSession.SessionState.CONNECTED
	session._on_server_disconnected()
	assert_eq(session.get_session_state(), MatchSession.SessionState.IDLE)
	assert_null(session.multiplayer.multiplayer_peer)


func test_exit_tree_clears_multiplayer_peer() -> void:
	var session := MatchSession.new()
	add_child(session)

	assert_eq(session.host(_test_port), OK)
	assert_not_null(session.multiplayer.multiplayer_peer)

	session.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var replacement := MatchSession.new()
	add_child_autofree(replacement)
	assert_null(replacement.multiplayer.multiplayer_peer)


func test_unknown_echo_reply_is_ignored() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.host(_test_port), OK)

	var completed := false
	session.echo_completed.connect(func(_from_peer_id: int, _message: String) -> void:
		completed = true
	)

	session._rpc_echo_reply("unexpected", 99999)
	assert_false(completed)


func test_echo_reply_requires_matching_sender_and_message() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.host(_test_port), OK)

	var nonce := 4242
	session._pending_echoes[nonce] = {
		"peer_id": 2,
		"message": "hello",
	}
	var completed := false
	session.echo_completed.connect(func(_from_peer_id: int, _message: String) -> void:
		completed = true
	)

	session._rpc_echo_reply("wrong-message", nonce)
	assert_false(completed)

	session._rpc_echo_reply("hello", nonce)
	assert_false(completed)


func test_ping_ms_recorded_from_echo_reply() -> void:
	var session := MatchSession.new()
	add_child_autofree(session)

	assert_eq(session.host(_test_port), OK)

	var nonce := 5150
	session._pending_echoes[nonce] = {
		"peer_id": 2,
		"message": "ping-test",
		"sent_msec": Time.get_ticks_msec() - 37,
	}

	session._apply_echo_reply(2, "ping-test", nonce)
	assert_gte(session.get_ping_ms(2), 37)
