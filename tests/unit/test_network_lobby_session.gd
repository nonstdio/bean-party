extends GutTest


func test_pending_client_rpc_queues_until_transport_ready() -> void:
	var match_session := MatchSession.new()
	var lobby := NetworkLobbySession.new()
	match_session.add_child(lobby)
	add_child_autofree(match_session)

	match_session._state = MatchSession.SessionState.CONNECTED
	match_session._transport_adapter = EnetTransportAdapter.new()

	var called := false
	lobby._issue_client_rpc(func() -> void:
		called = true
	)

	assert_false(called)
	assert_eq(lobby._pending_client_rpcs.size(), 1)
	assert_true(lobby._client_rpc_retry_connected)


func test_queue_lobby_sync_defers_until_peer_route_ready() -> void:
	var match_session := MatchSession.new()
	var lobby := NetworkLobbySession.new()
	match_session.add_child(lobby)
	add_child_autofree(match_session)

	match_session._state = MatchSession.SessionState.HOSTING
	match_session._transport_adapter = EnetTransportAdapter.new()
	lobby._authority = NetworkLobbyAuthority.new()

	lobby._queue_lobby_sync_to_peer(2)
	assert_true(lobby._pending_lobby_sync_peer_ids.has(2))
	assert_true(lobby._client_rpc_retry_connected)


func test_reset_lobby_clears_pending_client_rpcs() -> void:
	var match_session := MatchSession.new()
	var lobby := NetworkLobbySession.new()
	match_session.add_child(lobby)
	add_child_autofree(match_session)

	lobby._pending_client_rpcs.append(func() -> void: pass)
	lobby._client_rpc_retry_connected = true
	lobby._reset_lobby()
	assert_true(lobby._pending_client_rpcs.is_empty())
	assert_false(lobby._client_rpc_retry_connected)
