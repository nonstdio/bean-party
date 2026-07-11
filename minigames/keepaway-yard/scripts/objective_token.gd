extends Area2D

signal touched_by_player(player_id: int)

var holder_id: int = -1
var is_loose: bool = true

var _core: Polygon2D
var _halo: Line2D
var _label: Label
var _pulse_time: float = 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_build_visuals()


func _process(delta: float) -> void:
	_pulse_time += delta
	if is_loose:
		var pulse := 1.0 + sin(_pulse_time * 8.0) * 0.08
		scale = Vector2.ONE * pulse
		_label.text = "LOOSE"
	else:
		scale = Vector2.ONE
		_label.text = "P%d" % [holder_id + 1]


func set_loose() -> void:
	holder_id = -1
	is_loose = true
	_halo.default_color = Color(1.0, 0.95, 0.35, 0.95)
	_core.color = Color(1.0, 0.82, 0.2)


func attach_to_holder(new_holder_id: int) -> void:
	holder_id = new_holder_id
	is_loose = false
	_halo.default_color = Color(1, 1, 1, 0.95)
	_core.color = Color(1.0, 0.92, 0.45)


func follow_position(target_position: Vector2) -> void:
	position = target_position + Vector2(0, -8)


func _build_visuals() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)

	_core = Polygon2D.new()
	_core.polygon = _hex_points(12.0)
	_core.color = Color(1.0, 0.82, 0.2)
	add_child(_core)

	_halo = Line2D.new()
	_halo.width = 4.0
	_halo.closed = true
	_halo.points = _hex_points(16.0)
	_halo.default_color = Color(1.0, 0.95, 0.35, 0.95)
	add_child(_halo)

	_label = Label.new()
	_label.position = Vector2(-24, -34)
	add_child(_label)
	set_loose()


func _hex_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _on_body_entered(body: Node2D) -> void:
	if not is_loose:
		return
	if "player_id" in body:
		touched_by_player.emit(body.player_id)
