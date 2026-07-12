class_name WebRtcIceFetcher
extends RefCounted

signal completed(ice_servers: Array, diagnostic: String)
signal failed(message: String, diagnostic: String)

const MAX_RESPONSE_BYTES := OnlineServiceConfig.MAX_RESPONSE_BYTES

var _http: HTTPRequest = null
var _owner: Node = null
var _started_msec: int = 0
var _timeout_sec: float = 10.0
var _active: bool = false


func start(owner: Node, ice_config_url: String, timeout_sec: float) -> void:
	cancel()
	if ice_config_url == "":
		failed.emit("ICE configuration URL is missing.", "missing_ice_endpoint")
		return

	_owner = owner
	_timeout_sec = timeout_sec
	_active = true
	_started_msec = Time.get_ticks_msec()

	_http = HTTPRequest.new()
	_http.timeout = timeout_sec
	_http.body_size_limit = MAX_RESPONSE_BYTES
	_http.request_completed.connect(_on_request_completed)
	owner.add_child(_http)
	var error := _http.request(ice_config_url)
	if error != OK:
		_cleanup()
		failed.emit("ICE configuration request failed to start.", "http_start_failed")


func cancel() -> void:
	if _http != null and is_instance_valid(_http):
		if _http.request_completed.is_connected(_on_request_completed):
			_http.request_completed.disconnect(_on_request_completed)
		_http.queue_free()
	_http = null
	_owner = null
	_active = false


func is_active() -> bool:
	return _active


func _on_request_completed(
		result: int,
		response_code: int,
		_headers: PackedStringArray,
		body: PackedByteArray,
) -> void:
	if not _active:
		return

	_active = false
	var diagnostic := "http_%d" % response_code

	if result != HTTPRequest.RESULT_SUCCESS:
		_cleanup()
		if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			failed.emit("ICE configuration response is too large.", "response_too_large")
			return
		failed.emit("ICE configuration request failed.", diagnostic)
		return
	if response_code < 200 or response_code >= 300:
		_cleanup()
		failed.emit("ICE configuration endpoint returned HTTP %d." % response_code, diagnostic)
		return
	if body.size() > MAX_RESPONSE_BYTES:
		_cleanup()
		failed.emit("ICE configuration response is too large.", "response_too_large")
		return

	var parsed := _parse_response(body)
	_cleanup()
	if parsed.is_empty():
		failed.emit("ICE configuration response is invalid.", "invalid_response")
		return

	completed.emit(parsed.get("ice_servers", []), parsed.get("diagnostic", ""))


func _parse_response(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {}

	var parsed: Variant = json.data
	if parsed is not Dictionary:
		return {}

	var raw_servers: Variant = parsed.get("ice_servers", [])
	if raw_servers is not Array or raw_servers.is_empty():
		return {}

	var expires_at := int(parsed.get("expires_at", 0))
	if expires_at > 0 and expires_at <= Time.get_unix_time_from_system():
		return {}

	var servers := WebRtcIceConfig.parse_remote_ice_servers(raw_servers, expires_at)
	if servers.is_empty():
		return {}

	return {
		"ice_servers": servers,
		"diagnostic": "ice_fetched",
	}


func _cleanup() -> void:
	cancel()
