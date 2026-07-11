extends MinigameController

const PLAYER_RADIUS := 16.0

@onready var _arena: Control = %Arena
@onready var _status: Label = %Status

var _network_session: NetworkMinigameSession = null
var _offline_positions: Dictionary = {}


func _ready() -> void:
	_network_session = _find_network_session()
	_arena.draw.connect(_on_arena_draw)


func _process(delta: float) -> void:
	if state != State.RUNNING:
		return

	if _network_session == null or not _network_session.is_active:
		_tick_offline_positions(delta)

	_update_status()
	_arena.queue_redraw()


func _on_minigame_setup() -> void:
	_offline_positions.clear()
	_update_status()


func _on_minigame_start() -> void:
	_offline_positions.clear()
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
		_status.text = "Reach the center goal. Snap %d hash %d" % [
			_network_session.get_snapshot_serial(),
			_network_session.get_snapshot_hash(),
		]
	else:
		_status.text = "Reach the center goal with move inputs."


func _on_arena_draw() -> void:
	var context := get_minigame_context()
	if context == null:
		return

	var arena_size := HostSnapshotSimulator.ARENA_SIZE
	_arena.draw_rect(Rect2(Vector2.ZERO, arena_size), Color(0.08, 0.12, 0.16))
	_arena.draw_circle(
		HostSnapshotSimulator.GOAL_CENTER,
		HostSnapshotSimulator.GOAL_RADIUS,
		Color(0.28, 0.78, 0.48, 0.35),
	)

	for player in context.get_players():
		var position: Vector2 = _resolve_player_position(player.player_id, context)
		_arena.draw_circle(position, PLAYER_RADIUS, player.slot_color)
		_arena.draw_arc(
			position,
			PLAYER_RADIUS + 2.0,
			0.0,
			TAU,
			32,
			Color(0.95, 0.95, 0.95, 0.8),
			2.0,
		)


func _resolve_player_position(player_id: String, context: MinigameContext) -> Vector2:
	if _network_session != null and _network_session.is_active:
		return _network_session.get_display_position(player_id)

	return _offline_positions.get(
		player_id,
		_spawn_position_for_player(player_id, context),
	) as Vector2


func _tick_offline_positions(delta: float) -> void:
	var context := get_minigame_context()
	if context == null:
		return

	var input_source := context.get_input_source()
	for player_id in context.get_player_ids():
		var move: Vector2 = input_source.get_move_vector(player_id)
		var current: Vector2 = _offline_positions.get(
			player_id,
			_spawn_position_for_player(player_id, context),
		) as Vector2
		current += move * HostSnapshotSimulator.MOVE_SPEED * delta
		current.x = clampf(
			current.x,
			PLAYER_RADIUS,
			HostSnapshotSimulator.ARENA_SIZE.x - PLAYER_RADIUS,
		)
		current.y = clampf(
			current.y,
			PLAYER_RADIUS,
			HostSnapshotSimulator.ARENA_SIZE.y - PLAYER_RADIUS,
		)
		_offline_positions[player_id] = current

		if current.distance_to(HostSnapshotSimulator.GOAL_CENTER) <= HostSnapshotSimulator.GOAL_RADIUS:
			_finish_with_winner(player_id)
			return


func _spawn_position_for_player(player_id: String, context: MinigameContext) -> Vector2:
	var ids := context.get_player_ids()
	var index := ids.find(player_id)
	if index < 0:
		index = 0
	var simulator := HostSnapshotSimulator.new()
	simulator.reset_for_player_ids(ids)
	return simulator.get_position(player_id)


func _finish_with_winner(winner_id: String) -> void:
	var context := get_minigame_context()
	var simulator := HostSnapshotSimulator.new()
	simulator.reset_for_player_ids(context.get_player_ids())
	for player_id in context.get_player_ids():
		simulator.positions_by_player_id[player_id] = _offline_positions.get(
			player_id,
			simulator.get_position(player_id),
		)
	simulator.winner_player_id = winner_id
	submit_minigame_result(simulator.build_result(context.get_player_ids()))


func _find_network_session() -> NetworkMinigameSession:
	var node := get_tree().root.find_child("NetworkMinigameSession", true, false)
	if node is NetworkMinigameSession:
		return node
	return null
