class_name HostSnapshotPredictionTracker
extends RefCounted

## Debug helper for milestone 8 prediction/reconciliation measurement.
## Records residual error between pre-reconcile prediction and post-replay prediction.

const CORRECTION_EPSILON := 0.5

var correction_count: int = 0
var total_correction_distance: float = 0.0
var max_correction_distance: float = 0.0
var last_correction_distance: float = 0.0


func reset() -> void:
	correction_count = 0
	total_correction_distance = 0.0
	max_correction_distance = 0.0
	last_correction_distance = 0.0


func record_correction(predicted: Vector2, reconciled: Vector2) -> void:
	var distance := predicted.distance_to(reconciled)
	if distance < CORRECTION_EPSILON:
		return

	correction_count += 1
	last_correction_distance = distance
	total_correction_distance += distance
	max_correction_distance = maxf(max_correction_distance, distance)


func average_correction_distance() -> float:
	if correction_count == 0:
		return 0.0
	return total_correction_distance / float(correction_count)


func export_stats() -> Dictionary:
	return {
		"correction_count": correction_count,
		"last_correction_distance": last_correction_distance,
		"max_correction_distance": max_correction_distance,
		"average_correction_distance": average_correction_distance(),
	}
