extends GutTest


func test_release_config_without_urls_is_unconfigured() -> void:
	var resolved := OnlineServiceConfig.resolve({
		"development_mode": false,
		"signaling_url": "",
		"ice_config_url": "",
	})
	assert_eq(resolved.get("signaling_url"), "")
	assert_false(OnlineServiceConfig.is_online_configured({
		"development_mode": false,
		"signaling_url": "",
	}))


func test_development_config_allows_loopback_ws() -> void:
	var resolved := OnlineServiceConfig.resolve({
		"development_mode": true,
		"signaling_url": "ws://127.0.0.1:9080/v1/signal",
		"ice_config_url": "http://127.0.0.1:9080/v1/ice",
	})
	assert_eq(resolved.get("signaling_url"), "ws://127.0.0.1:9080/v1/signal")
	assert_eq(resolved.get("ice_config_url"), "http://127.0.0.1:9080/v1/ice")


func test_production_rejects_insecure_schemes() -> void:
	var resolved := OnlineServiceConfig.resolve({
		"development_mode": false,
		"signaling_url": "ws://example.test/v1/signal",
		"ice_config_url": "http://example.test/v1/ice",
	})
	assert_eq(resolved.get("signaling_url"), "")
	assert_eq(resolved.get("ice_config_url"), "")


func test_production_accepts_secure_schemes() -> void:
	var resolved := OnlineServiceConfig.resolve({
		"development_mode": false,
		"signaling_url": "wss://signal.example.test/v1/signal",
		"ice_config_url": "https://signal.example.test/v1/ice",
	})
	assert_eq(resolved.get("signaling_url"), "wss://signal.example.test/v1/signal")
	assert_eq(resolved.get("ice_config_url"), "https://signal.example.test/v1/ice")


func test_layer_precedence_env_beats_project_and_user() -> void:
	var resolved := OnlineServiceConfig.resolve({
		"development_mode": false,
		"_test_project_config": {
			"signaling_url": "wss://project.example.test/v1/signal",
			"ice_config_url": "https://project.example.test/v1/ice",
		},
		"_test_user_config": {
			"signaling_url": "wss://user.example.test/v1/signal",
			"ice_config_url": "https://user.example.test/v1/ice",
		},
		"_test_env": {
			OnlineServiceConfig.ENV_SIGNALING_URL: "wss://env.example.test/v1/signal",
			OnlineServiceConfig.ENV_ICE_CONFIG_URL: "https://env.example.test/v1/ice",
		},
	})
	assert_eq(resolved.get("signaling_url"), "wss://env.example.test/v1/signal")
	assert_eq(resolved.get("ice_config_url"), "https://env.example.test/v1/ice")


func test_layer_precedence_user_beats_project() -> void:
	var resolved := OnlineServiceConfig.resolve({
		"development_mode": false,
		"_test_project_config": {
			"signaling_url": "wss://project.example.test/v1/signal",
		},
		"_test_user_config": {
			"signaling_url": "wss://user.example.test/v1/signal",
		},
	})
	assert_eq(resolved.get("signaling_url"), "wss://user.example.test/v1/signal")


func test_explicit_options_override_env_and_files() -> void:
	var resolved := OnlineServiceConfig.resolve({
		"development_mode": false,
		"signaling_url": "wss://override.example.test/v1/signal",
		"ice_config_url": "https://override.example.test/v1/ice",
		"_test_project_config": {
			"signaling_url": "wss://project.example.test/v1/signal",
		},
		"_test_env": {
			OnlineServiceConfig.ENV_SIGNALING_URL: "wss://env.example.test/v1/signal",
		},
	})
	assert_eq(resolved.get("signaling_url"), "wss://override.example.test/v1/signal")
	assert_eq(resolved.get("ice_config_url"), "https://override.example.test/v1/ice")


func test_explicit_false_boolean_overrides_env_true() -> void:
	var resolved := OnlineServiceConfig.resolve({
		"development_mode": false,
		"allow_stun_only_fallback": false,
		"_test_env": {
			OnlineServiceConfig.ENV_ALLOW_STUN_ONLY_FALLBACK: "true",
		},
	})
	assert_false(resolved.get("allow_stun_only_fallback"))


func test_release_online_blocked_when_unconfigured() -> void:
	assert_true(
		OnlineServiceConfig.is_release_online_blocked({
			"development_mode": false,
			"signaling_url": "",
			"ice_config_url": "",
		}),
	)
	assert_false(
		OnlineServiceConfig.is_release_online_blocked({
			"development_mode": true,
			"signaling_url": "",
		}),
	)


func test_explicit_runtime_options_take_precedence() -> void:
	var resolved := OnlineServiceConfig.resolve({
		"development_mode": false,
		"signaling_url": "wss://override.example.test/v1/signal",
		"ice_config_url": "https://override.example.test/v1/ice",
	})
	assert_eq(resolved.get("signaling_url"), "wss://override.example.test/v1/signal")


func test_transport_adapter_adds_protocol_query() -> void:
	var url := WebRtcTransportAdapter.signaling_url_with_protocol(
		"wss://signal.example.test/v1/signal",
		1,
	)
	assert_eq(url, "wss://signal.example.test/v1/signal?protocol=1")


func test_unconfigured_message_is_stable() -> void:
	assert_eq(
		OnlineServiceConfig.unconfigured_message(),
		"Online play is not configured in this build.",
	)
