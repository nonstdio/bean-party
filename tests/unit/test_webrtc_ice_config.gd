extends GutTest


func test_default_stun_only_includes_public_stun() -> void:
	var servers := WebRtcIceConfig.default_stun_only()
	assert_eq(servers.size(), 1)
	assert_true(servers[0] is Dictionary)
	assert_eq((servers[0].get("urls") as Array)[0], WebRtcIceConfig.DEFAULT_STUN_URL)


func test_resolve_prefers_explicit_ice_servers() -> void:
	var custom := [
		{
			"urls": ["stun:stun.example.test:19302", "turn:turn.example.test:3478"],
			"username": "alice",
			"credential": "secret",
		},
	]
	var resolved := WebRtcIceConfig.resolve_ice_servers({"ice_servers": custom})
	assert_eq(resolved.size(), 1)
	assert_eq((resolved[0].get("urls") as Array)[0], "stun:stun.example.test:19302")
	assert_eq((resolved[0].get("urls") as Array)[1], "turn:turn.example.test:3478")
	assert_eq(resolved[0].get("username"), "alice")


func test_parse_json_text_accepts_array_or_object() -> void:
	var from_array := WebRtcIceConfig.parse_json_text('[{"urls":["stun:stun.example.test:19302"]}]')
	assert_eq(from_array.size(), 1)

	var from_object := WebRtcIceConfig.parse_json_text(
		'{"urls":"turn:turn.example.test:3478","username":"bob","credential":"pw"}'
	)
	assert_eq(from_object.size(), 1)
	assert_eq(from_object[0].get("username"), "bob")


func test_parse_json_text_rejects_invalid_payload() -> void:
	assert_true(WebRtcIceConfig.parse_json_text("not json").is_empty())
	assert_true(WebRtcIceConfig.parse_json_text("[]").is_empty())
	assert_true(WebRtcIceConfig.parse_json_text("123").is_empty())


func test_transport_adapter_uses_ice_config_resolver() -> void:
	var normalized := WebRtcTransportAdapter.normalize_options({})
	var servers: Array = normalized.get("ice_servers", [])
	assert_false(servers.is_empty())
	assert_eq((servers[0].get("urls") as Array)[0], WebRtcIceConfig.DEFAULT_STUN_URL)


func test_turn_only_config_still_includes_default_stun() -> void:
	var servers := (
		WebRtcIceConfig
		. resolve_ice_servers(
			{
				"ice_servers":
				[
					{
						"urls": ["turn:turn.example.test:3478"],
						"username": "alice",
						"credential": "secret",
					},
				],
			}
		)
	)
	assert_eq(servers.size(), 2)
	assert_eq((servers[0].get("urls") as Array)[0], WebRtcIceConfig.DEFAULT_STUN_URL)
	assert_eq((servers[1].get("urls") as Array)[0], "turn:turn.example.test:3478")
