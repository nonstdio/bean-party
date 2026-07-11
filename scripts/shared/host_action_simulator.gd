class_name HostActionSimulator
extends RefCounted

const ARENA_HALF_EXTENTS := Vector3(18.0, 4.0, 18.0)
const MOVE_SPEED := 8.0
const TURN_SPEED := 3.2
const JUMP_VELOCITY := 6.5
const GRAVITY := 20.0
const ROUND_DURATION_SEC := 90.0
const PLAYER_RADIUS := 0.45
const PLAYER_HEIGHT := 1.8
const MAX_HEALTH := 100
const HITSCAN_DAMAGE := 50
const FIRE_COOLDOWN_SEC := 0.4
const HITSCAN_RANGE := 36.0
const CHEST_HEIGHT := 1.35

var positions_by_player_id: Dictionary = {}
var vertical_velocity_by_player_id: Dictionary = {}
var health_by_player_id: Dictionary = {}
var yaw_by_player_id: Dictionary = {}
var fire_cooldown_by_player_id: Dictionary = {}
var eliminations_by_player_id: Dictionary = {}
var winner_player_id: String = ""
var elapsed_sec: float = 0.0
var sim_tick: int = 0


func reset_for_player_ids(player_ids: PackedStringArray) -> void:
	positions_by_player_id.clear()
	vertical_velocity_by_player_id.clear()
	health_by_player_id.clear()
	yaw_by_player_id.clear()
	fire_cooldown_by_player_id.clear()
	eliminations_by_player_id.clear()
	winner_player_id = ""
	elapsed_sec = 0.0
	sim_tick = 0
	var spawn_points := _spawn_points_for_count(player_ids.size())
	for index in player_ids.size():
		var player_id := String(player_ids[index])
		positions_by_player_id[player_id] = spawn_points[index]
		vertical_velocity_by_player_id[player_id] = 0.0
		health_by_player_id[player_id] = MAX_HEALTH
		yaw_by_player_id[player_id] = PI * 0.25 * float(index)
		fire_cooldown_by_player_id[player_id] = 0.0
		eliminations_by_player_id[player_id] = 0


func tick(
		inputs_by_player_id: Dictionary,
		delta: float,
		eligible_participants: Dictionary = {},
) -> void:
	if not winner_player_id.is_empty():
		return

	elapsed_sec += delta
	sim_tick += 1
	_decay_fire_cooldowns(delta)

	for player_id in positions_by_player_id.keys():
		if not is_alive(player_id):
			continue
		if not eligible_participants.is_empty() and not eligible_participants.has(player_id):
			continue

		var input: Dictionary = inputs_by_player_id.get(player_id, {})
		var move: Vector2 = input.get("move", Vector2.ZERO)
		if not move is Vector2:
			move = Vector2.ZERO
		var jump_pressed := bool(input.get("jump", false))
		var fire_pressed := bool(input.get("fire", false))

		var position: Vector3 = positions_by_player_id[player_id]
		var velocity_y: float = float(vertical_velocity_by_player_id.get(player_id, 0.0))
		var yaw: float = get_yaw(player_id)
		var applied: Dictionary = apply_tank_move(
			position,
			yaw,
			move,
			velocity_y,
			delta,
			jump_pressed,
		)
		positions_by_player_id[player_id] = applied.get("position", position)
		yaw_by_player_id[player_id] = float(applied.get("yaw", yaw))
		vertical_velocity_by_player_id[player_id] = float(
			applied.get("vertical_velocity", velocity_y)
		)

		if fire_pressed:
			_try_hitscan(player_id, eligible_participants)

	_check_last_player_standing()


func is_alive(player_id: String) -> bool:
	return int(health_by_player_id.get(player_id, 0)) > 0


func get_health(player_id: String) -> int:
	return int(health_by_player_id.get(player_id, 0))


func get_yaw(player_id: String) -> float:
	return float(yaw_by_player_id.get(player_id, 0.0))


func export_positions(acked_input_ticks: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = {}
	for player_id in positions_by_player_id.keys():
		var position: Vector3 = positions_by_player_id[player_id]
		var player_key := String(player_id)
		payload[player_key] = {
			"x": position.x,
			"y": position.y,
			"z": position.z,
			"yaw": get_yaw(player_id),
			"health": get_health(player_id),
			"eliminations": int(eliminations_by_player_id.get(player_id, 0)),
			"acked_input_tick": int(acked_input_ticks.get(player_key, 0)),
			"vertical_velocity": float(vertical_velocity_by_player_id.get(player_id, 0.0)),
		}
	return payload


func load_positions(payload: Dictionary) -> void:
	for player_id in payload.keys():
		var entry: Variant = payload[player_id]
		if entry is not Dictionary:
			continue
		var player_key := String(player_id)
		positions_by_player_id[player_key] = Vector3(
			float(entry.get("x", 0.0)),
			float(entry.get("y", 0.0)),
			float(entry.get("z", 0.0)),
		)
		if entry.has("yaw"):
			yaw_by_player_id[player_key] = float(entry.get("yaw", 0.0))
		if entry.has("health"):
			health_by_player_id[player_key] = int(entry.get("health", MAX_HEALTH))
		if entry.has("eliminations"):
			eliminations_by_player_id[player_key] = int(entry.get("eliminations", 0))
		if entry.has("vertical_velocity"):
			vertical_velocity_by_player_id[player_key] = float(entry.get("vertical_velocity", 0.0))


static func is_airborne(position: Vector3, vertical_velocity: float) -> bool:
	return position.y > 1.02 or vertical_velocity > 0.05


func get_position(player_id: String) -> Vector3:
	return positions_by_player_id.get(player_id, Vector3.ZERO)


func state_hash() -> int:
	return hash_positions(export_positions())


static func hash_positions(payload: Dictionary) -> int:
	var keys: Array = payload.keys()
	keys.sort()
	var normalized: Dictionary = {}
	for key in keys:
		normalized[String(key)] = payload[key]
	return hash(normalized)


static func apply_tank_move(
		position: Vector3,
		yaw: float,
		move: Vector2,
		vertical_velocity: float,
		delta: float,
		jump_pressed: bool,
) -> Dictionary:
	if absf(move.x) > 0.04:
		yaw += move.x * TURN_SPEED * delta

	var next := position
	var velocity_y := vertical_velocity
	var grounded := next.y <= 1.01
	if grounded:
		next.y = 1.0
		velocity_y = 0.0
		if jump_pressed:
			velocity_y = JUMP_VELOCITY
	else:
		velocity_y -= GRAVITY * delta

	var throttle := -move.y
	if absf(throttle) > 0.04:
		var forward := ActionNetcodeHitscan.yaw_to_forward(yaw)
		next += forward * throttle * MOVE_SPEED * delta

	next.y += velocity_y * delta
	next.x = clampf(next.x, -ARENA_HALF_EXTENTS.x + 1.0, ARENA_HALF_EXTENTS.x - 1.0)
	next.z = clampf(next.z, -ARENA_HALF_EXTENTS.z + 1.0, ARENA_HALF_EXTENTS.z - 1.0)
	next.y = clampf(next.y, 1.0, ARENA_HALF_EXTENTS.y)
	return {
		"position": next,
		"yaw": yaw,
		"vertical_velocity": velocity_y,
	}


## Kept for callers that still use the old name during migration.
static func apply_move(
		position: Vector3,
		move: Vector2,
		vertical_velocity: float,
		delta: float,
		jump_pressed: bool,
		yaw: float = 0.0,
) -> Dictionary:
	return apply_tank_move(position, yaw, move, vertical_velocity, delta, jump_pressed)


func build_result(participant_ids: PackedStringArray) -> MinigameResult:
	var ranked := _rank_by_score(participant_ids)
	return _result_from_ranked(ranked)


func should_end_round() -> bool:
	return not winner_player_id.is_empty() or elapsed_sec >= ROUND_DURATION_SEC


func _try_hitscan(shooter_id: String, eligible_participants: Dictionary) -> void:
	if float(fire_cooldown_by_player_id.get(shooter_id, 0.0)) > 0.0:
		return

	var origin := get_position(shooter_id) + Vector3(0.0, CHEST_HEIGHT, 0.0)
	var direction := ActionNetcodeHitscan.yaw_to_forward(get_yaw(shooter_id))
	var best_target := ""
	var best_distance := HITSCAN_RANGE + 1.0

	for target_id in positions_by_player_id.keys():
		if target_id == shooter_id:
			continue
		if not is_alive(target_id):
			continue
		if not eligible_participants.is_empty() and not eligible_participants.has(target_id):
			continue
		if not ActionNetcodeHitscan.ray_hits_capsule(
			origin,
			direction,
			get_position(target_id),
			PLAYER_RADIUS,
			PLAYER_HEIGHT,
			HITSCAN_RANGE,
		):
			continue
		var distance := origin.distance_to(get_position(target_id))
		if distance < best_distance:
			best_distance = distance
			best_target = target_id

	fire_cooldown_by_player_id[shooter_id] = FIRE_COOLDOWN_SEC
	if best_target == "":
		return

	var remaining := int(health_by_player_id.get(best_target, 0)) - HITSCAN_DAMAGE
	health_by_player_id[best_target] = maxi(0, remaining)
	if remaining <= 0:
		eliminations_by_player_id[shooter_id] = int(eliminations_by_player_id.get(shooter_id, 0)) + 1


func _check_last_player_standing() -> void:
	var alive_ids: Array[String] = []
	for player_id in positions_by_player_id.keys():
		if is_alive(player_id):
			alive_ids.append(player_id)
	if alive_ids.size() == 1:
		winner_player_id = alive_ids[0]


func _decay_fire_cooldowns(delta: float) -> void:
	for player_id in fire_cooldown_by_player_id.keys():
		var remaining := float(fire_cooldown_by_player_id[player_id]) - delta
		fire_cooldown_by_player_id[player_id] = maxf(0.0, remaining)


func _result_from_ranked(ranked: PackedStringArray) -> MinigameResult:
	var placements: Array = []
	var scores: Dictionary = {}
	for index in ranked.size():
		var group := PackedStringArray([ranked[index]])
		placements.append(group)
		scores[ranked[index]] = ranked.size() - index
	if not winner_player_id.is_empty() and ranked.size() > 0:
		scores[ranked[0]] = ranked.size() + 2
	return MinigameResult.completed(placements, scores)


func _rank_by_score(participant_ids: PackedStringArray) -> PackedStringArray:
	var entries: Array = []
	for player_id in participant_ids:
		entries.append(
			{
				"player_id": player_id,
				"eliminations": int(eliminations_by_player_id.get(player_id, 0)),
				"health": get_health(player_id),
			}
		)
	entries.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_elims := int(left.get("eliminations", 0))
			var right_elims := int(right.get("eliminations", 0))
			if left_elims != right_elims:
				return left_elims > right_elims
			return int(left.get("health", 0)) > int(right.get("health", 0))
	)
	var ranked := PackedStringArray()
	for entry in entries:
		ranked.append(String(entry.get("player_id", "")))
	return ranked


func _spawn_points_for_count(player_count: int) -> Array[Vector3]:
	match player_count:
		1:
			return [Vector3(-12.0, 1.0, -12.0)]
		2:
			return [Vector3(-12.0, 1.0, -12.0), Vector3(12.0, 1.0, 12.0)]
		3:
			return [
				Vector3(-12.0, 1.0, -12.0),
				Vector3(12.0, 1.0, -12.0),
				Vector3(0.0, 1.0, 12.0),
			]
		_:
			return [
				Vector3(-12.0, 1.0, -12.0),
				Vector3(12.0, 1.0, -12.0),
				Vector3(-12.0, 1.0, 12.0),
				Vector3(12.0, 1.0, 12.0),
			]
