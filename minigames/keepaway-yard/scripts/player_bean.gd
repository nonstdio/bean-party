extends CharacterBody2D

signal bumped

const PLAYER_COLORS: Array[Color] = [
	Color(0.95, 0.45, 0.2),
	Color(0.25, 0.75, 0.95),
	Color(0.55, 0.9, 0.35),
	Color(0.9, 0.55, 0.95),
]

const PLAYER_SHAPES: Array[String] = ["O", "[]", "^", "H"]

var player_id: int = 0
var move_vector := Vector2.ZERO
var bump_cooldown_remaining: float = 0.0
var bump_active_remaining: float = 0.0
var bump_direction := Vector2.RIGHT
var is_bumping: bool = false

var move_speed: float = 260.0
var move_acceleration: float = 2200.0
var move_friction: float = 1800.0
var bump_speed: float = 520.0
var bump_duration: float = 0.14
var bump_cooldown: float = 1.1
var knockback_speed: float = 340.0
var knockback_duration: float = 0.2

var _body: Polygon2D
var _outline: Line2D
var _label: Label
var _cooldown_ring: Line2D
var _knockback_remaining: float = 0.0
var _knockback_velocity := Vector2.ZERO


func setup(new_player_id: int, spawn_position: Vector2) -> void:
	player_id = new_player_id
	global_position = spawn_position
	_build_visuals()
	queue_redraw()


func _build_visuals() -> void:
	_body = Polygon2D.new()
	_body.color = PLAYER_COLORS[player_id % PLAYER_COLORS.size()]
	_body.polygon = _shape_points(player_id)
	add_child(_body)

	_outline = Line2D.new()
	_outline.width = 3.0
	_outline.default_color = Color(1, 1, 1, 0.9)
	_outline.closed = true
	_outline.points = _body.polygon
	add_child(_outline)

	_label = Label.new()
	_label.text = "P%d %s" % [player_id + 1, PLAYER_SHAPES[player_id % PLAYER_SHAPES.size()]]
	_label.position = Vector2(-24, -38)
	add_child(_label)

	_cooldown_ring = Line2D.new()
	_cooldown_ring.width = 4.0
	_cooldown_ring.default_color = Color(1, 1, 1, 0.35)
	_cooldown_ring.closed = true
	_cooldown_ring.points = _ring_points(26.0)
	add_child(_cooldown_ring)


func _physics_process(delta: float) -> void:
	_update_timers(delta)

	if _knockback_remaining > 0.0:
		velocity = _knockback_velocity
		_knockback_remaining = maxf(_knockback_remaining - delta, 0.0)
	elif is_bumping:
		velocity = bump_direction.normalized() * bump_speed
	else:
		var target_velocity := move_vector.normalized() * move_speed
		velocity = velocity.move_toward(target_velocity, move_acceleration * delta)
		if move_vector == Vector2.ZERO:
			velocity = velocity.move_toward(Vector2.ZERO, move_friction * delta)

	move_and_slide()
	_update_cooldown_ring()


func set_move_input(direction: Vector2) -> void:
	if is_bumping or _knockback_remaining > 0.0:
		return
	move_vector = direction
	if direction != Vector2.ZERO:
		bump_direction = direction.normalized()


func try_start_bump() -> bool:
	if bump_cooldown_remaining > 0.0 or is_bumping or _knockback_remaining > 0.0:
		return false
	if bump_direction == Vector2.ZERO:
		bump_direction = Vector2.RIGHT
	is_bumping = true
	bump_active_remaining = bump_duration
	bump_cooldown_remaining = bump_cooldown
	bumped.emit()
	return true


func apply_knockback(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	_knockback_velocity = direction.normalized() * knockback_speed
	_knockback_remaining = knockback_duration
	is_bumping = false
	bump_active_remaining = 0.0


func get_bump_hit_radius() -> float:
	return 30.0


func is_bump_window_active() -> bool:
	return is_bumping


func get_cooldown_ratio() -> float:
	if bump_cooldown <= 0.0:
		return 0.0
	return clampf(bump_cooldown_remaining / bump_cooldown, 0.0, 1.0)


func _update_timers(delta: float) -> void:
	if bump_cooldown_remaining > 0.0:
		bump_cooldown_remaining = maxf(bump_cooldown_remaining - delta, 0.0)
	if bump_active_remaining > 0.0:
		bump_active_remaining = maxf(bump_active_remaining - delta, 0.0)
		if bump_active_remaining <= 0.0:
			is_bumping = false


func _update_cooldown_ring() -> void:
	var ratio := get_cooldown_ratio()
	_cooldown_ring.visible = ratio > 0.0
	if ratio <= 0.0:
		return
	var angle := TAU * ratio
	_cooldown_ring.points = _arc_points(28.0, angle)


func _shape_points(shape_id: int) -> PackedVector2Array:
	match shape_id % 4:
		0:
			return _circle_points(20.0, 16)
		1:
			return PackedVector2Array([
				Vector2(-18, -18), Vector2(18, -18), Vector2(18, 18), Vector2(-18, 18),
			])
		2:
			return PackedVector2Array([
				Vector2(0, -22), Vector2(20, 18), Vector2(-20, 18),
			])
		_:
			return PackedVector2Array([
				Vector2(0, -22), Vector2(16, -8), Vector2(22, 12),
				Vector2(0, 4), Vector2(-22, 12), Vector2(-16, -8),
			])
	return PackedVector2Array()


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _ring_points(radius: float) -> PackedVector2Array:
	return _circle_points(radius, 24)


func _arc_points(radius: float, arc: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var segments := maxi(int(ceil(arc / TAU * 24.0)), 3)
	for index in range(segments + 1):
		var angle := -PI / 2.0 + arc * float(index) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
