extends GutTest


func test_parse_remote_ice_servers_accepts_valid_payload() -> void:
	var future_expiry := int(Time.get_unix_time_from_system()) + 120
	var servers := WebRtcIceConfig.parse_remote_ice_servers([
		{"urls": ["stun:stun.example.test:19302"]},
		{
			"urls": ["turn:turn.example.test:3478"],
			"username": "1700000000:user",
			"credential": "abc123",
		},
	], future_expiry)
	assert_eq(servers.size(), 2)
	assert_eq((servers[1].get("urls") as Array)[0], "turn:turn.example.test:3478")


func test_parse_remote_ice_servers_rejects_invalid_schemes() -> void:
	var future_expiry := int(Time.get_unix_time_from_system()) + 120
	assert_true(
		WebRtcIceConfig.parse_remote_ice_servers(
			[{"urls": ["http://turn.example.test:3478"]}],
			future_expiry,
		).is_empty(),
	)


func test_parse_remote_ice_servers_requires_turn_credentials() -> void:
	var future_expiry := int(Time.get_unix_time_from_system()) + 120
	assert_true(
		WebRtcIceConfig.parse_remote_ice_servers(
			[{"urls": ["turn:turn.example.test:3478"]}],
			future_expiry,
		).is_empty(),
	)


func test_parse_remote_ice_servers_rejects_short_lived_credentials() -> void:
	var servers := WebRtcIceConfig.parse_remote_ice_servers(
		[
			{"urls": ["stun:stun.example.test:19302"]},
			{
				"urls": ["turn:turn.example.test:3478"],
				"username": "1700000000:user",
				"credential": "abc123",
			},
		],
		int(Time.get_unix_time_from_system()) + 5,
	)
	assert_true(servers.is_empty())


func test_parse_remote_ice_servers_rejects_empty_urls() -> void:
	assert_true(WebRtcIceConfig.parse_remote_ice_servers([{"urls": []}]).is_empty())


func test_ice_fetcher_cancel_clears_active_state() -> void:
	var fetcher := WebRtcIceFetcher.new()
	var owner := Node.new()
	add_child_autofree(owner)
	fetcher.start(owner, "http://127.0.0.1:9080/v1/ice", 1.0)
	assert_true(fetcher.is_active())
	fetcher.cancel()
	assert_false(fetcher.is_active())
