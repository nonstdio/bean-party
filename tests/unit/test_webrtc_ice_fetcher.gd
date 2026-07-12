extends GutTest


func test_parse_remote_ice_servers_accepts_valid_payload() -> void:
	var servers := WebRtcIceConfig.parse_remote_ice_servers([
		{"urls": ["stun:stun.example.test:19302"]},
		{
			"urls": ["turn:turn.example.test:3478"],
			"username": "1700000000:user",
			"credential": "abc123",
		},
	])
	assert_eq(servers.size(), 2)
	assert_eq((servers[1].get("urls") as Array)[0], "turn:turn.example.test:3478")


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
