class_name KeepawayRules
extends RefCounted

enum Phase { BRIEFING, READY, COUNTDOWN, ACTIVE, RESULTS }

const ROUND_DURATION_SEC := 55.0
const COUNTDOWN_SEC := 3.0
const POINTS_PER_SECOND_HELD := 1.0
const BUMP_IMMUNITY_SEC := 0.6

var phase: Phase = Phase.BRIEFING
var player_count: int = 2
var holder_id: int = -1
var scores: PackedFloat32Array = PackedFloat32Array()
var time_remaining: float = ROUND_DURATION_SEC
var countdown_remaining: float = 0.0
var bump_immunity_remaining: PackedFloat32Array = PackedFloat32Array()
var elapsed_time: float = 0.0


func configure(new_player_count: int) -> void:
	player_count = clampi(new_player_count, 2, 4)
	reset()


func reset() -> void:
	phase = Phase.BRIEFING
	holder_id = -1
	scores = PackedFloat32Array()
	scores.resize(player_count)
	bump_immunity_remaining = PackedFloat32Array()
	bump_immunity_remaining.resize(player_count)
	time_remaining = ROUND_DURATION_SEC
	countdown_remaining = 0.0
	elapsed_time = 0.0


func advance_to_ready() -> void:
	phase = Phase.READY


func start_countdown() -> void:
	phase = Phase.COUNTDOWN
	countdown_remaining = COUNTDOWN_SEC


func begin_active_round() -> void:
	phase = Phase.ACTIVE
	time_remaining = ROUND_DURATION_SEC
	elapsed_time = 0.0


func tick(delta: float) -> void:
	_tick_immunity(delta)

	match phase:
		Phase.COUNTDOWN:
			countdown_remaining = maxf(countdown_remaining - delta, 0.0)
			if countdown_remaining <= 0.0:
				begin_active_round()
		Phase.ACTIVE:
			elapsed_time += delta
			time_remaining = maxf(time_remaining - delta, 0.0)
			if holder_id >= 0:
				scores[holder_id] += delta * POINTS_PER_SECOND_HELD
			if time_remaining <= 0.0:
				phase = Phase.RESULTS
		_:
			pass


func try_acquire_possession(player_id: int) -> bool:
	if phase != Phase.ACTIVE:
		return false
	if player_id < 0 or player_id >= player_count:
		return false
	if holder_id >= 0:
		return false
	holder_id = player_id
	return true


func apply_holder_bump(attacker_id: int) -> bool:
	if phase != Phase.ACTIVE:
		return false
	if holder_id < 0:
		return false
	if attacker_id < 0 or attacker_id >= player_count:
		return false
	if attacker_id == holder_id:
		return false
	if bump_immunity_remaining[holder_id] > 0.0:
		return false
	var former_holder := holder_id
	holder_id = -1
	bump_immunity_remaining[former_holder] = BUMP_IMMUNITY_SEC
	return true


func set_holder(player_id: int) -> void:
	if player_id >= -1 and player_id < player_count:
		holder_id = player_id


func get_rankings() -> Array:
	var entries: Array = []
	for player_id in range(player_count):
		entries.append({
			"player_id": player_id,
			"score": scores[player_id],
		})
	entries.sort_custom(_compare_rank_entries)
	return entries


func get_winners() -> Array:
	var rankings := get_rankings()
	if rankings.is_empty():
		return []
	var top_score: float = rankings[0]["score"]
	var winners: Array = []
	for entry in rankings:
		if is_equal_approx(entry["score"], top_score):
			winners.append(entry["player_id"])
		else:
			break
	return winners


func restart_round() -> void:
	for index in range(player_count):
		scores[index] = 0.0
		bump_immunity_remaining[index] = 0.0
	holder_id = -1
	time_remaining = ROUND_DURATION_SEC
	countdown_remaining = 0.0
	elapsed_time = 0.0
	phase = Phase.READY


func _tick_immunity(delta: float) -> void:
	for index in range(player_count):
		if bump_immunity_remaining[index] > 0.0:
			bump_immunity_remaining[index] = maxf(
				bump_immunity_remaining[index] - delta,
				0.0
			)


func _compare_rank_entries(left: Dictionary, right: Dictionary) -> bool:
	if left["score"] == right["score"]:
		return left["player_id"] < right["player_id"]
	return left["score"] > right["score"]
