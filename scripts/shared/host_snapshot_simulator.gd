class_name HostSnapshotSimulator
extends RefCounted

const ARENA_SIZE := Vector2(640.0, 480.0)
const PLAYER_RADIUS := 16.0
const MOVE_SPEED := 220.0
const GOAL_CENTER := Vector2(320.0, 240.0)
const GOAL_RADIUS := 48.0

var positions_by_player_id: Dictionary = {}
var winner_player_id: String = ""


func reset_for_player_ids(player_ids: PackedStringArray) -> void:
	positions_by_player_id.clear()
	winner_player_id = ""
	var spawn_points := _spawn_points_for_count(player_ids.size())
	for index in player_ids.size():
		positions_by_player_id[player_ids[index]] = spawn_points[index]


static func apply_move(position: Vector2, move: Vector2, delta: float) -> Vector2:
	var next := position + move.limit_length(1.0) * MOVE_SPEED * delta
	next.x = clampf(next.x, PLAYER_RADIUS, ARENA_SIZE.x - PLAYER_RADIUS)
	next.y = clampf(next.y, PLAYER_RADIUS, ARENA_SIZE.y - PLAYER_RADIUS)
	return next


func tick(
	inputs_by_player_id: Dictionary,
	delta: float,
	eligible_winners: Dictionary = {},
) -> void:
	if not winner_player_id.is_empty():
		return

	for player_id in positions_by_player_id.keys():
		var move: Vector2 = inputs_by_player_id.get(player_id, Vector2.ZERO)
		if not move is Vector2:
			move = Vector2.ZERO

		var position: Vector2 = positions_by_player_id[player_id]
		position = apply_move(position, move, delta)
		positions_by_player_id[player_id] = position

		if position.distance_to(GOAL_CENTER) <= GOAL_RADIUS:
			if not eligible_winners.is_empty() and not eligible_winners.has(player_id):
				continue
			winner_player_id = String(player_id)
			return


func export_positions(acked_input_ticks: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {}
	for player_id in positions_by_player_id.keys():
		var position: Vector2 = positions_by_player_id[player_id]
		var player_key := String(player_id)
		var entry := {
			"x": position.x,
			"y": position.y,
			"acked_input_tick": int(acked_input_ticks.get(player_key, 0)),
		}
		payload[player_key] = entry
	return payload


func load_positions(payload: Dictionary) -> void:
	for player_id in payload.keys():
		var entry: Variant = payload[player_id]
		if entry is Dictionary:
			positions_by_player_id[String(player_id)] = Vector2(
				float(entry.get("x", 0.0)),
				float(entry.get("y", 0.0)),
			)


func get_position(player_id: String) -> Vector2:
	return positions_by_player_id.get(player_id, Vector2.ZERO)


func state_hash() -> int:
	return hash_positions(export_positions())


static func hash_positions(payload: Dictionary) -> int:
	var keys: Array = payload.keys()
	keys.sort()
	var normalized: Dictionary = {}
	for key in keys:
		normalized[String(key)] = payload[key]
	return hash(normalized)


func build_result(participant_ids: PackedStringArray) -> MinigameResult:
	var ranked := _rank_by_goal_distance(participant_ids)
	var placements: Array = []
	var scores: Dictionary = {}
	for index in ranked.size():
		var group := PackedStringArray([ranked[index]])
		placements.append(group)
		scores[ranked[index]] = ranked.size() - index

	if not winner_player_id.is_empty() and ranked.size() > 0:
		scores[ranked[0]] = ranked.size() + 1

	return MinigameResult.completed(placements, scores)


func _rank_by_goal_distance(participant_ids: PackedStringArray) -> PackedStringArray:
	var entries: Array = []
	for player_id in participant_ids:
		var position := get_position(player_id)
		(
			entries
			. append(
				{
					"player_id": player_id,
					"distance": position.distance_to(GOAL_CENTER),
				}
			)
		)
	entries.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return float(left.get("distance", 0.0)) < float(right.get("distance", 0.0))
	)

	var ranked := PackedStringArray()
	for entry in entries:
		ranked.append(String(entry.get("player_id", "")))
	return ranked


func _spawn_points_for_count(player_count: int) -> Array[Vector2]:
	var margin := 72.0
	match player_count:
		1:
			return [Vector2(ARENA_SIZE.x * 0.5, margin)]
		2:
			return [
				Vector2(margin, margin),
				Vector2(ARENA_SIZE.x - margin, ARENA_SIZE.y - margin),
			]
		3:
			return [
				Vector2(margin, margin),
				Vector2(ARENA_SIZE.x - margin, margin),
				Vector2(ARENA_SIZE.x * 0.5, ARENA_SIZE.y - margin),
			]
		_:
			return [
				Vector2(margin, margin),
				Vector2(ARENA_SIZE.x - margin, margin),
				Vector2(margin, ARENA_SIZE.y - margin),
				Vector2(ARENA_SIZE.x - margin, ARENA_SIZE.y - margin),
			]
