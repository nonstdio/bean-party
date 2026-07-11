class_name NetworkMinigameSession
extends Node

signal minigame_result_ready(result: MinigameResult)

const SNAPSHOT_ARENA_MANIFEST_PATH := "res://minigames/snapshot-arena/minigame.tres"
const SNAPSHOT_HZ := 20.0
const RECONCILE_DECAY_RATE := 12.0

var prediction_enabled: bool = true
var is_active: bool = false

var _runner: MinigameRunner
var _simulator: HostSnapshotSimulator = HostSnapshotSimulator.new()
var _input_source: MinigameInputSource
var _slots: Array[PlayerSlot] = []
var _local_player_ids: PackedStringArray = PackedStringArray()
var _remote_inputs: Dictionary = {}
var _display_positions: Dictionary = {}
var _target_positions: Dictionary = {}
var _predicted_positions: Dictionary = {}
var _correction_offsets: Dictionary = {}
var _local_input_ticks: Dictionary = {}
var _local_input_history: Dictionary = {}
var _latest_input_tick_by_player: Dictionary = {}
var _acked_input_tick_by_player: Dictionary = {}
var _prediction_tracker: HostSnapshotPredictionTracker = HostSnapshotPredictionTracker.new()
var _snapshot_accumulator: float = 0.0
var _snapshot_serial: int = 0
var _authoritative_snapshot_serial: int = 0
var _authoritative_snapshot_hash: int = 0
var _minigame_instance_id: String = ""
var _owns_local_player_ids: Dictionary = {}


func _ready() -> void:
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
	_sample_local_inputs(delta)
	_send_local_inputs_to_host()

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

	var manifest := load(SNAPSHOT_ARENA_MANIFEST_PATH) as MinigameManifest
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
	_remote_inputs.clear()
	_predicted_positions.clear()
	_correction_offsets.clear()
	_local_input_ticks.clear()
	_local_input_history.clear()
	_latest_input_tick_by_player.clear()
	_acked_input_tick_by_player.clear()
	_prediction_tracker.reset()
	_simulator.reset_for_player_ids(player_ids)
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
	_remote_inputs.clear()
	_display_positions.clear()
	_target_positions.clear()
	_predicted_positions.clear()
	_correction_offsets.clear()
	_local_input_ticks.clear()
	_local_input_history.clear()
	_latest_input_tick_by_player.clear()
	_acked_input_tick_by_player.clear()
	_owns_local_player_ids.clear()
	_prediction_tracker.reset()
	_minigame_instance_id = ""
	_authoritative_snapshot_serial = 0
	_authoritative_snapshot_hash = 0


func get_display_position(player_id: String) -> Vector2:
	return _display_positions.get(player_id, Vector2.ZERO)


func get_snapshot_hash() -> int:
	return _authoritative_snapshot_hash


func get_snapshot_serial() -> int:
	return _authoritative_snapshot_serial


func get_prediction_stats() -> Dictionary:
	return _prediction_tracker.export_stats()


func is_using_prediction() -> bool:
	return prediction_enabled and not is_authority() and is_networked()


func _predicts_local_player(player_id: String) -> bool:
	return (
		prediction_enabled
		and not is_authority()
		and _local_player_ids.has(player_id)
		and (is_networked() or is_active)
	)


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
		_remote_inputs.erase(slot.player_id)
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


func _send_local_inputs_to_host() -> void:
	if not is_networked() or is_authority():
		return

	for player_id in _local_player_ids:
		var player_key := String(player_id)
		var move := _input_source.get_move_vector(player_id)
		var input_tick: int = int(_local_input_ticks.get(player_key, 0))
		_rpc_submit_input.rpc_id(1, player_id, move.x, move.y, input_tick)


func _sample_local_inputs(delta: float) -> void:
	if _input_source == null:
		return

	for player_id in _local_player_ids:
		var player_key := String(player_id)
		var move := _input_source.get_move_vector(player_key)
		var input_tick := _advance_local_input_tick(player_key)
		if prediction_enabled and not is_authority():
			_record_local_input(player_key, input_tick, move, delta)
		if is_authority():
			_latest_input_tick_by_player[player_key] = input_tick
			_remote_inputs[player_id] = move


func _host_tick(delta: float) -> void:
	var inputs := _collect_host_inputs()
	var eligible_winners: Dictionary = {}
	for slot in _slots:
		if PlayerSlotConnectivity.is_participating(slot):
			eligible_winners[slot.player_id] = true
	_simulator.tick(inputs, delta, eligible_winners)
	_sync_display_from_simulator()

	_snapshot_accumulator += delta
	if _snapshot_accumulator < 1.0 / SNAPSHOT_HZ:
		if not _simulator.winner_player_id.is_empty():
			_snapshot_serial += 1
			_update_snapshot_input_acks()
			_broadcast_snapshot()
			_submit_host_result()
		return

	_snapshot_accumulator = 0.0
	_snapshot_serial += 1
	_update_snapshot_input_acks()
	_broadcast_snapshot()

	if not _simulator.winner_player_id.is_empty():
		_submit_host_result()


func _collect_host_inputs() -> Dictionary:
	var inputs: Dictionary = {}
	for slot in _slots:
		var player_id := slot.player_id
		if not PlayerSlotConnectivity.is_participating(slot):
			inputs[player_id] = Vector2.ZERO
			continue
		if _owns_local_player_ids.has(player_id) and _input_source != null:
			inputs[player_id] = _input_source.get_move_vector(player_id)
		else:
			inputs[player_id] = _remote_inputs.get(player_id, Vector2.ZERO)
	return inputs


func _broadcast_snapshot() -> void:
	var payload := _simulator.export_positions(_acked_input_tick_by_player)
	_publish_authoritative_snapshot(_snapshot_serial, payload)
	if is_networked():
		_rpc_apply_snapshot.rpc(_snapshot_serial, payload)


func _client_tick(delta: float) -> void:
	if prediction_enabled and not is_authority():
		_client_predict_local(delta)
	_client_interpolate_remotes(delta)


func _client_predict_local(delta: float) -> void:
	if _input_source == null:
		return

	for player_id in _local_player_ids:
		var player_key := String(player_id)
		var move := _input_source.get_move_vector(player_key)
		var position: Vector2 = _predicted_positions.get(
			player_key,
			_display_positions.get(player_key, Vector2.ZERO),
		)
		position = HostSnapshotSimulator.apply_move(position, move, delta)
		_predicted_positions[player_key] = position
		var offset: Vector2 = _correction_offsets.get(player_key, Vector2.ZERO)
		_display_positions[player_key] = position + offset
		var decay := clampf(delta * RECONCILE_DECAY_RATE, 0.0, 1.0)
		_correction_offsets[player_key] = offset.lerp(Vector2.ZERO, decay)


func _client_interpolate_remotes(delta: float) -> void:
	var blend := clampf(delta * SNAPSHOT_HZ, 0.0, 1.0)
	for player_id in _target_positions.keys():
		if _predicts_local_player(player_id):
			continue

		var from_pos: Vector2 = _display_positions.get(player_id, _target_positions[player_id])
		var to_pos: Vector2 = _target_positions[player_id]
		_display_positions[player_id] = from_pos.lerp(to_pos, blend)


func _sync_display_from_simulator() -> void:
	for player_id in _simulator.positions_by_player_id.keys():
		var position: Vector2 = _simulator.positions_by_player_id[player_id]
		_display_positions[player_id] = position
		_target_positions[player_id] = position


func _apply_snapshot_payload(serial: int, payload: Dictionary) -> void:
	if serial < _snapshot_serial:
		return
	_snapshot_serial = serial
	_simulator.load_positions(payload)
	_publish_authoritative_snapshot(serial, payload)
	for player_id in payload.keys():
		var player_key := String(player_id)
		var entry: Variant = payload[player_id]
		if entry is Dictionary:
			var target := Vector2(
				float(entry.get("x", 0.0)),
				float(entry.get("y", 0.0)),
			)
			_target_positions[player_key] = target
			if _predicts_local_player(player_key):
				var predicted_before: Vector2 = _predicted_positions.get(player_key, target)
				var acked_input_tick := int(entry.get("acked_input_tick", 0))
				_predicted_positions[player_key] = target
				_replay_unacked_inputs(player_key, acked_input_tick)
				var predicted_after: Vector2 = _predicted_positions[player_key]
				_prediction_tracker.record_correction(predicted_before, predicted_after)
				var correction := predicted_before - predicted_after
				if correction.length_squared() >= HostSnapshotPredictionTracker.CORRECTION_EPSILON * HostSnapshotPredictionTracker.CORRECTION_EPSILON:
					var offset: Vector2 = _correction_offsets.get(player_key, Vector2.ZERO)
					_correction_offsets[player_key] = offset + correction
				_display_positions[player_key] = predicted_after + _correction_offsets.get(player_key, Vector2.ZERO)
			elif not _display_positions.has(player_key):
				_display_positions[player_key] = target


func _init_predicted_positions() -> void:
	_predicted_positions.clear()
	if not prediction_enabled or is_authority():
		return

	for player_id in _local_player_ids:
		var position := _simulator.get_position(player_id)
		_predicted_positions[player_id] = position


func _publish_authoritative_snapshot(serial: int, payload: Dictionary) -> void:
	_authoritative_snapshot_serial = serial
	_authoritative_snapshot_hash = HostSnapshotSimulator.hash_positions(payload)


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


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_submit_input(player_id: String, move_x: float, move_y: float, input_tick: int) -> void:
	if not is_authority():
		return
	_host_apply_remote_input(
		multiplayer.get_remote_sender_id(),
		player_id,
		Vector2(move_x, move_y),
		input_tick,
	)


func _host_apply_remote_input(peer_id: int, player_id: String, move: Vector2, input_tick: int) -> void:
	if not _peer_owns_player(peer_id, player_id):
		return
	if not _player_id_is_participating(player_id):
		return
	var player_key := String(player_id)
	var latest_tick: int = int(_latest_input_tick_by_player.get(player_key, 0))
	if input_tick < latest_tick:
		return
	_remote_inputs[player_id] = move
	_latest_input_tick_by_player[player_key] = input_tick


func _update_snapshot_input_acks() -> void:
	for slot in _slots:
		var player_key := String(slot.player_id)
		_acked_input_tick_by_player[player_key] = _latest_input_tick_by_player.get(player_key, 0)


func _advance_local_input_tick(player_key: String) -> int:
	var next_tick: int = int(_local_input_ticks.get(player_key, 0)) + 1
	_local_input_ticks[player_key] = next_tick
	return next_tick


func _record_local_input(player_key: String, input_tick: int, move: Vector2, delta: float) -> void:
	var history: Array = _local_input_history.get(player_key, [])
	history.append(
		{
			"tick": input_tick,
			"move": move,
			"delta": delta,
		}
	)
	_local_input_history[player_key] = history


func _replay_unacked_inputs(player_key: String, acked_input_tick: int) -> void:
	var position: Vector2 = _predicted_positions.get(player_key, Vector2.ZERO)
	var history: Array = _local_input_history.get(player_key, [])
	var remaining: Array = []
	for entry in history:
		if entry is not Dictionary:
			continue

		var tick: int = int(entry.get("tick", 0))
		if tick <= acked_input_tick:
			continue

		var move: Vector2 = entry.get("move", Vector2.ZERO)
		if not move is Vector2:
			move = Vector2.ZERO
		var step_delta: float = float(entry.get("delta", 0.0))
		position = HostSnapshotSimulator.apply_move(position, move, step_delta)
		remaining.append(entry)

	_predicted_positions[player_key] = position
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


@rpc("authority", "call_remote", "unreliable")
func _rpc_apply_snapshot(serial: int, payload: Dictionary) -> void:
	if is_authority():
		return
	_apply_snapshot_payload(serial, payload)
