class_name WebRtcIceConfig
extends RefCounted

## Resolves ICE server entries for WebRTC peer connections.
## See docs/guides/webrtc-ops.md for deployment and TURN configuration.

const ENV_ICE_SERVERS_JSON := "BEAN_PARTY_ICE_SERVERS_JSON"
const ENV_TURN_URLS := "BEAN_PARTY_TURN_URLS"
const ENV_TURN_USERNAME := "BEAN_PARTY_TURN_USERNAME"
const ENV_TURN_CREDENTIAL := "BEAN_PARTY_TURN_CREDENTIAL"

const PROJECT_CONFIG_PATH := "res://config/webrtc_ice_servers.json"
const USER_CONFIG_PATH := "user://webrtc_ice_servers.json"
const EXAMPLE_CONFIG_PATH := "res://config/webrtc_ice_servers.example.json"

const DEFAULT_STUN_URL := "stun:stun.l.google.com:19302"

const REMOTE_MAX_SERVERS := 8
const REMOTE_MAX_URLS_PER_SERVER := 4
const REMOTE_MAX_URL_LENGTH := 512
const REMOTE_MIN_CREDENTIAL_REMAINING_SEC := 30
const REMOTE_ALLOWED_SCHEMES := ["stun:", "stuns:", "turn:", "turns:"]


static func parse_json_text(json_text: String) -> Array:
	return _parse_json_server_list(json_text)


static func parse_remote_ice_servers(raw_servers: Array, expires_at: int = 0) -> Array:
	if expires_at > 0:
		var remaining: int = expires_at - int(Time.get_unix_time_from_system())
		if remaining < REMOTE_MIN_CREDENTIAL_REMAINING_SEC:
			return []
	return _normalize_remote_server_list(raw_servers)


static func resolve_ice_servers(options: Dictionary = {}) -> Array:
	var explicit: Variant = options.get("ice_servers")
	if explicit is Array and not explicit.is_empty():
		return _ensure_default_stun(_normalize_server_list(explicit))

	var servers: Array = []
	_append_unique_servers(servers, _servers_from_environment())
	_append_unique_servers(servers, _servers_from_file(USER_CONFIG_PATH))
	_append_unique_servers(servers, _servers_from_file(PROJECT_CONFIG_PATH))

	if servers.is_empty():
		return default_stun_only()

	return _ensure_default_stun(servers)


static func default_stun_only() -> Array:
	return [{"urls": [DEFAULT_STUN_URL]}]


static func _ensure_default_stun(servers: Array) -> Array:
	if _includes_stun(servers):
		return servers
	var merged := default_stun_only().duplicate(true)
	merged.append_array(servers)
	return merged


static func _includes_stun(servers: Array) -> bool:
	for entry in servers:
		if entry is not Dictionary:
			continue
		for url in entry.get("urls", []):
			if String(url).begins_with("stun:"):
				return true
	return false


static func _servers_from_environment() -> Array:
	var servers: Array = []
	var json_text := OS.get_environment(ENV_ICE_SERVERS_JSON).strip_edges()
	if json_text != "":
		_append_unique_servers(servers, _parse_json_server_list(json_text))
		return servers

	var turn_urls := _split_urls(OS.get_environment(ENV_TURN_URLS))
	if turn_urls.is_empty():
		return servers

	var turn_entry := {"urls": turn_urls}
	var username := OS.get_environment(ENV_TURN_USERNAME).strip_edges()
	var credential := OS.get_environment(ENV_TURN_CREDENTIAL).strip_edges()
	if username != "":
		turn_entry["username"] = username
	if credential != "":
		turn_entry["credential"] = credential
	servers.append(turn_entry)
	return servers


static func _servers_from_file(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to read ICE config at %s." % path)
		return []

	return _parse_json_server_list(file.get_as_text())


static func _parse_json_server_list(json_text: String) -> Array:
	var trimmed := json_text.strip_edges()
	if trimmed == "":
		return []

	var json := JSON.new()
	if json.parse(trimmed) != OK:
		push_warning("ICE server JSON is invalid.")
		return []
	var parsed: Variant = json.data
	if parsed is Dictionary:
		return _normalize_server_list([parsed])
	if parsed is Array:
		return _normalize_server_list(parsed)

	push_warning("ICE server JSON must be an array or object.")
	return []


static func _normalize_server_list(raw_servers: Array) -> Array:
	var normalized: Array = []
	for entry in raw_servers:
		if entry is Dictionary:
			var server := _normalize_server_entry(entry)
			if not server.is_empty():
				normalized.append(server)
	return normalized


static func _normalize_remote_server_list(raw_servers: Array) -> Array:
	if raw_servers.size() > REMOTE_MAX_SERVERS:
		return []

	var normalized: Array = []
	for entry in raw_servers:
		if entry is not Dictionary:
			return []
		var server := _normalize_remote_server_entry(entry)
		if server.is_empty():
			return []
		normalized.append(server)
	return normalized


static func _normalize_remote_server_entry(entry: Dictionary) -> Dictionary:
	var urls := _normalize_remote_urls(entry.get("urls", []))
	if urls.is_empty():
		return {}

	var requires_credentials := false
	for url in urls:
		if String(url).begins_with("turn:") or String(url).begins_with("turns:"):
			requires_credentials = true
			break

	var server := {"urls": urls}
	if entry.has("username"):
		server["username"] = String(entry.get("username", ""))
	if entry.has("credential"):
		server["credential"] = String(entry.get("credential", ""))

	if requires_credentials:
		if String(server.get("username", "")).strip_edges() == "":
			return {}
		if String(server.get("credential", "")).strip_edges() == "":
			return {}

	return server


static func _normalize_remote_urls(raw_urls: Variant) -> Array:
	var urls: Array = []
	if raw_urls is String:
		urls = _split_urls(String(raw_urls))
	elif raw_urls is Array:
		for url in raw_urls:
			var trimmed := String(url).strip_edges()
			if trimmed != "":
				urls.append(trimmed)

	if urls.is_empty() or urls.size() > REMOTE_MAX_URLS_PER_SERVER:
		return []

	var normalized: Array = []
	for url in urls:
		var validated := _validate_remote_url(url)
		if validated == "":
			return []
		normalized.append(validated)
	return normalized


static func _validate_remote_url(url: String) -> String:
	if url.length() > REMOTE_MAX_URL_LENGTH:
		return ""
	for scheme in REMOTE_ALLOWED_SCHEMES:
		if url.begins_with(scheme):
			return url
	return ""


static func _normalize_server_entry(entry: Dictionary) -> Dictionary:
	var urls: Array = []
	var raw_urls: Variant = entry.get("urls", [])
	if raw_urls is String:
		urls = _split_urls(String(raw_urls))
	elif raw_urls is Array:
		for url in raw_urls:
			var trimmed := String(url).strip_edges()
			if trimmed != "":
				urls.append(trimmed)
	if urls.is_empty():
		return {}

	var server := {"urls": urls}
	if entry.has("username"):
		server["username"] = String(entry.get("username", ""))
	if entry.has("credential"):
		server["credential"] = String(entry.get("credential", ""))
	return server


static func _append_unique_servers(target: Array, additions: Array) -> void:
	for server in additions:
		if server is Dictionary and not server.is_empty():
			target.append(server)


static func _split_urls(raw: String) -> Array:
	var urls: Array = []
	for part in raw.split(",", false):
		var trimmed := part.strip_edges()
		if trimmed != "":
			urls.append(trimmed)
	return urls
