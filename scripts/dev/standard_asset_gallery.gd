extends Node3D

const _BEAN_SCENE: PackedScene = preload(
	"res://assets/standard/characters/bean-static-prototype.glb"
)
const _BADGE_SCENE := preload("res://scenes/shared/player_identity_badge.tscn")
const _CAMERA_NAMES: Array[String] = ["Close", "Shared arena", "Board distance"]
const _CAMERA_POSITIONS: Array[Vector3] = [
	Vector3(0.0, 1.65, -4.5),
	Vector3(0.0, 2.35, -7.5),
	Vector3(0.0, 3.4, -11.5),
]

@onready var _camera: Camera3D = %Camera
@onready var _world_environment: WorldEnvironment = %WorldEnvironment
@onready var _identity_row: HBoxContainer = %IdentityRow
@onready var _state_label: Label = %StateLabel

var camera_preset := 1
var grayscale_enabled := false
var _bean_instances: Array[Node3D] = []


func _ready() -> void:
	_configure_environment()
	_create_identity_examples()
	set_camera_preset(camera_preset)
	_apply_argument_overrides()
	var capture_path := _capture_path_from_arguments()
	if not capture_path.is_empty():
		_capture_after_frames.call_deferred(capture_path)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_1:
			set_camera_preset(0)
		KEY_2:
			set_camera_preset(1)
		KEY_3:
			set_camera_preset(2)
		KEY_G:
			set_grayscale_enabled(not grayscale_enabled)


func set_camera_preset(preset: int) -> void:
	camera_preset = clampi(preset, 0, _CAMERA_POSITIONS.size() - 1)
	_camera.position = _CAMERA_POSITIONS[camera_preset]
	_camera.look_at(Vector3(0.0, 0.72, 0.0), Vector3.UP)
	_update_state_label()


func set_grayscale_enabled(enabled: bool) -> void:
	grayscale_enabled = enabled
	_world_environment.environment.adjustment_saturation = 0.0 if enabled else 1.0
	_update_state_label()


func get_bean_instance_count() -> int:
	return _bean_instances.size()


func _configure_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = StandardVisuals.CANVAS
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = StandardVisuals.TEXT_PRIMARY
	environment.ambient_light_energy = 0.65
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.0
	_world_environment.environment = environment


func _create_identity_examples() -> void:
	# The camera looks along +Z, so positive world X appears on screen left.
	var positions: Array[float] = [1.8, 0.6, -0.6, -1.8]
	for identity_index in StandardVisuals.IDENTITY_IDS.size():
		var bean := _BEAN_SCENE.instantiate() as Node3D
		bean.name = "Bean%s" % String(StandardVisuals.IDENTITY_IDS[identity_index]).capitalize()
		bean.position = Vector3(positions[identity_index], 0.0, 0.0)
		add_child(bean)
		StandardVisuals.apply_identity_material(
			bean,
			StandardVisuals.IDENTITY_MATERIALS[identity_index],
		)
		_bean_instances.append(bean)

		var marker := Sprite3D.new()
		marker.name = "Marker%s" % identity_index
		marker.texture = StandardVisuals.IDENTITY_ICONS[identity_index]
		marker.modulate = StandardVisuals.IDENTITY_COLORS[identity_index]
		marker.pixel_size = 0.004
		marker.position = Vector3(positions[identity_index], 1.68, 0.0)
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(marker)

		var group := VBoxContainer.new()
		group.alignment = BoxContainer.ALIGNMENT_CENTER
		var badge := _BADGE_SCENE.instantiate() as PlayerIdentityBadge
		badge.set_slot_color(StandardVisuals.IDENTITY_COLORS[identity_index])
		group.add_child(badge)
		var label := Label.new()
		label.text = String(StandardVisuals.IDENTITY_IDS[identity_index]).capitalize()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"ShellPrimary"
		group.add_child(label)
		_identity_row.add_child(group)


func _update_state_label() -> void:
	if not is_instance_valid(_state_label):
		return
	var color_mode := "3D grayscale" if grayscale_enabled else "full color"
	_state_label.text = "%s camera · %s" % [_CAMERA_NAMES[camera_preset], color_mode]


func _capture_path_from_arguments() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--asset-gallery-capture="):
			return argument.trim_prefix("--asset-gallery-capture=")
	return ""


func _apply_argument_overrides() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--asset-gallery-grayscale":
			set_grayscale_enabled(true)
		elif argument.begins_with("--asset-gallery-camera="):
			var value := argument.trim_prefix("--asset-gallery-camera=")
			if value.is_valid_int():
				set_camera_preset(int(value))


func _capture_after_frames(capture_path: String) -> void:
	for _frame in 30:
		await get_tree().process_frame
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		push_error("The active display driver cannot capture the asset gallery viewport.")
		get_tree().quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("The active renderer returned no asset gallery image.")
		get_tree().quit(1)
		return
	var error := image.save_png(capture_path)
	if error != OK:
		push_error("Could not save asset gallery capture to %s" % capture_path)
		get_tree().quit(1)
		return
	get_tree().quit()
