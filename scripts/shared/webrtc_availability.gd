class_name WebRtcAvailability
extends RefCounted

## Runtime probe for the optional webrtc-native GDExtension.

const EXTENSION_MANIFEST := "res://addons/webrtc_native/webrtc_native.gdextension"


static func is_extension_installed() -> bool:
	return ResourceLoader.exists(EXTENSION_MANIFEST)


static func is_extension_loaded() -> bool:
	if not is_extension_installed():
		return false

	# Godot ships WebRTC stubs without webrtc-native; initialize fails until the
	# GDExtension registers a real WebRTCPeerConnection backend.
	var peer := WebRTCPeerConnection.new()
	return peer.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]}) == OK
