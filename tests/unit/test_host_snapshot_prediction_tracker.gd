extends GutTest


func test_records_correction_above_epsilon() -> void:
	var tracker := HostSnapshotPredictionTracker.new()

	tracker.record_correction(Vector2(100.0, 100.0), Vector2(110.0, 100.0))

	assert_eq(tracker.correction_count, 1)
	assert_eq(tracker.last_correction_distance, 10.0)
	assert_eq(tracker.max_correction_distance, 10.0)
	assert_eq(tracker.average_correction_distance(), 10.0)


func test_ignores_sub_epsilon_drift() -> void:
	var tracker := HostSnapshotPredictionTracker.new()

	tracker.record_correction(Vector2(100.0, 100.0), Vector2(100.2, 100.0))

	assert_eq(tracker.correction_count, 0)


func test_reset_clears_stats() -> void:
	var tracker := HostSnapshotPredictionTracker.new()
	tracker.record_correction(Vector2.ZERO, Vector2(20.0, 0.0))

	tracker.reset()

	assert_eq(tracker.correction_count, 0)
	assert_eq(tracker.max_correction_distance, 0.0)
