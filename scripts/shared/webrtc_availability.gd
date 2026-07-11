class_name WebRtcAvailability
extends RefCounted

## Runtime probe for the optional webrtc-native GDExtension.

const EXTENSION_MANIFEST := "res://addons/webrtc_native/webrtc_native.gdextension"

static var _extension_loaded: bool = false
static var _extension_loaded_checked: bool = false


static func is_extension_installed() -> bool:
	return ResourceLoader.exists(EXTENSION_MANIFEST)


static func is_extension_loaded() -> bool:
	if _extension_loaded_checked:
		return _extension_loaded

	_extension_loaded_checked = true
	if not is_extension_installed():
		_extension_loaded = false
		return false

	# Godot ships WebRTC stubs without webrtc-native; initialize fails until the
	# GDExtension registers a real WebRTCPeerConnection backend.
	var peer := WebRTCPeerConnection.new()
	_extension_loaded = peer.initialize({"iceServers": WebRtcIceConfig.default_stun_only()}) == OK
	return _extension_loaded


static func reset_probe_cache_for_tests() -> void:
	_extension_loaded_checked = false
	_extension_loaded = false
