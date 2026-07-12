class_name OnlineServiceConfig
extends RefCounted

## Resolves hosted online-service endpoints for WebRTC transport.
## See docs/guides/webrtc-ops.md for deployment and precedence rules.

const UNCONFIGURED_MESSAGE := "Online play is not configured in this build."

const ENV_SIGNALING_URL := "BEAN_PARTY_SIGNALING_URL"
const ENV_ICE_CONFIG_URL := "BEAN_PARTY_ICE_CONFIG_URL"
const ENV_REQUEST_TIMEOUT_SEC := "BEAN_PARTY_ONLINE_REQUEST_TIMEOUT_SEC"
const ENV_PROTOCOL_VERSION := "BEAN_PARTY_SIGNALING_PROTOCOL_VERSION"
const ENV_DEVELOPMENT_MODE := "BEAN_PARTY_ONLINE_DEV_MODE"
const ENV_ALLOW_STUN_ONLY_FALLBACK := "BEAN_PARTY_ALLOW_STUN_ONLY_FALLBACK"

const RELEASE_CONFIG_PATH := "res://config/online_services.release.json"
const DEVELOPMENT_CONFIG_PATH := "res://config/online_services.development.json"
const USER_CONFIG_PATH := "user://online_services.json"
const EXAMPLE_CONFIG_PATH := "res://config/online_services.example.json"

const LOCAL_HOSTS := ["127.0.0.1", "localhost", "::1"]

const DEFAULT_REQUEST_TIMEOUT_SEC := 10.0
const DEFAULT_PROTOCOL_VERSION := 1
const MAX_URL_LENGTH := 2048
const MAX_RESPONSE_BYTES := 16384


static func resolve(options: Dictionary = {}) -> Dictionary:
	var merged := _merge_layers(options)
	return _validate_resolved(merged)


static func is_development_mode(options: Dictionary = {}) -> bool:
	if options.has("development_mode"):
		return bool(options.get("development_mode"))
	var env := OS.get_environment(ENV_DEVELOPMENT_MODE).strip_edges().to_lower()
	if env in ["1", "true", "yes"]:
		return true
	if OS.is_debug_build():
		return true
	var file_config := _read_config_file(_project_config_path())
	return bool(file_config.get("development_mode", false))


static func unconfigured_message() -> String:
	return UNCONFIGURED_MESSAGE


static func is_release_online_blocked(options: Dictionary = {}) -> bool:
	if is_development_mode(options):
		return false
	return String(resolve(options).get("signaling_url", "")) == ""


static func is_online_configured(options: Dictionary = {}) -> bool:
	var resolved := resolve(options)
	return String(resolved.get("signaling_url", "")) != ""


static func _merge_layers(options: Dictionary) -> Dictionary:
	var resolved := {
		"signaling_url": "",
		"ice_config_url": "",
		"request_timeout_sec": DEFAULT_REQUEST_TIMEOUT_SEC,
		"signaling_protocol_version": DEFAULT_PROTOCOL_VERSION,
		"development_mode": is_development_mode(options),
		"allow_stun_only_fallback": false,
	}

	var project_layer: Dictionary = {}
	if options.has("_test_project_config"):
		var probe: Variant = options.get("_test_project_config", {})
		if probe is Dictionary:
			project_layer = probe
	else:
		project_layer = _read_config_file(_project_config_path())

	var user_layer: Dictionary = {}
	if options.has("_test_user_config"):
		var user_probe: Variant = options.get("_test_user_config", {})
		if user_probe is Dictionary:
			user_layer = user_probe
	else:
		user_layer = _read_config_file(USER_CONFIG_PATH)

	_apply_dictionary(resolved, project_layer)
	_apply_dictionary(resolved, user_layer)

	if options.has("_test_env"):
		_apply_test_env_overrides(resolved, options.get("_test_env", {}))
	else:
		_apply_env_overrides(resolved)

	_apply_explicit_options(resolved, options)

	if resolved["development_mode"] and resolved["signaling_url"] == "":
		var dev := _read_config_file(DEVELOPMENT_CONFIG_PATH)
		_apply_dictionary(resolved, dev)

	return resolved


static func _apply_explicit_options(resolved: Dictionary, options: Dictionary) -> void:
	if options.has("signaling_url"):
		resolved["signaling_url"] = String(options.get("signaling_url", ""))
	if options.has("ice_config_url"):
		resolved["ice_config_url"] = String(options.get("ice_config_url", ""))
	if options.has("request_timeout_sec"):
		resolved["request_timeout_sec"] = float(options.get("request_timeout_sec"))
	if options.has("signaling_protocol_version"):
		resolved["signaling_protocol_version"] = int(options.get("signaling_protocol_version"))
	if options.has("development_mode"):
		resolved["development_mode"] = bool(options.get("development_mode"))
	if options.has("allow_stun_only_fallback"):
		resolved["allow_stun_only_fallback"] = bool(options.get("allow_stun_only_fallback"))


static func _apply_test_env_overrides(resolved: Dictionary, env: Dictionary) -> void:
	if env.has(ENV_SIGNALING_URL):
		resolved["signaling_url"] = String(env.get(ENV_SIGNALING_URL, "")).strip_edges()
	if env.has(ENV_ICE_CONFIG_URL):
		resolved["ice_config_url"] = String(env.get(ENV_ICE_CONFIG_URL, "")).strip_edges()
	if env.has(ENV_REQUEST_TIMEOUT_SEC):
		var timeout := String(env.get(ENV_REQUEST_TIMEOUT_SEC, "")).strip_edges()
		if timeout != "" and timeout.is_valid_float():
			resolved["request_timeout_sec"] = float(timeout)
	if env.has(ENV_PROTOCOL_VERSION):
		var protocol := String(env.get(ENV_PROTOCOL_VERSION, "")).strip_edges()
		if protocol != "" and protocol.is_valid_int():
			resolved["signaling_protocol_version"] = int(protocol)
	if env.has(ENV_DEVELOPMENT_MODE):
		_apply_boolean_env_value(
			resolved,
			"development_mode",
			String(env.get(ENV_DEVELOPMENT_MODE, "")),
		)
	if env.has(ENV_ALLOW_STUN_ONLY_FALLBACK):
		_apply_boolean_env_value(
			resolved,
			"allow_stun_only_fallback",
			String(env.get(ENV_ALLOW_STUN_ONLY_FALLBACK, "")),
		)


static func _apply_boolean_env_value(resolved: Dictionary, key: String, raw_value: String) -> void:
	var normalized := raw_value.strip_edges().to_lower()
	if normalized in ["1", "true", "yes"]:
		resolved[key] = true
	elif normalized in ["0", "false", "no"]:
		resolved[key] = false


static func _project_config_path() -> String:
	if OS.is_debug_build():
		return DEVELOPMENT_CONFIG_PATH
	return RELEASE_CONFIG_PATH


static func _apply_env_overrides(resolved: Dictionary) -> void:
	var signaling := OS.get_environment(ENV_SIGNALING_URL).strip_edges()
	if signaling != "":
		resolved["signaling_url"] = signaling
	var ice := OS.get_environment(ENV_ICE_CONFIG_URL).strip_edges()
	if ice != "":
		resolved["ice_config_url"] = ice
	var timeout := OS.get_environment(ENV_REQUEST_TIMEOUT_SEC).strip_edges()
	if timeout != "" and timeout.is_valid_float():
		resolved["request_timeout_sec"] = float(timeout)
	var protocol := OS.get_environment(ENV_PROTOCOL_VERSION).strip_edges()
	if protocol != "" and protocol.is_valid_int():
		resolved["signaling_protocol_version"] = int(protocol)
	if OS.get_environment(ENV_DEVELOPMENT_MODE) != "":
		_apply_boolean_env_value(
			resolved,
			"development_mode",
			OS.get_environment(ENV_DEVELOPMENT_MODE),
		)
	if OS.get_environment(ENV_ALLOW_STUN_ONLY_FALLBACK) != "":
		_apply_boolean_env_value(
			resolved,
			"allow_stun_only_fallback",
			OS.get_environment(ENV_ALLOW_STUN_ONLY_FALLBACK),
		)


static func _apply_file_overrides(resolved: Dictionary, path: String) -> void:
	_apply_dictionary(resolved, _read_config_file(path))


static func _apply_dictionary(target: Dictionary, source: Dictionary) -> void:
	if source.is_empty():
		return
	for key in [
		"signaling_url",
		"ice_config_url",
		"request_timeout_sec",
		"signaling_protocol_version",
		"development_mode",
		"allow_stun_only_fallback",
	]:
		if source.has(key):
			target[key] = source[key]


static func _read_config_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary:
		return parsed
	return {}


static func _validate_resolved(resolved: Dictionary) -> Dictionary:
	var development_mode := bool(resolved.get("development_mode", false))
	var signaling_url := _normalize_service_url(
		String(resolved.get("signaling_url", "")),
		["ws", "wss"],
		development_mode,
	)
	var ice_config_url := _normalize_service_url(
		String(resolved.get("ice_config_url", "")),
		["http", "https"],
		development_mode,
	)
	var timeout := clampf(float(resolved.get("request_timeout_sec", DEFAULT_REQUEST_TIMEOUT_SEC)), 1.0, 60.0)
	return {
		"signaling_url": signaling_url,
		"ice_config_url": ice_config_url,
		"request_timeout_sec": timeout,
		"signaling_protocol_version": maxi(1, int(resolved.get("signaling_protocol_version", DEFAULT_PROTOCOL_VERSION))),
		"development_mode": development_mode,
		"allow_stun_only_fallback": bool(resolved.get("allow_stun_only_fallback", false)),
	}


static func _normalize_service_url(raw_url: String, allowed_schemes: Array, development_mode: bool) -> String:
	var url := raw_url.strip_edges()
	if url == "":
		return ""
	if url.length() > MAX_URL_LENGTH:
		return ""

	var scheme_end := url.find("://")
	if scheme_end < 0:
		return ""
	var scheme := url.substr(0, scheme_end).to_lower()
	if scheme not in allowed_schemes:
		return ""

	var secure_required := not development_mode
	if secure_required and scheme not in ["wss", "https"]:
		return ""
	if not development_mode and _is_loopback_url(url):
		return ""

	if development_mode and scheme in ["ws", "http"] and not _is_loopback_url(url):
		return ""

	return url


static func _is_loopback_url(url: String) -> bool:
	var without_scheme := url.split("://", false, 1)
	if without_scheme.size() != 2:
		return false
	var remainder := without_scheme[1]
	var host := remainder.split("/", false, 1)[0]
	host = host.split(":", false, 1)[0]
	return host in LOCAL_HOSTS
