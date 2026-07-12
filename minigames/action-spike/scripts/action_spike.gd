extends MinigameController

const CAMERA_FOV := 78.0
const CAMERA_DISTANCE := 8.5
const CAMERA_HEIGHT := 3.6
const CAMERA_SHOULDER := 1.35
const CAMERA_SMOOTH := 10.0
const CAMERA_YAW_SMOOTH := 7.0
const CAMERA_FOCUS_SMOOTH := 14.0
const CAMERA_PIVOT_HEIGHT := 1.25
const CAMERA_PIVOT_Y_SMOOTH := 12.0
const CHARACTER_FOOT_OFFSET := 0.055
const _BEAN_SCENE: PackedScene = preload(
	"res://assets/standard/characters/bean-static-prototype.glb"
)

@onready var _players_root: Node3D = %PlayersRoot
@onready var _status: Label = %Status
@onready var _camera: Camera3D = %Camera3D
@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _crosshair: Label = %Crosshair
@onready var _remain_label: Label = %RemainLabel

var _network_session: NetworkActionMinigameSession = null
var _offline_simulator: HostActionSimulator = HostActionSimulator.new()
var _player_meshes: Dictionary = {}
var _player_body_materials: Dictionary = {}
var _camera_initialized: bool = false
var _camera_yaw: float = 0.0
var _smoothed_focus_xz: Vector3 = Vector3.ZERO
var _smoothed_pivot_y: float = CAMERA_PIVOT_HEIGHT


func _ready() -> void:
	_network_session = _find_network_session()
	_camera.fov = CAMERA_FOV
	_camera.current = true


func _process(delta: float) -> void:
	if state != State.RUNNING:
		return

	if _network_session == null or not _network_session.is_active:
		_tick_offline_simulator(delta)

	_update_status()
	_sync_player_meshes()
	_update_camera(delta)
	_update_hud()


func _on_minigame_setup() -> void:
	_clear_player_meshes()
	_offline_simulator = HostActionSimulator.new()
	_camera_initialized = false
	_camera_yaw = 0.0
	_smoothed_focus_xz = Vector3.ZERO
	_smoothed_pivot_y = CAMERA_PIVOT_HEIGHT
	_update_status()


func _on_minigame_start() -> void:
	_clear_player_meshes()
	_camera_initialized = false
	_camera_yaw = 0.0
	_smoothed_focus_xz = Vector3.ZERO
	_smoothed_pivot_y = CAMERA_PIVOT_HEIGHT
	var context := get_minigame_context()
	if context != null:
		_offline_simulator.reset_for_player_ids(context.get_player_ids())
	_update_status()


func _on_minigame_abort(reason: String) -> void:
	if is_node_ready():
		_status.text = "Round aborted: %s" % reason


func _update_status() -> void:
	if not is_node_ready():
		return

	var context := get_minigame_context()
	if context == null:
		return

	if _network_session != null and _network_session.is_active:
		var status := "Eliminate rivals. Snap %d hash %d" % [
			_network_session.get_snapshot_serial(),
			_network_session.get_snapshot_hash(),
		]
		if _network_session.is_using_prediction():
			var stats: Dictionary = _network_session.get_prediction_stats()
			status += " · pred corrections %d" % int(stats.get("correction_count", 0))
		_status.text = status
	else:
		_status.text = (
			"Move: W/S forward/back · A/D turn · Jump: accept/space/u/kp enter · Fire: click/F/O/kp 0"
		)


func _sync_player_meshes() -> void:
	var context := get_minigame_context()
	if context == null:
		return

	for player in context.get_players():
		var player_id := player.player_id
		var mesh_root: Node3D = _player_meshes.get(player_id)
		if mesh_root == null:
			mesh_root = _create_player_mesh(player_id, player.slot_color)
			_players_root.add_child(mesh_root)
			_player_meshes[player_id] = mesh_root

		var position := _resolve_player_position(player_id, context)
		mesh_root.position = position
		var yaw := _resolve_player_yaw(player_id)
		mesh_root.rotation.y = yaw

		var health := _resolve_player_health(player_id)
		var material := _player_body_materials.get(player_id) as StandardMaterial3D
		if material != null:
			material.albedo_color = player.slot_color if health > 0 else player.slot_color.darkened(0.55)
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if health > 0 else BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = 1.0 if health > 0 else 0.45


func _update_camera(delta: float) -> void:
	var context := get_minigame_context()
	if context == null:
		return

	var focus_player_id := _resolve_camera_player_id(context)
	if focus_player_id == "":
		return

	var focus_position := _resolve_camera_focus_position(focus_player_id, context)
	var target_yaw := _resolve_camera_yaw(focus_player_id)
	if not _camera_initialized:
		_camera_yaw = target_yaw
		_smoothed_focus_xz = Vector3(focus_position.x, 0.0, focus_position.z)
	else:
		_camera_yaw = lerp_angle(_camera_yaw, target_yaw, clampf(delta * CAMERA_YAW_SMOOTH, 0.0, 1.0))
	var focus_blend := clampf(delta * CAMERA_FOCUS_SMOOTH, 0.0, 1.0)
	_smoothed_focus_xz = _smoothed_focus_xz.lerp(
		Vector3(focus_position.x, 0.0, focus_position.z),
		focus_blend,
	)
	var airborne := _is_focus_player_airborne(focus_player_id, focus_position)
	var target_pivot_y := focus_position.y + 0.25 if airborne else CAMERA_PIVOT_HEIGHT
	if not _camera_initialized:
		_smoothed_pivot_y = target_pivot_y
	else:
		_smoothed_pivot_y = lerpf(
			_smoothed_pivot_y,
			target_pivot_y,
			clampf(delta * CAMERA_PIVOT_Y_SMOOTH, 0.0, 1.0),
		)
	var pivot := Vector3(_smoothed_focus_xz.x, _smoothed_pivot_y, _smoothed_focus_xz.z)
	var forward := ActionNetcodeHitscan.yaw_to_forward(_camera_yaw)
	var right := Vector3(forward.z, 0.0, -forward.x).normalized()
	var target_position := (
		pivot
		+ Vector3(0.0, CAMERA_HEIGHT, 0.0)
		- forward * CAMERA_DISTANCE
		+ right * CAMERA_SHOULDER
	)
	if not _camera_initialized:
		_camera.position = target_position
		_camera_initialized = true
	else:
		var blend := clampf(delta * CAMERA_SMOOTH, 0.0, 1.0)
		_camera.position = _camera.position.lerp(target_position, blend)
	_camera.look_at(pivot, Vector3.UP)


func _update_hud() -> void:
	var context := get_minigame_context()
	if context == null:
		return

	var alive_count := 0
	for player in context.get_players():
		if _resolve_player_health(player.player_id) > 0:
			alive_count += 1
	_remain_label.text = "%d remain" % alive_count

	var focus_player_id := _resolve_camera_player_id(context)
	if focus_player_id == "":
		return
	var health := _resolve_player_health(focus_player_id)
	_health_bar.max_value = HostActionSimulator.MAX_HEALTH
	_health_bar.value = health
	_health_label.text = str(health)
	_crosshair.modulate.a = 1.0 if health > 0 else 0.35


func _resolve_camera_player_id(context: MinigameContext) -> String:
	if _network_session != null and _network_session.is_active:
		var local_ids := _network_session.get_local_player_ids()
		if not local_ids.is_empty():
			return String(local_ids[0])

	var local_peer_id := _resolve_local_peer_id()
	for player in context.get_players():
		if player.owning_peer_id == local_peer_id:
			return player.player_id

	var player_ids := context.get_player_ids()
	if player_ids.is_empty():
		return ""
	return String(player_ids[0])


func _resolve_local_peer_id() -> int:
	var match_session := get_tree().root.find_child("MatchSession", true, false)
	if match_session is MatchSession and match_session.is_session_established():
		return match_session.multiplayer.get_unique_id()
	return MatchConstants.OFFLINE_PEER_ID


func _resolve_camera_yaw(player_id: String) -> float:
	if _network_session != null and _network_session.is_active:
		if _network_session.is_local_player(player_id):
			return _network_session.get_local_display_yaw(player_id)
	return _resolve_player_yaw(player_id)


func _resolve_camera_focus_position(player_id: String, context: MinigameContext) -> Vector3:
	if _network_session != null and _network_session.is_active and _network_session.is_using_prediction():
		if _network_session.is_local_player(player_id):
			return _network_session.get_local_camera_position(player_id)
	return _resolve_player_position(player_id, context)


func _is_focus_player_airborne(player_id: String, focus_position: Vector3) -> bool:
	if _network_session != null and _network_session.is_active and _network_session.is_using_prediction():
		if _network_session.is_local_player(player_id):
			return _network_session.is_local_player_airborne(player_id)
	return HostActionSimulator.is_airborne(focus_position, 0.0)


func _resolve_player_position(player_id: String, context: MinigameContext) -> Vector3:
	if _network_session != null and _network_session.is_active:
		return _network_session.get_display_position(player_id)
	return _offline_simulator.get_position(player_id)


func _resolve_player_yaw(player_id: String) -> float:
	if _network_session != null and _network_session.is_active:
		if _network_session.is_using_prediction() and _network_session.is_local_player(player_id):
			return _network_session.get_local_display_yaw(player_id)
		var state: Dictionary = _network_session.get_display_player_state(player_id)
		return float(state.get("yaw", 0.0))
	return _offline_simulator.get_yaw(player_id)


func _resolve_player_health(player_id: String) -> int:
	if _network_session != null and _network_session.is_active:
		var state: Dictionary = _network_session.get_display_player_state(player_id)
		return int(state.get("health", HostActionSimulator.MAX_HEALTH))
	return _offline_simulator.get_health(player_id)


func _tick_offline_simulator(delta: float) -> void:
	var context := get_minigame_context()
	if context == null:
		return

	var inputs: Dictionary = {}
	var input_source := context.get_input_source()
	for player_id in context.get_player_ids():
		var move := input_source.get_move_vector(player_id)
		inputs[player_id] = {
			"move": move,
			"jump": input_source.get_action_strength(
				player_id,
				MinigameInputSource.ACTION_PRIMARY,
			) > 0.5,
			"fire": input_source.get_action_strength(
				player_id,
				MinigameInputSource.ACTION_SECONDARY,
			) > 0.5,
			"aim_yaw": _offline_simulator.get_yaw(player_id),
		}

	_offline_simulator.tick(inputs, delta, {})
	if _offline_simulator.should_end_round():
		submit_minigame_result(_offline_simulator.build_result(context.get_player_ids()))


func _create_player_mesh(player_id: String, color: Color) -> Node3D:
	var root := Node3D.new()
	var bean := _BEAN_SCENE.instantiate() as Node3D
	bean.name = "Bean"
	bean.position.y = -CHARACTER_FOOT_OFFSET
	root.add_child(bean)

	var material := StandardVisuals.identity_material_for_color(color).duplicate() as StandardMaterial3D
	_apply_identity_material(bean, material)
	_player_body_materials[player_id] = material

	var marker := Sprite3D.new()
	marker.name = "IdentityMarker"
	marker.texture = StandardVisuals.identity_icon_for_color(color)
	marker.modulate = color
	marker.pixel_size = 0.0035
	marker.position = Vector3(0.0, 1.95, 0.0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(marker)
	return root


func _apply_identity_material(bean: Node, identity_material: StandardMaterial3D) -> void:
	for node in bean.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material != null and source_material.resource_name == "identity_primary":
				mesh_instance.set_surface_override_material(surface_index, identity_material)


func _clear_player_meshes() -> void:
	for player_id in _player_meshes:
		var mesh_root: Node3D = _player_meshes[player_id]
		mesh_root.queue_free()
	_player_meshes.clear()
	_player_body_materials.clear()


func _find_network_session() -> NetworkActionMinigameSession:
	var node := get_tree().root.find_child("NetworkActionMinigameSession", true, false)
	if node is NetworkActionMinigameSession:
		return node
	return null
