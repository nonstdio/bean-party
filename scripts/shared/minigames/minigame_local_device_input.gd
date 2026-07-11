class_name MinigameLocalDeviceInput
extends RefCounted

## Shell-owned keyboard bindings for couch device slots 0–3.
## Device-slot mapping is local to each peer and is not replicated.

const SLOT_3_HORIZONTAL_KEYS := [KEY_KP_4, KEY_KP_6]
const SLOT_3_VERTICAL_KEYS := [KEY_KP_8, KEY_KP_2]

static var _jump_prev_held: Dictionary = {}


static func read_move_vector(device_slot: int) -> Vector2:
	var vector := Vector2.ZERO
	match device_slot:
		0:
			vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
			vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		1:
			vector.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
			vector.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
		2:
			vector.x = float(Input.is_key_pressed(KEY_L)) - float(Input.is_key_pressed(KEY_J))
			vector.y = float(Input.is_key_pressed(KEY_K)) - float(Input.is_key_pressed(KEY_I))
		3:
			vector.x = float(Input.is_key_pressed(KEY_KP_6)) - float(Input.is_key_pressed(KEY_KP_4))
			vector.y = float(Input.is_key_pressed(KEY_KP_2)) - float(Input.is_key_pressed(KEY_KP_8))
	return vector.limit_length(1.0)


static func reset_input_edge_state() -> void:
	_jump_prev_held.clear()


static func read_jump_just_pressed(device_slot: int) -> bool:
	if device_slot == 0:
		return Input.is_action_just_pressed("ui_accept")
	return _consume_jump_edge(device_slot, _is_jump_held(device_slot))


static func _is_jump_held(device_slot: int) -> bool:
	match device_slot:
		1:
			return Input.is_key_pressed(KEY_SPACE)
		2:
			return Input.is_key_pressed(KEY_U)
		3:
			return Input.is_key_pressed(KEY_KP_ENTER)
	return false


static func _consume_jump_edge(device_slot: int, is_held: bool) -> bool:
	var was_held := bool(_jump_prev_held.get(device_slot, false))
	_jump_prev_held[device_slot] = is_held
	return is_held and not was_held


static func read_fire_pressed(device_slot: int) -> bool:
	match device_slot:
		0:
			return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		1:
			return Input.is_key_pressed(KEY_F)
		2:
			return Input.is_key_pressed(KEY_O)
		3:
			return Input.is_key_pressed(KEY_KP_0)
	return false
