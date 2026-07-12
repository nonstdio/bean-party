class_name WebRtcExportSmoke
extends RefCounted

## Headless exported-build probe for webrtc-native packaging.

const SMOKE_FLAG := "--webrtc-export-smoke"
const EXTENSION_MANIFEST := "res://addons/webrtc_native/webrtc_native.gdextension"


static func should_run_from_cmdline() -> bool:
	return OS.get_cmdline_user_args().has(SMOKE_FLAG) or OS.get_cmdline_args().has(SMOKE_FLAG)


static func run() -> int:
	if not ResourceLoader.exists(EXTENSION_MANIFEST):
		push_error("WebRTC export smoke: extension manifest is missing at %s." % EXTENSION_MANIFEST)
		return 1

	if not WebRtcAvailability.is_extension_installed():
		push_error("WebRTC export smoke: WebRtcAvailability reports the extension is not installed.")
		return 1

	if not WebRtcAvailability.is_extension_loaded():
		push_error("WebRTC export smoke: WebRTCPeerConnection failed to initialize.")
		return 1

	print("WebRTC export smoke: extension manifest resolvable and WebRTCPeerConnection initialized.")
	return 0
