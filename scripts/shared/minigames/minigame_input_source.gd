class_name MinigameInputSource
extends RefCounted

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_UP: StringName = &"move_up"
const ACTION_MOVE_DOWN: StringName = &"move_down"
const ACTION_PRIMARY: StringName = &"primary"
const ACTION_SECONDARY: StringName = &"secondary"
const SUPPORTED_ACTIONS: Array[StringName] = [
	ACTION_MOVE_LEFT,
	ACTION_MOVE_RIGHT,
	ACTION_MOVE_UP,
	ACTION_MOVE_DOWN,
	ACTION_PRIMARY,
	ACTION_SECONDARY,
]

var _strengths_by_player_id: Dictionary = {}
var _just_pressed_by_player_id: Dictionary = {}


func _init(player_ids: PackedStringArray = PackedStringArray()) -> void:
	for player_id in player_ids:
		register_player(player_id)


func register_player(player_id: String) -> bool:
	if player_id.is_empty() or _strengths_by_player_id.has(player_id):
		return false

	var strengths: Dictionary = {}
	var just_pressed: Dictionary = {}
	for action in SUPPORTED_ACTIONS:
		strengths[action] = 0.0
		just_pressed[action] = false
	_strengths_by_player_id[player_id] = strengths
	_just_pressed_by_player_id[player_id] = just_pressed
	return true


func has_player(player_id: String) -> bool:
	return _strengths_by_player_id.has(player_id)


func get_player_ids() -> PackedStringArray:
	var player_ids := PackedStringArray()
	for player_id in _strengths_by_player_id:
		player_ids.append(String(player_id))
	player_ids.sort()
	return player_ids


## Shell-owned input routing calls this method. Minigames only read from this object.
func set_action_strength(player_id: String, action: StringName, strength: float) -> bool:
	if not has_player(player_id) or action not in SUPPORTED_ACTIONS:
		return false

	var strengths: Dictionary = _strengths_by_player_id[player_id]
	var previous := float(strengths.get(action, 0.0))
	var resolved := clampf(strength, 0.0, 1.0)
	strengths[action] = resolved
	_strengths_by_player_id[player_id] = strengths

	if previous <= 0.5 and resolved > 0.5:
		var just_pressed: Dictionary = _just_pressed_by_player_id[player_id]
		just_pressed[action] = true
		_just_pressed_by_player_id[player_id] = just_pressed
	return true


func get_action_strength(player_id: String, action: StringName) -> float:
	if not has_player(player_id) or action not in SUPPORTED_ACTIONS:
		return 0.0
	return float((_strengths_by_player_id[player_id] as Dictionary).get(action, 0.0))


func is_action_pressed(player_id: String, action: StringName) -> bool:
	return get_action_strength(player_id, action) > 0.5


func is_action_just_pressed(player_id: String, action: StringName) -> bool:
	if not has_player(player_id) or action not in SUPPORTED_ACTIONS:
		return false
	return bool((_just_pressed_by_player_id[player_id] as Dictionary).get(action, false))


func get_move_vector(player_id: String) -> Vector2:
	var vector := Vector2(
		(
			get_action_strength(player_id, ACTION_MOVE_RIGHT)
			- get_action_strength(player_id, ACTION_MOVE_LEFT)
		),
		(
			get_action_strength(player_id, ACTION_MOVE_DOWN)
			- get_action_strength(player_id, ACTION_MOVE_UP)
		),
	)
	return vector.limit_length(1.0)


## The shell calls this after one simulation frame has consumed edge-triggered inputs.
func finish_frame() -> void:
	for player_id in _just_pressed_by_player_id:
		var just_pressed: Dictionary = _just_pressed_by_player_id[player_id]
		for action in SUPPORTED_ACTIONS:
			just_pressed[action] = false
		_just_pressed_by_player_id[player_id] = just_pressed


func release_all() -> void:
	for player_id in _strengths_by_player_id:
		var strengths: Dictionary = _strengths_by_player_id[player_id]
		for action in SUPPORTED_ACTIONS:
			strengths[action] = 0.0
		_strengths_by_player_id[player_id] = strengths
	finish_frame()
