class_name WebRtcAvailability
extends RefCounted

## Runtime probe for the optional webrtc-native GDExtension.


static func is_extension_loaded() -> bool:
	return ClassDB.class_exists("WebRTCMultiplayerPeer")
