extends GutTest


func test_export_smoke_fails_without_extension_when_not_loaded() -> void:
	if WebRtcAvailability.is_extension_loaded():
		pass_test("Skipping negative-path smoke test because webrtc-native is installed.")
		return

	assert_eq(WebRtcExportSmoke.run(), 1)


func test_export_smoke_succeeds_when_extension_loads() -> void:
	if not WebRtcAvailability.is_extension_loaded():
		pass_test("Skipping positive-path smoke test without webrtc-native.")
		return

	assert_eq(WebRtcExportSmoke.run(), 0)
