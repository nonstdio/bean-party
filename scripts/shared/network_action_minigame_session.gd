class_name NetworkActionMinigameSession
extends Node

signal minigame_result_ready(result: MinigameResult)

const ACTION_SPIKE_MANIFEST_PATH := "res://minigames/action-spike/minigame.tres"
const SNAPSHOT_HZ := 20.0
const SIM_TICK_HZ := 30.0
const RECONCILE_DECAY_RATE := 12.0
const AUTHORITY_BLEND_RATE := 0.3
const NEUTRAL_ACTION_INPUT := {
	"move": Vector2.ZERO,
	"jump": false,
	"fire": false,
	"aim_yaw": 0.0,
}

var is_active: bool = false

var _runner: MinigameRunner
var _simulator: HostActionSimulator = HostActionSimulator.new()
var _fixed_tick: ActionNetcodeFixedTick = ActionNetcodeFixedTick.new()
var _entity_registry: ActionNetcodeEntityRegistry = ActionNetcodeEntityRegistry.new()
var _input_buffer: ActionNetcodeInputBuffer = ActionNetcodeInputBuffer.new()
var _input_source: MinigameInputSource
var _slots: Array[PlayerSlot] = []
var _local_player_ids: PackedStringArray = PackedStringArray()
var _display_positions: Dictionary = {}
var _display_state: Dictionary = {}
var _target_positions: Dictionary = {}
var _predicted_positions: Dictionary = {}
var _predicted_yaw: Dictionary = {}
var _predicted_vertical_velocity: Dictionary = {}
var _correction_offsets: Dictionary = {}
var _local_input_ticks: Dictionary = {}
var _local_input_history: Dictionary = {}
var _processed_input_tick_by_player: Dictionary = {}
var _last_consumed_input_by_player: Dictionary = {}
var _prediction_tracker: HostSnapshotPredictionTracker = HostSnapshotPredictionTracker.new()
var _snapshot_accumulator: float = 0.0
var _snapshot_serial: int = 0
var _authoritative_snapshot_serial: int = 0
var _authoritative_snapshot_hash: int = 0
var _minigame_instance_id: String = ""
var _owns_local_player_ids: Dictionary = {}
var _acked_input_tick_by_player: Dictionary = {}


func _ready() -> void:
	_fixed_tick.tick_hz = SIM_TICK_HZ
	_runner = MinigameRunner.new()
	add_child(_runner)
	_runner.minigame_finished.connect(_on_minigame_finished)

	var match_session := _match_session()
	if match_session != null:
		match_session.peer_disconnected.connect(_on_peer_disconnected)


func _process(delta: float) -> void:
	if not is_active:
		return

	_poll_local_device_input()

	if is_authority():
		_host_tick(delta)
	else:
		_client_tick(delta)

	if _input_source != null:
		_input_source.finish_frame()


func start_minigame(slots: Array[PlayerSlot], minigame_instance_id: String) -> bool:
	stop_minigame()
	if slots.is_empty() or minigame_instance_id.is_empty():
		return false

	var manifest := load(ACTION_SPIKE_MANIFEST_PATH) as MinigameManifest
	if manifest == null:
		return false

	_slots.clear()
	_local_player_ids = PackedStringArray()
	_owns_local_player_ids.clear()
	for slot in slots:
		_slots.append(slot.duplicate_slot())
		if slot.owning_peer_id == _local_peer_id():
			_local_player_ids.append(slot.player_id)
			_owns_local_player_ids[slot.player_id] = true

	var player_ids := PackedStringArray()
	for slot in _slots:
		player_ids.append(slot.player_id)

	_input_source = MinigameInputSource.new(player_ids)
	_display_positions.clear()
	_predicted_positions.clear()
	_predicted_yaw.clear()
	_predicted_vertical_velocity.clear()
	_correction_offsets.clear()
	_local_input_ticks.clear()
	_local_input_history.clear()
	_processed_input_tick_by_player.clear()
	_last_consumed_input_by_player.clear()
	_acked_input_tick_by_player.clear()
	_prediction_tracker.reset()
	_input_buffer.clear()
	_fixed_tick.reset()
	_entity_registry.reset(minigame_instance_id)
	_simulator.reset_for_player_ids(player_ids)
	for player_id in player_ids:
		var position := _simulator.get_position(player_id)
		_entity_registry.register_player_avatar(player_id, 0, position)
	_snapshot_accumulator = 0.0
	_snapshot_serial = 0
	_minigame_instance_id = minigame_instance_id
	_sync_display_from_simulator()
	_init_predicted_positions()
	_publish_authoritative_snapshot(0, _simulator.export_positions())

	var context := MinigameContext.create(
		minigame_instance_id,
		_slots,
		{},
		hash(minigame_instance_id),
		_input_source,
	)
	if not _runner.load_minigame(manifest, context):
		stop_minigame()
		return false
	if not _runner.start_active_minigame():
		stop_minigame()
		return false

	is_active = true
	if is_authority() and is_networked():
		_snapshot_serial = 1
		_broadcast_snapshot()
	return true


func stop_minigame() -> void:
	if _runner != null and _runner.state != MinigameRunner.State.EMPTY:
		_runner.unload_minigame()
	is_active = false
	_input_source = null
	_slots.clear()
	_local_player_ids = PackedStringArray()
	_display_positions.clear()
	_display_state.clear()
	_target_positions.clear()
	_predicted_positions.clear()
	_predicted_yaw.clear()
	_predicted_vertical_velocity.clear()
	_correction_offsets.clear()
	_local_input_ticks.clear()
	_local_input_history.clear()
	_processed_input_tick_by_player.clear()
	_last_consumed_input_by_player.clear()
	_acked_input_tick_by_player.clear()
	_owns_local_player_ids.clear()
	_prediction_tracker.reset()
	_input_buffer.clear()
	_entity_registry.reset()
	_minigame_instance_id = ""
	_authoritative_snapshot_serial = 0
	_authoritative_snapshot_hash = 0


func get_display_position(player_id: String) -> Vector3:
	if is_using_prediction() and is_local_player(player_id):
		return get_local_visual_position(player_id)
	return _display_positions.get(player_id, Vector3.ZERO)


func get_local_visual_position(player_id: String) -> Vector3:
	if not is_local_player(player_id):
		return get_display_position(player_id)
	var position: Vector3 = _predicted_positions.get(
		player_id,
		_display_positions.get(player_id, Vector3.ZERO),
	)
	position.y = maxf(position.y, 1.0)
	return position


func get_local_vertical_velocity(player_id: String) -> float:
	if not is_local_player(player_id):
		return 0.0
	return float(_predicted_vertical_velocity.get(player_id, 0.0))


func get_local_camera_position(player_id: String) -> Vector3:
	return get_local_visual_position(player_id)


func is_local_player_airborne(player_id: String) -> bool:
	if not is_local_player(player_id):
		return false
	var position: Vector3 = _predicted_positions.get(player_id, Vector3.ZERO)
	var vertical_velocity := float(_predicted_vertical_velocity.get(player_id, 0.0))
	return HostActionSimulator.is_airborne(position, vertical_velocity)


func get_display_player_state(player_id: String) -> Dictionary:
	return _display_state.get(player_id, {})


func get_primary_local_player_id() -> String:
	if _local_player_ids.is_empty():
		return ""
	return String(_local_player_ids[0])


func get_local_player_ids() -> PackedStringArray:
	return _local_player_ids.duplicate()


func is_local_player(player_id: String) -> bool:
	return _local_player_ids.has(player_id)


func get_local_display_yaw(player_id: String) -> float:
	if is_local_player(player_id) and _predicted_yaw.has(player_id):
		return float(_predicted_yaw[player_id])
	var state: Dictionary = _display_state.get(player_id, {})
	return float(state.get("yaw", 0.0))


func get_snapshot_hash() -> int:
	return _authoritative_snapshot_hash


func get_snapshot_serial() -> int:
	return _authoritative_snapshot_serial


func get_prediction_stats() -> Dictionary:
	return _prediction_tracker.export_stats()


func get_entity_registry() -> ActionNetcodeEntityRegistry:
	return _entity_registry


func is_using_prediction() -> bool:
	return not is_authority() and is_networked()


func force_complete_round() -> void:
	if not is_authority() or not is_active:
		return
	_submit_host_result()


func mark_peer_inactive(peer_id: int) -> void:
	if not is_active:
		return
	if not PlayerSlotConnectivity.mark_peer_inactive(_slots, peer_id):
		return
	for slot in _slots:
		if slot.owning_peer_id != peer_id:
			continue
		_input_buffer.clear_player(slot.player_id)
		_processed_input_tick_by_player.erase(slot.player_id)
		_last_consumed_input_by_player.erase(slot.player_id)
		if _simulator.winner_player_id == slot.player_id:
			_simulator.winner_player_id = ""


func is_authority() -> bool:
	var match_session := _match_session()
	return match_session != null and match_session.is_server()


func _match_session() -> MatchSession:
	var parent := get_parent()
	if parent is MatchSession:
		return parent
	return null


func _local_peer_id() -> int:
	var match_session := _match_session()
	if match_session == null or not match_session.is_session_established():
		return MatchConstants.OFFLINE_PEER_ID
	return match_session.multiplayer.get_unique_id()


func _poll_local_device_input() -> void:
	if _input_source == null:
		return

	for player_id in _local_player_ids:
		var device_slot := _local_device_slot_for_player(player_id)
		var move := MinigameLocalDeviceInput.read_move_vector(device_slot)
		_input_source.set_action_strength(
			player_id,
			MinigameInputSource.ACTION_MOVE_LEFT,
			1.0 if move.x < -0.5 else 0.0,
		)
		_input_source.set_action_strength(
			player_id,
			MinigameInputSource.ACTION_MOVE_RIGHT,
			1.0 if move.x > 0.5 else 0.0,
		)
		_input_source.set_action_strength(
			player_id,
			MinigameInputSource.ACTION_MOVE_UP,
			1.0 if move.y < -0.5 else 0.0,
		)
		_input_source.set_action_strength(
			player_id,
			MinigameInputSource.ACTION_MOVE_DOWN,
			1.0 if move.y > 0.5 else 0.0,
		)
		var jump_pressed := MinigameLocalDeviceInput.read_jump_just_pressed(device_slot)
		_input_source.set_action_strength(
			player_id,
			MinigameInputSource.ACTION_PRIMARY,
			1.0 if jump_pressed else 0.0,
		)
		var fire_pressed := MinigameLocalDeviceInput.read_fire_pressed(device_slot)
		_input_source.set_action_strength(
			player_id,
			MinigameInputSource.ACTION_SECONDARY,
			1.0 if fire_pressed else 0.0,
		)


func _local_device_slot_for_player(player_id: String) -> int:
	var lobby := _lobby_session()
	if lobby != null:
		var device_slot := lobby.get_local_device_slot(player_id)
		if device_slot >= 0:
			return device_slot
	var local_index := _local_player_ids.find(player_id)
	if local_index < 0:
		return 0
	return local_index


func _lobby_session() -> NetworkLobbySession:
	var match_session := _match_session()
	if match_session == null:
		return null
	for child in match_session.get_children():
		if child is NetworkLobbySession:
			return child
	return null


func _sample_local_inputs_for_sim_step(sim_step: float) -> void:
	if _input_source == null:
		return

	for player_id in _local_player_ids:
		var player_key := String(player_id)
		var move := _input_source.get_move_vector(player_key)
		var jump := _input_source.get_action_strength(player_key, MinigameInputSource.ACTION_PRIMARY) > 0.5
		var fire := _input_source.get_action_strength(player_key, MinigameInputSource.ACTION_SECONDARY) > 0.5
		var aim_yaw := _resolve_aim_yaw(player_key, move)
		var input_tick := _advance_local_input_tick(player_key)
		var payload := {"move": move, "jump": jump, "fire": fire, "aim_yaw": aim_yaw}
		_input_buffer.record_input(player_key, input_tick, payload)
		if not is_authority():
			_record_local_input(player_key, input_tick, payload, sim_step)
			_send_sampled_input_to_host(player_key, input_tick, payload)


func _send_sampled_input_to_host(player_key: String, input_tick: int, payload: Dictionary) -> void:
	if not is_networked() or is_authority():
		return

	var move: Vector2 = payload.get("move", Vector2.ZERO)
	if not move is Vector2:
		move = Vector2.ZERO
	_rpc_submit_input.rpc_id(
		1,
		player_key,
		move.x,
		move.y,
		bool(payload.get("jump", false)),
		bool(payload.get("fire", false)),
		float(payload.get("aim_yaw", 0.0)),
		input_tick,
	)

	var history: Array = _local_input_history.get(player_key, [])
	var redundant_sent := 0
	for index in range(history.size() - 2, -1, -1):
		if redundant_sent >= 2:
			break
		var entry: Variant = history[index]
		if entry is not Dictionary:
			continue
		var redo_tick: int = int(entry.get("tick", 0))
		if redo_tick >= input_tick:
			continue
		var redo_payload: Dictionary = entry.get("payload", {})
		if redo_payload.is_empty():
			continue
		var redo_move: Vector2 = redo_payload.get("move", Vector2.ZERO)
		if not redo_move is Vector2:
			redo_move = Vector2.ZERO
		_rpc_submit_input.rpc_id(
			1,
			player_key,
			redo_move.x,
			redo_move.y,
			bool(redo_payload.get("jump", false)),
			bool(redo_payload.get("fire", false)),
			float(redo_payload.get("aim_yaw", 0.0)),
			redo_tick,
		)
		redundant_sent += 1


func _host_tick(delta: float) -> void:
	var tick_count := _fixed_tick.consume_ticks(delta)
	var step := 1.0 / SIM_TICK_HZ
	for _i in tick_count:
		_sample_local_inputs_for_sim_step(step)
		var inputs := _consume_simulation_inputs()
		var eligible_winners: Dictionary = {}
		for slot in _slots:
			if PlayerSlotConnectivity.is_participating(slot):
				eligible_winners[slot.player_id] = true
		_simulator.tick(inputs, step, eligible_winners)
		_sync_entity_registry_from_simulator()

	_sync_display_from_simulator()

	_snapshot_accumulator += delta
	if _snapshot_accumulator < 1.0 / SNAPSHOT_HZ:
		if _simulator.should_end_round():
			_snapshot_serial += 1
			_update_snapshot_input_acks()
			_broadcast_snapshot()
			_submit_host_result()
		return

	_snapshot_accumulator = 0.0
	_snapshot_serial += 1
	_update_snapshot_input_acks()
	_broadcast_snapshot()

	if _simulator.should_end_round():
		_submit_host_result()


func _consume_simulation_inputs() -> Dictionary:
	var inputs: Dictionary = {}
	for slot in _slots:
		var player_key := String(slot.player_id)
		if not PlayerSlotConnectivity.is_participating(slot):
			inputs[slot.player_id] = NEUTRAL_ACTION_INPUT.duplicate(true)
			continue
		var processed_tick: int = int(_processed_input_tick_by_player.get(player_key, 0))
		var next_tick: int = processed_tick + 1
		var payload: Dictionary = _input_buffer.get_input_at_tick(player_key, next_tick)
		if payload.is_empty():
			payload = _last_consumed_input_by_player.get(player_key, NEUTRAL_ACTION_INPUT)
			if payload is Dictionary:
				payload = payload.duplicate(true)
			else:
				payload = NEUTRAL_ACTION_INPUT.duplicate(true)
		else:
			payload = payload.duplicate(true)
			_processed_input_tick_by_player[player_key] = next_tick
			_last_consumed_input_by_player[player_key] = payload.duplicate(true)
		inputs[slot.player_id] = payload
	return inputs


func _client_predict_buffered_step(step: float) -> void:
	if _input_source == null:
		return

	for player_id in _local_player_ids:
		var player_key := String(player_id)
		var input_tick: int = int(_local_input_ticks.get(player_key, 0))
		if input_tick <= 0:
			continue
		var payload: Dictionary = _input_buffer.get_input_at_tick(player_key, input_tick)
		if payload.is_empty():
			continue
		_apply_predicted_input_step(player_key, payload, step)


func _apply_predicted_input_step(player_key: String, payload: Dictionary, step: float) -> void:
	var move: Vector2 = payload.get("move", Vector2.ZERO)
	if not move is Vector2:
		move = Vector2.ZERO
	var jump := bool(payload.get("jump", false))
	var position: Vector3 = _predicted_positions.get(
		player_key,
		_display_positions.get(player_key, Vector3.ZERO),
	)
	var yaw: float = float(
		_predicted_yaw.get(player_key, _display_state.get(player_key, {}).get("yaw", 0.0))
	)
	var vertical_velocity: float = float(_predicted_vertical_velocity.get(player_key, 0.0))
	var applied: Dictionary = HostActionSimulator.apply_tank_move(
		position,
		yaw,
		move,
		vertical_velocity,
		step,
		jump,
	)
	position = applied.get("position", position)
	yaw = float(applied.get("yaw", yaw))
	vertical_velocity = float(applied.get("vertical_velocity", vertical_velocity))
	_predicted_positions[player_key] = position
	_predicted_yaw[player_key] = yaw
	_predicted_vertical_velocity[player_key] = vertical_velocity
	_display_positions[player_key] = get_local_visual_position(player_key)


func _sync_entity_registry_from_simulator() -> void:
	for player_id in _simulator.positions_by_player_id.keys():
		var entity_id := _entity_registry.get_player_avatar_id(player_id)
		if entity_id == "":
			continue
		_entity_registry.update_entity_transform(
			entity_id,
			_simulator.get_position(player_id),
		)


func _broadcast_snapshot() -> void:
	var payload := _simulator.export_positions(_acked_input_tick_by_player)
	_publish_authoritative_snapshot(_snapshot_serial, payload)
	if is_networked():
		_rpc_apply_snapshot.rpc(_snapshot_serial, payload)


func _client_tick(delta: float) -> void:
	if not is_authority():
		var tick_count := _fixed_tick.consume_ticks(delta)
		var step := 1.0 / SIM_TICK_HZ
		for _i in tick_count:
			_sample_local_inputs_for_sim_step(step)
			_client_predict_buffered_step(step)
		_decay_correction_offsets(delta)
	_client_interpolate_remotes(delta)


func _client_predict_local_step(step: float) -> void:
	_client_predict_buffered_step(step)


func _decay_correction_offsets(delta: float) -> void:
	var decay := clampf(delta * RECONCILE_DECAY_RATE, 0.0, 1.0)
	for player_id in _local_player_ids:
		var player_key := String(player_id)
		var offset: Vector3 = _correction_offsets.get(player_key, Vector3.ZERO)
		offset.y = 0.0
		_correction_offsets[player_key] = offset.lerp(Vector3.ZERO, decay)


func _client_interpolate_remotes(delta: float) -> void:
	var blend := clampf(delta * SNAPSHOT_HZ, 0.0, 1.0)
	for player_id in _target_positions.keys():
		if _predicts_local_player(player_id):
			continue
		var from_pos: Vector3 = _display_positions.get(player_id, _target_positions[player_id])
		var to_pos: Vector3 = _target_positions[player_id]
		_display_positions[player_id] = from_pos.lerp(to_pos, blend)


func _sync_display_from_simulator() -> void:
	for player_id in _simulator.positions_by_player_id.keys():
		var position: Vector3 = _simulator.positions_by_player_id[player_id]
		_display_positions[player_id] = position
		_target_positions[player_id] = position
		_display_state[player_id] = {
			"health": _simulator.get_health(player_id),
			"yaw": _simulator.get_yaw(player_id),
			"eliminations": int(_simulator.eliminations_by_player_id.get(player_id, 0)),
		}


func _sync_display_state_from_payload(payload: Dictionary) -> void:
	for player_id in payload.keys():
		var entry: Variant = payload[player_id]
		if entry is not Dictionary:
			continue
		var player_key := String(player_id)
		_display_state[player_key] = {
			"health": int(entry.get("health", HostActionSimulator.MAX_HEALTH)),
			"yaw": float(entry.get("yaw", 0.0)),
			"eliminations": int(entry.get("eliminations", 0)),
		}


func _resolve_aim_yaw(player_key: String, _move: Vector2) -> float:
	if is_authority():
		return _simulator.get_yaw(player_key)
	if _predicted_yaw.has(player_key):
		return float(_predicted_yaw[player_key])
	var state: Dictionary = _display_state.get(player_key, {})
	return float(state.get("yaw", 0.0))


func _apply_snapshot_payload(serial: int, payload: Dictionary) -> void:
	if serial < _snapshot_serial:
		return
	_snapshot_serial = serial
	_simulator.load_positions(payload)
	_sync_display_state_from_payload(payload)
	_publish_authoritative_snapshot(serial, payload)
	for player_id in payload.keys():
		var player_key := String(player_id)
		var entry: Variant = payload[player_id]
		if entry is not Dictionary:
			continue
		var target := Vector3(
			float(entry.get("x", 0.0)),
			float(entry.get("y", 0.0)),
			float(entry.get("z", 0.0)),
		)
		_target_positions[player_key] = target
		if _predicts_local_player(player_key):
			var predicted_before: Vector3 = _predicted_positions.get(player_key, target)
			var acked_input_tick := int(entry.get("acked_input_tick", 0))
			var auth_yaw := float(entry.get("yaw", 0.0))
			var auth_vy := float(entry.get("vertical_velocity", 0.0))
			var client_vy := float(_predicted_vertical_velocity.get(player_key, auth_vy))
			var client_airborne := HostActionSimulator.is_airborne(predicted_before, client_vy)
			if client_airborne:
				_predicted_positions[player_key] = Vector3(target.x, predicted_before.y, target.z)
			else:
				_predicted_positions[player_key] = target
				_predicted_vertical_velocity[player_key] = auth_vy
			_predicted_yaw[player_key] = auth_yaw
			_replay_unacked_inputs(player_key, acked_input_tick)
			var predicted_after: Vector3 = _predicted_positions.get(player_key, target)
			var after_vy := float(_predicted_vertical_velocity.get(player_key, auth_vy))
			if HostActionSimulator.is_airborne(predicted_after, after_vy):
				predicted_after.y = maxf(predicted_after.y, 1.0)
			else:
				predicted_after.y = lerpf(predicted_after.y, target.y, AUTHORITY_BLEND_RATE)
			_predicted_positions[player_key] = predicted_after
			_prediction_tracker.record_correction(
				Vector2(predicted_before.x, predicted_before.z),
				Vector2(predicted_after.x, predicted_after.z),
			)
			_display_positions[player_key] = get_local_visual_position(player_key)
		elif not _display_positions.has(player_key):
			_display_positions[player_key] = target


func _init_predicted_positions() -> void:
	_predicted_positions.clear()
	_predicted_yaw.clear()
	_predicted_vertical_velocity.clear()
	if is_authority():
		return
	for player_id in _local_player_ids:
		var position := _simulator.get_position(player_id)
		_predicted_positions[player_id] = position
		_predicted_yaw[player_id] = _simulator.get_yaw(player_id)
		_predicted_vertical_velocity[player_id] = 0.0


func _publish_authoritative_snapshot(serial: int, payload: Dictionary) -> void:
	_authoritative_snapshot_serial = serial
	_authoritative_snapshot_hash = HostActionSimulator.hash_positions(payload)


func _submit_host_result() -> void:
	if not is_active or _runner == null:
		return
	var participant_ids := PackedStringArray()
	for slot in _slots:
		if PlayerSlotConnectivity.is_participating(slot):
			participant_ids.append(slot.player_id)
	var result := _simulator.build_result(participant_ids)
	var controller := _runner.get_active_controller()
	if controller != null and controller.state == MinigameController.State.RUNNING:
		controller.submit_minigame_result(result)


func _on_minigame_finished(result: MinigameResult) -> void:
	if not is_authority():
		return
	is_active = false
	call_deferred("_emit_minigame_result_ready", result)


func _emit_minigame_result_ready(result: MinigameResult) -> void:
	minigame_result_ready.emit(result)


func is_networked() -> bool:
	var match_session := _match_session()
	return match_session != null and match_session.is_session_established()


func _predicts_local_player(player_id: String) -> bool:
	return not is_authority() and _local_player_ids.has(player_id) and (is_networked() or is_active)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_submit_input(
		player_id: String,
		move_x: float,
		move_y: float,
		jump: bool,
		fire: bool,
		aim_yaw: float,
		input_tick: int,
) -> void:
	if not is_authority():
		return
	_host_apply_remote_input(
		multiplayer.get_remote_sender_id(),
		player_id,
		Vector2(move_x, move_y),
		jump,
		fire,
		aim_yaw,
		input_tick,
	)


func _host_apply_remote_input(
		peer_id: int,
		player_id: String,
		move: Vector2,
		jump: bool,
		fire: bool,
		aim_yaw: float,
		input_tick: int,
) -> void:
	if not _peer_owns_player(peer_id, player_id):
		return
	if not _player_id_is_participating(player_id):
		return
	var player_key := String(player_id)
	_input_buffer.record_input(
		player_key,
		input_tick,
		{
			"move": move,
			"jump": jump,
			"fire": fire,
			"aim_yaw": aim_yaw,
		},
	)


func _update_snapshot_input_acks() -> void:
	for slot in _slots:
		var player_key := String(slot.player_id)
		_acked_input_tick_by_player[player_key] = _processed_input_tick_by_player.get(player_key, 0)


func _advance_local_input_tick(player_key: String) -> int:
	var next_tick: int = int(_local_input_ticks.get(player_key, 0)) + 1
	_local_input_ticks[player_key] = next_tick
	return next_tick


func _record_local_input(player_key: String, input_tick: int, payload: Dictionary, delta: float) -> void:
	var history: Array = _local_input_history.get(player_key, [])
	history.append(
		{
			"tick": input_tick,
			"payload": payload.duplicate(true),
			"delta": delta,
		}
	)
	_local_input_history[player_key] = history


func _replay_unacked_inputs(player_key: String, acked_input_tick: int) -> void:
	var position: Vector3 = _predicted_positions.get(player_key, Vector3.ZERO)
	var yaw: float = float(_predicted_yaw.get(player_key, 0.0))
	var vertical_velocity: float = float(_predicted_vertical_velocity.get(player_key, 0.0))
	var history: Array = _local_input_history.get(player_key, [])
	var remaining: Array = []
	for entry in history:
		if entry is not Dictionary:
			continue
		var tick: int = int(entry.get("tick", 0))
		if tick <= acked_input_tick:
			continue
		var payload: Dictionary = entry.get("payload", {})
		var move: Vector2 = payload.get("move", Vector2.ZERO)
		if not move is Vector2:
			move = Vector2.ZERO
		var jump := bool(payload.get("jump", false))
		var step_delta: float = 1.0 / SIM_TICK_HZ
		var applied: Dictionary = HostActionSimulator.apply_tank_move(
			position,
			yaw,
			move,
			vertical_velocity,
			step_delta,
			jump,
		)
		position = applied.get("position", position)
		yaw = float(applied.get("yaw", yaw))
		vertical_velocity = float(applied.get("vertical_velocity", vertical_velocity))
		remaining.append(entry)
	_predicted_positions[player_key] = position
	_predicted_yaw[player_key] = yaw
	_predicted_vertical_velocity[player_key] = vertical_velocity
	_local_input_history[player_key] = remaining


func _peer_owns_player(peer_id: int, player_id: String) -> bool:
	for slot in _slots:
		if slot.player_id == player_id:
			return slot.owning_peer_id == peer_id
	return false


func _player_id_is_participating(player_id: String) -> bool:
	for slot in _slots:
		if slot.player_id == player_id:
			return PlayerSlotConnectivity.is_participating(slot)
	return false


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_authority():
		return
	mark_peer_inactive(peer_id)


@rpc("authority", "call_remote", "unreliable", 2)
func _rpc_apply_snapshot(serial: int, payload: Dictionary) -> void:
	if is_authority():
		return
	_apply_snapshot_payload(serial, payload)
